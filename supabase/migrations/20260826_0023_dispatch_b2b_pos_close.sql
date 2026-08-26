-- Courier dispatch, B2B negotiated pricing, and POS close/reconciliation.
-- Pricing and POS records remain operational snapshots; no settlement or custody is introduced.

alter table public.wholesale_requests
  add column if not exists approved_price_list_id uuid;

create table if not exists public.wholesale_price_lists (
  id uuid primary key default gen_random_uuid(),
  merchant_id uuid not null references public.merchants(id) on delete cascade,
  shop_id uuid not null references public.shops(id) on delete cascade,
  name_ar text not null,
  currency text not null default 'YER',
  status text not null default 'draft' check (status in ('draft','active','paused')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists wholesale_price_lists_shop_status_idx
  on public.wholesale_price_lists(shop_id, status, updated_at desc);

alter table public.wholesale_requests
  add constraint wholesale_requests_price_list_fk
  foreign key (approved_price_list_id) references public.wholesale_price_lists(id) on delete set null;

create table if not exists public.wholesale_price_list_items (
  id uuid primary key default gen_random_uuid(),
  price_list_id uuid not null references public.wholesale_price_lists(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  variant_id uuid references public.product_variants(id) on delete cascade,
  unit_price_minor bigint not null check (unit_price_minor > 0),
  min_quantity integer not null default 1 check (min_quantity > 0),
  status text not null default 'active' check (status in ('active','paused')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(price_list_id, product_id, variant_id)
);
create index if not exists wholesale_price_list_items_product_idx
  on public.wholesale_price_list_items(product_id, status);

create table if not exists public.courier_dispatch_events (
  id uuid primary key default gen_random_uuid(),
  assignment_id uuid not null references public.order_courier_assignments(id) on delete cascade,
  merchant_order_id uuid not null references public.merchant_orders(id) on delete cascade,
  courier_user_id uuid not null references public.courier_profiles(user_id) on delete restrict,
  actor_user_id uuid not null references public.profiles(id) on delete restrict,
  event_type text not null check (event_type in ('assigned','picked_up','out_for_delivery','delivered','failed','cancelled','note')),
  note text,
  created_at timestamptz not null default now()
);
create index if not exists courier_dispatch_events_assignment_idx
  on public.courier_dispatch_events(assignment_id, created_at desc);

alter table public.pos_sessions
  add column if not exists expected_total_minor bigint not null default 0,
  add column if not exists counted_total_minor bigint,
  add column if not exists variance_minor bigint,
  add column if not exists reconciliation_status text not null default 'open';

alter table public.pos_sessions
  drop constraint if exists pos_sessions_reconciliation_status_check;
alter table public.pos_sessions
  add constraint pos_sessions_reconciliation_status_check
  check (reconciliation_status in ('open','reconciled','variance'));

alter table public.wholesale_price_lists enable row level security;
alter table public.wholesale_price_list_items enable row level security;
alter table public.courier_dispatch_events enable row level security;
grant select on public.wholesale_price_lists, public.wholesale_price_list_items, public.courier_dispatch_events to authenticated;

drop policy if exists wholesale_price_lists_owner_read on public.wholesale_price_lists;
create policy wholesale_price_lists_owner_read on public.wholesale_price_lists for select to authenticated
using (merchant_id in (select private.current_merchant_ids()) or private.is_admin());
drop policy if exists wholesale_price_list_items_owner_read on public.wholesale_price_list_items;
create policy wholesale_price_list_items_owner_read on public.wholesale_price_list_items for select to authenticated
using (exists(select 1 from wholesale_price_lists p where p.id = price_list_id and (p.merchant_id in (select private.current_merchant_ids()) or private.is_admin())));
drop policy if exists courier_dispatch_events_participant_read on public.courier_dispatch_events;
create policy courier_dispatch_events_participant_read on public.courier_dispatch_events for select to authenticated
using (courier_user_id = (select auth.uid()) or merchant_order_id in (select id from merchant_orders where merchant_id in (select private.current_merchant_ids())) or private.is_admin());

create or replace function private.save_wholesale_price_list(
  p_id uuid,
  p_shop_id uuid,
  p_name_ar text,
  p_currency text,
  p_status text,
  p_reason text
)
returns jsonb language plpgsql security definer set search_path = public, private, pg_catalog
as $$
declare v_user uuid := (select auth.uid()); v_merchant uuid; v_id uuid;
begin
  if v_user is null then raise exception using errcode = '28000', message = 'AUTH_REQUIRED'; end if;
  select merchant_id into v_merchant from shops where id = p_shop_id and merchant_id in (select private.current_merchant_ids());
  if v_merchant is null and not private.is_admin() then raise exception using errcode = '42501', message = 'SHOP_NOT_OWNED'; end if;
  if length(trim(coalesce(p_name_ar, ''))) < 2 or length(trim(coalesce(p_currency, ''))) < 3 or p_status not in ('draft','active','paused') or length(trim(coalesce(p_reason, ''))) < 3 then
    raise exception using errcode = 'P0001', message = 'INVALID_PRICE_LIST';
  end if;
  if p_id is null then
    insert into wholesale_price_lists(merchant_id, shop_id, name_ar, currency, status)
    values(coalesce(v_merchant, (select merchant_id from shops where id = p_shop_id)), p_shop_id, trim(p_name_ar), upper(trim(p_currency)), p_status)
    returning id into v_id;
  else
    update wholesale_price_lists set name_ar = trim(p_name_ar), currency = upper(trim(p_currency)), status = p_status, updated_at = now()
    where id = p_id and shop_id = p_shop_id and (merchant_id in (select private.current_merchant_ids()) or private.is_admin())
    returning id into v_id;
    if v_id is null then raise exception using errcode = 'P0001', message = 'PRICE_LIST_NOT_FOUND'; end if;
  end if;
  insert into audit_events(actor_user_id, action, resource_type, resource_id, metadata)
  values(v_user, 'b2b.price_list_saved', 'wholesale_price_list', v_id::text, jsonb_build_object('shop_id', p_shop_id, 'reason', trim(p_reason)));
  return jsonb_build_object('price_list_id', v_id, 'status', p_status);
end;
$$;
revoke all on function private.save_wholesale_price_list(uuid, uuid, text, text, text, text) from public, anon, authenticated;
grant execute on function private.save_wholesale_price_list(uuid, uuid, text, text, text, text) to authenticated, service_role;
create or replace function public.save_wholesale_price_list(p_id uuid, p_shop_id uuid, p_name_ar text, p_currency text, p_status text, p_reason text)
returns jsonb language sql security invoker set search_path = public, pg_catalog as $$ select private.save_wholesale_price_list(p_id, p_shop_id, p_name_ar, p_currency, p_status, p_reason); $$;
revoke all on function public.save_wholesale_price_list(uuid, uuid, text, text, text, text) from public, anon;
grant execute on function public.save_wholesale_price_list(uuid, uuid, text, text, text, text) to authenticated;

create or replace function private.save_wholesale_price_list_item(
  p_id uuid,
  p_price_list_id uuid,
  p_product_id uuid,
  p_variant_id uuid,
  p_unit_price_minor bigint,
  p_min_quantity integer,
  p_status text,
  p_reason text
)
returns jsonb language plpgsql security definer set search_path = public, private, pg_catalog
as $$
declare v_user uuid := (select auth.uid()); v_shop uuid; v_id uuid;
begin
  if v_user is null then raise exception using errcode = '28000', message = 'AUTH_REQUIRED'; end if;
  select shop_id into v_shop from wholesale_price_lists where id = p_price_list_id and (merchant_id in (select private.current_merchant_ids()) or private.is_admin());
  if v_shop is null then raise exception using errcode = '42501', message = 'PRICE_LIST_NOT_FOUND'; end if;
  if not exists(select 1 from products where id = p_product_id and shop_id = v_shop) then raise exception using errcode = 'P0001', message = 'PRODUCT_NOT_IN_SHOP'; end if;
  if p_variant_id is not null and not exists(select 1 from product_variants where id = p_variant_id and product_id = p_product_id) then raise exception using errcode = 'P0001', message = 'VARIANT_NOT_IN_PRODUCT'; end if;
  if p_unit_price_minor <= 0 or p_min_quantity <= 0 or p_status not in ('active','paused') or length(trim(coalesce(p_reason, ''))) < 3 then raise exception using errcode = 'P0001', message = 'INVALID_PRICE_ITEM'; end if;
  if p_id is null then
    insert into wholesale_price_list_items(price_list_id, product_id, variant_id, unit_price_minor, min_quantity, status)
    values(p_price_list_id, p_product_id, p_variant_id, p_unit_price_minor, p_min_quantity, p_status)
    returning id into v_id;
  else
    update wholesale_price_list_items set unit_price_minor = p_unit_price_minor, min_quantity = p_min_quantity, status = p_status, updated_at = now()
    where id = p_id and price_list_id = p_price_list_id returning id into v_id;
    if v_id is null then raise exception using errcode = 'P0001', message = 'PRICE_ITEM_NOT_FOUND'; end if;
  end if;
  insert into audit_events(actor_user_id, action, resource_type, resource_id, metadata)
  values(v_user, 'b2b.price_item_saved', 'wholesale_price_list_item', v_id::text, jsonb_build_object('price_list_id', p_price_list_id, 'reason', trim(p_reason)));
  return jsonb_build_object('price_list_item_id', v_id, 'status', p_status);
end;
$$;
revoke all on function private.save_wholesale_price_list_item(uuid, uuid, uuid, uuid, bigint, integer, text, text) from public, anon, authenticated;
grant execute on function private.save_wholesale_price_list_item(uuid, uuid, uuid, uuid, bigint, integer, text, text) to authenticated, service_role;
create or replace function public.save_wholesale_price_list_item(p_id uuid, p_price_list_id uuid, p_product_id uuid, p_variant_id uuid, p_unit_price_minor bigint, p_min_quantity integer, p_status text, p_reason text)
returns jsonb language sql security invoker set search_path = public, pg_catalog as $$ select private.save_wholesale_price_list_item(p_id, p_price_list_id, p_product_id, p_variant_id, p_unit_price_minor, p_min_quantity, p_status, p_reason); $$;
revoke all on function public.save_wholesale_price_list_item(uuid, uuid, uuid, uuid, bigint, integer, text, text) from public, anon;
grant execute on function public.save_wholesale_price_list_item(uuid, uuid, uuid, uuid, bigint, integer, text, text) to authenticated;

create or replace function private.list_merchant_wholesale_requests(p_shop_id uuid)
returns setof jsonb language sql security definer set search_path = public, private, pg_catalog
as $$
  select jsonb_build_object('id', r.id, 'shop_id', r.shop_id, 'business_name', b.business_name, 'contact_phone', b.contact_phone, 'note', r.note, 'estimated_monthly_minor', r.estimated_monthly_minor, 'status', r.status, 'approved_price_list_id', r.approved_price_list_id, 'review_note', r.review_note, 'created_at', r.created_at)
  from wholesale_requests r join business_profiles b on b.id = r.business_profile_id
  where r.shop_id = p_shop_id and (r.merchant_id in (select private.current_merchant_ids()) or private.is_admin())
  order by r.created_at desc limit 100;
$$;
revoke all on function private.list_merchant_wholesale_requests(uuid) from public, anon, authenticated;
grant execute on function private.list_merchant_wholesale_requests(uuid) to authenticated, service_role;
create or replace function public.list_merchant_wholesale_requests(p_shop_id uuid)
returns setof jsonb language sql security invoker set search_path = public, pg_catalog as $$ select * from private.list_merchant_wholesale_requests(p_shop_id); $$;
revoke all on function public.list_merchant_wholesale_requests(uuid) from public, anon;
grant execute on function public.list_merchant_wholesale_requests(uuid) to authenticated;

create or replace function private.review_wholesale_request_with_price_list(p_request_id uuid, p_status text, p_review_note text, p_price_list_id uuid default null)
returns jsonb language plpgsql security definer set search_path = public, private, pg_catalog
as $$
declare v_user uuid := (select auth.uid()); v_shop uuid;
begin
  if v_user is null then raise exception using errcode = '28000', message = 'AUTH_REQUIRED'; end if;
  if p_status not in ('reviewing','approved','rejected','closed') or length(trim(coalesce(p_review_note, ''))) < 3 then raise exception using errcode = 'P0001', message = 'INVALID_WHOLESALE_REVIEW'; end if;
  select shop_id into v_shop from wholesale_requests where id = p_request_id and merchant_id in (select private.current_merchant_ids());
  if v_shop is null and not private.is_admin() then raise exception using errcode = '42501', message = 'WHOLESALE_REQUEST_NOT_FOUND'; end if;
  if p_price_list_id is not null and not exists(select 1 from wholesale_price_lists where id = p_price_list_id and shop_id = v_shop and status = 'active') then raise exception using errcode = 'P0001', message = 'PRICE_LIST_NOT_ACTIVE'; end if;
  update wholesale_requests set status = p_status, reviewed_by_user_id = v_user, review_note = trim(p_review_note), approved_price_list_id = p_price_list_id, updated_at = now() where id = p_request_id;
  insert into audit_events(actor_user_id, action, resource_type, resource_id, metadata)
  values(v_user, 'b2b.wholesale_request_priced_reviewed', 'wholesale_request', p_request_id::text, jsonb_build_object('status', p_status, 'price_list_id', p_price_list_id));
  return jsonb_build_object('request_id', p_request_id, 'status', p_status, 'price_list_id', p_price_list_id);
end;
$$;
revoke all on function private.review_wholesale_request_with_price_list(uuid, text, text, uuid) from public, anon, authenticated;
grant execute on function private.review_wholesale_request_with_price_list(uuid, text, text, uuid) to authenticated, service_role;
create or replace function public.review_wholesale_request_with_price_list(p_request_id uuid, p_status text, p_review_note text, p_price_list_id uuid default null)
returns jsonb language sql security invoker set search_path = public, pg_catalog as $$ select private.review_wholesale_request_with_price_list(p_request_id, p_status, p_review_note, p_price_list_id); $$;
revoke all on function public.review_wholesale_request_with_price_list(uuid, text, text, uuid) from public, anon;
grant execute on function public.review_wholesale_request_with_price_list(uuid, text, text, uuid) to authenticated;

create or replace function private.close_pos_session(p_pos_session_id uuid, p_counted_total_minor bigint, p_closing_note text default null)
returns jsonb language plpgsql security definer set search_path = public, private, pg_catalog
as $$
declare v_user uuid := (select auth.uid()); v_session pos_sessions%rowtype; v_expected bigint; v_status text; v_variance bigint;
begin
  if v_user is null then raise exception using errcode = '28000', message = 'AUTH_REQUIRED'; end if;
  select * into v_session from pos_sessions where id = p_pos_session_id and status = 'open' and (opened_by_user_id = v_user or exists(select 1 from shops sh join merchants m on m.id = sh.merchant_id where sh.id = shop_id and m.owner_user_id = v_user)) for update;
  if not found then raise exception using errcode = '42501', message = 'POS_SESSION_NOT_FOUND'; end if;
  if p_counted_total_minor < 0 then raise exception using errcode = 'P0001', message = 'INVALID_COUNTED_TOTAL'; end if;
  select coalesce(sum(total_minor), 0) into v_expected from pos_sales where pos_session_id = p_pos_session_id and reconciliation_status <> 'voided';
  v_variance := p_counted_total_minor - v_expected;
  v_status := case when v_variance = 0 then 'reconciled' else 'variance' end;
  update pos_sessions set status = 'closed', closed_at = now(), closing_note = nullif(trim(p_closing_note), ''), expected_total_minor = v_expected, counted_total_minor = p_counted_total_minor, variance_minor = v_variance, reconciliation_status = v_status where id = p_pos_session_id;
  update pos_sales set reconciliation_status = case when v_status = 'reconciled' then 'reconciled' else reconciliation_status end where pos_session_id = p_pos_session_id and reconciliation_status = 'pending';
  insert into audit_events(actor_user_id, action, resource_type, resource_id, metadata)
  values(v_user, 'pos.session_closed', 'pos_session', p_pos_session_id::text, jsonb_build_object('expected_total_minor', v_expected, 'counted_total_minor', p_counted_total_minor, 'variance_minor', v_variance));
  return jsonb_build_object('pos_session_id', p_pos_session_id, 'status', 'closed', 'reconciliation_status', v_status, 'expected_total_minor', v_expected, 'counted_total_minor', p_counted_total_minor, 'variance_minor', v_variance);
end;
$$;
revoke all on function private.close_pos_session(uuid, bigint, text) from public, anon;
grant execute on function private.close_pos_session(uuid, bigint, text) to authenticated, service_role;
create or replace function public.close_pos_session(p_pos_session_id uuid, p_counted_total_minor bigint, p_closing_note text default null)
returns jsonb language sql security invoker set search_path = public, pg_catalog as $$ select private.close_pos_session(p_pos_session_id, p_counted_total_minor, p_closing_note); $$;
revoke all on function public.close_pos_session(uuid, bigint, text) from public, anon;
grant execute on function public.close_pos_session(uuid, bigint, text) to authenticated;

create or replace function private.record_courier_dispatch_event(p_assignment_id uuid, p_event_type text, p_note text default null)
returns jsonb language plpgsql security definer set search_path = public, private, pg_catalog
as $$
declare v_user uuid := (select auth.uid()); v_assignment order_courier_assignments%rowtype; v_id uuid;
begin
  if v_user is null then raise exception using errcode = '28000', message = 'AUTH_REQUIRED'; end if;
  select * into v_assignment from order_courier_assignments a where a.id = p_assignment_id and (a.courier_user_id = v_user or private.is_admin() or exists(select 1 from merchant_orders o where o.id = a.merchant_order_id and o.merchant_id in (select private.current_merchant_ids()))) for update;
  if not found then raise exception using errcode = '42501', message = 'ASSIGNMENT_NOT_FOUND'; end if;
  if p_event_type not in ('assigned','picked_up','out_for_delivery','delivered','failed','cancelled','note') then raise exception using errcode = 'P0001', message = 'INVALID_DISPATCH_EVENT'; end if;
  if p_event_type in ('failed','note') and length(trim(coalesce(p_note, ''))) < 3 then raise exception using errcode = 'P0001', message = 'DISPATCH_NOTE_REQUIRED'; end if;
  insert into courier_dispatch_events(assignment_id, merchant_order_id, courier_user_id, actor_user_id, event_type, note)
  values(v_assignment.id, v_assignment.merchant_order_id, v_assignment.courier_user_id, v_user, p_event_type, nullif(trim(p_note), '')) returning id into v_id;
  return jsonb_build_object('event_id', v_id, 'event_type', p_event_type);
end;
$$;
revoke all on function private.record_courier_dispatch_event(uuid, text, text) from public, anon;
grant execute on function private.record_courier_dispatch_event(uuid, text, text) to authenticated, service_role;
create or replace function public.record_courier_dispatch_event(p_assignment_id uuid, p_event_type text, p_note text default null)
returns jsonb language sql security invoker set search_path = public, pg_catalog as $$ select private.record_courier_dispatch_event(p_assignment_id, p_event_type, p_note); $$;
revoke all on function public.record_courier_dispatch_event(uuid, text, text) from public, anon;
grant execute on function public.record_courier_dispatch_event(uuid, text, text) to authenticated;
