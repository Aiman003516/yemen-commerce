-- Yemen-first geography and delivery foundation.
-- This migration adds configuration and ownership boundaries without changing
-- the existing merchant-order splitting or payment-review semantics.

create table if not exists public.market_service_areas (
  id uuid primary key default gen_random_uuid(),
  market_id uuid not null references public.markets(id) on delete cascade,
  name_ar text not null,
  name_en text,
  area_code text not null,
  status text not null default 'draft' check (status in ('draft', 'active', 'paused')),
  delivery_enabled boolean not null default true,
  pickup_enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (market_id, area_code)
);
create index if not exists market_service_areas_market_status_idx
  on public.market_service_areas(market_id, status);

create table if not exists public.pickup_points (
  id uuid primary key default gen_random_uuid(),
  market_id uuid not null references public.markets(id) on delete cascade,
  service_area_id uuid references public.market_service_areas(id) on delete set null,
  name_ar text not null,
  name_en text,
  address_details text not null,
  contact_phone text,
  operating_hours text,
  status text not null default 'draft' check (status in ('draft', 'active', 'paused')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists pickup_points_market_status_idx
  on public.pickup_points(market_id, status);

create table if not exists public.customer_addresses (
  id uuid primary key default gen_random_uuid(),
  customer_user_id uuid not null references public.profiles(id) on delete cascade,
  market_id uuid not null references public.markets(id) on delete restrict,
  service_area_id uuid references public.market_service_areas(id) on delete set null,
  label text not null,
  recipient_name text not null,
  phone text not null,
  address_line text not null,
  landmark text,
  city text not null,
  district text,
  is_default boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists customer_addresses_owner_market_idx
  on public.customer_addresses(customer_user_id, market_id, is_active);

create table if not exists public.merchant_delivery_zones (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  service_area_id uuid references public.market_service_areas(id) on delete restrict,
  name text not null,
  fee_minor bigint not null default 0 check (fee_minor >= 0),
  currency text not null default 'YER' check (char_length(currency) = 3),
  eta_min_minutes integer check (eta_min_minutes is null or eta_min_minutes >= 0),
  eta_max_minutes integer check (eta_max_minutes is null or eta_max_minutes >= coalesce(eta_min_minutes, 0)),
  instructions text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (shop_id, service_area_id)
);
create index if not exists merchant_delivery_zones_shop_active_idx
  on public.merchant_delivery_zones(shop_id, is_active);

alter table public.merchant_orders
  add column if not exists delivery_address_snapshot jsonb not null default '{}'::jsonb,
  add column if not exists pickup_point_id uuid references public.pickup_points(id) on delete set null,
  add column if not exists delivery_zone_id uuid references public.merchant_delivery_zones(id) on delete set null,
  add column if not exists delivery_fee_minor bigint not null default 0;

alter table public.merchant_orders
  drop constraint if exists merchant_orders_delivery_address_snapshot_object_check;
alter table public.merchant_orders
  add constraint merchant_orders_delivery_address_snapshot_object_check
  check (jsonb_typeof(delivery_address_snapshot) = 'object' and length(delivery_address_snapshot::text) <= 4000);

alter table public.merchant_orders
  drop constraint if exists merchant_orders_delivery_fee_nonnegative_check;
alter table public.merchant_orders
  add constraint merchant_orders_delivery_fee_nonnegative_check
  check (delivery_fee_minor >= 0);

alter table public.market_service_areas enable row level security;
alter table public.pickup_points enable row level security;
alter table public.customer_addresses enable row level security;
alter table public.merchant_delivery_zones enable row level security;

grant select on public.market_service_areas, public.pickup_points, public.merchant_delivery_zones to anon, authenticated;
grant select, insert, update, delete on public.customer_addresses to authenticated;

drop policy if exists market_service_areas_public_read on public.market_service_areas;
create policy market_service_areas_public_read
on public.market_service_areas for select to anon, authenticated
using (
  status = 'active'
  and exists (select 1 from public.markets m where m.id = market_id and m.status = 'active')
);

drop policy if exists pickup_points_public_read on public.pickup_points;
create policy pickup_points_public_read
on public.pickup_points for select to anon, authenticated
using (
  status = 'active'
  and exists (select 1 from public.markets m where m.id = market_id and m.status = 'active')
);

drop policy if exists customer_addresses_owner_read on public.customer_addresses;
create policy customer_addresses_owner_read
on public.customer_addresses for select to authenticated
using (customer_user_id = (select auth.uid()) or private.is_admin());

drop policy if exists customer_addresses_owner_insert on public.customer_addresses;
create policy customer_addresses_owner_insert
on public.customer_addresses for insert to authenticated
with check (customer_user_id = (select auth.uid()));

drop policy if exists customer_addresses_owner_update on public.customer_addresses;
create policy customer_addresses_owner_update
on public.customer_addresses for update to authenticated
using (customer_user_id = (select auth.uid()) or private.is_admin())
with check (customer_user_id = (select auth.uid()) or private.is_admin());

drop policy if exists customer_addresses_owner_delete on public.customer_addresses;
create policy customer_addresses_owner_delete
on public.customer_addresses for delete to authenticated
using (customer_user_id = (select auth.uid()) or private.is_admin());

drop policy if exists merchant_delivery_zones_public_read on public.merchant_delivery_zones;
create policy merchant_delivery_zones_public_read
on public.merchant_delivery_zones for select to anon, authenticated
using (
  is_active
  and exists (
    select 1 from public.shops s
    join public.markets m on m.id = s.market_id
    where s.id = shop_id and s.status = 'approved' and m.status = 'active'
  )
);
drop policy if exists merchant_delivery_zones_owner_read on public.merchant_delivery_zones;
create policy merchant_delivery_zones_owner_read
on public.merchant_delivery_zones for select to authenticated
using (
  exists (
    select 1 from public.shops s
    join public.merchants merchant on merchant.id = s.merchant_id
    where s.id = shop_id and (merchant.owner_user_id = (select auth.uid()) or private.is_admin())
  )
);

create or replace function private.save_customer_address(
  p_id uuid,
  p_market_id uuid,
  p_service_area_id uuid,
  p_label text,
  p_recipient_name text,
  p_phone text,
  p_address_line text,
  p_landmark text,
  p_city text,
  p_district text,
  p_is_default boolean
)
returns jsonb
language plpgsql
security definer
set search_path = public, private, pg_catalog
as $$
declare
  v_user uuid := (select auth.uid());
  v_id uuid;
  v_address customer_addresses%rowtype;
begin
  if v_user is null then
    raise exception using errcode = '28000', message = 'AUTH_REQUIRED';
  end if;
  if not exists (select 1 from markets where id = p_market_id and status = 'active') then
    raise exception using errcode = 'P0001', message = 'MARKET_UNAVAILABLE';
  end if;
  if p_service_area_id is not null and not exists (
    select 1 from market_service_areas
    where id = p_service_area_id and market_id = p_market_id and status = 'active'
  ) then
    raise exception using errcode = 'P0001', message = 'SERVICE_AREA_UNAVAILABLE';
  end if;
  if length(trim(coalesce(p_label, ''))) < 2
     or length(trim(coalesce(p_recipient_name, ''))) < 2
     or length(trim(coalesce(p_phone, ''))) < 5
     or length(trim(coalesce(p_address_line, ''))) < 4
     or length(trim(coalesce(p_city, ''))) < 2 then
    raise exception using errcode = 'P0001', message = 'INVALID_ADDRESS';
  end if;

  if p_is_default then
    update customer_addresses
    set is_default = false, updated_at = now()
    where customer_user_id = v_user and market_id = p_market_id;
  end if;

  if p_id is null then
    insert into customer_addresses(
      customer_user_id, market_id, service_area_id, label, recipient_name,
      phone, address_line, landmark, city, district, is_default
    ) values (
      v_user, p_market_id, p_service_area_id, trim(p_label), trim(p_recipient_name),
      trim(p_phone), trim(p_address_line), nullif(trim(coalesce(p_landmark, '')), ''),
      trim(p_city), nullif(trim(coalesce(p_district, '')), ''), p_is_default
    ) returning * into v_address;
  else
    update customer_addresses
    set service_area_id = p_service_area_id,
        label = trim(p_label),
        recipient_name = trim(p_recipient_name),
        phone = trim(p_phone),
        address_line = trim(p_address_line),
        landmark = nullif(trim(coalesce(p_landmark, '')), ''),
        city = trim(p_city),
        district = nullif(trim(coalesce(p_district, '')), ''),
        is_default = p_is_default,
        is_active = true,
        updated_at = now()
    where id = p_id and customer_user_id = v_user and market_id = p_market_id
    returning * into v_address;
    if not found then
      raise exception using errcode = '42501', message = 'ADDRESS_NOT_FOUND';
    end if;
  end if;

  insert into audit_events(actor_user_id, action, resource_type, resource_id, metadata)
  values(v_user, 'customer.address_saved', 'customer_address', v_address.id::text,
         jsonb_build_object('market_id', p_market_id, 'is_default', v_address.is_default));

  return jsonb_build_object('address_id', v_address.id, 'is_default', v_address.is_default);
end;
$$;
revoke all on function private.save_customer_address(uuid, uuid, uuid, text, text, text, text, text, text, text, boolean) from public, anon;
grant execute on function private.save_customer_address(uuid, uuid, uuid, text, text, text, text, text, text, text, boolean) to authenticated, service_role;

create or replace function public.save_customer_address(
  p_id uuid,
  p_market_id uuid,
  p_service_area_id uuid,
  p_label text,
  p_recipient_name text,
  p_phone text,
  p_address_line text,
  p_landmark text,
  p_city text,
  p_district text,
  p_is_default boolean
)
returns jsonb
language sql
security invoker
set search_path = public, pg_catalog
as $$
  select private.save_customer_address(
    p_id, p_market_id, p_service_area_id, p_label, p_recipient_name,
    p_phone, p_address_line, p_landmark, p_city, p_district, p_is_default
  );
$$;
revoke all on function public.save_customer_address(uuid, uuid, uuid, text, text, text, text, text, text, text, boolean) from public, anon;
grant execute on function public.save_customer_address(uuid, uuid, uuid, text, text, text, text, text, text, text, boolean) to authenticated;

create or replace function private.save_merchant_delivery_zone(
  p_id uuid,
  p_shop_id uuid,
  p_service_area_id uuid,
  p_name text,
  p_fee_minor bigint,
  p_eta_min_minutes integer,
  p_eta_max_minutes integer,
  p_instructions text,
  p_is_active boolean
)
returns jsonb
language plpgsql
security definer
set search_path = public, private, pg_catalog
as $$
declare
  v_user uuid := (select auth.uid());
  v_id uuid;
begin
  if v_user is null then
    raise exception using errcode = '28000', message = 'AUTH_REQUIRED';
  end if;
  if not exists (
    select 1 from shops s
    join merchants merchant on merchant.id = s.merchant_id
    where s.id = p_shop_id and merchant.owner_user_id = v_user
  ) then
    raise exception using errcode = '42501', message = 'SHOP_NOT_OWNED';
  end if;
  if length(trim(coalesce(p_name, ''))) < 2
     or p_fee_minor < 0
     or (p_eta_min_minutes is not null and p_eta_min_minutes < 0)
     or (p_eta_max_minutes is not null and p_eta_max_minutes < coalesce(p_eta_min_minutes, 0)) then
    raise exception using errcode = 'P0001', message = 'INVALID_DELIVERY_ZONE';
  end if;
  if p_service_area_id is not null and not exists (
    select 1 from market_service_areas area
    join shops s on s.market_id = area.market_id
    where area.id = p_service_area_id and s.id = p_shop_id and area.status = 'active'
  ) then
    raise exception using errcode = 'P0001', message = 'SERVICE_AREA_UNAVAILABLE';
  end if;

  if p_id is null then
    insert into merchant_delivery_zones(
      shop_id, service_area_id, name, fee_minor, eta_min_minutes,
      eta_max_minutes, instructions, is_active
    ) values (
      p_shop_id, p_service_area_id, trim(p_name), p_fee_minor,
      p_eta_min_minutes, p_eta_max_minutes,
      nullif(trim(coalesce(p_instructions, '')), ''), p_is_active
    )
    on conflict (shop_id, service_area_id) do update
      set name = excluded.name,
          fee_minor = excluded.fee_minor,
          eta_min_minutes = excluded.eta_min_minutes,
          eta_max_minutes = excluded.eta_max_minutes,
          instructions = excluded.instructions,
          is_active = excluded.is_active,
          updated_at = now()
    returning id into v_id;
  else
    update merchant_delivery_zones
    set service_area_id = p_service_area_id,
        name = trim(p_name),
        fee_minor = p_fee_minor,
        eta_min_minutes = p_eta_min_minutes,
        eta_max_minutes = p_eta_max_minutes,
        instructions = nullif(trim(coalesce(p_instructions, '')), ''),
        is_active = p_is_active,
        updated_at = now()
    where id = p_id and shop_id = p_shop_id
    returning id into v_id;
    if not found then
      raise exception using errcode = '42501', message = 'DELIVERY_ZONE_NOT_FOUND';
    end if;
  end if;

  insert into audit_events(actor_user_id, action, resource_type, resource_id, metadata)
  values(v_user, 'merchant.delivery_zone_saved', 'delivery_zone', v_id::text,
         jsonb_build_object('shop_id', p_shop_id, 'service_area_id', p_service_area_id));
  return jsonb_build_object('delivery_zone_id', v_id);
end;
$$;
revoke all on function private.save_merchant_delivery_zone(uuid, uuid, uuid, text, bigint, integer, integer, text, boolean) from public, anon;
grant execute on function private.save_merchant_delivery_zone(uuid, uuid, uuid, text, bigint, integer, integer, text, boolean) to authenticated, service_role;

create or replace function public.save_merchant_delivery_zone(
  p_id uuid,
  p_shop_id uuid,
  p_service_area_id uuid,
  p_name text,
  p_fee_minor bigint,
  p_eta_min_minutes integer,
  p_eta_max_minutes integer,
  p_instructions text,
  p_is_active boolean
)
returns jsonb
language sql
security invoker
set search_path = public, pg_catalog
as $$
  select private.save_merchant_delivery_zone(
    p_id, p_shop_id, p_service_area_id, p_name, p_fee_minor,
    p_eta_min_minutes, p_eta_max_minutes, p_instructions, p_is_active
  );
$$;
revoke all on function public.save_merchant_delivery_zone(uuid, uuid, uuid, text, bigint, integer, integer, text, boolean) from public, anon;
grant execute on function public.save_merchant_delivery_zone(uuid, uuid, uuid, text, bigint, integer, integer, text, boolean) to authenticated;
