-- Customer recovery and trust foundation.
-- Cases record cancellations, returns, and disputes without pretending that
-- the platform itself has custody of merchant funds or can issue a refund.

create table if not exists public.order_cases (
  id uuid primary key default gen_random_uuid(),
  merchant_order_id uuid not null references public.merchant_orders(id) on delete cascade,
  opened_by_user_id uuid not null references public.profiles(id) on delete restrict,
  case_type text not null check (case_type in ('cancellation', 'return', 'dispute')),
  status text not null default 'open' check (status in ('open', 'reviewing', 'approved', 'rejected', 'resolved')),
  reason text not null,
  requested_quantity integer check (requested_quantity is null or requested_quantity > 0),
  merchant_note text,
  resolution_note text,
  reviewed_by_user_id uuid references public.profiles(id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists order_cases_order_status_idx
  on public.order_cases(merchant_order_id, status, created_at desc);
create index if not exists order_cases_opener_idx
  on public.order_cases(opened_by_user_id, created_at desc);

alter table public.order_cases enable row level security;
grant select on public.order_cases to authenticated;

drop policy if exists order_cases_participant_read on public.order_cases;
create policy order_cases_participant_read
on public.order_cases for select to authenticated
using (
  opened_by_user_id = (select auth.uid())
  or exists (
    select 1 from public.merchant_orders o
    where o.id = merchant_order_id
      and (o.merchant_id in (select private.current_merchant_ids()) or private.is_admin())
  )
);

drop policy if exists order_cases_customer_insert on public.order_cases;
create policy order_cases_customer_insert
on public.order_cases for insert to authenticated
with check (
  opened_by_user_id = (select auth.uid())
  and exists (
    select 1 from public.merchant_orders o
    where o.id = merchant_order_id and o.customer_user_id = (select auth.uid())
  )
);

create or replace function private.open_order_case(
  p_merchant_order_id uuid,
  p_case_type text,
  p_reason text,
  p_requested_quantity integer default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, private, pg_catalog
as $$
declare
  v_user uuid := (select auth.uid());
  v_order merchant_orders%rowtype;
  v_case order_cases%rowtype;
begin
  if v_user is null then
    raise exception using errcode = '28000', message = 'AUTH_REQUIRED';
  end if;
  if p_case_type not in ('cancellation', 'return', 'dispute')
     or length(trim(coalesce(p_reason, ''))) < 5
     or (p_requested_quantity is not null and p_requested_quantity <= 0) then
    raise exception using errcode = 'P0001', message = 'INVALID_ORDER_CASE';
  end if;
  select * into v_order
  from merchant_orders
  where id = p_merchant_order_id
    and customer_user_id = v_user
  for update;
  if not found then
    raise exception using errcode = '42501', message = 'ORDER_NOT_FOUND';
  end if;
  if v_order.fulfilment_status in ('completed', 'cancelled') and p_case_type = 'cancellation' then
    raise exception using errcode = 'P0001', message = 'CANCELLATION_NOT_ALLOWED';
  end if;
  if exists (
    select 1 from order_cases
    where merchant_order_id = v_order.id
      and case_type = p_case_type
      and status in ('open', 'reviewing', 'approved')
  ) then
    raise exception using errcode = 'P0001', message = 'CASE_ALREADY_OPEN';
  end if;

  insert into order_cases(
    merchant_order_id, opened_by_user_id, case_type, reason, requested_quantity
  ) values (
    v_order.id, v_user, p_case_type, trim(p_reason), p_requested_quantity
  ) returning * into v_case;

  insert into audit_events(actor_user_id, action, resource_type, resource_id, metadata)
  values(v_user, 'order.case_opened', 'order_case', v_case.id::text,
         jsonb_build_object('merchant_order_id', v_order.id, 'case_type', p_case_type));
  return jsonb_build_object('case_id', v_case.id, 'status', v_case.status);
end;
$$;
revoke all on function private.open_order_case(uuid, text, text, integer) from public, anon;
grant execute on function private.open_order_case(uuid, text, text, integer) to authenticated, service_role;

create or replace function public.open_order_case(
  p_merchant_order_id uuid,
  p_case_type text,
  p_reason text,
  p_requested_quantity integer default null
)
returns jsonb
language sql
security invoker
set search_path = public, pg_catalog
as $$
  select private.open_order_case(p_merchant_order_id, p_case_type, p_reason, p_requested_quantity);
$$;
revoke all on function public.open_order_case(uuid, text, text, integer) from public, anon;
grant execute on function public.open_order_case(uuid, text, text, integer) to authenticated;

create or replace function private.review_order_case(
  p_case_id uuid,
  p_decision text,
  p_resolution_note text,
  p_merchant_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, private, pg_catalog
as $$
declare
  v_user uuid := (select auth.uid());
  v_case order_cases%rowtype;
  v_order merchant_orders%rowtype;
begin
  if v_user is null then
    raise exception using errcode = '28000', message = 'AUTH_REQUIRED';
  end if;
  if not private.has_role('merchant', null) and not private.is_admin() then
    raise exception using errcode = '42501', message = 'FORBIDDEN';
  end if;
  if p_decision not in ('approved', 'rejected', 'resolved')
     or (p_decision in ('rejected', 'resolved') and length(trim(coalesce(p_resolution_note, ''))) < 3) then
    raise exception using errcode = 'P0001', message = 'INVALID_CASE_REVIEW';
  end if;
  select c.* into v_case
  from order_cases c
  join merchant_orders o on o.id = c.merchant_order_id
  where c.id = p_case_id
    and (o.merchant_id in (select private.current_merchant_ids()) or private.is_admin())
  for update of c;
  if not found or v_case.status not in ('open', 'reviewing') then
    raise exception using errcode = 'P0001', message = 'CASE_REVIEW_NOT_ALLOWED';
  end if;

  select * into v_order from merchant_orders where id = v_case.merchant_order_id for update;
  update order_cases
  set status = p_decision,
      merchant_note = nullif(trim(coalesce(p_merchant_note, '')), ''),
      resolution_note = nullif(trim(coalesce(p_resolution_note, '')), ''),
      reviewed_by_user_id = v_user,
      reviewed_at = now(),
      updated_at = now()
  where id = v_case.id;

  if p_decision = 'approved' and v_case.case_type = 'cancellation'
     and v_order.fulfilment_status <> 'completed' then
    update merchant_orders set fulfilment_status = 'cancelled' where id = v_order.id;
    insert into order_status_history(
      merchant_order_id, actor_user_id, event_type, previous_value, next_value, reason
    ) values(v_order.id, v_user, 'cancellation_approved', v_order.fulfilment_status, 'cancelled', p_resolution_note);
  end if;

  insert into audit_events(actor_user_id, action, resource_type, resource_id, metadata)
  values(v_user, 'order.case_' || p_decision, 'order_case', v_case.id::text,
         jsonb_build_object('merchant_order_id', v_case.merchant_order_id, 'case_type', v_case.case_type));
  return jsonb_build_object('case_id', v_case.id, 'status', p_decision);
end;
$$;
revoke all on function private.review_order_case(uuid, text, text, text) from public, anon;
grant execute on function private.review_order_case(uuid, text, text, text) to authenticated, service_role;

create or replace function public.review_order_case(
  p_case_id uuid,
  p_decision text,
  p_resolution_note text,
  p_merchant_note text default null
)
returns jsonb
language sql
security invoker
set search_path = public, pg_catalog
as $$
  select private.review_order_case(p_case_id, p_decision, p_resolution_note, p_merchant_note);
$$;
revoke all on function public.review_order_case(uuid, text, text, text) from public, anon;
grant execute on function public.review_order_case(uuid, text, text, text) to authenticated;
