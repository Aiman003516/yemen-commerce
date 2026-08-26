-- Loyalty, B2B, POS, and inventory operations foundations.
-- POS and loyalty records do not settle funds or bypass the authoritative order/payment flow.

create table if not exists public.customer_loyalty_accounts (
  id uuid primary key default gen_random_uuid(),
  customer_user_id uuid not null references public.profiles(id) on delete cascade,
  market_id uuid not null references public.markets(id) on delete restrict,
  points_balance integer not null default 0 check (points_balance >= 0),
  tier text not null default 'standard' check (tier in ('standard','silver','gold')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (customer_user_id, market_id)
);

create table if not exists public.loyalty_ledger (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.customer_loyalty_accounts(id) on delete cascade,
  customer_user_id uuid not null references public.profiles(id) on delete restrict,
  merchant_order_id uuid references public.merchant_orders(id) on delete set null,
  entry_type text not null check (entry_type in ('earned','redeemed','adjusted','expired')),
  points_delta integer not null check (points_delta <> 0),
  reason text not null,
  created_by_user_id uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);
create index if not exists loyalty_ledger_account_created_idx
  on public.loyalty_ledger(account_id, created_at desc);

create table if not exists public.business_profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  business_name text not null,
  contact_phone text not null,
  tax_identifier text,
  status text not null default 'pending' check (status in ('pending','verified','rejected')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id)
);

