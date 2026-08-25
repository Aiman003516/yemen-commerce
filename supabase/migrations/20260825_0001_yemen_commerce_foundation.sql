-- Yemen Commerce Supabase foundation
-- PostgreSQL/Supabase migration. Application keys and service credentials never belong here.

create extension if not exists pgcrypto;
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;
grant usage on schema private to postgres, service_role;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  email text,
  phone text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.markets (
  id uuid primary key default gen_random_uuid(),
  governorate text not null,
  city text not null,
  district text,
  service_area text,
  status text not null default 'draft' check (status in ('draft','active','paused')),
  currency text not null default 'YER' check (char_length(currency) = 3),
  is_pilot boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index if not exists markets_scope_unique on public.markets (governorate, city, coalesce(district, ''), coalesce(service_area, ''));
create index if not exists markets_status_idx on public.markets(status);

create table if not exists public.capabilities (
  id uuid primary key default gen_random_uuid(),
  key text not null unique,
  default_enabled boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.market_capabilities (
  id uuid primary key default gen_random_uuid(),
  market_id uuid not null references public.markets(id) on delete cascade,
  capability_id uuid not null references public.capabilities(id) on delete cascade,
  enabled boolean not null default false,
  reason_ar text,
  updated_at timestamptz not null default now(),
  unique (market_id, capability_id)
);
create index if not exists market_capabilities_market_idx on public.market_capabilities(market_id);

create table if not exists public.market_policy_versions (
  id uuid primary key default gen_random_uuid(),
  market_id uuid not null references public.markets(id) on delete cascade,
  key text not null,
  version integer not null check (version > 0),
  value jsonb not null default '{}'::jsonb,
  is_active boolean not null default true,
  effective_from timestamptz,
  created_at timestamptz not null default now(),
  unique (market_id, key, version)
);
create index if not exists market_policy_active_idx on public.market_policy_versions(market_id, key, is_active);

create table if not exists public.user_roles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null check (role in ('customer','merchant','admin')),
  market_id uuid references public.markets(id) on delete cascade,
  created_at timestamptz not null default now()
);
create unique index if not exists user_roles_scope_unique on public.user_roles(user_id, role, coalesce(market_id, '00000000-0000-0000-0000-000000000000'::uuid));
create index if not exists user_roles_user_idx on public.user_roles(user_id);

create table if not exists public.merchants (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references public.profiles(id) on delete restrict,
  market_id uuid not null references public.markets(id) on delete restrict,
  phone text not null,
  phone_verification_status text not null default 'unverified' check (phone_verification_status in ('unverified','pending','verified')),
  phone_verified_at timestamptz,
  owner_name text not null,
  verification_status text not null default 'draft' check (verification_status in ('draft','pending','verified','rejected')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists merchants_owner_idx on public.merchants(owner_user_id);
create index if not exists merchants_market_idx on public.merchants(market_id);

create table if not exists public.identity_verification_cases (
  id uuid primary key default gen_random_uuid(),
  merchant_id uuid not null unique references public.merchants(id) on delete cascade,
  submitted_by_user_id uuid not null references public.profiles(id) on delete restrict,
  consent_at timestamptz not null,
  status text not null default 'draft' check (status in ('draft','submitted','under_review','verified','rejected','expired')),
  reviewed_by_user_id uuid references public.profiles(id) on delete set null,
  reviewed_at timestamptz,
  decision_note text,
  retention_until timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists identity_cases_status_idx on public.identity_verification_cases(status);

create table if not exists public.identity_evidence (
  id uuid primary key default gen_random_uuid(),
  identity_case_id uuid not null references public.identity_verification_cases(id) on delete cascade,
  kind text not null check (kind in ('passport','selfie')),
  storage_key text not null,
  mime_type text not null,
  original_name text not null,
  created_at timestamptz not null default now(),
  unique (identity_case_id, kind)
);

create table if not exists public.shops (
  id uuid primary key default gen_random_uuid(),
  merchant_id uuid not null references public.merchants(id) on delete cascade,
  market_id uuid not null references public.markets(id) on delete restrict,
  name text not null,
  slug text not null unique,
  description text,
  area_label text,
  logo_path text,
  cover_path text,
  accent_color text not null default '#006A63' check (accent_color ~ '^#[0-9a-fA-F]{6}$'),
  contact_route text,
  collection_instructions text,
  status text not null default 'draft' check (status in ('draft','pending','approved','suspended')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists shops_market_status_idx on public.shops(market_id, status);
create index if not exists shops_merchant_idx on public.shops(merchant_id);

create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  market_id uuid references public.markets(id) on delete cascade,
  name_ar text not null,
  name_en text,
  slug text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);
create unique index if not exists categories_slug_market_unique on public.categories(coalesce(market_id, '00000000-0000-0000-0000-000000000000'::uuid), slug);
create index if not exists categories_market_active_idx on public.categories(market_id, is_active);

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  category_id uuid references public.categories(id) on delete set null,
  name text not null,
  description text,
  price_minor bigint not null check (price_minor > 0),
  currency text not null default 'YER' check (char_length(currency) = 3),
  stock_quantity integer not null default 0 check (stock_quantity >= 0),
  image_path text,
  status text not null default 'draft' check (status in ('draft','active','archived','out_of_stock')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists products_shop_status_idx on public.products(shop_id, status);
create index if not exists products_category_idx on public.products(category_id);

create table if not exists public.shop_fulfilment_methods (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  method text not null check (method in ('collection','digital','seller_arranged')),
  instructions text,
  is_active boolean not null default true,
  unique (shop_id, method)
);

create table if not exists public.payment_methods (
  id uuid primary key default gen_random_uuid(),
  merchant_id uuid not null references public.merchants(id) on delete cascade,
  name text not null,
  mode text not null default 'manual' check (mode in ('manual','provider_api')),
  account_holder_name text not null,
  receiving_identifier text not null,
  currency text not null default 'YER' check (char_length(currency) = 3),
  exact_amount_required boolean not null default true,
  customer_instructions text not null,
  proof_requirement text not null default 'both' check (proof_requirement in ('none','reference','screenshot','both')),
  provider_verification text not null default 'manual_only' check (provider_verification in ('manual_only','pending','verified')),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists payment_methods_merchant_active_idx on public.payment_methods(merchant_id, is_active);

create table if not exists public.carts (
  id uuid primary key default gen_random_uuid(),
  customer_user_id uuid not null references public.profiles(id) on delete cascade,
  market_id uuid not null references public.markets(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (customer_user_id, market_id)
);

create table if not exists public.cart_items (
  id uuid primary key default gen_random_uuid(),
  cart_id uuid not null references public.carts(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete restrict,
  quantity integer not null check (quantity between 1 and 99),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (cart_id, product_id)
);
create index if not exists cart_items_cart_idx on public.cart_items(cart_id);

create table if not exists public.checkout_sessions (
  id uuid primary key default gen_random_uuid(),
  customer_user_id uuid not null references public.profiles(id) on delete restrict,
  market_id uuid not null references public.markets(id) on delete restrict,
  status text not null default 'created' check (status in ('created','completed','cancelled')),
  created_at timestamptz not null default now()
);

create table if not exists public.merchant_orders (
  id uuid primary key default gen_random_uuid(),
  checkout_session_id uuid not null references public.checkout_sessions(id) on delete restrict,
  merchant_id uuid not null references public.merchants(id) on delete restrict,
  shop_id uuid not null references public.shops(id) on delete restrict,
  customer_user_id uuid not null references public.profiles(id) on delete restrict,
  market_id uuid not null references public.markets(id) on delete restrict,
  order_reference text not null unique,
  currency text not null default 'YER' check (char_length(currency) = 3),
  subtotal_minor bigint not null check (subtotal_minor >= 0),
  fee_minor bigint not null default 0 check (fee_minor >= 0),
  tax_minor bigint not null default 0 check (tax_minor >= 0),
  total_minor bigint not null check (total_minor >= 0),
  payment_method_name text not null,
  payment_method_id uuid references public.payment_methods(id) on delete set null,
  account_holder_name text not null,
  receiving_identifier text not null,
  payment_instructions text not null,
  proof_requirement text not null check (proof_requirement in ('none','reference','screenshot','both')),
  payment_status text not null default 'awaiting_payment' check (payment_status in ('awaiting_payment','payment_under_review','paid','rejected','cancelled')),
  fulfilment_method text not null check (fulfilment_method in ('collection','digital','seller_arranged')),
  fulfilment_instructions text,
  fulfilment_status text not null default 'pending' check (fulfilment_status in ('pending','ready','arranged','completed','cancelled')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists merchant_orders_customer_idx on public.merchant_orders(customer_user_id, created_at desc);
create index if not exists merchant_orders_merchant_status_idx on public.merchant_orders(merchant_id, payment_status, created_at desc);
create index if not exists merchant_orders_session_idx on public.merchant_orders(checkout_session_id);

create table if not exists public.merchant_order_items (
  id uuid primary key default gen_random_uuid(),
  merchant_order_id uuid not null references public.merchant_orders(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete restrict,
  product_name text not null,
  unit_price_minor bigint not null check (unit_price_minor > 0),
  quantity integer not null check (quantity > 0),
  line_total_minor bigint not null check (line_total_minor >= 0)
);
create index if not exists merchant_order_items_order_idx on public.merchant_order_items(merchant_order_id);

create table if not exists public.payment_claims (
  id uuid primary key default gen_random_uuid(),
  merchant_order_id uuid not null references public.merchant_orders(id) on delete cascade,
  customer_user_id uuid not null references public.profiles(id) on delete restrict,
  transaction_reference text,
  review_note text,
  reviewed_by_user_id uuid references public.profiles(id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists payment_claims_order_idx on public.payment_claims(merchant_order_id, created_at desc);

create table if not exists public.payment_proofs (
  id uuid primary key default gen_random_uuid(),
  payment_claim_id uuid not null references public.payment_claims(id) on delete cascade,
  storage_key text not null,
  mime_type text not null,
  original_name text,
  created_at timestamptz not null default now()
);

create table if not exists public.order_status_history (
  id uuid primary key default gen_random_uuid(),
  merchant_order_id uuid not null references public.merchant_orders(id) on delete cascade,
  actor_user_id uuid references public.profiles(id) on delete set null,
  event_type text not null,
  previous_value text,
  next_value text,
  reason text,
  created_at timestamptz not null default now()
);
create index if not exists order_history_order_idx on public.order_status_history(merchant_order_id, created_at desc);

create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_user_id uuid not null references public.profiles(id) on delete restrict,
  merchant_order_id uuid references public.merchant_orders(id) on delete set null,
  shop_id uuid references public.shops(id) on delete set null,
  category text not null,
  description text not null,
  status text not null default 'open' check (status in ('open','reviewing','resolved','dismissed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.audit_events (
  id uuid primary key default gen_random_uuid(),
  actor_user_id uuid references public.profiles(id) on delete set null,
  action text not null,
  resource_type text not null,
  resource_id text,
  metadata jsonb,
  created_at timestamptz not null default now()
);
create index if not exists audit_events_resource_idx on public.audit_events(resource_type, resource_id, created_at desc);
create index if not exists audit_events_actor_idx on public.audit_events(actor_user_id, created_at desc);

create or replace function private.touch_updated_at()
returns trigger language plpgsql security invoker set search_path = public, pg_catalog as $$
begin
  new.updated_at = now();
  return new;
end;
$$;
revoke all on function private.touch_updated_at() from public, anon, authenticated;

do $$
declare t text;
begin
  foreach t in array array['profiles','markets','market_capabilities','merchants','identity_verification_cases','shops','products','payment_methods','carts','cart_items','merchant_orders','reports'] loop
    execute format('drop trigger if exists %I_updated_at on public.%I', t, t);
    execute format('create trigger %I_updated_at before update on public.%I for each row execute function private.touch_updated_at()', t, t);
  end loop;
end $$;

create or replace function private.is_admin()
returns boolean language sql stable security definer set search_path = public, pg_catalog as $$
  select exists (select 1 from public.user_roles ur where ur.user_id = (select auth.uid()) and ur.role = 'admin');
$$;
create or replace function private.has_role(p_role text, p_market_id uuid default null)
returns boolean language sql stable security definer set search_path = public, pg_catalog as $$
  select exists (select 1 from public.user_roles ur where ur.user_id = (select auth.uid()) and ur.role = p_role and (p_market_id is null or ur.market_id is null or ur.market_id = p_market_id));
$$;
create or replace function private.current_merchant_ids()
returns setof uuid language sql stable security definer set search_path = public, pg_catalog as $$
  select m.id from public.merchants m where m.owner_user_id = (select auth.uid());
$$;
create or replace function private.can_access_order(p_order_id uuid)
returns boolean language sql stable security definer set search_path = public, pg_catalog as $$
  select exists (
    select 1 from public.merchant_orders o
    where o.id = p_order_id
      and (o.customer_user_id = (select auth.uid()) or o.merchant_id in (select private.current_merchant_ids()) or private.is_admin())
  );
$$;
revoke all on function private.is_admin() from public, anon, authenticated;
revoke all on function private.has_role(text, uuid) from public, anon, authenticated;
revoke all on function private.current_merchant_ids() from public, anon, authenticated;
revoke all on function private.can_access_order(uuid) from public, anon, authenticated;

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public, pg_catalog as $$
begin
  insert into public.profiles(id, display_name, email, phone)
  values (new.id, coalesce(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name'), new.email, new.phone)
  on conflict (id) do update set email = excluded.email, phone = excluded.phone, updated_at = now();
  insert into public.user_roles(user_id, role) values (new.id, 'customer') on conflict do nothing;
  return new;
end;
$$;
revoke all on function public.handle_new_user() from public, anon, authenticated;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();

-- Seed only Ibb configuration and capability defaults; no fabricated shops, products, users, or orders.
insert into public.markets(governorate, city, status, currency, is_pilot)
values ('إب', 'إب', 'active', 'YER', true)
on conflict do nothing;
insert into public.capabilities(key, default_enabled) values
  ('manual_payments', true), ('payment_proof_upload', true), ('digital_delivery', true),
  ('seller_arranged_fulfilment', true), ('notifications', false), ('provider_api_payments', false),
  ('support_agent', false), ('phone_otp_verification', false), ('merchant_identity_verification', true)
on conflict (key) do nothing;
insert into public.market_capabilities(market_id, capability_id, enabled, reason_ar)
select m.id, c.id, c.default_enabled,
  case when c.key = 'notifications' then 'سيتم تفعيل الإشعارات في مرحلة لاحقة.'
       when c.key = 'provider_api_payments' then 'تظل عمليات الدفع يدوية حتى اعتماد مزود الدفع رسمياً.'
       when c.key = 'support_agent' then 'دور الدعم محدود ومؤجل في مرحلة الإطلاق.'
       when c.key = 'phone_otp_verification' then 'سيُفعّل التحقق من ملكية الهاتف بعد اعتماد مزود رسائل مناسب.'
       when c.key = 'merchant_identity_verification' then 'مراجعة موظف مخوّل فقط؛ لا توجد مطابقة وجه أو قرار آلي.'
       else null end
from public.markets m cross join public.capabilities c
where m.city = 'إب' and m.governorate = 'إب'
on conflict (market_id, capability_id) do nothing;
insert into public.market_policy_versions(market_id, key, version, value, is_active)
select m.id, v.key, 1, v.value, true
from public.markets m cross join (values
  ('pilot_pricing', '{"subscription_minor":0,"commission_bps":0,"central_funds_custody":false}'::jsonb),
  ('merchant_verification', '{"approval_required":true,"phone_required":true,"location_required":true,"identity_evidence_required_for_review":true,"manual_identity_review_only":true}'::jsonb),
  ('fulfilment', '{"enabled_methods":["collection","digital","seller_arranged"],"platform_managed_shipping":false}'::jsonb)
) as v(key, value)
where m.city = 'إب' and m.governorate = 'إب'
on conflict (market_id, key, version) do nothing;

-- Public catalogue policies.
alter table public.markets enable row level security;
alter table public.capabilities enable row level security;
alter table public.market_capabilities enable row level security;
alter table public.market_policy_versions enable row level security;
alter table public.profiles enable row level security;
alter table public.user_roles enable row level security;
alter table public.merchants enable row level security;
alter table public.identity_verification_cases enable row level security;
alter table public.identity_evidence enable row level security;
alter table public.shops enable row level security;
alter table public.categories enable row level security;
alter table public.products enable row level security;
alter table public.shop_fulfilment_methods enable row level security;
alter table public.payment_methods enable row level security;
alter table public.carts enable row level security;
alter table public.cart_items enable row level security;
alter table public.checkout_sessions enable row level security;
alter table public.merchant_orders enable row level security;
alter table public.merchant_order_items enable row level security;
alter table public.payment_claims enable row level security;
alter table public.payment_proofs enable row level security;
alter table public.order_status_history enable row level security;
alter table public.reports enable row level security;
alter table public.audit_events enable row level security;

revoke all on all tables in schema public from anon, authenticated;
grant select on public.markets, public.capabilities, public.market_capabilities, public.market_policy_versions, public.shops, public.categories, public.products, public.shop_fulfilment_methods to anon, authenticated;
grant select on public.profiles, public.user_roles, public.merchants, public.identity_verification_cases, public.identity_evidence, public.payment_methods, public.carts, public.cart_items, public.checkout_sessions, public.merchant_orders, public.merchant_order_items, public.payment_claims, public.payment_proofs, public.order_status_history, public.reports, public.audit_events to authenticated;
grant insert, update, delete on public.carts, public.cart_items, public.reports to authenticated;
grant execute on function public.handle_new_user() to postgres, service_role;

-- Policies are intentionally explicit and scoped.
drop policy if exists markets_public_read on public.markets;
create policy markets_public_read on public.markets for select to anon, authenticated using (status = 'active');
drop policy if exists capabilities_public_read on public.capabilities;
create policy capabilities_public_read on public.capabilities for select to anon, authenticated using (true);
drop policy if exists market_capabilities_public_read on public.market_capabilities;
create policy market_capabilities_public_read on public.market_capabilities for select to anon, authenticated using (enabled = true and exists(select 1 from public.markets m where m.id = market_id and m.status = 'active'));
drop policy if exists policies_public_read on public.market_policy_versions;
create policy policies_public_read on public.market_policy_versions for select to anon, authenticated using (is_active = true and exists(select 1 from public.markets m where m.id = market_id and m.status = 'active'));
drop policy if exists shops_public_read on public.shops;
create policy shops_public_read on public.shops for select to anon, authenticated using (status = 'approved' and exists(select 1 from public.markets m where m.id = market_id and m.status = 'active'));
drop policy if exists categories_public_read on public.categories;
create policy categories_public_read on public.categories for select to anon, authenticated using (is_active = true and (market_id is null or exists(select 1 from public.markets m where m.id = market_id and m.status = 'active')));
drop policy if exists products_public_read on public.products;
create policy products_public_read on public.products for select to anon, authenticated using (status = 'active' and exists(select 1 from public.shops s where s.id = shop_id and s.status = 'approved'));
drop policy if exists fulfilment_public_read on public.shop_fulfilment_methods;
create policy fulfilment_public_read on public.shop_fulfilment_methods for select to anon, authenticated using (is_active = true and exists(select 1 from public.shops s where s.id = shop_id and s.status = 'approved'));

create policy profiles_self_read on public.profiles for select to authenticated using (id = (select auth.uid()) or private.is_admin());
create policy roles_self_read on public.user_roles for select to authenticated using (user_id = (select auth.uid()) or private.is_admin());
create policy merchants_owner_read on public.merchants for select to authenticated using (owner_user_id = (select auth.uid()) or private.is_admin());
create policy identity_cases_owner_read on public.identity_verification_cases for select to authenticated using (merchant_id in (select private.current_merchant_ids()) or private.is_admin());
create policy identity_evidence_owner_read on public.identity_evidence for select to authenticated using (exists(select 1 from public.identity_verification_cases c where c.id = identity_case_id and (c.merchant_id in (select private.current_merchant_ids()) or private.is_admin())));
create policy shops_owner_read on public.shops for select to authenticated using (merchant_id in (select private.current_merchant_ids()) or status = 'approved' or private.is_admin());
create policy products_owner_read on public.products for select to authenticated using (exists(select 1 from public.shops s where s.id = shop_id and (s.merchant_id in (select private.current_merchant_ids()) or s.status = 'approved' or private.is_admin())));
create policy payment_methods_owner_read on public.payment_methods for select to authenticated using (merchant_id in (select private.current_merchant_ids()) or (is_active = true and exists(select 1 from public.shops s where s.merchant_id = merchant_id and s.status = 'approved')) or private.is_admin());
create policy carts_owner_read on public.carts for select to authenticated using (customer_user_id = (select auth.uid()));
create policy carts_owner_insert on public.carts for insert to authenticated with check (customer_user_id = (select auth.uid()));
create policy carts_owner_update on public.carts for update to authenticated using (customer_user_id = (select auth.uid())) with check (customer_user_id = (select auth.uid()));
create policy carts_owner_delete on public.carts for delete to authenticated using (customer_user_id = (select auth.uid()));
create policy cart_items_owner_read on public.cart_items for select to authenticated using (exists(select 1 from public.carts c where c.id = cart_id and c.customer_user_id = (select auth.uid())));
create policy cart_items_owner_insert on public.cart_items for insert to authenticated with check (exists(select 1 from public.carts c where c.id = cart_id and c.customer_user_id = (select auth.uid())));
create policy cart_items_owner_update on public.cart_items for update to authenticated using (exists(select 1 from public.carts c where c.id = cart_id and c.customer_user_id = (select auth.uid()))) with check (exists(select 1 from public.carts c where c.id = cart_id and c.customer_user_id = (select auth.uid())));
create policy cart_items_owner_delete on public.cart_items for delete to authenticated using (exists(select 1 from public.carts c where c.id = cart_id and c.customer_user_id = (select auth.uid())));
create policy checkout_customer_read on public.checkout_sessions for select to authenticated using (customer_user_id = (select auth.uid()) or private.is_admin());
create policy orders_participant_read on public.merchant_orders for select to authenticated using (customer_user_id = (select auth.uid()) or merchant_id in (select private.current_merchant_ids()) or private.is_admin());
create policy order_items_participant_read on public.merchant_order_items for select to authenticated using (private.can_access_order(merchant_order_id));
create policy claims_participant_read on public.payment_claims for select to authenticated using (customer_user_id = (select auth.uid()) or exists(select 1 from public.merchant_orders o where o.id = merchant_order_id and (o.merchant_id in (select private.current_merchant_ids()) or private.is_admin())));
create policy proofs_participant_read on public.payment_proofs for select to authenticated using (exists(select 1 from public.payment_claims pc where pc.id = payment_claim_id and (pc.customer_user_id = (select auth.uid()) or exists(select 1 from public.merchant_orders o where o.id = pc.merchant_order_id and (o.merchant_id in (select private.current_merchant_ids()) or private.is_admin())))));
create policy history_participant_read on public.order_status_history for select to authenticated using (private.can_access_order(merchant_order_id));
create policy reports_participant_read on public.reports for select to authenticated using (reporter_user_id = (select auth.uid()) or private.is_admin());
create policy reports_owner_insert on public.reports for insert to authenticated with check (reporter_user_id = (select auth.uid()));
create policy audit_admin_read on public.audit_events for select to authenticated using (private.is_admin());

-- Checkout is the first authoritative multi-row command. It executes atomically.
create or replace function public.checkout_create_orders(
  p_market_id uuid,
  p_fulfilment_by_shop jsonb,
  p_payment_by_merchant jsonb
)
returns jsonb language plpgsql security definer set search_path = public, private, pg_catalog as $$
declare
  v_user uuid := (select auth.uid());
  v_cart carts%rowtype;
  v_session checkout_sessions%rowtype;
  v_group record;
  v_item record;
  v_fulfilment text;
  v_payment_id uuid;
  v_method payment_methods%rowtype;
  v_order merchant_orders%rowtype;
  v_subtotal bigint;
  v_order_ids jsonb := '[]'::jsonb;
begin
  if v_user is null then raise exception using errcode = '28000', message = 'AUTH_REQUIRED'; end if;
  if not exists(select 1 from markets where id = p_market_id and status = 'active') then raise exception using errcode = 'P0001', message = 'MARKET_UNAVAILABLE'; end if;
  select * into v_cart from carts where customer_user_id = v_user and market_id = p_market_id for update;
  if not found then raise exception using errcode = 'P0001', message = 'CART_EMPTY'; end if;
  if not exists(select 1 from cart_items where cart_id = v_cart.id) then raise exception using errcode = 'P0001', message = 'CART_EMPTY'; end if;
  insert into checkout_sessions(customer_user_id, market_id, status) values (v_user, p_market_id, 'created') returning * into v_session;

  for v_group in
    select s.id as shop_id, s.merchant_id, s.name as shop_name,
           sum(p.price_minor * ci.quantity)::bigint as subtotal_minor
    from cart_items ci join products p on p.id = ci.product_id join shops s on s.id = p.shop_id
    where ci.cart_id = v_cart.id group by s.id, s.merchant_id, s.name order by s.id
  loop
    select x->>'method' into v_fulfilment from jsonb_array_elements(coalesce(p_fulfilment_by_shop, '[]'::jsonb)) x where (x->>'shop_id')::uuid = v_group.shop_id limit 1;
    if v_fulfilment is null or not exists(select 1 from shop_fulfilment_methods sf where sf.shop_id = v_group.shop_id and sf.method = v_fulfilment and sf.is_active) then
      raise exception using errcode = 'P0001', message = 'FULFILMENT_UNAVAILABLE';
    end if;
    select (x->>'payment_method_id')::uuid into v_payment_id from jsonb_array_elements(coalesce(p_payment_by_merchant, '[]'::jsonb)) x where (x->>'merchant_id')::uuid = v_group.merchant_id limit 1;
    select * into v_method from payment_methods where id = v_payment_id and merchant_id = v_group.merchant_id and is_active and mode = 'manual' for update;
    if not found then raise exception using errcode = 'P0001', message = 'PAYMENT_METHOD_UNAVAILABLE'; end if;
    insert into merchant_orders(checkout_session_id, merchant_id, shop_id, customer_user_id, market_id, order_reference, currency, subtotal_minor, fee_minor, tax_minor, total_minor, payment_method_name, payment_method_id, account_holder_name, receiving_identifier, payment_instructions, proof_requirement, fulfilment_method, fulfilment_instructions)
    select v_session.id, v_group.merchant_id, v_group.shop_id, v_user, p_market_id,
      'YC-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 10)), v_method.currency, v_group.subtotal_minor, 0, 0, v_group.subtotal_minor,
      v_method.name, v_method.id, v_method.account_holder_name, v_method.receiving_identifier, v_method.customer_instructions, v_method.proof_requirement,
      v_fulfilment, sf.instructions
    from shop_fulfilment_methods sf where sf.shop_id = v_group.shop_id and sf.method = v_fulfilment and sf.is_active
    returning * into v_order;
    for v_item in select p.id, p.name, p.price_minor, p.stock_quantity, p.status, ci.quantity from cart_items ci join products p on p.id = ci.product_id where ci.cart_id = v_cart.id and p.shop_id = v_group.shop_id for update of p loop
      if v_item.status <> 'active' or v_item.stock_quantity < v_item.quantity then raise exception using errcode = 'P0001', message = 'STOCK_CHANGED'; end if;
      insert into merchant_order_items(merchant_order_id, product_id, product_name, unit_price_minor, quantity, line_total_minor) values (v_order.id, v_item.id, v_item.name, v_item.price_minor, v_item.quantity, v_item.price_minor * v_item.quantity);
      update products set stock_quantity = stock_quantity - v_item.quantity, status = case when stock_quantity - v_item.quantity = 0 then 'out_of_stock' else status end where id = v_item.id;
    end loop;
    insert into order_status_history(merchant_order_id, actor_user_id, event_type, previous_value, next_value) values (v_order.id, v_user, 'order_created', null, 'awaiting_payment');
    insert into audit_events(actor_user_id, action, resource_type, resource_id, metadata) values (v_user, 'checkout.merchant_order_created', 'merchant_order', v_order.id::text, jsonb_build_object('order_reference', v_order.order_reference, 'merchant_id', v_order.merchant_id));
    v_order_ids := v_order_ids || jsonb_build_object('id', v_order.id, 'order_reference', v_order.order_reference, 'merchant_id', v_order.merchant_id, 'total_minor', v_order.total_minor);
  end loop;
  delete from cart_items where cart_id = v_cart.id;
  update checkout_sessions set status = 'completed' where id = v_session.id;
  return jsonb_build_object('checkout_session_id', v_session.id, 'orders', v_order_ids);
end;
$$;
revoke all on function public.checkout_create_orders(uuid, jsonb, jsonb) from public, anon;
grant execute on function public.checkout_create_orders(uuid, jsonb, jsonb) to authenticated, service_role;

-- Payment and fulfilment commands remain separate from checkout.
create or replace function public.submit_payment_claim(p_merchant_order_id uuid, p_transaction_reference text, p_proof_storage_key text default null, p_proof_mime_type text default null, p_proof_original_name text default null)
returns jsonb language plpgsql security definer set search_path = public, private, pg_catalog as $$
declare o merchant_orders%rowtype; c payment_claims%rowtype;
begin
  select * into o from merchant_orders where id = p_merchant_order_id and customer_user_id = (select auth.uid()) for update;
  if not found or o.payment_status <> 'awaiting_payment' then raise exception using errcode = 'P0001', message = 'PAYMENT_CLAIM_NOT_ALLOWED'; end if;
  if (o.proof_requirement in ('reference','both') and nullif(trim(p_transaction_reference), '') is null) or (o.proof_requirement in ('screenshot','both') and nullif(trim(p_proof_storage_key), '') is null) then raise exception using errcode = 'P0001', message = 'PAYMENT_PROOF_REQUIRED'; end if;
  insert into payment_claims(merchant_order_id, customer_user_id, transaction_reference) values(o.id, (select auth.uid()), nullif(trim(p_transaction_reference), '')) returning * into c;
  if p_proof_storage_key is not null then insert into payment_proofs(payment_claim_id, storage_key, mime_type, original_name) values(c.id, p_proof_storage_key, coalesce(p_proof_mime_type, 'application/octet-stream'), p_proof_original_name); end if;
  update merchant_orders set payment_status = 'payment_under_review' where id = o.id;
  insert into order_status_history(merchant_order_id, actor_user_id, event_type, previous_value, next_value) values(o.id, (select auth.uid()), 'payment_claim_submitted', 'awaiting_payment', 'payment_under_review');
  insert into audit_events(actor_user_id, action, resource_type, resource_id) values((select auth.uid()), 'payment.claim_submitted', 'merchant_order', o.id::text);
  return jsonb_build_object('payment_status', 'payment_under_review');
end;
$$;
revoke all on function public.submit_payment_claim(uuid, text, text, text, text) from public, anon;
grant execute on function public.submit_payment_claim(uuid, text, text, text, text) to authenticated, service_role;

create or replace function public.review_payment_claim(p_merchant_order_id uuid, p_decision text, p_reason text default null)
returns jsonb language plpgsql security definer set search_path = public, private, pg_catalog as $$
declare o merchant_orders%rowtype;
begin
  if not private.has_role('merchant', null) and not private.is_admin() then raise exception using errcode = '42501', message = 'FORBIDDEN'; end if;
  select * into o from merchant_orders where id = p_merchant_order_id and (merchant_id in (select private.current_merchant_ids()) or private.is_admin()) for update;
  if not found or o.payment_status <> 'payment_under_review' or p_decision not in ('paid','rejected') or (p_decision = 'rejected' and nullif(trim(p_reason), '') is null) then raise exception using errcode = 'P0001', message = 'PAYMENT_REVIEW_NOT_ALLOWED'; end if;
  update merchant_orders set payment_status = p_decision where id = o.id;
  update payment_claims set reviewed_by_user_id = (select auth.uid()), reviewed_at = now(), review_note = nullif(trim(p_reason), '') where merchant_order_id = o.id and reviewed_at is null;
  insert into order_status_history(merchant_order_id, actor_user_id, event_type, previous_value, next_value, reason) values(o.id, (select auth.uid()), 'payment_reviewed', 'payment_under_review', p_decision, p_reason);
  insert into audit_events(actor_user_id, action, resource_type, resource_id, metadata) values((select auth.uid()), 'payment.claim_' || p_decision, 'merchant_order', o.id::text, jsonb_build_object('reason', p_reason));
  return jsonb_build_object('payment_status', p_decision);
end;
$$;
revoke all on function public.review_payment_claim(uuid, text, text) from public, anon;
grant execute on function public.review_payment_claim(uuid, text, text) to authenticated, service_role;

create or replace function public.transition_fulfilment(p_merchant_order_id uuid, p_next_status text, p_reason text default null)
returns jsonb language plpgsql security definer set search_path = public, private, pg_catalog as $$
declare o merchant_orders%rowtype;
begin
  select * into o from merchant_orders where id = p_merchant_order_id and (merchant_id in (select private.current_merchant_ids()) or private.is_admin()) for update;
  if not found or p_next_status not in ('ready','arranged','completed','cancelled') then raise exception using errcode = 'P0001', message = 'FULFILMENT_TRANSITION_NOT_ALLOWED'; end if;
  if p_next_status <> 'cancelled' and o.payment_status <> 'paid' then raise exception using errcode = 'P0001', message = 'PAYMENT_REQUIRED_BEFORE_FULFILMENT'; end if;
  update merchant_orders set fulfilment_status = p_next_status where id = o.id;
  insert into order_status_history(merchant_order_id, actor_user_id, event_type, previous_value, next_value, reason) values(o.id, (select auth.uid()), 'fulfilment_updated', o.fulfilment_status, p_next_status, p_reason);
  insert into audit_events(actor_user_id, action, resource_type, resource_id, metadata) values((select auth.uid()), 'fulfilment.' || p_next_status, 'merchant_order', o.id::text, jsonb_build_object('reason', p_reason));
  return jsonb_build_object('fulfilment_status', p_next_status);
end;
$$;
revoke all on function public.transition_fulfilment(uuid, text, text) from public, anon;
grant execute on function public.transition_fulfilment(uuid, text, text) to authenticated, service_role;

-- Storage buckets are private by default. Object access is separately controlled by storage.objects policies.
insert into storage.buckets(id, name, public) values ('product-assets','product-assets',false), ('payment-proofs','payment-proofs',false), ('identity-evidence','identity-evidence',false)
on conflict (id) do update set public = excluded.public;
revoke all on table storage.objects from anon, authenticated;
grant select, insert, update, delete on table storage.objects to authenticated;

drop policy if exists product_assets_authenticated_read on storage.objects;
create policy product_assets_authenticated_read on storage.objects for select to authenticated using (bucket_id = 'product-assets');
drop policy if exists product_assets_authenticated_insert on storage.objects;
create policy product_assets_authenticated_insert on storage.objects for insert to authenticated with check (bucket_id = 'product-assets' and (storage.foldername(name))[1] = (select auth.uid())::text);
drop policy if exists payment_proofs_owner_insert on storage.objects;
create policy payment_proofs_owner_insert on storage.objects for insert to authenticated with check (bucket_id = 'payment-proofs' and (storage.foldername(name))[1] = (select auth.uid())::text);
drop policy if exists payment_proofs_participant_read on storage.objects;
create policy payment_proofs_participant_read on storage.objects for select to authenticated using (bucket_id = 'payment-proofs' and ((storage.foldername(name))[1] = (select auth.uid())::text or private.is_admin()));
drop policy if exists identity_evidence_owner_insert on storage.objects;
create policy identity_evidence_owner_insert on storage.objects for insert to authenticated with check (bucket_id = 'identity-evidence' and (storage.foldername(name))[1] = (select auth.uid())::text);
drop policy if exists identity_evidence_admin_read on storage.objects;
create policy identity_evidence_admin_read on storage.objects for select to authenticated using (bucket_id = 'identity-evidence' and private.is_admin());
