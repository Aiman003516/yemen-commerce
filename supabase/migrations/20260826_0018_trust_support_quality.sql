-- Trust, support, and merchant quality operations.
-- Risk signals are internal review inputs, not automatic bans or payment decisions.

create table if not exists public.support_tickets (
  id uuid primary key default gen_random_uuid(),
  opened_by_user_id uuid not null references public.profiles(id) on delete restrict,
  customer_user_id uuid references public.profiles(id) on delete restrict,
  merchant_id uuid references public.merchants(id) on delete restrict,
  merchant_order_id uuid references public.merchant_orders(id) on delete set null,
  category text not null check (category in ('order', 'payment', 'delivery', 'account', 'merchant', 'other')),
  subject text not null,
  description text not null,
  priority text not null default 'normal' check (priority in ('low', 'normal', 'high', 'urgent')),
  status text not null default 'open' check (status in ('open', 'in_progress', 'waiting_customer', 'resolved', 'closed')),
  assigned_to_user_id uuid references public.profiles(id) on delete set null,
  resolution_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (customer_user_id is not null or merchant_id is not null)
);
create index if not exists support_tickets_status_priority_idx
  on public.support_tickets(status, priority, updated_at desc);
create index if not exists support_tickets_customer_idx
  on public.support_tickets(customer_user_id, created_at desc);
create index if not exists support_tickets_merchant_idx
  on public.support_tickets(merchant_id, created_at desc);

create table if not exists public.risk_signals (
  id uuid primary key default gen_random_uuid(),
  signal_type text not null check (signal_type in ('duplicate_account', 'delivery_failure', 'coupon_abuse', 'review_pattern', 'payment_claim_pattern', 'courier_anomaly', 'other')),
  severity text not null default 'medium' check (severity in ('low', 'medium', 'high', 'critical')),
  customer_user_id uuid references public.profiles(id) on delete set null,
  merchant_id uuid references public.merchants(id) on delete set null,
  merchant_order_id uuid references public.merchant_orders(id) on delete set null,
  evidence jsonb not null default '{}'::jsonb,
  status text not null default 'open' check (status in ('open', 'reviewed', 'dismissed')),
  created_by_user_id uuid references public.profiles(id) on delete set null,
  resolved_by_user_id uuid references public.profiles(id) on delete set null,
  resolution_note text,
  created_at timestamptz not null default now(),
  resolved_at timestamptz,
  check (jsonb_typeof(evidence) = 'object' and length(evidence::text) <= 8000)
);
create index if not exists risk_signals_status_severity_idx
  on public.risk_signals(status, severity, created_at desc);
create index if not exists risk_signals_merchant_idx
  on public.risk_signals(merchant_id, created_at desc);