create table if not exists public.wholesale_requests (
  id uuid primary key default gen_random_uuid(),
  buyer_user_id uuid not null references public.profiles(id) on delete cascade,
  business_profile_id uuid not null references public.business_profiles(id) on delete restrict,
  merchant_id uuid not null references public.merchants(id) on delete cascade,
  shop_id uuid not null references public.shops(id) on delete cascade,
  note text not null,
  requested_currency text not null default 'YER',
  estimated_monthly_minor bigint not null default 0 check (estimated_monthly_minor >= 0),
  status text not null default 'open' check (status in ('open','reviewing','approved','rejected','closed')),
  reviewed_by_user_id uuid references public.profiles(id) on delete set null,
  review_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists wholesale_requests_merchant_status_idx
  on public.wholesale_requests(merchant_id, status, created_at desc);
create index if not exists wholesale_requests_buyer_idx
  on public.wholesale_requests(buyer_user_id, created_at desc);

create table if not exists public.pos_sessions (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  opened_by_user_id uuid not null references public.profiles(id) on delete restrict,
  status text not null default 'open' check (status in ('open','closed')),
  opening_note text,
  closing_note text,
  opened_at timestamptz not null default now(),
  closed_at timestamptz
);
create index if not exists pos_sessions_shop_status_idx
  on public.pos_sessions(shop_id, status, opened_at desc);

create table if not exists public.pos_sales (
  id uuid primary key default gen_random_uuid(),
  pos_session_id uuid not null references public.pos_sessions(id) on delete cascade,
  shop_id uuid not null references public.shops(id) on delete cascade,
  recorded_by_user_id uuid not null references public.profiles(id) on delete restrict,
  external_order_reference text,
  currency text not null default 'YER',
  total_minor bigint not null check (total_minor > 0),
  payment_mode text not null check (payment_mode in ('cash','manual_reference','mock')),
  reconciliation_status text not null default 'pending' check (reconciliation_status in ('pending','reconciled','voided')),
  line_items jsonb not null default '[]'::jsonb,
  note text,
  created_at timestamptz not null default now(),
  check (jsonb_typeof(line_items) = 'array' and length(line_items::text) <= 16000)
);
create index if not exists pos_sales_session_created_idx
  on public.pos_sales(pos_session_id, created_at desc);

alter table public.customer_loyalty_accounts enable row level security;
alter table public.loyalty_ledger enable row level security;
alter table public.business_profiles enable row level security;
alter table public.wholesale_requests enable row level security;
alter table public.pos_sessions enable row level security;
alter table public.pos_sales enable row level security;
grant select on public.customer_loyalty_accounts, public.loyalty_ledger, public.business_profiles, public.wholesale_requests, public.pos_sessions, public.pos_sales to authenticated;

drop policy if exists loyalty_account_owner_read on public.customer_loyalty_accounts;
create policy loyalty_account_owner_read on public.customer_loyalty_accounts for select to authenticated
using (customer_user_id = (select auth.uid()) or private.is_admin());
drop policy if exists loyalty_ledger_owner_read on public.loyalty_ledger;
create policy loyalty_ledger_owner_read on public.loyalty_ledger for select to authenticated
using (customer_user_id = (select auth.uid()) or private.is_admin());
drop policy if exists business_profile_owner_read on public.business_profiles;
create policy business_profile_owner_read on public.business_profiles for select to authenticated
using (user_id = (select auth.uid()) or private.is_admin());
drop policy if exists wholesale_request_participant_read on public.wholesale_requests;
create policy wholesale_request_participant_read on public.wholesale_requests for select to authenticated
using (buyer_user_id = (select auth.uid()) or merchant_id in (select private.current_merchant_ids()) or private.is_admin());
drop policy if exists pos_sessions_owner_read on public.pos_sessions;
create policy pos_sessions_owner_read on public.pos_sessions for select to authenticated
using (opened_by_user_id = (select auth.uid()) or exists(select 1 from shops s join merchants m on m.id = s.merchant_id where s.id = shop_id and m.owner_user_id = (select auth.uid())) or private.is_admin());
drop policy if exists pos_sales_owner_read on public.pos_sales;
create policy pos_sales_owner_read on public.pos_sales for select to authenticated
using (recorded_by_user_id = (select auth.uid()) or exists(select 1 from shops s join merchants m on m.id = s.merchant_id where s.id = shop_id and m.owner_user_id = (select auth.uid())) or private.is_admin());

create or replace function private.save_business_profile(
  p_business_name text,
  p_contact_phone text,
  p_tax_identifier text default null
)
returns jsonb
language plpgsql security definer set search_path = public, private, pg_catalog
as $$
declare v_user uuid := (select auth.uid()); v_id uuid;
begin
  if v_user is null then raise exception using errcode = '28000', message = 'AUTH_REQUIRED'; end if;
  if length(trim(coalesce(p_business_name, ''))) < 2 or length(trim(coalesce(p_contact_phone, ''))) < 7 then
    raise exception using errcode = 'P0001', message = 'INVALID_BUSINESS_PROFILE';
  end if;
  insert into business_profiles(user_id, business_name, contact_phone, tax_identifier)
  values(v_user, trim(p_business_name), trim(p_contact_phone), nullif(trim(p_tax_identifier), ''))
  on conflict (user_id) do update set business_name = excluded.business_name, contact_phone = excluded.contact_phone, tax_identifier = excluded.tax_identifier, updated_at = now()
  returning id into v_id;
  insert into audit_events(actor_user_id, action, resource_type, resource_id, metadata)
  values(v_user, 'b2b.business_profile_saved', 'business_profile', v_id::text, '{}'::jsonb);
  return jsonb_build_object('business_profile_id', v_id, 'status', 'pending');
end;
$$;
revoke all on function private.save_business_profile(text, text, text) from public, anon;
grant execute on function private.save_business_profile(text, text, text) to authenticated, service_role;
create or replace function public.save_business_profile(p_business_name text, p_contact_phone text, p_tax_identifier text default null)
returns jsonb language sql security invoker set search_path = public, pg_catalog as $$
  select private.save_business_profile(p_business_name, p_contact_phone, p_tax_identifier);
$$;
revoke all on function public.save_business_profile(text, text, text) from public, anon;
grant execute on function public.save_business_profile(text, text, text) to authenticated;

create or replace function private.open_wholesale_request(
  p_shop_id uuid,
  p_note text,
  p_estimated_monthly_minor bigint default 0
)
returns jsonb
language plpgsql security definer set search_path = public, private, pg_catalog
as $$
declare v_user uuid := (select auth.uid()); v_business business_profiles%rowtype; v_merchant uuid; v_id uuid;
begin
  if v_user is null then raise exception using errcode = '28000', message = 'AUTH_REQUIRED'; end if;
  select * into v_business from business_profiles where user_id = v_user and status in ('pending','verified');
  if not found then raise exception using errcode = 'P0001', message = 'BUSINESS_PROFILE_REQUIRED'; end if;
  select merchant_id into v_merchant from shops where id = p_shop_id and status = 'approved';
  if v_merchant is null then raise exception using errcode = 'P0001', message = 'SHOP_UNAVAILABLE'; end if;
  if length(trim(coalesce(p_note, ''))) < 8 or p_estimated_monthly_minor < 0 then raise exception using errcode = 'P0001', message = 'INVALID_WHOLESALE_REQUEST'; end if;
  insert into wholesale_requests(buyer_user_id, business_profile_id, merchant_id, shop_id, note, estimated_monthly_minor)
  values(v_user, v_business.id, v_merchant, p_shop_id, trim(p_note), p_estimated_monthly_minor)
  returning id into v_id;
  insert into audit_events(actor_user_id, action, resource_type, resource_id, metadata)
  values(v_user, 'b2b.wholesale_request_opened', 'wholesale_request', v_id::text, jsonb_build_object('shop_id', p_shop_id));
  return jsonb_build_object('request_id', v_id, 'status', 'open');
end;
$$;
revoke all on function private.open_wholesale_request(uuid, text, bigint) from public, anon;
grant execute on function private.open_wholesale_request(uuid, text, bigint) to authenticated, service_role;
create or replace function public.open_wholesale_request(p_shop_id uuid, p_note text, p_estimated_monthly_minor bigint default 0)
returns jsonb language sql security invoker set search_path = public, pg_catalog as $$
  select private.open_wholesale_request(p_shop_id, p_note, p_estimated_monthly_minor);
$$;
revoke all on function public.open_wholesale_request(uuid, text, bigint) from public, anon;
grant execute on function public.open_wholesale_request(uuid, text, bigint) to authenticated;

create or replace function private.review_wholesale_request(p_request_id uuid, p_status text, p_review_note text)
returns jsonb
language plpgsql security definer set search_path = public, private, pg_catalog
as $$
declare v_user uuid := (select auth.uid()); v_request wholesale_requests%rowtype;
begin
  if v_user is null then raise exception using errcode = '28000', message = 'AUTH_REQUIRED'; end if;
  if p_status not in ('reviewing','approved','rejected','closed') or length(trim(coalesce(p_review_note, ''))) < 3 then raise exception using errcode = 'P0001', message = 'INVALID_WHOLESALE_REVIEW'; end if;
  select * into v_request from wholesale_requests r where r.id = p_request_id and (r.merchant_id in (select private.current_merchant_ids()) or private.is_admin()) for update;
  if not found then raise exception using errcode = '42501', message = 'WHOLESALE_REQUEST_NOT_FOUND'; end if;
  update wholesale_requests set status = p_status, reviewed_by_user_id = v_user, review_note = trim(p_review_note), updated_at = now() where id = p_request_id;
  insert into audit_events(actor_user_id, action, resource_type, resource_id, metadata)
  values(v_user, 'b2b.wholesale_request_reviewed', 'wholesale_request', p_request_id::text, jsonb_build_object('status', p_status));
  return jsonb_build_object('request_id', p_request_id, 'status', p_status);
end;
$$;
revoke all on function private.review_wholesale_request(uuid, text, text) from public, anon;
grant execute on function private.review_wholesale_request(uuid, text, text) to authenticated, service_role;
create or replace function public.review_wholesale_request(p_request_id uuid, p_status text, p_review_note text)
returns jsonb language sql security invoker set search_path = public, pg_catalog as $$
  select private.review_wholesale_request(p_request_id, p_status, p_review_note);
$$;
revoke all on function public.review_wholesale_request(uuid, text, text) from public, anon;
grant execute on function public.review_wholesale_request(uuid, text, text) to authenticated;

create or replace function private.earn_loyalty_points(p_merchant_order_id uuid, p_points integer, p_reason text)
returns jsonb language plpgsql security definer set search_path = public, private, pg_catalog
as $$
declare v_user uuid := (select auth.uid()); v_order merchant_orders%rowtype; v_account customer_loyalty_accounts%rowtype;
begin
  if v_user is null then raise exception using errcode = '28000', message = 'AUTH_REQUIRED'; end if;
  if not private.is_admin() and not private.has_role('merchant', null) then raise exception using errcode = '42501', message = 'FORBIDDEN'; end if;
  if p_points <= 0 or length(trim(coalesce(p_reason, ''))) < 3 then raise exception using errcode = 'P0001', message = 'INVALID_LOYALTY_ENTRY'; end if;
  select * into v_order from merchant_orders where id = p_merchant_order_id and payment_status = 'paid' and fulfilment_status = 'completed' and (merchant_id in (select private.current_merchant_ids()) or private.is_admin()) for update;
  if not found then raise exception using errcode = 'P0001', message = 'ORDER_NOT_ELIGIBLE_FOR_LOYALTY'; end if;
  insert into customer_loyalty_accounts(customer_user_id, market_id) values(v_order.customer_user_id, v_order.market_id)
  on conflict (customer_user_id, market_id) do update set updated_at = now()
  returning * into v_account;
  insert into loyalty_ledger(account_id, customer_user_id, merchant_order_id, entry_type, points_delta, reason, created_by_user_id)
  values(v_account.id, v_order.customer_user_id, v_order.id, 'earned', p_points, trim(p_reason), v_user);
  update customer_loyalty_accounts set points_balance = points_balance + p_points, tier = case when points_balance + p_points >= 1000 then 'gold' when points_balance + p_points >= 500 then 'silver' else tier end, updated_at = now() where id = v_account.id;
  return jsonb_build_object('account_id', v_account.id, 'points_delta', p_points);
end;
$$;
revoke all on function private.earn_loyalty_points(uuid, integer, text) from public, anon;
grant execute on function private.earn_loyalty_points(uuid, integer, text) to authenticated, service_role;
create or replace function public.earn_loyalty_points(p_merchant_order_id uuid, p_points integer, p_reason text)
returns jsonb language sql security invoker set search_path = public, pg_catalog as $$ select private.earn_loyalty_points(p_merchant_order_id, p_points, p_reason); $$;
revoke all on function public.earn_loyalty_points(uuid, integer, text) from public, anon;
grant execute on function public.earn_loyalty_points(uuid, integer, text) to authenticated;

create or replace function private.open_pos_session(p_shop_id uuid, p_opening_note text default null)
returns jsonb language plpgsql security definer set search_path = public, private, pg_catalog
as $$
declare v_user uuid := (select auth.uid()); v_id uuid;
begin
  if v_user is null then raise exception using errcode = '28000', message = 'AUTH_REQUIRED'; end if;
  if not exists(select 1 from shops s join merchants m on m.id = s.merchant_id where s.id = p_shop_id and m.owner_user_id = v_user) then raise exception using errcode = '42501', message = 'SHOP_NOT_OWNED'; end if;
  if exists(select 1 from pos_sessions where shop_id = p_shop_id and status = 'open') then raise exception using errcode = 'P0001', message = 'POS_SESSION_ALREADY_OPEN'; end if;
  insert into pos_sessions(shop_id, opened_by_user_id, opening_note) values(p_shop_id, v_user, nullif(trim(p_opening_note), '')) returning id into v_id;
  return jsonb_build_object('pos_session_id', v_id, 'status', 'open');
end;
$$;
revoke all on function private.open_pos_session(uuid, text) from public, anon;
grant execute on function private.open_pos_session(uuid, text) to authenticated, service_role;
create or replace function public.open_pos_session(p_shop_id uuid, p_opening_note text default null)
returns jsonb language sql security invoker set search_path = public, pg_catalog as $$ select private.open_pos_session(p_shop_id, p_opening_note); $$;
revoke all on function public.open_pos_session(uuid, text) from public, anon;
grant execute on function public.open_pos_session(uuid, text) to authenticated;

create or replace function private.record_pos_sale(p_pos_session_id uuid, p_total_minor bigint, p_payment_mode text, p_line_items jsonb default '[]'::jsonb, p_note text default null)
returns jsonb language plpgsql security definer set search_path = public, private, pg_catalog
as $$
declare v_user uuid := (select auth.uid()); v_session pos_sessions%rowtype; v_id uuid;
begin
  if v_user is null then raise exception using errcode = '28000', message = 'AUTH_REQUIRED'; end if;
  select * into v_session from pos_sessions s where s.id = p_pos_session_id and s.status = 'open' and (s.opened_by_user_id = v_user or exists(select 1 from shops sh join merchants m on m.id = sh.merchant_id where sh.id = s.shop_id and m.owner_user_id = v_user)) for update;
  if not found then raise exception using errcode = '42501', message = 'POS_SESSION_NOT_FOUND'; end if;
  if p_total_minor <= 0 or p_payment_mode not in ('cash','manual_reference','mock') or jsonb_typeof(coalesce(p_line_items, '[]'::jsonb)) <> 'array' then raise exception using errcode = 'P0001', message = 'INVALID_POS_SALE'; end if;
  insert into pos_sales(pos_session_id, shop_id, recorded_by_user_id, total_minor, payment_mode, line_items, note)
  values(p_pos_session_id, v_session.shop_id, v_user, p_total_minor, p_payment_mode, coalesce(p_line_items, '[]'::jsonb), nullif(trim(p_note), '')) returning id into v_id;
  insert into audit_events(actor_user_id, action, resource_type, resource_id, metadata)
  values(v_user, 'pos.sale_recorded', 'pos_sale', v_id::text, jsonb_build_object('total_minor', p_total_minor, 'payment_mode', p_payment_mode));
  return jsonb_build_object('pos_sale_id', v_id, 'reconciliation_status', 'pending');
end;
$$;
revoke all on function private.record_pos_sale(uuid, bigint, text, jsonb, text) from public, anon;
grant execute on function private.record_pos_sale(uuid, bigint, text, jsonb, text) to authenticated, service_role;
create or replace function public.record_pos_sale(p_pos_session_id uuid, p_total_minor bigint, p_payment_mode text, p_line_items jsonb default '[]'::jsonb, p_note text default null)
returns jsonb language sql security invoker set search_path = public, pg_catalog as $$ select private.record_pos_sale(p_pos_session_id, p_total_minor, p_payment_mode, p_line_items, p_note); $$;
revoke all on function public.record_pos_sale(uuid, bigint, text, jsonb, text) from public, anon;
grant execute on function public.record_pos_sale(uuid, bigint, text, jsonb, text) to authenticated;
