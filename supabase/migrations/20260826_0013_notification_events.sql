-- Optional notification event module.
-- Events are durable, non-sensitive, and recipient-scoped. Delivery through
-- push/SMS/WhatsApp/email adapters can be added later without changing order
-- state transitions.

create table if not exists public.notification_events (
  id uuid primary key default gen_random_uuid(),
  recipient_user_id uuid not null references public.profiles(id) on delete cascade,
  kind text not null check (kind in ('order_status', 'payment_review', 'case_update', 'delivery_update', 'system')),
  payload jsonb not null default '{}'::jsonb,
  read_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists notification_events_recipient_idx
  on public.notification_events(recipient_user_id, read_at, created_at desc);

alter table public.notification_events enable row level security;
revoke all on public.notification_events from anon, authenticated;
grant select, update on public.notification_events to authenticated;

drop policy if exists notification_events_recipient_read on public.notification_events;
create policy notification_events_recipient_read
on public.notification_events for select to authenticated
using (recipient_user_id = (select auth.uid()));

drop policy if exists notification_events_recipient_update on public.notification_events;
create policy notification_events_recipient_update
on public.notification_events for update to authenticated
using (recipient_user_id = (select auth.uid()))
with check (recipient_user_id = (select auth.uid()));

create or replace function private.enqueue_order_status_notifications()
returns trigger
language plpgsql
security definer
set search_path = public, private, pg_catalog
as $$
declare
  v_order merchant_orders%rowtype;
  v_payload jsonb;
begin
  select * into v_order from merchant_orders where id = new.merchant_order_id;
  if not found then return new; end if;

  v_payload := jsonb_build_object(
    'merchant_order_id', v_order.id,
    'order_reference', v_order.order_reference,
    'event_type', new.event_type,
    'previous_value', new.previous_value,
    'next_value', new.next_value,
    'created_at', new.created_at
  );

  insert into notification_events(recipient_user_id, kind, payload)
  select distinct recipient_user_id, 'order_status', v_payload
  from (
    select v_order.customer_user_id as recipient_user_id
    union all
    select m.owner_user_id
    from merchants m
    where m.id = v_order.merchant_id
  ) recipients
  where recipient_user_id is not null;

  return new;
end;
$$;
revoke all on function private.enqueue_order_status_notifications() from public, anon, authenticated;
grant execute on function private.enqueue_order_status_notifications() to service_role;

drop trigger if exists order_status_notification_events on public.order_status_history;
create trigger order_status_notification_events
after insert on public.order_status_history
for each row execute function private.enqueue_order_status_notifications();

create or replace function private.mark_notification_read(p_notification_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, private, pg_catalog
as $$
declare
  v_id uuid;
begin
  update notification_events
  set read_at = coalesce(read_at, now())
  where id = p_notification_id and recipient_user_id = (select auth.uid())
  returning id into v_id;
  if v_id is null then
    raise exception using errcode = '42501', message = 'NOTIFICATION_NOT_FOUND';
  end if;
  return jsonb_build_object('notification_id', v_id, 'read', true);
end;
$$;
revoke all on function private.mark_notification_read(uuid) from public, anon, authenticated;
grant execute on function private.mark_notification_read(uuid) to authenticated, service_role;

create or replace function public.mark_notification_read(p_notification_id uuid)
returns jsonb
language sql
security invoker
set search_path = public, pg_catalog
as $$
  select private.mark_notification_read(p_notification_id);
$$;
revoke all on function public.mark_notification_read(uuid) from public, anon;
grant execute on function public.mark_notification_read(uuid) to authenticated;
