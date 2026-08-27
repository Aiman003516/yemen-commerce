-- Research-backed local-commerce vertical slice.
-- Adds multi-channel catalog operations, carrier-neutral delivery planning,
-- exception visibility, and return logistics without custody, settlement, or
-- provider activation.

insert into public.erp_module_registry(
  module_key, bounded_context, owner_surface, api_version,
  implementation_status, provider_required, enabled, route_key,
  name_ar, description_ar, extension_slots
)
values
  ('commerce_channels', 'commerce_channels', 'merchant', 'v1', 'reviewable', false, true,
   'channels', 'القنوات والمتاجر', 'إدارة قنوات البيع والمتاجر المتعددة وقوائم المنتجات الخاصة بكل قناة.',
   '["channel.catalog","channel.analytics"]'::jsonb),
  ('delivery_orchestration', 'delivery_orchestration', 'merchant', 'v1', 'reviewable', false, true,
   'logistics', 'تنسيق التوصيل', 'خطط توصيل محايدة للمزود وأحداث التسليم والاستثناءات التشغيلية.',
   '["delivery.timeline","delivery.exception"]'::jsonb),
  ('returns_logistics', 'returns_logistics', 'merchant', 'v1', 'reviewable', false, true,
   'returns', 'لوجستيات المرتجعات', 'تتبع استلام المرتجعات وفحصها دون إنشاء استرداد مالي تلقائي.',
   '["returns.timeline","returns.review"]'::jsonb),
  ('trust_operations', 'trust_operations', 'merchant', 'v1', 'foundation', false, true,
   'trust', 'الثقة والعمليات', 'رسائل حالة واضحة وسجل تدقيق لاستثناءات التوصيل والمرتجعات.',
   '["trust.status"]'::jsonb)
on conflict (module_key) do update set
  bounded_context = excluded.bounded_context,
  owner_surface = excluded.owner_surface,
  api_version = excluded.api_version,
  implementation_status = excluded.implementation_status,
  provider_required = excluded.provider_required,
  enabled = excluded.enabled,
  route_key = excluded.route_key,
  name_ar = excluded.name_ar,
  description_ar = excluded.description_ar,
  extension_slots = excluded.extension_slots,
  updated_at = now();

insert into public.erp_module_contracts(
  module_key, contract_key, contract_kind, api_version,
  required_capability, status, input_schema, output_schema
)
values
  ('commerce_channels', 'merchant_channel', 'command', 'v1', null, 'active',
   '{"shop_id":"uuid","channel_key":"string","channel_kind":"enum","reason":"string"}'::jsonb,
   '{"channel_id":"uuid","status":"string"}'::jsonb),
  ('commerce_channels', 'channel_listing', 'command', 'v1', null, 'active',
   '{"channel_id":"uuid","product_id":"uuid","listing_status":"enum","reason":"string"}'::jsonb,
   '{"listing_id":"uuid","status":"string"}'::jsonb),
  ('delivery_orchestration', 'shipment_plan', 'command', 'v1', null, 'active',
   '{"merchant_order_id":"uuid","carrier_key":"string","service_level":"string","reason":"string"}'::jsonb,
   '{"shipment_plan_id":"uuid","dispatch_eligible":"boolean"}'::jsonb),
  ('delivery_orchestration', 'delivery_exception', 'command', 'v1', null, 'active',
   '{"shipment_plan_id":"uuid","code":"string","message":"string","reason":"string"}'::jsonb,
   '{"exception_id":"uuid","status":"string"}'::jsonb),
  ('returns_logistics', 'return_logistics', 'command', 'v1', null, 'active',
   '{"case_id":"uuid","method":"enum","customer_message":"string","reason":"string"}'::jsonb,
   '{"return_logistics_id":"uuid","status":"string"}'::jsonb)
on conflict (module_key, contract_key, api_version) do update set
  required_capability = excluded.required_capability,
  status = excluded.status,
  input_schema = excluded.input_schema,
  output_schema = excluded.output_schema;

