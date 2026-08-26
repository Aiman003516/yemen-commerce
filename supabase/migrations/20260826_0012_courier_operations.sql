-- Local fulfillment and courier operations.
-- Couriers can update handoff state but cannot alter payment state or inspect
-- payment proofs outside their assigned order scope.

alter table public.user_roles drop constraint if exists user_roles_role_allowed;
alter table public.user_roles add constraint user_roles_role_allowed
  check (role in ('customer','merchant','admin','creator','platform_operator','review_agent','support_agent','courier'));

alter table public.user_capabilities drop constraint if exists user_capabilities_capability_check;
alter table public.user_capabilities add constraint user_capabilities_capability_check
  check (capability in ('manage_people','manage_merchants','review_identity','manage_markets','manage_policies','manage_capabilities','view_audit','view_sensitive_evidence','manage_reports','export_operational_data','manage_fulfillment'));

create table if not exists public.courier_profiles (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  market_id uuid not null references public.markets(id) on delete restrict,
  display_name text not null,
  phone text not null,
  status text not null default 'active' check (status in ('active','suspended')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists courier_profiles_market_status_idx
  on public.courier_profiles(market_id, status);

create table if not exists public.order_courier_assignments (
  id uuid primary key default gen_random_uuid(),
  merchant_order_id uuid not null references public.merchant_orders(id) on delete cascade,
  courier_user_id uuid not null references public.courier_profiles(user_id) on delete restrict,
  assigned_by_user_id uuid not null references public.profiles(id) on delete restrict,
  status text not null default 'assigned' check (status in ('assigned','picked_up','out_for_delivery','delivered','failed','cancelled')),
  delivery_note text,
  failure_reason text,
  assigned_at timestamptz not null default now(),
  picked_up_at timestamptz,
  delivered_at timestamptz,
  updated_at timestamptz not null default now()
);
create unique index if not exists order_courier_active_unique
  on public.order_courier_assignments(merchant_order_id)
  where status in ('assigned','picked_up','out_for_delivery');
create index if not exists order_courier_courier_status_idx
  on public.order_courier_assignments(courier_user_id, status, updated_at desc);

alter table public.courier_profiles enable row level security;
alter table public.order_courier_assignments enable row level security;
grant select on public.courier_profiles, public.order_courier_assignments to authenticated;

drop policy if exists courier_profiles_self_read on public.courier_profiles;
create policy courier_profiles_self_read
on public.courier_profiles for select to authenticated
using (
  user_id = (select auth.uid())
  or private.is_admin()
  or exists (
    select 1 from public.merchant_orders o
    join public.order_courier_assignments assignment on assignment.merchant_order_id = o.id
    where assignment.courier_user_id = courier_profiles.user_id
      and o.merchant_id in (select private.current_merchant_ids())
  )
);

drop policy if exists order_courier_participant_read on public.order_courier_assignments;
create policy order_courier_participant_read
on public.order_courier_assignments for select to authenticated
using (
  courier_user_id = (select auth.uid())
  or exists (
    select 1 from public.merchant_orders o
    where o.id = merchant_order_id
      and (o.merchant_id in (select private.current_merchant_ids()) or o.customer_user_id = (select auth.uid()) or private.is_admin())
  )
);

create or replace function private.assign_order_courier(
  p_merchant_order_id uuid,
  p_courier_user_id uuid,
  p_delivery_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, private, pg_catalog
as $$
declare
  v_user uuid := (select auth.uid());
  v_order merchant_orders%rowtype;
  v_assignment order_courier_assignments%rowtype;
begin
  if v_user is null then
    raise exception using errcode = '28000', message = 'AUTH_REQUIRED';
  end if;
  if not private.has_role('merchant', null) and not private.is_admin() and not private.current_user_has_capability('manage_fulfillment', null) then
    raise exception using errcode = '42501', message = 'FORBIDDEN';
  end if;
  select * into v_order
  from merchant_orders
  where id = p_merchant_order_id
    and (merchant_id in (select private.current_merchant_ids()) or private.is_admin() or private.current_user_has_capability('manage_fulfillment', market_id))
  for update;
  if not found then
    raise exception using errcode = '42501', message = 'ORDER_NOT_FOUND';
  end if;
  if v_order.payment_status <> 'paid' or v_order.fulfilment_status in ('completed','cancelled') then
    raise exception using errcode = 'P0001', message = 'COURIER_ASSIGNMENT_NOT_ALLOWED';
  end if;
  if not exists (
    select 1 from courier_profiles courier
    join user_roles role on role.user_id = courier.user_id and role.role = 'courier'
    where courier.user_id = p_courier_user_id
      and courier.market_id = v_order.market_id
      and courier.status = 'active'
  ) then
    raise exception using errcode = 'P0001', message = 'COURIER_UNAVAILABLE';
  end if;

  insert into order_courier_assignments(
    merchant_order_id, courier_user_id, assigned_by_user_id, delivery_note
  ) values (
    v_order.id, p_courier_user_id, v_user, nullif(trim(coalesce(p_delivery_note, '')), '')
  ) returning * into v_assignment;

  if v_order.fulfilment_status <> 'arranged' then
    update merchant_orders set fulfilment_status = 'arranged' where id = v_order.id;
    insert into order_status_history(
      merchant_order_id, actor_user_id, event_type, previous_value, next_value, reason
    ) values(v_order.id, v_user, 'courier_assigned', v_order.fulfilment_status, 'arranged', p_delivery_note);
  end if;

  insert into audit_events(actor_user_id, action, resource_type, resource_id, metadata)
  values(v_user, 'fulfillment.courier_assigned', 'merchant_order', v_order.id::text,
         jsonb_build_object('courier_user_id', p_courier_user_id, 'assignment_id', v_assignment.id));
  return jsonb_build_object('assignment_id', v_assignment.id, 'status', v_assignment.status);
exception when unique_violation then
  raise exception using errcode = '23505', message = 'ACTIVE_COURIER_ASSIGNMENT_EXISTS';
end;
$$;
revoke all on function private.assign_order_courier(uuid, uuid, text) from public, anon;
grant execute on function private.assign_order_courier(uuid, uuid, text) to authenticated, service_role;

create or replace function public.assign_order_courier(
  p_merchant_order_id uuid,
  p_courier_user_id uuid,
  p_delivery_note text default null
)
returns jsonb
language sql
security invoker
set search_path = public, pg_catalog
as $$
  select private.assign_order_courier(p_merchant_order_id, p_courier_user_id, p_delivery_note);
$$;
revoke all on function public.assign_order_courier(uuid, uuid, text) from public, anon;
grant execute on function public.assign_order_courier(uuid, uuid, text) to authenticated;

create or replace function private.record_courier_handoff(
  p_assignment_id uuid,
  p_status text,
  p_delivery_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, private, pg_catalog
as $$
declare
  v_user uuid := (select auth.uid());
  v_assignment order_courier_assignments%rowtype;
  v_order merchant_orders%rowtype;
begin
  if v_user is null then
    raise exception using errcode = '28000', message = 'AUTH_REQUIRED';
  end if;
  select * into v_assignment
  from order_courier_assignments
  where id = p_assignment_id
    and (courier_user_id = v_user or private.is_admin() or exists (
      select 1 from merchant_orders o
      where o.id = merchant_order_id and o.merchant_id in (select private.current_merchant_ids())
    ))
  for update;
  if not found then
    raise exception using errcode = '42501', message = 'ASSIGNMENT_NOT_FOUND';
  end if;
  if p_status not in ('picked_up','out_for_delivery','delivered','failed') then
    raise exception using errcode = 'P0001', message = 'INVALID_HANDOFF_STATUS';
  end if;
  if v_assignment.status in ('delivered','failed','cancelled') then
    raise exception using errcode = 'P0001', message = 'HANDOFF_ALREADY_FINAL';
  end if;
  if p_status = 'failed' and length(trim(coalesce(p_delivery_note, ''))) < 3 then
    raise exception using errcode = 'P0001', message = 'FAILURE_REASON_REQUIRED';
  end if;

  update order_courier_assignments
  set status = p_status,
      delivery_note = coalesce(nullif(trim(p_delivery_note), ''), delivery_note),
      failure_reason = case when p_status = 'failed' then nullif(trim(p_delivery_note), '') else failure_reason end,
      picked_up_at = case when p_status = 'picked_up' and picked_up_at is null then now() else picked_up_at end,
      delivered_at = case when p_status = 'delivered' then now() else delivered_at end,
      updated_at = now()
  where id = v_assignment.id;

  select * into v_order from merchant_orders where id = v_assignment.merchant_order_id for update;
  if p_status = 'delivered' then
    update merchant_orders set fulfilment_status = 'completed' where id = v_order.id and v_order.payment_status = 'paid';
  end if;
  insert into order_status_history(
    merchant_order_id, actor_user_id, event_type, previous_value, next_value, reason
  ) values(v_order.id, v_user, 'courier_handoff', v_assignment.status, p_status, p_delivery_note);
  insert into audit_events(actor_user_id, action, resource_type, resource_id, metadata)
  values(v_user, 'fulfillment.courier_' || p_status, 'merchant_order', v_order.id::text,
         jsonb_build_object('assignment_id', v_assignment.id));
  return jsonb_build_object('assignment_id', v_assignment.id, 'status', p_status);
end;
$$;
revoke all on function private.record_courier_handoff(uuid, text, text) from public, anon;
grant execute on function private.record_courier_handoff(uuid, text, text) to authenticated, service_role;

create or replace function public.record_courier_handoff(
  p_assignment_id uuid,
  p_status text,
  p_delivery_note text default null
)
returns jsonb
language sql
security invoker
set search_path = public, pg_catalog
as $$
  select private.record_courier_handoff(p_assignment_id, p_status, p_delivery_note);
$$;
revoke all on function public.record_courier_handoff(uuid, text, text) from public, anon;
grant execute on function public.record_courier_handoff(uuid, text, text) to authenticated;
