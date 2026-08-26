-- Increment C: B2B quote versions, scale-safe rollups, asset variants, and provider gates.
-- Quotes and price snapshots remain merchant-owned operational records. No funds,
-- credit, automatic payment verification, or external provider call is performed.

create table if not exists public.wholesale_quotes (
  id uuid primary key default gen_random_uuid(),
  merchant_id uuid not null references public.merchants(id) on delete cascade,
  shop_id uuid not null references public.shops(id) on delete cascade,
  buyer_user_id uuid not null references public.profiles(id) on delete restrict,
  wholesale_request_id uuid references public.wholesale_requests(id) on delete set null,
  status text not null default 'draft' check (status in ('draft','sent','accepted','expired','rejected','cancelled')),
  current_version_no integer not null default 0 check (current_version_no >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists wholesale_quotes_shop_status_idx
  on public.wholesale_quotes(shop_id, status, updated_at desc);
create index if not exists wholesale_quotes_buyer_status_idx
  on public.wholesale_quotes(buyer_user_id, status, updated_at desc);

create table if not exists public.wholesale_quote_versions (
  id uuid primary key default gen_random_uuid(),
  quote_id uuid not null references public.wholesale_quotes(id) on delete cascade,
  version_no integer not null check (version_no > 0),
  status text not null default 'sent' check (status in ('draft','sent','accepted','expired','rejected','cancelled')),
  currency text not null default 'YER' check (char_length(currency) = 3),
  valid_until timestamptz,
  note text,
  reason text not null,
  created_by_user_id uuid not null references public.profiles(id) on delete restrict,
  accepted_by_user_id uuid references public.profiles(id) on delete set null,
  accepted_at timestamptz,
  created_at timestamptz not null default now(),
  unique (quote_id, version_no),
  check (valid_until is null or valid_until > created_at)
);
create index if not exists wholesale_quote_versions_quote_created_idx
  on public.wholesale_quote_versions(quote_id, created_at desc);

create table if not exists public.wholesale_quote_items (
  id uuid primary key default gen_random_uuid(),
  quote_version_id uuid not null references public.wholesale_quote_versions(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete restrict,
  variant_id uuid references public.product_variants(id) on delete restrict,
  product_name_snapshot text not null,
  unit_price_minor bigint not null check (unit_price_minor > 0),
  quantity integer not null check (quantity > 0),
  line_total_minor bigint not null check (line_total_minor > 0),
  created_at timestamptz not null default now()
);
create unique index if not exists wholesale_quote_items_unique_line_idx
  on public.wholesale_quote_items(quote_version_id, product_id, coalesce(variant_id, '00000000-0000-0000-0000-000000000000'::uuid));
create index if not exists wholesale_quote_items_product_idx
  on public.wholesale_quote_items(product_id, created_at desc);

alter table public.merchant_order_items
  add column if not exists variant_id uuid references public.product_variants(id) on delete restrict;
alter table public.merchant_orders
  add column if not exists wholesale_quote_version_id uuid references public.wholesale_quote_versions(id) on delete set null;
create index if not exists merchant_order_items_variant_idx
  on public.merchant_order_items(variant_id);
create index if not exists merchant_orders_quote_version_idx
  on public.merchant_orders(wholesale_quote_version_id);

create table if not exists public.merchant_daily_rollups (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  business_date date not null,
  order_count integer not null default 0 check (order_count >= 0),
  paid_order_count integer not null default 0 check (paid_order_count >= 0),
  gross_total_minor bigint not null default 0 check (gross_total_minor >= 0),
  cod_expected_minor bigint not null default 0 check (cod_expected_minor >= 0),
  cod_collected_minor bigint not null default 0 check (cod_collected_minor >= 0),
  wholesale_request_count integer not null default 0 check (wholesale_request_count >= 0),
  wholesale_approved_count integer not null default 0 check (wholesale_approved_count >= 0),
  pos_sale_count integer not null default 0 check (pos_sale_count >= 0),
  pos_gross_total_minor bigint not null default 0 check (pos_gross_total_minor >= 0),
  computed_at timestamptz not null default now(),
  computed_by_user_id uuid references public.profiles(id) on delete set null,
  unique (shop_id, business_date)
);
create index if not exists merchant_daily_rollups_shop_date_idx
  on public.merchant_daily_rollups(shop_id, business_date desc);

create table if not exists public.product_asset_variants (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  source_storage_key text not null,
  optimized_storage_key text,
  format text not null check (format in ('jpeg','png','webp')),
  width integer check (width is null or width > 0),
  height integer check (height is null or height > 0),
  byte_size integer check (byte_size is null or byte_size >= 0),
  status text not null default 'pending' check (status in ('pending','ready','failed')),
  failure_code text,
  created_by_user_id uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (product_id, source_storage_key, format)
);
create index if not exists product_asset_variants_product_status_idx
  on public.product_asset_variants(product_id, status, updated_at desc);

create table if not exists public.provider_adapter_operations (
  provider_code text not null references public.provider_catalog(provider_code) on delete cascade,
  operation_key text not null,
  category text not null check (category in ('messaging','logistics','maps','sales_channel','analytics','financing','payments','other')),
  enabled boolean not null default false,
  required_readiness_state text not null default 'configured' check (required_readiness_state in ('configured','pending_approval')),
  required_capability text,
  notes_ar text not null,
  updated_at timestamptz not null default now(),
  primary key (provider_code, operation_key)
);
create index if not exists provider_adapter_operations_enabled_idx
  on public.provider_adapter_operations(provider_code, enabled);

insert into public.provider_adapter_operations(provider_code, operation_key, category, enabled, required_readiness_state, required_capability, notes_ar)
values
  ('whatsapp_business', 'send_template_message', 'messaging', false, 'configured', 'manage_notifications', 'يتطلب اعتماد القوالب وموافقة العميل وتوقيع Webhook.'),
  ('yemen_sms', 'send_sms', 'messaging', false, 'configured', 'manage_notifications', 'لا إرسال فعلي في وضع المعاينة.'),
  ('local_courier', 'create_dispatch', 'logistics', false, 'configured', 'manage_fulfillment', 'لا يتم إنشاء شحنة خارجية دون عقد وتشغيل معتمد.'),
  ('maps_geocoding', 'geocode_address', 'maps', false, 'configured', 'manage_policies', 'يظل الحي ونقطة الاستلام بديلين محليين.'),
  ('social_catalog', 'publish_catalog', 'sales_channel', false, 'configured', 'manage_integrations', 'المعاينة لا تنشر إلى قنوات خارجية.'),
  ('merchant_finance', 'request_financing', 'financing', false, 'configured', 'manage_finance', 'يتطلب شريكاً مالياً مرخصاً ومراجعة قانونية.'),
  ('jaib_manual', 'verify_payment', 'payments', false, 'configured', 'manage_payments', 'غير متاح؛ Jaib يدوي QR/POS/مرجع فقط حتى اعتماد API رسمي.')
on conflict (provider_code, operation_key) do update set
  category = excluded.category,
  required_readiness_state = excluded.required_readiness_state,
  required_capability = excluded.required_capability,
  notes_ar = excluded.notes_ar,
  updated_at = now();

alter table public.wholesale_quotes enable row level security;
alter table public.wholesale_quote_versions enable row level security;
alter table public.wholesale_quote_items enable row level security;
alter table public.merchant_daily_rollups enable row level security;
alter table public.product_asset_variants enable row level security;
alter table public.provider_adapter_operations enable row level security;
grant select on public.wholesale_quotes, public.wholesale_quote_versions, public.wholesale_quote_items, public.merchant_daily_rollups, public.product_asset_variants, public.provider_adapter_operations to authenticated;

drop policy if exists wholesale_quotes_participant_read on public.wholesale_quotes;
create policy wholesale_quotes_participant_read on public.wholesale_quotes for select to authenticated
using (buyer_user_id = (select auth.uid()) or merchant_id in (select private.current_merchant_ids()) or private.is_admin());
drop policy if exists wholesale_quote_versions_participant_read on public.wholesale_quote_versions;
create policy wholesale_quote_versions_participant_read on public.wholesale_quote_versions for select to authenticated
using (exists (select 1 from wholesale_quotes q where q.id = quote_id and (q.buyer_user_id = (select auth.uid()) or q.merchant_id in (select private.current_merchant_ids()) or private.is_admin())));
drop policy if exists wholesale_quote_items_participant_read on public.wholesale_quote_items;
create policy wholesale_quote_items_participant_read on public.wholesale_quote_items for select to authenticated
using (exists (select 1 from wholesale_quote_versions v join wholesale_quotes q on q.id = v.quote_id where v.id = quote_version_id and (q.buyer_user_id = (select auth.uid()) or q.merchant_id in (select private.current_merchant_ids()) or private.is_admin())));
drop policy if exists merchant_daily_rollups_owner_read on public.merchant_daily_rollups;
create policy merchant_daily_rollups_owner_read on public.merchant_daily_rollups for select to authenticated
using (exists (select 1 from shops s where s.id = shop_id and (s.merchant_id in (select private.current_merchant_ids()) or private.is_admin())));
drop policy if exists product_asset_variants_owner_read on public.product_asset_variants;
create policy product_asset_variants_owner_read on public.product_asset_variants for select to authenticated
using (exists (select 1 from products p join shops s on s.id = p.shop_id where p.id = product_id and (s.merchant_id in (select private.current_merchant_ids()) or private.is_admin())));
drop policy if exists provider_adapter_operations_authenticated_read on public.provider_adapter_operations;
create policy provider_adapter_operations_authenticated_read on public.provider_adapter_operations for select to authenticated using (true);

create or replace function private.list_merchant_price_lists(p_shop_id uuid)
returns setof jsonb
language plpgsql security definer set search_path = public, private, pg_catalog
as $$
begin
  if auth.uid() is null then raise exception using errcode = '28000', message = 'AUTH_REQUIRED'; end if;
  if not exists (select 1 from shops s where s.id = p_shop_id and (s.merchant_id in (select private.current_merchant_ids()) or private.is_admin())) then
    raise exception using errcode = '42501', message = 'SHOP_NOT_OWNED';
  end if;
  return query
  select jsonb_build_object(
    'price_list_id', p.id,
    'shop_id', p.shop_id,
    'name_ar', p.name_ar,
    'currency', p.currency,
    'status', p.status,
    'updated_at', p.updated_at,
    'items', coalesce((select jsonb_agg(jsonb_build_object(
      'price_list_item_id', i.id,
      'product_id', i.product_id,
      'product_name', pr.name,
      'variant_id', i.variant_id,
      'unit_price_minor', i.unit_price_minor,
      'min_quantity', i.min_quantity,
      'status', i.status,
      'updated_at', i.updated_at
    ) order by pr.name, i.id) from wholesale_price_list_items i join products pr on pr.id = i.product_id where i.price_list_id = p.id), '[]'::jsonb)
  )
  from wholesale_price_lists p
  where p.shop_id = p_shop_id and (p.merchant_id in (select private.current_merchant_ids()) or private.is_admin())
  order by p.updated_at desc, p.id desc;
end;
$$;
revoke all on function private.list_merchant_price_lists(uuid) from public, anon, authenticated;
grant execute on function private.list_merchant_price_lists(uuid) to authenticated, service_role;
create or replace function public.list_merchant_price_lists(p_shop_id uuid)
returns setof jsonb language sql security invoker set search_path = public, pg_catalog
as $$ select * from private.list_merchant_price_lists(p_shop_id); $$;
revoke all on function public.list_merchant_price_lists(uuid) from public, anon;
grant execute on function public.list_merchant_price_lists(uuid) to authenticated;

create or replace function private.create_wholesale_quote_version(
  p_quote_id uuid,
  p_wholesale_request_id uuid,
  p_shop_id uuid,
  p_buyer_user_id uuid,
  p_currency text,
  p_valid_until timestamptz,
  p_note text,
  p_items jsonb,
  p_reason text
)
returns jsonb language plpgsql security definer set search_path = public, private, pg_catalog
as $$
declare
  v_user uuid := (select auth.uid());
  v_merchant uuid;
  v_quote wholesale_quotes%rowtype;
  v_version_id uuid;
  v_version_no integer;
  v_item jsonb;
  v_product products%rowtype;
  v_variant product_variants%rowtype;
  v_item_count integer;
  v_qty integer;
  v_unit bigint;
  v_variant_id uuid;
begin
  if v_user is null then raise exception using errcode = '28000', message = 'AUTH_REQUIRED'; end if;
  if length(trim(coalesce(p_reason, ''))) < 3 then raise exception using errcode = 'P0001', message = 'QUOTE_REASON_REQUIRED'; end if;
  if p_buyer_user_id is null or p_shop_id is null or p_items is null or jsonb_typeof(p_items) <> 'array' then raise exception using errcode = 'P0001', message = 'INVALID_QUOTE'; end if;
  v_item_count := jsonb_array_length(p_items);
  if v_item_count < 1 or v_item_count > 100 then raise exception using errcode = 'P0001', message = 'INVALID_QUOTE_ITEMS'; end if;
  select merchant_id into v_merchant from shops where id = p_shop_id and (merchant_id in (select private.current_merchant_ids()) or private.is_admin());
  if v_merchant is null then raise exception using errcode = '42501', message = 'SHOP_NOT_OWNED'; end if;
  if p_quote_id is null then
    if p_wholesale_request_id is not null and not exists (select 1 from wholesale_requests r where r.id = p_wholesale_request_id and r.shop_id = p_shop_id and r.buyer_user_id = p_buyer_user_id and r.merchant_id = v_merchant) then
      raise exception using errcode = 'P0001', message = 'WHOLESALE_REQUEST_NOT_FOUND';
    end if;
    insert into wholesale_quotes(merchant_id, shop_id, buyer_user_id, wholesale_request_id, status, current_version_no)
    values(v_merchant, p_shop_id, p_buyer_user_id, p_wholesale_request_id, 'sent', 0)
    returning * into v_quote;
  else
    select * into v_quote from wholesale_quotes where id = p_quote_id and shop_id = p_shop_id and (merchant_id in (select private.current_merchant_ids()) or private.is_admin()) for update;
    if not found then raise exception using errcode = 'P0001', message = 'QUOTE_NOT_FOUND'; end if;
    if v_quote.buyer_user_id <> p_buyer_user_id then raise exception using errcode = 'P0001', message = 'QUOTE_BUYER_MISMATCH'; end if;
  end if;
  v_version_no := v_quote.current_version_no + 1;
  insert into wholesale_quote_versions(quote_id, version_no, status, currency, valid_until, note, reason, created_by_user_id)
  values(v_quote.id, v_version_no, 'sent', upper(coalesce(nullif(trim(p_currency), ''), 'YER')), p_valid_until, nullif(trim(p_note), ''), trim(p_reason), v_user)
  returning id into v_version_id;
  for v_item in select value from jsonb_array_elements(p_items) loop
    v_qty := (v_item->>'quantity')::integer;
    v_unit := (v_item->>'unit_price_minor')::bigint;
    v_variant_id := nullif(v_item->>'variant_id', '')::uuid;
    select * into v_product from products where id = nullif(v_item->>'product_id', '')::uuid and shop_id = p_shop_id and status <> 'archived';
    if not found then raise exception using errcode = 'P0001', message = 'PRODUCT_NOT_IN_SHOP'; end if;
    if v_variant_id is not null then
      select * into v_variant from product_variants where id = v_variant_id and product_id = v_product.id and status <> 'archived';
      if not found then raise exception using errcode = 'P0001', message = 'VARIANT_NOT_IN_PRODUCT'; end if;
    end if;
    if v_qty is null or v_qty <= 0 or v_unit is null or v_unit <= 0 then raise exception using errcode = 'P0001', message = 'INVALID_QUOTE_ITEM'; end if;
    insert into wholesale_quote_items(quote_version_id, product_id, variant_id, product_name_snapshot, unit_price_minor, quantity, line_total_minor)
    values(v_version_id, v_product.id, v_variant_id, v_product.name, v_unit, v_qty, v_unit * v_qty);
  end loop;
  update wholesale_quotes set current_version_no = v_version_no, status = 'sent', updated_at = now() where id = v_quote.id;
  insert into audit_events(actor_user_id, action, resource_type, resource_id, metadata)
  values(v_user, 'b2b.quote_version_created', 'wholesale_quote', v_quote.id::text, jsonb_build_object('version_id', v_version_id, 'version_no', v_version_no, 'shop_id', p_shop_id, 'buyer_user_id', p_buyer_user_id, 'reason', trim(p_reason)));
  return jsonb_build_object('quote_id', v_quote.id, 'quote_version_id', v_version_id, 'version_no', v_version_no, 'status', 'sent');
exception when unique_violation then
  raise exception using errcode = '23505', message = 'QUOTE_VERSION_CONFLICT';
end;
$$;
revoke all on function private.create_wholesale_quote_version(uuid, uuid, uuid, uuid, text, timestamptz, text, jsonb, text) from public, anon, authenticated;
grant execute on function private.create_wholesale_quote_version(uuid, uuid, uuid, uuid, text, timestamptz, text, jsonb, text) to authenticated, service_role;
create or replace function public.create_wholesale_quote_version(p_quote_id uuid, p_wholesale_request_id uuid, p_shop_id uuid, p_buyer_user_id uuid, p_currency text, p_valid_until timestamptz, p_note text, p_items jsonb, p_reason text)
returns jsonb language sql security invoker set search_path = public, pg_catalog
as $$ select private.create_wholesale_quote_version(p_quote_id, p_wholesale_request_id, p_shop_id, p_buyer_user_id, p_currency, p_valid_until, p_note, p_items, p_reason); $$;
revoke all on function public.create_wholesale_quote_version(uuid, uuid, uuid, uuid, text, timestamptz, text, jsonb, text) from public, anon;
grant execute on function public.create_wholesale_quote_version(uuid, uuid, uuid, uuid, text, timestamptz, text, jsonb, text) to authenticated;

create or replace function private.accept_wholesale_quote_version(p_quote_version_id uuid)
returns jsonb language plpgsql security definer set search_path = public, private, pg_catalog
as $$
declare v_user uuid := (select auth.uid()); v_version wholesale_quote_versions%rowtype; v_quote wholesale_quotes%rowtype;
begin
  if v_user is null then raise exception using errcode = '28000', message = 'AUTH_REQUIRED'; end if;
  select v.* into v_version from wholesale_quote_versions v join wholesale_quotes q on q.id = v.quote_id where v.id = p_quote_version_id and q.buyer_user_id = v_user for update;
  if not found then raise exception using errcode = '42501', message = 'QUOTE_NOT_FOUND'; end if;
  if v_version.status <> 'sent' or (v_version.valid_until is not null and v_version.valid_until <= now()) then raise exception using errcode = 'P0001', message = 'QUOTE_NOT_AVAILABLE'; end if;
  update wholesale_quote_versions set status = 'accepted', accepted_by_user_id = v_user, accepted_at = now() where id = p_quote_version_id;
  update wholesale_quotes set status = 'accepted', updated_at = now() where id = v_version.quote_id returning * into v_quote;
  insert into audit_events(actor_user_id, action, resource_type, resource_id, metadata)
  values(v_user, 'b2b.quote_version_accepted', 'wholesale_quote_version', p_quote_version_id::text, jsonb_build_object('quote_id', v_version.quote_id, 'version_no', v_version.version_no));
  return jsonb_build_object('quote_id', v_version.quote_id, 'quote_version_id', p_quote_version_id, 'status', 'accepted');
end;
$$;
revoke all on function private.accept_wholesale_quote_version(uuid) from public, anon, authenticated;
grant execute on function private.accept_wholesale_quote_version(uuid) to authenticated, service_role;
create or replace function public.accept_wholesale_quote_version(p_quote_version_id uuid)
returns jsonb language sql security invoker set search_path = public, pg_catalog
as $$ select private.accept_wholesale_quote_version(p_quote_version_id); $$;
revoke all on function public.accept_wholesale_quote_version(uuid) from public, anon;
grant execute on function public.accept_wholesale_quote_version(uuid) to authenticated;

create or replace function private.apply_accepted_wholesale_quote(p_merchant_order_id uuid, p_quote_version_id uuid)
returns jsonb language plpgsql security definer set search_path = public, private, pg_catalog
as $$
declare
  v_user uuid := (select auth.uid());
  v_order merchant_orders%rowtype;
  v_version wholesale_quote_versions%rowtype;
  v_quote wholesale_quotes%rowtype;
  v_expected_count integer;
  v_actual_count integer;
  v_subtotal bigint;
  v_total bigint;
begin
  if v_user is null then raise exception using errcode = '28000', message = 'AUTH_REQUIRED'; end if;
  select o.* into v_order from merchant_orders o where o.id = p_merchant_order_id and o.customer_user_id = v_user for update;
  if not found then raise exception using errcode = '42501', message = 'ORDER_NOT_FOUND'; end if;
  if v_order.payment_status <> 'awaiting_payment' then raise exception using errcode = 'P0001', message = 'QUOTE_ORDER_NOT_EDITABLE'; end if;
  if v_order.promotion_id is not null or v_order.wholesale_quote_version_id is not null then raise exception using errcode = 'P0001', message = 'QUOTE_ORDER_ALREADY_PRICED'; end if;
  select v.* into v_version from wholesale_quote_versions v where v.id = p_quote_version_id and v.status = 'accepted' and (v.valid_until is null or v.valid_until > now());
  if not found then raise exception using errcode = 'P0001', message = 'QUOTE_NOT_AVAILABLE'; end if;
  select q.* into v_quote from wholesale_quotes q where q.id = v_version.quote_id and q.buyer_user_id = v_user and q.shop_id = v_order.shop_id;
  if not found then raise exception using errcode = '42501', message = 'QUOTE_NOT_FOUND'; end if;
  select count(*) into v_expected_count from wholesale_quote_items where quote_version_id = p_quote_version_id;
  select count(*) into v_actual_count from merchant_order_items where merchant_order_id = v_order.id;
  if v_expected_count <> v_actual_count then raise exception using errcode = 'P0001', message = 'QUOTE_ITEMS_MISMATCH'; end if;
  if exists (
    select 1 from merchant_order_items oi
    full join wholesale_quote_items qi on qi.quote_version_id = p_quote_version_id and qi.product_id = oi.product_id and coalesce(qi.variant_id, '00000000-0000-0000-0000-000000000000'::uuid) = coalesce(oi.variant_id, '00000000-0000-0000-0000-000000000000'::uuid) and qi.quantity = oi.quantity
    where oi.merchant_order_id = v_order.id and (oi.id is null or qi.id is null)
  ) then raise exception using errcode = 'P0001', message = 'QUOTE_ITEMS_MISMATCH'; end if;
  select coalesce(sum(qi.line_total_minor), 0) into v_subtotal from wholesale_quote_items qi where qi.quote_version_id = p_quote_version_id;
  update merchant_order_items oi
  set unit_price_minor = qi.unit_price_minor,
      line_total_minor = qi.line_total_minor
  from wholesale_quote_items qi
  where qi.quote_version_id = p_quote_version_id and oi.merchant_order_id = v_order.id and oi.product_id = qi.product_id and coalesce(oi.variant_id, '00000000-0000-0000-0000-000000000000'::uuid) = coalesce(qi.variant_id, '00000000-0000-0000-0000-000000000000'::uuid);
  v_total := v_subtotal + v_order.fee_minor + v_order.tax_minor;
  update merchant_orders set subtotal_minor = v_subtotal, total_minor = v_total, discount_minor = 0, cod_expected_minor = case when payment_provider_code = 'cash' then v_total else cod_expected_minor end, wholesale_quote_version_id = p_quote_version_id, updated_at = now() where id = v_order.id;
  insert into order_status_history(merchant_order_id, actor_user_id, event_type, previous_value, next_value, reason)
  values(v_order.id, v_user, 'wholesale_quote_applied', v_order.total_minor::text, v_total::text, v_version.reason);
  insert into audit_events(actor_user_id, action, resource_type, resource_id, metadata)
  values(v_user, 'b2b.quote_applied_to_order', 'merchant_order', v_order.id::text, jsonb_build_object('quote_version_id', p_quote_version_id, 'subtotal_minor', v_subtotal, 'total_minor', v_total));
  return jsonb_build_object('merchant_order_id', v_order.id, 'quote_version_id', p_quote_version_id, 'subtotal_minor', v_subtotal, 'total_minor', v_total);
end;
$$;
revoke all on function private.apply_accepted_wholesale_quote(uuid, uuid) from public, anon, authenticated;
grant execute on function private.apply_accepted_wholesale_quote(uuid, uuid) to authenticated, service_role;
create or replace function public.apply_accepted_wholesale_quote(p_merchant_order_id uuid, p_quote_version_id uuid)
returns jsonb language sql security invoker set search_path = public, pg_catalog
as $$ select private.apply_accepted_wholesale_quote(p_merchant_order_id, p_quote_version_id); $$;
revoke all on function public.apply_accepted_wholesale_quote(uuid, uuid) from public, anon;
grant execute on function public.apply_accepted_wholesale_quote(uuid, uuid) to authenticated;

create or replace function private.refresh_merchant_daily_rollup(p_shop_id uuid, p_business_date date)
returns jsonb language plpgsql security definer set search_path = public, private, pg_catalog
as $$
declare
  v_user uuid := (select auth.uid()); v_merchant uuid; v_row merchant_daily_rollups%rowtype;
begin
  if v_user is null then raise exception using errcode = '28000', message = 'AUTH_REQUIRED'; end if;
  if p_business_date is null or p_business_date > current_date then raise exception using errcode = 'P0001', message = 'INVALID_ROLLUP_DATE'; end if;
  select merchant_id into v_merchant from shops where id = p_shop_id and (merchant_id in (select private.current_merchant_ids()) or private.is_admin());
  if v_merchant is null then raise exception using errcode = '42501', message = 'SHOP_NOT_OWNED'; end if;
  insert into merchant_daily_rollups(shop_id, business_date, order_count, paid_order_count, gross_total_minor, cod_expected_minor, cod_collected_minor, wholesale_request_count, wholesale_approved_count, pos_sale_count, pos_gross_total_minor, computed_by_user_id)
  select p_shop_id, p_business_date,
    (select count(*) from merchant_orders o where o.shop_id = p_shop_id and o.created_at::date = p_business_date),
    (select count(*) from merchant_orders o where o.shop_id = p_shop_id and o.created_at::date = p_business_date and o.payment_status = 'paid'),
    coalesce((select sum(o.total_minor) from merchant_orders o where o.shop_id = p_shop_id and o.created_at::date = p_business_date and o.payment_status <> 'cancelled'), 0),
    coalesce((select sum(o.cod_expected_minor) from merchant_orders o where o.shop_id = p_shop_id and o.created_at::date = p_business_date and o.payment_provider_code = 'cash'), 0),
    coalesce((select sum(o.cod_collected_minor) from merchant_orders o where o.shop_id = p_shop_id and o.created_at::date = p_business_date and o.payment_provider_code = 'cash'), 0),
    (select count(*) from wholesale_requests r where r.shop_id = p_shop_id and r.created_at::date = p_business_date),
    (select count(*) from wholesale_requests r where r.shop_id = p_shop_id and r.created_at::date = p_business_date and r.status = 'approved'),
    (select count(*) from pos_sales s where s.shop_id = p_shop_id and s.created_at::date = p_business_date and s.reconciliation_status <> 'voided'),
    coalesce((select sum(s.total_minor) from pos_sales s where s.shop_id = p_shop_id and s.created_at::date = p_business_date and s.reconciliation_status <> 'voided'), 0),
    v_user
  on conflict (shop_id, business_date) do update set
    order_count = excluded.order_count,
    paid_order_count = excluded.paid_order_count,
    gross_total_minor = excluded.gross_total_minor,
    cod_expected_minor = excluded.cod_expected_minor,
    cod_collected_minor = excluded.cod_collected_minor,
    wholesale_request_count = excluded.wholesale_request_count,
    wholesale_approved_count = excluded.wholesale_approved_count,
    pos_sale_count = excluded.pos_sale_count,
    pos_gross_total_minor = excluded.pos_gross_total_minor,
    computed_at = now(),
    computed_by_user_id = excluded.computed_by_user_id
  returning * into v_row;
  insert into audit_events(actor_user_id, action, resource_type, resource_id, metadata)
  values(v_user, 'merchant.daily_rollup_refreshed', 'merchant_daily_rollup', v_row.id::text, jsonb_build_object('shop_id', p_shop_id, 'business_date', p_business_date));
  return jsonb_build_object('rollup_id', v_row.id, 'shop_id', v_row.shop_id, 'business_date', v_row.business_date, 'order_count', v_row.order_count, 'gross_total_minor', v_row.gross_total_minor, 'computed_at', v_row.computed_at);
end;
$$;
revoke all on function private.refresh_merchant_daily_rollup(uuid, date) from public, anon, authenticated;
grant execute on function private.refresh_merchant_daily_rollup(uuid, date) to authenticated, service_role;
create or replace function public.refresh_merchant_daily_rollup(p_shop_id uuid, p_business_date date)
returns jsonb language sql security invoker set search_path = public, pg_catalog
as $$ select private.refresh_merchant_daily_rollup(p_shop_id, p_business_date); $$;
revoke all on function public.refresh_merchant_daily_rollup(uuid, date) from public, anon;
grant execute on function public.refresh_merchant_daily_rollup(uuid, date) to authenticated;

create or replace function private.merchant_daily_rollups(p_shop_id uuid, p_from date, p_to date, p_limit integer default 90, p_offset integer default 0)
returns setof jsonb language plpgsql security definer set search_path = public, private, pg_catalog
as $$
begin
  if auth.uid() is null then raise exception using errcode = '28000', message = 'AUTH_REQUIRED'; end if;
  if p_from is null or p_to is null or p_to < p_from or p_to - p_from > 366 or p_limit is null or p_limit < 1 or p_limit > 366 or p_offset is null or p_offset < 0 or p_offset > 10000 then
    raise exception using errcode = 'P0001', message = 'INVALID_ROLLUP_RANGE';
  end if;
  if not exists (select 1 from shops s where s.id = p_shop_id and (s.merchant_id in (select private.current_merchant_ids()) or private.is_admin())) then
    raise exception using errcode = '42501', message = 'SHOP_NOT_OWNED';
  end if;
  return query select jsonb_build_object('id', r.id, 'shop_id', r.shop_id, 'business_date', r.business_date, 'order_count', r.order_count, 'paid_order_count', r.paid_order_count, 'gross_total_minor', r.gross_total_minor, 'cod_expected_minor', r.cod_expected_minor, 'cod_collected_minor', r.cod_collected_minor, 'wholesale_request_count', r.wholesale_request_count, 'wholesale_approved_count', r.wholesale_approved_count, 'pos_sale_count', r.pos_sale_count, 'pos_gross_total_minor', r.pos_gross_total_minor, 'computed_at', r.computed_at)
  from merchant_daily_rollups r where r.shop_id = p_shop_id and r.business_date between p_from and p_to order by r.business_date desc limit p_limit offset p_offset;
end;
$$;
revoke all on function private.merchant_daily_rollups(uuid, date, date, integer, integer) from public, anon, authenticated;
grant execute on function private.merchant_daily_rollups(uuid, date, date, integer, integer) to authenticated, service_role;
create or replace function public.merchant_daily_rollups(p_shop_id uuid, p_from date, p_to date, p_limit integer default 90, p_offset integer default 0)
returns setof jsonb language sql security invoker set search_path = public, pg_catalog
as $$ select * from private.merchant_daily_rollups(p_shop_id, p_from, p_to, p_limit, p_offset); $$;
revoke all on function public.merchant_daily_rollups(uuid, date, date, integer, integer) from public, anon;
grant execute on function public.merchant_daily_rollups(uuid, date, date, integer, integer) to authenticated;

create or replace function private.register_product_asset_variant(p_product_id uuid, p_source_storage_key text, p_format text, p_width integer, p_height integer, p_byte_size integer)
returns jsonb language plpgsql security definer set search_path = public, private, pg_catalog
as $$
declare v_user uuid := (select auth.uid()); v_id uuid;
begin
  if v_user is null then raise exception using errcode = '28000', message = 'AUTH_REQUIRED'; end if;
  if not exists (select 1 from products p join shops s on s.id = p.shop_id where p.id = p_product_id and (s.merchant_id in (select private.current_merchant_ids()) or private.is_admin())) then raise exception using errcode = '42501', message = 'PRODUCT_NOT_FOUND'; end if;
  if length(trim(coalesce(p_source_storage_key, ''))) < 3 or p_format not in ('jpeg','png','webp') or p_width is null or p_width <= 0 or p_height is null or p_height <= 0 or p_byte_size is null or p_byte_size < 0 then raise exception using errcode = 'P0001', message = 'INVALID_ASSET_VARIANT'; end if;
  insert into product_asset_variants(product_id, source_storage_key, format, width, height, byte_size, status, created_by_user_id)
  values(p_product_id, trim(p_source_storage_key), lower(p_format), p_width, p_height, p_byte_size, 'pending', v_user)
  on conflict (product_id, source_storage_key, format) do update set width = excluded.width, height = excluded.height, byte_size = excluded.byte_size, status = 'pending', failure_code = null, updated_at = now(), created_by_user_id = v_user
  returning id into v_id;
  insert into audit_events(actor_user_id, action, resource_type, resource_id, metadata)
  values(v_user, 'merchant.product_asset_variant_registered', 'product_asset_variant', v_id::text, jsonb_build_object('product_id', p_product_id, 'format', lower(p_format), 'width', p_width, 'height', p_height, 'byte_size', p_byte_size));
  return jsonb_build_object('asset_variant_id', v_id, 'status', 'pending');
end;
$$;
revoke all on function private.register_product_asset_variant(uuid, text, text, integer, integer, integer) from public, anon, authenticated;
grant execute on function private.register_product_asset_variant(uuid, text, text, integer, integer, integer) to authenticated, service_role;
create or replace function public.register_product_asset_variant(p_product_id uuid, p_source_storage_key text, p_format text, p_width integer, p_height integer, p_byte_size integer)
returns jsonb language sql security invoker set search_path = public, pg_catalog
as $$ select private.register_product_asset_variant(p_product_id, p_source_storage_key, p_format, p_width, p_height, p_byte_size); $$;
revoke all on function public.register_product_asset_variant(uuid, text, text, integer, integer, integer) from public, anon;
grant execute on function public.register_product_asset_variant(uuid, text, text, integer, integer, integer) to authenticated;

create or replace function public.provider_adapter_operations()
returns setof jsonb language sql security invoker set search_path = public, pg_catalog
as $$
  select jsonb_build_object('provider_code', o.provider_code, 'operation_key', o.operation_key, 'category', o.category, 'enabled', o.enabled, 'required_readiness_state', o.required_readiness_state, 'required_capability', o.required_capability, 'notes_ar', o.notes_ar)
  from provider_adapter_operations o order by o.category, o.provider_code, o.operation_key;
$$;
revoke all on function public.provider_adapter_operations() from public, anon;
grant execute on function public.provider_adapter_operations() to authenticated;