create table if not exists public.merchant_quality_snapshots (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  computed_by_user_id uuid references public.profiles(id) on delete set null,
  orders_count integer not null default 0 check (orders_count >= 0),
  completed_orders_count integer not null default 0 check (completed_orders_count >= 0),
  cancelled_orders_count integer not null default 0 check (cancelled_orders_count >= 0),
  disputed_orders_count integer not null default 0 check (disputed_orders_count >= 0),
  average_rating numeric(5,2) check (average_rating is null or average_rating between 0 and 5),
  score numeric(5,2) not null default 0 check (score between 0 and 100),
  explanation jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists merchant_quality_shop_created_idx
  on public.merchant_quality_snapshots(shop_id, created_at desc);

alter table public.support_tickets enable row level security;
alter table public.risk_signals enable row level security;
alter table public.merchant_quality_snapshots enable row level security;
grant select on public.support_tickets, public.risk_signals, public.merchant_quality_snapshots to authenticated;

drop policy if exists support_tickets_participant_read on public.support_tickets;
create policy support_tickets_participant_read
on public.support_tickets for select to authenticated
using (
  opened_by_user_id = (select auth.uid())
  or customer_user_id = (select auth.uid())
  or assigned_to_user_id = (select auth.uid())
  or merchant_id in (select private.current_merchant_ids())
  or private.is_admin()
  or private.has_role('support_agent', null)
);

drop policy if exists risk_signals_internal_read on public.risk_signals;
create policy risk_signals_internal_read
on public.risk_signals for select to authenticated
using (
  private.is_admin()
  or private.has_role('review_agent', null)
  or private.has_role('support_agent', null)
  or private.has_role('creator', null)
);

drop policy if exists merchant_quality_owner_read on public.merchant_quality_snapshots;
create policy merchant_quality_owner_read
on public.merchant_quality_snapshots for select to authenticated
using (
  private.is_admin()
  or exists (
    select 1 from public.shops s
    join public.merchants merchant on merchant.id = s.merchant_id
    where s.id = shop_id and merchant.owner_user_id = (select auth.uid())
  )
);

create or replace function private.open_support_ticket(
  p_category text,
  p_subject text,
  p_description text,
  p_priority text default 'normal',
  p_merchant_order_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, private, pg_catalog
as $$
declare
  v_user uuid := (select auth.uid());
  v_ticket support_tickets%rowtype;
  v_customer uuid := null;
  v_merchant uuid := null;
begin
  if v_user is null then raise exception using errcode = '28000', message = 'AUTH_REQUIRED'; end if;
  if p_category not in ('order','payment','delivery','account','merchant','other')
     or p_priority not in ('low','normal','high','urgent')
     or length(trim(coalesce(p_subject, ''))) < 3
     or length(trim(coalesce(p_description, ''))) < 8 then
    raise exception using errcode = 'P0001', message = 'INVALID_SUPPORT_TICKET';
  end if;
  if p_merchant_order_id is not null then
    select customer_user_id, merchant_id into v_customer, v_merchant
    from merchant_orders
    where id = p_merchant_order_id
      and (customer_user_id = v_user or merchant_id in (select private.current_merchant_ids()) or private.is_admin());
    if not found then raise exception using errcode = '42501', message = 'ORDER_NOT_FOUND'; end if;
  elsif exists(select 1 from merchants where owner_user_id = v_user) then
    select id into v_merchant from merchants where owner_user_id = v_user order by created_at desc limit 1;
  else
    v_customer := v_user;
  end if;

  insert into support_tickets(
    opened_by_user_id, customer_user_id, merchant_id, merchant_order_id,
    category, subject, description, priority
  ) values(
    v_user, v_customer, v_merchant, p_merchant_order_id,
    p_category, trim(p_subject), trim(p_description), p_priority
  ) returning * into v_ticket;

  insert into audit_events(actor_user_id, action, resource_type, resource_id, metadata)
  values(v_user, 'support.ticket_opened', 'support_ticket', v_ticket.id::text,
         jsonb_build_object('category', p_category, 'priority', p_priority));
  return jsonb_build_object('ticket_id', v_ticket.id, 'status', v_ticket.status);
end;
$$;
revoke all on function private.open_support_ticket(text, text, text, text, uuid) from public, anon;
grant execute on function private.open_support_ticket(text, text, text, text, uuid) to authenticated, service_role;

create or replace function public.open_support_ticket(
  p_category text,
  p_subject text,
  p_description text,
  p_priority text default 'normal',
  p_merchant_order_id uuid default null
)
returns jsonb
language sql
security invoker
set search_path = public, pg_catalog
as $$
  select private.open_support_ticket(p_category, p_subject, p_description, p_priority, p_merchant_order_id);
$$;
revoke all on function public.open_support_ticket(text, text, text, text, uuid) from public, anon;
grant execute on function public.open_support_ticket(text, text, text, text, uuid) to authenticated;

create or replace function private.review_support_ticket(
  p_ticket_id uuid,
  p_status text,
  p_resolution_note text default null,
  p_assigned_to_user_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, private, pg_catalog
as $$
declare
  v_user uuid := (select auth.uid());
  v_ticket support_tickets%rowtype;
begin
  if v_user is null then raise exception using errcode = '28000', message = 'AUTH_REQUIRED'; end if;
  if not private.is_admin() and not private.has_role('support_agent', null) then
    raise exception using errcode = '42501', message = 'FORBIDDEN';
  end if;
  if p_status not in ('open','in_progress','waiting_customer','resolved','closed') then
    raise exception using errcode = 'P0001', message = 'INVALID_SUPPORT_STATUS';
  end if;
  if p_status in ('resolved','closed') and length(trim(coalesce(p_resolution_note, ''))) < 3 then
    raise exception using errcode = 'P0001', message = 'RESOLUTION_NOTE_REQUIRED';
  end if;
  select * into v_ticket from support_tickets where id = p_ticket_id for update;
  if not found then raise exception using errcode = 'P0001', message = 'TICKET_NOT_FOUND'; end if;
  update support_tickets
  set status = p_status,
      assigned_to_user_id = coalesce(p_assigned_to_user_id, assigned_to_user_id),
      resolution_note = case when p_resolution_note is null then resolution_note else trim(p_resolution_note) end,
      updated_at = now()
  where id = p_ticket_id;
  insert into audit_events(actor_user_id, action, resource_type, resource_id, metadata)
  values(v_user, 'support.ticket_reviewed', 'support_ticket', p_ticket_id::text,
         jsonb_build_object('status', p_status));
  return jsonb_build_object('ticket_id', p_ticket_id, 'status', p_status);
end;
$$;
revoke all on function private.review_support_ticket(uuid, text, text, uuid) from public, anon;
grant execute on function private.review_support_ticket(uuid, text, text, uuid) to authenticated, service_role;

create or replace function public.review_support_ticket(
  p_ticket_id uuid,
  p_status text,
  p_resolution_note text default null,
  p_assigned_to_user_id uuid default null
)
returns jsonb
language sql
security invoker
set search_path = public, pg_catalog
as $$
  select private.review_support_ticket(p_ticket_id, p_status, p_resolution_note, p_assigned_to_user_id);
$$;
revoke all on function public.review_support_ticket(uuid, text, text, uuid) from public, anon;
grant execute on function public.review_support_ticket(uuid, text, text, uuid) to authenticated;

create or replace function private.review_risk_signal(
  p_signal_id uuid,
  p_decision text,
  p_resolution_note text
)
returns jsonb
language plpgsql
security definer
set search_path = public, private, pg_catalog
as $$
declare
  v_user uuid := (select auth.uid());
begin
  if v_user is null then raise exception using errcode = '28000', message = 'AUTH_REQUIRED'; end if;
  if not private.is_admin() and not private.has_role('review_agent', null) and not private.has_role('support_agent', null) then
    raise exception using errcode = '42501', message = 'FORBIDDEN';
  end if;
  if p_decision not in ('reviewed','dismissed') or length(trim(coalesce(p_resolution_note, ''))) < 3 then
    raise exception using errcode = 'P0001', message = 'INVALID_RISK_REVIEW';
  end if;
  update risk_signals
  set status = p_decision,
      resolved_by_user_id = v_user,
      resolution_note = trim(p_resolution_note),
      resolved_at = now()
  where id = p_signal_id and status = 'open';
  if not found then raise exception using errcode = 'P0001', message = 'RISK_SIGNAL_NOT_FOUND'; end if;
  insert into audit_events(actor_user_id, action, resource_type, resource_id, metadata)
  values(v_user, 'risk.signal_reviewed', 'risk_signal', p_signal_id::text,
         jsonb_build_object('decision', p_decision));
  return jsonb_build_object('signal_id', p_signal_id, 'status', p_decision);
end;
$$;
revoke all on function private.review_risk_signal(uuid, text, text) from public, anon;
grant execute on function private.review_risk_signal(uuid, text, text) to authenticated, service_role;

create or replace function public.review_risk_signal(
  p_signal_id uuid,
  p_decision text,
  p_resolution_note text
)
returns jsonb
language sql
security invoker
set search_path = public, pg_catalog
as $$
  select private.review_risk_signal(p_signal_id, p_decision, p_resolution_note);
$$;
revoke all on function public.review_risk_signal(uuid, text, text) from public, anon;
grant execute on function public.review_risk_signal(uuid, text, text) to authenticated;

create or replace function public.merchant_quality_summary(p_shop_id uuid)
returns jsonb
language plpgsql
security invoker
set search_path = public, pg_catalog
as $$
declare
  v_result jsonb;
begin
  if not exists(
    select 1 from shops s join merchants m on m.id = s.merchant_id
    where s.id = p_shop_id and (m.owner_user_id = (select auth.uid()) or private.is_admin())
  ) then
    raise exception using errcode = '42501', message = 'SHOP_NOT_OWNED';
  end if;
  select jsonb_build_object(
    'shop_id', p_shop_id,
    'orders_count', (select count(*) from merchant_orders where shop_id = p_shop_id),
    'completed_orders_count', (select count(*) from merchant_orders where shop_id = p_shop_id and fulfilment_status = 'completed'),
    'cancelled_orders_count', (select count(*) from merchant_orders where shop_id = p_shop_id and fulfilment_status = 'cancelled'),
    'disputed_orders_count', (select count(*) from order_cases c join merchant_orders o on o.id = c.merchant_order_id where o.shop_id = p_shop_id and c.case_type = 'dispute'),
    'average_rating', (select round(avg(rating)::numeric, 2) from product_reviews r join products p on p.id = r.product_id where p.shop_id = p_shop_id and r.status = 'approved'),
    'open_risk_signals_count', (select count(*) from risk_signals where merchant_id = (select merchant_id from shops where id = p_shop_id) and status = 'open'),
    'explanation', jsonb_build_object(
      'source', 'operational_aggregates',
      'note_ar', 'المؤشرات تفسيرية ولا تُستخدم للحظر الآلي أو تعديل المدفوعات.'
    )
  ) into v_result;
  return v_result;
end;
$$;
revoke all on function public.merchant_quality_summary(uuid) from public, anon;
grant execute on function public.merchant_quality_summary(uuid) to authenticated;