create table if not exists public.commerce_channels (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  channel_key text not null check (channel_key ~ '^[a-z][a-z0-9_-]{1,63}$'),
  display_name text not null check (length(trim(display_name)) between 2 and 120),
  channel_kind text not null check (channel_kind in ('web','social','pos','b2b','marketplace','service')),
  status text not null default 'draft' check (status in ('draft','active','paused','archived')),
  public_slug text,
  public_config jsonb not null default '{}'::jsonb check (jsonb_typeof(public_config) = 'object'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (shop_id, channel_key),
  unique (public_slug)
);
create index if not exists commerce_channels_shop_status_idx
  on public.commerce_channels(shop_id, status, updated_at desc);

create table if not exists public.channel_listings (
  id uuid primary key default gen_random_uuid(),
  channel_id uuid not null references public.commerce_channels(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete restrict,
  listing_status text not null default 'draft' check (listing_status in ('draft','active','paused','archived')),
  channel_title text,
  channel_description text,
  price_override_minor bigint check (price_override_minor is null or price_override_minor > 0),
  currency_override text check (currency_override is null or char_length(currency_override) = 3),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (channel_id, product_id)
);
create index if not exists channel_listings_channel_status_idx
  on public.channel_listings(channel_id, listing_status, updated_at desc);
create index if not exists channel_listings_product_idx
  on public.channel_listings(product_id, listing_status);

create table if not exists public.shipment_plans (
  id uuid primary key default gen_random_uuid(),
  merchant_order_id uuid not null unique references public.merchant_orders(id) on delete cascade,
  carrier_key text not null default 'merchant_arranged',
  service_level text,
  status text not null default 'planned' check (status in ('planned','ready','dispatched','in_transit','delivered','failed','cancelled')),
  dispatch_eligible boolean not null default false,
  tracking_reference text,
  customer_message text,
  created_by_user_id uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists shipment_plans_order_status_idx
  on public.shipment_plans(merchant_order_id, status, updated_at desc);
create index if not exists shipment_plans_carrier_status_idx
  on public.shipment_plans(carrier_key, status, updated_at desc);

create table if not exists public.shipment_events (
  id uuid primary key default gen_random_uuid(),
  shipment_plan_id uuid not null references public.shipment_plans(id) on delete cascade,
  status text not null check (status in ('planned','ready','dispatched','in_transit','delivered','failed','cancelled')),
  customer_message text,
  recorded_by_user_id uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now()
);
create index if not exists shipment_events_plan_created_idx
  on public.shipment_events(shipment_plan_id, created_at desc);

create table if not exists public.delivery_exceptions (
  id uuid primary key default gen_random_uuid(),
  shipment_plan_id uuid not null references public.shipment_plans(id) on delete cascade,
  code text not null check (code ~ '^[a-z][a-z0-9_-]{1,63}$'),
  severity text not null default 'medium' check (severity in ('low','medium','high','critical')),
  status text not null default 'open' check (status in ('open','acknowledged','resolved','cancelled')),
  customer_message text,
  opened_by_user_id uuid not null references public.profiles(id) on delete restrict,
  resolved_by_user_id uuid references public.profiles(id) on delete set null,
  resolved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists delivery_exceptions_plan_status_idx
  on public.delivery_exceptions(shipment_plan_id, status, created_at desc);
create index if not exists delivery_exceptions_status_created_idx
  on public.delivery_exceptions(status, created_at desc);

create table if not exists public.return_logistics (
  id uuid primary key default gen_random_uuid(),
  order_case_id uuid not null unique references public.order_cases(id) on delete cascade,
  method text not null default 'seller_arranged' check (method in ('dropoff','pickup','seller_arranged','not_set')),
  status text not null default 'requested' check (status in ('requested','label_pending','awaiting_handoff','in_transit','received','inspected','closed','cancelled')),
  provider_key text,
  external_reference text,
  customer_message text,
  created_by_user_id uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists return_logistics_status_updated_idx
  on public.return_logistics(status, updated_at desc);

create table if not exists public.return_logistics_events (
  id uuid primary key default gen_random_uuid(),
  return_logistics_id uuid not null references public.return_logistics(id) on delete cascade,
  status text not null check (status in ('requested','label_pending','awaiting_handoff','in_transit','received','inspected','closed','cancelled')),
  customer_message text,
  recorded_by_user_id uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now()
);
create index if not exists return_logistics_events_return_created_idx
  on public.return_logistics_events(return_logistics_id, created_at desc);

alter table public.commerce_channels enable row level security;
alter table public.channel_listings enable row level security;
alter table public.shipment_plans enable row level security;
alter table public.shipment_events enable row level security;
alter table public.delivery_exceptions enable row level security;
alter table public.return_logistics enable row level security;
alter table public.return_logistics_events enable row level security;

grant select on public.commerce_channels, public.channel_listings, public.shipment_plans,
  public.shipment_events, public.delivery_exceptions, public.return_logistics,
  public.return_logistics_events to authenticated;
grant select on public.commerce_channels, public.channel_listings to anon;

-- Merchant/admin rows; public catalog rows are separately constrained below.
drop policy if exists commerce_channels_owner_read on public.commerce_channels;
create policy commerce_channels_owner_read on public.commerce_channels
for select to authenticated using (
  private.is_admin()
  or exists (
    select 1 from public.shops s
    join public.merchants m on m.id = s.merchant_id
    where s.id = commerce_channels.shop_id
      and m.owner_user_id = (select auth.uid())
  )
);

drop policy if exists channel_listings_participant_read on public.channel_listings;
create policy channel_listings_participant_read on public.channel_listings
for select to authenticated using (
  private.is_admin()
  or exists (
    select 1 from public.commerce_channels c
    join public.shops s on s.id = c.shop_id
    join public.merchants m on m.id = s.merchant_id
    where c.id = channel_listings.channel_id
      and m.owner_user_id = (select auth.uid())
  )
  or exists (
    select 1 from public.commerce_channels c
    join public.shops s on s.id = c.shop_id
    join public.markets market on market.id = s.market_id
    join public.products p on p.id = channel_listings.product_id
    where c.id = channel_listings.channel_id
      and c.status = 'active'
      and channel_listings.listing_status = 'active'
      and p.status = 'active'
      and s.status = 'approved'
      and market.status = 'active'
  )
);

drop policy if exists channel_listings_public_read on public.channel_listings;
create policy channel_listings_public_read on public.channel_listings
for select to anon using (
  listing_status = 'active'
  and exists (
    select 1 from public.commerce_channels c
    join public.shops s on s.id = c.shop_id
    join public.markets market on market.id = s.market_id
    join public.products p on p.id = channel_listings.product_id
    where c.id = channel_listings.channel_id
      and c.status = 'active'
      and p.status = 'active'
      and s.status = 'approved'
      and market.status = 'active'
  )
);

-- Customers see only their own delivery timeline; merchants/admins see their operational rows.
drop policy if exists shipment_plans_participant_read on public.shipment_plans;
create policy shipment_plans_participant_read on public.shipment_plans
for select to authenticated using (
  private.is_admin()
  or exists (
    select 1 from public.merchant_orders o
    where o.id = shipment_plans.merchant_order_id
      and (o.customer_user_id = (select auth.uid()) or o.merchant_id in (select private.current_merchant_ids()))
  )
);

drop policy if exists shipment_events_participant_read on public.shipment_events;
create policy shipment_events_participant_read on public.shipment_events
for select to authenticated using (
  private.is_admin()
  or exists (
    select 1 from public.shipment_plans sp
    join public.merchant_orders o on o.id = sp.merchant_order_id
    where sp.id = shipment_events.shipment_plan_id
      and (o.customer_user_id = (select auth.uid()) or o.merchant_id in (select private.current_merchant_ids()))
  )
);

drop policy if exists delivery_exceptions_merchant_read on public.delivery_exceptions;
create policy delivery_exceptions_merchant_read on public.delivery_exceptions
for select to authenticated using (
  private.is_admin()
  or exists (
    select 1 from public.shipment_plans sp
    join public.merchant_orders o on o.id = sp.merchant_order_id
    where sp.id = delivery_exceptions.shipment_plan_id
      and o.merchant_id in (select private.current_merchant_ids())
  )
);

drop policy if exists return_logistics_participant_read on public.return_logistics;
create policy return_logistics_participant_read on public.return_logistics
for select to authenticated using (
  private.is_admin()
  or exists (
    select 1 from public.order_cases c
    join public.merchant_orders o on o.id = c.merchant_order_id
    where c.id = return_logistics.order_case_id
      and (c.opened_by_user_id = (select auth.uid()) or o.merchant_id in (select private.current_merchant_ids()))
  )
);

drop policy if exists return_logistics_events_participant_read on public.return_logistics_events;
create policy return_logistics_events_participant_read on public.return_logistics_events
for select to authenticated using (
  private.is_admin()
  or exists (
    select 1 from public.return_logistics rl
    join public.order_cases c on c.id = rl.order_case_id
    join public.merchant_orders o on o.id = c.merchant_order_id
    where rl.id = return_logistics_events.return_logistics_id
      and (c.opened_by_user_id = (select auth.uid()) or o.merchant_id in (select private.current_merchant_ids()))
  )
);

create or replace function private.commerce_event_append_only()
returns trigger language plpgsql security invoker set search_path = public, private, pg_catalog as $$
begin
  raise exception using errcode = '42501', message = 'APPEND_ONLY_RECORD';
end;
$$;
revoke all on function private.commerce_event_append_only() from public, anon, authenticated;
create trigger shipment_events_append_only
before update or delete on public.shipment_events
for each row execute function private.commerce_event_append_only();
create trigger return_logistics_events_append_only
before update or delete on public.return_logistics_events
for each row execute function private.commerce_event_append_only();

create or replace function private.merchant_upsert_channel(
  p_shop_id uuid,
  p_channel_key text,
  p_display_name text,
  p_channel_kind text,
  p_status text,
  p_reason text
)
returns jsonb language plpgsql security definer set search_path = public, private, pg_catalog as $$
declare
  v_user uuid := (select auth.uid());
  v_channel commerce_channels%rowtype;
begin
  if v_user is null then raise exception using errcode = '28000', message = 'AUTH_REQUIRED'; end if;
  if length(trim(coalesce(p_reason, ''))) < 5 then raise exception using errcode = 'P0001', message = 'AUDIT_REASON_REQUIRED'; end if;
  if p_channel_key is null or p_channel_key !~ '^[a-z][a-z0-9_-]{1,63}$'
     or length(trim(coalesce(p_display_name, ''))) < 2
     or p_channel_kind not in ('web','social','pos','b2b','marketplace','service')
     or p_status not in ('draft','active','paused','archived') then
    raise exception using errcode = 'P0001', message = 'INVALID_CHANNEL';
  end if;
  if not private.is_admin() and not exists (
    select 1 from public.shops s join public.merchants m on m.id = s.merchant_id
    where s.id = p_shop_id and m.owner_user_id = v_user
  ) then raise exception using errcode = '42501', message = 'SHOP_NOT_OWNED'; end if;

  insert into commerce_channels(shop_id, channel_key, display_name, channel_kind, status)
  values(p_shop_id, lower(trim(p_channel_key)), trim(p_display_name), p_channel_kind, p_status)
  on conflict (shop_id, channel_key) do update set
    display_name = excluded.display_name,
    channel_kind = excluded.channel_kind,
    status = excluded.status,
    updated_at = now()
  returning * into v_channel;

  insert into audit_events(actor_user_id, action, resource_type, resource_id, metadata)
  values(v_user, 'merchant.channel_saved', 'commerce_channel', v_channel.id::text,
         jsonb_build_object('shop_id', p_shop_id, 'channel_key', v_channel.channel_key,
                            'status', v_channel.status, 'reason', trim(p_reason)));
  return jsonb_build_object('channel_id', v_channel.id, 'status', v_channel.status);
end;
$$;
revoke all on function private.merchant_upsert_channel(uuid, text, text, text, text, text) from public, anon;
grant execute on function private.merchant_upsert_channel(uuid, text, text, text, text, text) to authenticated, service_role;

create or replace function public.merchant_upsert_channel(
  p_shop_id uuid, p_channel_key text, p_display_name text, p_channel_kind text,
  p_status text, p_reason text
)
returns jsonb language sql security invoker set search_path = public, pg_catalog as $$
  select private.merchant_upsert_channel($1, $2, $3, $4, $5, $6);
$$;
revoke all on function public.merchant_upsert_channel(uuid, text, text, text, text, text) from public, anon;
grant execute on function public.merchant_upsert_channel(uuid, text, text, text, text, text) to authenticated;

create or replace function private.merchant_upsert_channel_listing(
  p_channel_id uuid,
  p_product_id uuid,
  p_listing_status text,
  p_channel_title text,
  p_channel_description text,
  p_price_override_minor bigint,
  p_currency_override text,
  p_reason text
)
returns jsonb language plpgsql security definer set search_path = public, private, pg_catalog as $$
declare
  v_user uuid := (select auth.uid());
  v_channel commerce_channels%rowtype;
  v_product products%rowtype;
  v_listing channel_listings%rowtype;
begin
  if v_user is null then raise exception using errcode = '28000', message = 'AUTH_REQUIRED'; end if;
  if length(trim(coalesce(p_reason, ''))) < 5 then raise exception using errcode = 'P0001', message = 'AUDIT_REASON_REQUIRED'; end if;
  if p_listing_status not in ('draft','active','paused','archived')
     or (p_price_override_minor is not null and p_price_override_minor <= 0)
     or (p_currency_override is not null and char_length(p_currency_override) <> 3) then
    raise exception using errcode = 'P0001', message = 'INVALID_CHANNEL_LISTING';
  end if;
  select c.* into v_channel from commerce_channels c join shops s on s.id = c.shop_id join merchants m on m.id = s.merchant_id
  where c.id = p_channel_id and (m.owner_user_id = v_user or private.is_admin()) for update;
  if not found then raise exception using errcode = '42501', message = 'CHANNEL_NOT_OWNED'; end if;
  select p.* into v_product from products p where p.id = p_product_id and p.shop_id = v_channel.shop_id for update;
  if not found then raise exception using errcode = 'P0001', message = 'PRODUCT_NOT_IN_CHANNEL_SHOP'; end if;
  if p_listing_status = 'active' and (v_channel.status <> 'active' or v_product.status <> 'active') then
    raise exception using errcode = 'P0001', message = 'CHANNEL_LISTING_REQUIRES_ACTIVE_RECORDS';
  end if;

  insert into channel_listings(channel_id, product_id, listing_status, channel_title, channel_description, price_override_minor, currency_override)
  values(p_channel_id, p_product_id, p_listing_status, nullif(trim(p_channel_title), ''), nullif(trim(p_channel_description), ''), p_price_override_minor, upper(nullif(trim(p_currency_override), '')))
  on conflict (channel_id, product_id) do update set
    listing_status = excluded.listing_status,
    channel_title = excluded.channel_title,
    channel_description = excluded.channel_description,
    price_override_minor = excluded.price_override_minor,
    currency_override = excluded.currency_override,
    updated_at = now()
  returning * into v_listing;

  insert into audit_events(actor_user_id, action, resource_type, resource_id, metadata)
  values(v_user, 'merchant.channel_listing_saved', 'channel_listing', v_listing.id::text,
         jsonb_build_object('channel_id', p_channel_id, 'product_id', p_product_id,
                            'status', v_listing.listing_status, 'reason', trim(p_reason)));
  return jsonb_build_object('listing_id', v_listing.id, 'status', v_listing.listing_status);
end;
$$;
revoke all on function private.merchant_upsert_channel_listing(uuid, uuid, text, text, text, bigint, text, text) from public, anon;
grant execute on function private.merchant_upsert_channel_listing(uuid, uuid, text, text, text, bigint, text, text) to authenticated, service_role;

create or replace function public.merchant_upsert_channel_listing(
  p_channel_id uuid, p_product_id uuid, p_listing_status text,
  p_channel_title text, p_channel_description text, p_price_override_minor bigint,
  p_currency_override text, p_reason text
)
returns jsonb language sql security invoker set search_path = public, pg_catalog as $$
  select private.merchant_upsert_channel_listing($1, $2, $3, $4, $5, $6, $7, $8);
$$;
revoke all on function public.merchant_upsert_channel_listing(uuid, uuid, text, text, text, bigint, text, text) from public, anon;
grant execute on function public.merchant_upsert_channel_listing(uuid, uuid, text, text, text, bigint, text, text) to authenticated;

create or replace function private.merchant_create_shipment_plan(
  p_merchant_order_id uuid,
  p_carrier_key text,
  p_service_level text,
  p_reason text
)
returns jsonb language plpgsql security definer set search_path = public, private, pg_catalog as $$
declare
  v_user uuid := (select auth.uid());
  v_order merchant_orders%rowtype;
  v_plan shipment_plans%rowtype;
begin
  if v_user is null then raise exception using errcode = '28000', message = 'AUTH_REQUIRED'; end if;
  if length(trim(coalesce(p_reason, ''))) < 5 then raise exception using errcode = 'P0001', message = 'AUDIT_REASON_REQUIRED'; end if;
  select o.* into v_order from merchant_orders o
  where o.id = p_merchant_order_id
    and (o.merchant_id in (select private.current_merchant_ids()) or private.is_admin()) for update;
  if not found then raise exception using errcode = '42501', message = 'ORDER_NOT_FOUND'; end if;
  if v_order.fulfilment_status = 'cancelled' or v_order.payment_status = 'cancelled' then
    raise exception using errcode = 'P0001', message = 'SHIPMENT_PLAN_NOT_ALLOWED';
  end if;
  if length(trim(coalesce(p_carrier_key, ''))) < 2 then raise exception using errcode = 'P0001', message = 'CARRIER_KEY_REQUIRED'; end if;

  insert into shipment_plans(merchant_order_id, carrier_key, service_level, dispatch_eligible, customer_message, created_by_user_id)
  values(v_order.id, lower(trim(p_carrier_key)), nullif(trim(p_service_level), ''), v_order.payment_status = 'paid',
         'تم إنشاء خطة التوصيل، وسيتم تحديث الحالة عند توفر معلومات جديدة.', v_user)
  on conflict (merchant_order_id) do update set
    carrier_key = excluded.carrier_key,
    service_level = excluded.service_level,
    dispatch_eligible = case when shipment_plans.status in ('planned','ready','failed') then excluded.dispatch_eligible else shipment_plans.dispatch_eligible end,
    updated_at = now()
  returning * into v_plan;

  insert into shipment_events(shipment_plan_id, status, customer_message, recorded_by_user_id)
  select v_plan.id, v_plan.status, v_plan.customer_message, v_user
  where not exists (select 1 from shipment_events e where e.shipment_plan_id = v_plan.id);
  insert into audit_events(actor_user_id, action, resource_type, resource_id, metadata)
  values(v_user, 'merchant.shipment_plan_saved', 'shipment_plan', v_plan.id::text,
         jsonb_build_object('merchant_order_id', v_order.id, 'carrier_key', v_plan.carrier_key,
                            'dispatch_eligible', v_plan.dispatch_eligible, 'reason', trim(p_reason)));
  return jsonb_build_object('shipment_plan_id', v_plan.id, 'status', v_plan.status,
                            'dispatch_eligible', v_plan.dispatch_eligible);
end;
$$;
revoke all on function private.merchant_create_shipment_plan(uuid, text, text, text) from public, anon;
grant execute on function private.merchant_create_shipment_plan(uuid, text, text, text) to authenticated, service_role;

create or replace function public.merchant_create_shipment_plan(
  p_merchant_order_id uuid, p_carrier_key text, p_service_level text, p_reason text
)
returns jsonb language sql security invoker set search_path = public, pg_catalog as $$
  select private.merchant_create_shipment_plan($1, $2, $3, $4);
$$;
revoke all on function public.merchant_create_shipment_plan(uuid, text, text, text) from public, anon;
grant execute on function public.merchant_create_shipment_plan(uuid, text, text, text) to authenticated;

create or replace function private.merchant_record_shipment_event(
  p_shipment_plan_id uuid,
  p_status text,
  p_customer_message text,
  p_reason text
)
returns jsonb language plpgsql security definer set search_path = public, private, pg_catalog as $$
declare
  v_user uuid := (select auth.uid());
  v_plan shipment_plans%rowtype;
  v_order merchant_orders%rowtype;
  v_allowed boolean := false;
  v_previous text;
begin
  if v_user is null then raise exception using errcode = '28000', message = 'AUTH_REQUIRED'; end if;
  if length(trim(coalesce(p_reason, ''))) < 5 then raise exception using errcode = 'P0001', message = 'AUDIT_REASON_REQUIRED'; end if;
  if p_status not in ('ready','dispatched','in_transit','delivered','failed','cancelled') then raise exception using errcode = 'P0001', message = 'INVALID_SHIPMENT_STATUS'; end if;
  select sp.* into v_plan from shipment_plans sp join merchant_orders o on o.id = sp.merchant_order_id
  where sp.id = p_shipment_plan_id and (o.merchant_id in (select private.current_merchant_ids()) or private.is_admin()) for update;
  if not found then raise exception using errcode = '42501', message = 'SHIPMENT_PLAN_NOT_FOUND'; end if;
  select * into v_order from merchant_orders where id = v_plan.merchant_order_id for update;
  v_previous := v_plan.status;
  v_allowed := (v_previous = 'planned' and p_status in ('ready','cancelled','failed'))
    or (v_previous = 'ready' and p_status in ('dispatched','cancelled','failed'))
    or (v_previous = 'dispatched' and p_status in ('in_transit','failed','cancelled'))
    or (v_previous = 'in_transit' and p_status in ('delivered','failed'))
    or (v_previous = 'failed' and p_status = 'ready');
  if not v_allowed then raise exception using errcode = 'P0001', message = 'INVALID_SHIPMENT_TRANSITION'; end if;
  if p_status in ('dispatched','in_transit','delivered') and v_order.payment_status <> 'paid' then
    raise exception using errcode = 'P0001', message = 'PAYMENT_CONFIRMATION_REQUIRED';
  end if;
  update shipment_plans set status = p_status, dispatch_eligible = (v_order.payment_status = 'paid'),
    customer_message = coalesce(nullif(trim(p_customer_message), ''), customer_message), updated_at = now()
  where id = v_plan.id;
  insert into shipment_events(shipment_plan_id, status, customer_message, recorded_by_user_id)
  values(v_plan.id, p_status, coalesce(nullif(trim(p_customer_message), ''), v_plan.customer_message), v_user);
  if p_status = 'delivered' and v_order.payment_status = 'paid' and v_order.fulfilment_status not in ('completed','cancelled') then
    update merchant_orders set fulfilment_status = 'completed', updated_at = now() where id = v_order.id;
    insert into order_status_history(merchant_order_id, actor_user_id, event_type, previous_value, next_value, reason)
    values(v_order.id, v_user, 'shipment_delivered', v_order.fulfilment_status, 'completed', p_reason);
  elsif p_status in ('dispatched','in_transit') and v_order.fulfilment_status not in ('arranged','completed','cancelled') then
    update merchant_orders set fulfilment_status = 'arranged', updated_at = now() where id = v_order.id;
    insert into order_status_history(merchant_order_id, actor_user_id, event_type, previous_value, next_value, reason)
    values(v_order.id, v_user, 'shipment_arranged', v_order.fulfilment_status, 'arranged', p_reason);
  end if;
  insert into audit_events(actor_user_id, action, resource_type, resource_id, metadata)
  values(v_user, 'merchant.shipment_status_changed', 'shipment_plan', v_plan.id::text,
         jsonb_build_object('previous_status', v_previous, 'next_status', p_status,
                            'merchant_order_id', v_order.id, 'reason', trim(p_reason)));
  return jsonb_build_object('shipment_plan_id', v_plan.id, 'status', p_status);
end;
$$;
revoke all on function private.merchant_record_shipment_event(uuid, text, text, text) from public, anon;
grant execute on function private.merchant_record_shipment_event(uuid, text, text, text) to authenticated, service_role;

create or replace function public.merchant_record_shipment_event(
  p_shipment_plan_id uuid, p_status text, p_customer_message text, p_reason text
)
returns jsonb language sql security invoker set search_path = public, pg_catalog as $$
  select private.merchant_record_shipment_event($1, $2, $3, $4);
$$;
revoke all on function public.merchant_record_shipment_event(uuid, text, text, text) from public, anon;
grant execute on function public.merchant_record_shipment_event(uuid, text, text, text) to authenticated;

create or replace function private.merchant_open_delivery_exception(
  p_shipment_plan_id uuid,
  p_code text,
  p_severity text,
  p_customer_message text,
  p_reason text
)
returns jsonb language plpgsql security definer set search_path = public, private, pg_catalog as $$
declare
  v_user uuid := (select auth.uid());
  v_plan shipment_plans%rowtype;
  v_exception delivery_exceptions%rowtype;
begin
  if v_user is null then raise exception using errcode = '28000', message = 'AUTH_REQUIRED'; end if;
  if length(trim(coalesce(p_reason, ''))) < 5 then raise exception using errcode = 'P0001', message = 'AUDIT_REASON_REQUIRED'; end if;
  if p_code is null or p_code !~ '^[a-z][a-z0-9_-]{1,63}$' or p_severity not in ('low','medium','high','critical')
     or length(trim(coalesce(p_customer_message, ''))) < 3 then raise exception using errcode = 'P0001', message = 'INVALID_DELIVERY_EXCEPTION'; end if;
  select sp.* into v_plan from shipment_plans sp join merchant_orders o on o.id = sp.merchant_order_id
  where sp.id = p_shipment_plan_id and (o.merchant_id in (select private.current_merchant_ids()) or private.is_admin());
  if not found then raise exception using errcode = '42501', message = 'SHIPMENT_PLAN_NOT_FOUND'; end if;
  insert into delivery_exceptions(shipment_plan_id, code, severity, customer_message, opened_by_user_id)
  values(v_plan.id, lower(trim(p_code)), p_severity, trim(p_customer_message), v_user)
  returning * into v_exception;
  insert into audit_events(actor_user_id, action, resource_type, resource_id, metadata)
  values(v_user, 'merchant.delivery_exception_opened', 'delivery_exception', v_exception.id::text,
         jsonb_build_object('shipment_plan_id', v_plan.id, 'code', v_exception.code,
                            'severity', v_exception.severity, 'reason', trim(p_reason)));
  return jsonb_build_object('exception_id', v_exception.id, 'status', v_exception.status);
end;
$$;
revoke all on function private.merchant_open_delivery_exception(uuid, text, text, text, text) from public, anon;
grant execute on function private.merchant_open_delivery_exception(uuid, text, text, text, text) to authenticated, service_role;

create or replace function public.merchant_open_delivery_exception(
  p_shipment_plan_id uuid, p_code text, p_severity text, p_customer_message text, p_reason text
)
returns jsonb language sql security invoker set search_path = public, pg_catalog as $$
  select private.merchant_open_delivery_exception($1, $2, $3, $4, $5);
$$;
revoke all on function public.merchant_open_delivery_exception(uuid, text, text, text, text) from public, anon;
grant execute on function public.merchant_open_delivery_exception(uuid, text, text, text, text) to authenticated;

create or replace function private.merchant_resolve_delivery_exception(
  p_exception_id uuid,
  p_status text,
  p_reason text
)
returns jsonb language plpgsql security definer set search_path = public, private, pg_catalog as $$
declare
  v_user uuid := (select auth.uid());
  v_exception delivery_exceptions%rowtype;
begin
  if v_user is null then raise exception using errcode = '28000', message = 'AUTH_REQUIRED'; end if;
  if length(trim(coalesce(p_reason, ''))) < 5 then raise exception using errcode = 'P0001', message = 'AUDIT_REASON_REQUIRED'; end if;
  if p_status not in ('acknowledged','resolved','cancelled') then raise exception using errcode = 'P0001', message = 'INVALID_EXCEPTION_STATUS'; end if;
  select de.* into v_exception from delivery_exceptions de join shipment_plans sp on sp.id = de.shipment_plan_id
  join merchant_orders o on o.id = sp.merchant_order_id
  where de.id = p_exception_id and (o.merchant_id in (select private.current_merchant_ids()) or private.is_admin()) for update;
  if not found then raise exception using errcode = '42501', message = 'DELIVERY_EXCEPTION_NOT_FOUND'; end if;
  if v_exception.status in ('resolved','cancelled') then raise exception using errcode = 'P0001', message = 'DELIVERY_EXCEPTION_FINAL'; end if;
  update delivery_exceptions set status = p_status, resolved_by_user_id = case when p_status in ('resolved','cancelled') then v_user else resolved_by_user_id end,
    resolved_at = case when p_status in ('resolved','cancelled') then now() else null end, updated_at = now()
  where id = v_exception.id;
  insert into audit_events(actor_user_id, action, resource_type, resource_id, metadata)
  values(v_user, 'merchant.delivery_exception_' || p_status, 'delivery_exception', v_exception.id::text,
         jsonb_build_object('previous_status', v_exception.status, 'reason', trim(p_reason)));
  return jsonb_build_object('exception_id', v_exception.id, 'status', p_status);
end;
$$;
revoke all on function private.merchant_resolve_delivery_exception(uuid, text, text) from public, anon;
grant execute on function private.merchant_resolve_delivery_exception(uuid, text, text) to authenticated, service_role;

create or replace function public.merchant_resolve_delivery_exception(
  p_exception_id uuid, p_status text, p_reason text
)
returns jsonb language sql security invoker set search_path = public, pg_catalog as $$
  select private.merchant_resolve_delivery_exception($1, $2, $3);
$$;
revoke all on function public.merchant_resolve_delivery_exception(uuid, text, text) from public, anon;
grant execute on function public.merchant_resolve_delivery_exception(uuid, text, text) to authenticated;

create or replace function private.merchant_start_return_logistics(
  p_order_case_id uuid,
  p_method text,
  p_customer_message text,
  p_reason text
)
returns jsonb language plpgsql security definer set search_path = public, private, pg_catalog as $$
declare
  v_user uuid := (select auth.uid());
  v_case order_cases%rowtype;
  v_return return_logistics%rowtype;
begin
  if v_user is null then raise exception using errcode = '28000', message = 'AUTH_REQUIRED'; end if;
  if length(trim(coalesce(p_reason, ''))) < 5 then raise exception using errcode = 'P0001', message = 'AUDIT_REASON_REQUIRED'; end if;
  if p_method not in ('dropoff','pickup','seller_arranged','not_set') then raise exception using errcode = 'P0001', message = 'INVALID_RETURN_METHOD'; end if;
  select c.* into v_case from order_cases c join merchant_orders o on o.id = c.merchant_order_id
  where c.id = p_order_case_id and c.case_type = 'return'
    and c.status in ('approved','resolved')
    and (o.merchant_id in (select private.current_merchant_ids()) or private.is_admin()) for update;
  if not found then raise exception using errcode = '42501', message = 'RETURN_CASE_NOT_READY'; end if;
  insert into return_logistics(order_case_id, method, customer_message, created_by_user_id)
  values(v_case.id, p_method, nullif(trim(p_customer_message), ''), v_user)
  on conflict (order_case_id) do update set method = excluded.method,
    customer_message = excluded.customer_message, updated_at = now()
  returning * into v_return;
  insert into return_logistics_events(return_logistics_id, status, customer_message, recorded_by_user_id)
  select v_return.id, v_return.status, v_return.customer_message, v_user
  where not exists (select 1 from return_logistics_events e where e.return_logistics_id = v_return.id);
  insert into audit_events(actor_user_id, action, resource_type, resource_id, metadata)
  values(v_user, 'merchant.return_logistics_started', 'return_logistics', v_return.id::text,
         jsonb_build_object('order_case_id', v_case.id, 'method', v_return.method, 'reason', trim(p_reason)));
  return jsonb_build_object('return_logistics_id', v_return.id, 'status', v_return.status);
end;
$$;
revoke all on function private.merchant_start_return_logistics(uuid, text, text, text) from public, anon;
grant execute on function private.merchant_start_return_logistics(uuid, text, text, text) to authenticated, service_role;

create or replace function public.merchant_start_return_logistics(
  p_order_case_id uuid, p_method text, p_customer_message text, p_reason text
)
returns jsonb language sql security invoker set search_path = public, pg_catalog as $$
  select private.merchant_start_return_logistics($1, $2, $3, $4);
$$;
revoke all on function public.merchant_start_return_logistics(uuid, text, text, text) from public, anon;
grant execute on function public.merchant_start_return_logistics(uuid, text, text, text) to authenticated;

create or replace function private.merchant_record_return_event(
  p_return_logistics_id uuid,
  p_status text,
  p_customer_message text,
  p_reason text
)
returns jsonb language plpgsql security definer set search_path = public, private, pg_catalog as $$
declare
  v_user uuid := (select auth.uid());
  v_return return_logistics%rowtype;
  v_allowed boolean := false;
  v_previous text;
begin
  if v_user is null then raise exception using errcode = '28000', message = 'AUTH_REQUIRED'; end if;
  if length(trim(coalesce(p_reason, ''))) < 5 then raise exception using errcode = 'P0001', message = 'AUDIT_REASON_REQUIRED'; end if;
  if p_status not in ('label_pending','awaiting_handoff','in_transit','received','inspected','closed','cancelled') then raise exception using errcode = 'P0001', message = 'INVALID_RETURN_STATUS'; end if;
  select rl.* into v_return from return_logistics rl join order_cases c on c.id = rl.order_case_id
  join merchant_orders o on o.id = c.merchant_order_id
  where rl.id = p_return_logistics_id and (o.merchant_id in (select private.current_merchant_ids()) or private.is_admin()) for update;
  if not found then raise exception using errcode = '42501', message = 'RETURN_LOGISTICS_NOT_FOUND'; end if;
  v_previous := v_return.status;
  v_allowed := (v_previous = 'requested' and p_status in ('label_pending','awaiting_handoff','cancelled'))
    or (v_previous = 'label_pending' and p_status in ('awaiting_handoff','cancelled'))
    or (v_previous = 'awaiting_handoff' and p_status in ('in_transit','cancelled'))
    or (v_previous = 'in_transit' and p_status in ('received','cancelled'))
    or (v_previous = 'received' and p_status in ('inspected','cancelled'))
    or (v_previous = 'inspected' and p_status in ('closed','cancelled'));
  if not v_allowed then raise exception using errcode = 'P0001', message = 'INVALID_RETURN_TRANSITION'; end if;
  update return_logistics set status = p_status,
    customer_message = coalesce(nullif(trim(p_customer_message), ''), customer_message), updated_at = now()
  where id = v_return.id;
  insert into return_logistics_events(return_logistics_id, status, customer_message, recorded_by_user_id)
  values(v_return.id, p_status, coalesce(nullif(trim(p_customer_message), ''), v_return.customer_message), v_user);
  insert into audit_events(actor_user_id, action, resource_type, resource_id, metadata)
  values(v_user, 'merchant.return_logistics_' || p_status, 'return_logistics', v_return.id::text,
         jsonb_build_object('previous_status', v_previous, 'reason', trim(p_reason)));
  return jsonb_build_object('return_logistics_id', v_return.id, 'status', p_status);
end;
$$;
revoke all on function private.merchant_record_return_event(uuid, text, text, text) from public, anon;
grant execute on function private.merchant_record_return_event(uuid, text, text, text) to authenticated, service_role;

create or replace function public.merchant_record_return_event(
  p_return_logistics_id uuid, p_status text, p_customer_message text, p_reason text
)
returns jsonb language sql security invoker set search_path = public, pg_catalog as $$
  select private.merchant_record_return_event($1, $2, $3, $4);
$$;
revoke all on function public.merchant_record_return_event(uuid, text, text, text) from public, anon;
grant execute on function public.merchant_record_return_event(uuid, text, text, text) to authenticated;

create or replace function private.merchant_get_operations_summary()
returns jsonb language sql security definer set search_path = public, private, pg_catalog as $$
  with owned_shops as (
    select s.id from shops s join merchants m on m.id = s.merchant_id
    where m.owner_user_id = (select auth.uid()) or private.is_admin()
  ),
  channels as (
    select count(*) filter (where c.status = 'active')::int active_count, count(*)::int total_count
    from commerce_channels c where c.shop_id in (select id from owned_shops)
  ),
  shipments as (
    select count(*) filter (where sp.status in ('planned','ready'))::int planned_count,
           count(*) filter (where sp.status in ('dispatched','in_transit'))::int in_flight_count,
           count(*) filter (where sp.status = 'delivered')::int delivered_count,
           count(*) filter (where sp.status = 'failed')::int failed_count
    from shipment_plans sp join merchant_orders o on o.id = sp.merchant_order_id
    where o.shop_id in (select id from owned_shops)
  ),
  exceptions as (
    select count(*) filter (where de.status in ('open','acknowledged'))::int open_count,
           count(*)::int total_count
    from delivery_exceptions de join shipment_plans sp on sp.id = de.shipment_plan_id
    join merchant_orders o on o.id = sp.merchant_order_id
    where o.shop_id in (select id from owned_shops)
  ),
  returns as (
    select count(*) filter (where rl.status not in ('closed','cancelled'))::int active_count,
           count(*) filter (where rl.status = 'received')::int awaiting_inspection_count,
           count(*)::int total_count
    from return_logistics rl join order_cases c on c.id = rl.order_case_id
    join merchant_orders o on o.id = c.merchant_order_id
    where o.shop_id in (select id from owned_shops)
  )
  select jsonb_build_object(
    'channels', (select to_jsonb(channels) from channels),
    'shipments', (select to_jsonb(shipments) from shipments),
    'delivery_exceptions', (select to_jsonb(exceptions) from exceptions),
    'returns', (select to_jsonb(returns) from returns),
    'custody_notice_ar', 'لا يحتفظ النظام بأموال التجار، وإثبات الدفع لا يساوي تأكيد الدفع.'
  );
$$;
revoke all on function private.merchant_get_operations_summary() from public, anon;
grant execute on function private.merchant_get_operations_summary() to authenticated, service_role;

create or replace function public.merchant_get_operations_summary()
returns jsonb language sql security invoker set search_path = public, pg_catalog as $$
  select private.merchant_get_operations_summary();
$$;
revoke all on function public.merchant_get_operations_summary() from public, anon;
grant execute on function public.merchant_get_operations_summary() to authenticated;

create or replace function public.get_published_channel_catalog(
  p_channel_id uuid,
  p_limit integer default 50,
  p_offset integer default 0
)
returns table(
  product_id uuid,
  product_name text,
  product_description text,
  price_minor bigint,
  currency text,
  channel_title text,
  channel_description text
)
language sql security invoker set search_path = public, pg_catalog as $$
  select p.id, p.name, p.description,
    coalesce(cl.price_override_minor, p.price_minor),
    coalesce(cl.currency_override, p.currency),
    coalesce(cl.channel_title, p.name),
    coalesce(cl.channel_description, p.description)
  from channel_listings cl
  join commerce_channels c on c.id = cl.channel_id
  join products p on p.id = cl.product_id
  join shops s on s.id = c.shop_id
  join markets m on m.id = s.market_id
  where cl.channel_id = p_channel_id
    and c.status = 'active'
    and cl.listing_status = 'active'
    and p.status = 'active'
    and s.status = 'approved'
    and m.status = 'active'
  order by p.created_at desc
  limit least(greatest(coalesce(p_limit, 50), 1), 100)
  offset greatest(coalesce(p_offset, 0), 0);
$$;
revoke all on function public.get_published_channel_catalog(uuid, integer, integer) from public;
grant execute on function public.get_published_channel_catalog(uuid, integer, integer) to anon, authenticated;

comment on table public.commerce_channels is 'Merchant-owned channel metadata; provider credentials and secrets are never stored here.';
comment on table public.shipment_plans is 'Carrier-neutral logistics projection; dispatch eligibility requires confirmed paid status and does not custody funds.';
comment on table public.return_logistics is 'Return logistics only; closing a return never creates an automatic refund or settlement.';
