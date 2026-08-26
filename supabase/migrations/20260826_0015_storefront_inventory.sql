-- Storefront and multi-location inventory foundation.
-- These settings are configuration only; orders continue to snapshot product
-- and merchant terms at checkout.

create table if not exists public.storefront_settings (
  shop_id uuid primary key references public.shops(id) on delete cascade,
  display_name text,
  tagline text,
  theme_key text not null default 'yemen_teal',
  primary_color text not null default '#006A63',
  logo_storage_key text,
  custom_slug text unique,
  custom_domain text unique,
  is_published boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.inventory_locations (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  name text not null,
  area_label text,
  status text not null default 'active' check (status in ('active','paused','archived')),
  is_default boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (shop_id, name)
);
create index if not exists inventory_locations_shop_status_idx
  on public.inventory_locations(shop_id, status);

create table if not exists public.product_location_inventory (
  product_id uuid not null references public.products(id) on delete cascade,
  location_id uuid not null references public.inventory_locations(id) on delete cascade,
  stock_quantity integer not null default 0 check (stock_quantity >= 0),
  reserved_quantity integer not null default 0 check (reserved_quantity >= 0 and reserved_quantity <= stock_quantity),
  updated_at timestamptz not null default now(),
  primary key (product_id, location_id)
);
create index if not exists product_location_inventory_location_idx
  on public.product_location_inventory(location_id, stock_quantity);

alter table public.storefront_settings enable row level security;
alter table public.inventory_locations enable row level security;
alter table public.product_location_inventory enable row level security;
grant select on public.storefront_settings to anon, authenticated;
grant select on public.inventory_locations, public.product_location_inventory to authenticated;

drop policy if exists storefront_public_read on public.storefront_settings;
create policy storefront_public_read
on public.storefront_settings for select to anon, authenticated
using (
  is_published
  and exists (select 1 from shops s join markets m on m.id = s.market_id where s.id = shop_id and s.status = 'approved' and m.status = 'active')
);
drop policy if exists storefront_owner_read on public.storefront_settings;
create policy storefront_owner_read
on public.storefront_settings for select to authenticated
using (
  exists (select 1 from shops s join merchants merchant on merchant.id = s.merchant_id where s.id = shop_id and (merchant.owner_user_id = (select auth.uid()) or private.is_admin()))
);

drop policy if exists inventory_locations_owner_read on public.inventory_locations;
create policy inventory_locations_owner_read
on public.inventory_locations for select to authenticated
using (
  exists (select 1 from shops s join merchants merchant on merchant.id = s.merchant_id where s.id = shop_id and (merchant.owner_user_id = (select auth.uid()) or private.is_admin()))
);
drop policy if exists product_location_inventory_owner_read on public.product_location_inventory;
create policy product_location_inventory_owner_read
on public.product_location_inventory for select to authenticated
using (
  exists (
    select 1 from products p join shops s on s.id = p.shop_id join merchants merchant on merchant.id = s.merchant_id
    where p.id = product_id and (merchant.owner_user_id = (select auth.uid()) or private.is_admin())
  )
);

create or replace function private.save_storefront_settings(
  p_shop_id uuid,
  p_display_name text,
  p_tagline text,
  p_theme_key text,
  p_primary_color text,
  p_logo_storage_key text,
  p_custom_slug text,
  p_custom_domain text,
  p_is_published boolean
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
  if v_user is null then raise exception using errcode = '28000', message = 'AUTH_REQUIRED'; end if;
  if not exists (select 1 from shops s join merchants merchant on merchant.id = s.merchant_id where s.id = p_shop_id and merchant.owner_user_id = v_user) then
    raise exception using errcode = '42501', message = 'SHOP_NOT_OWNED';
  end if;
  if length(trim(coalesce(p_theme_key, ''))) < 2 or not (coalesce(p_primary_color, '') ~ '^#[0-9A-Fa-f]{6}$') then
    raise exception using errcode = 'P0001', message = 'INVALID_STOREFRONT_SETTINGS';
  end if;
  if p_is_published and not exists (select 1 from shops where id = p_shop_id and status = 'approved') then
    raise exception using errcode = 'P0001', message = 'SHOP_MUST_BE_APPROVED';
  end if;
  insert into storefront_settings(shop_id, display_name, tagline, theme_key, primary_color, logo_storage_key, custom_slug, custom_domain, is_published)
  values(p_shop_id, nullif(trim(p_display_name), ''), nullif(trim(p_tagline), ''), trim(p_theme_key), upper(p_primary_color), nullif(trim(p_logo_storage_key), ''), nullif(lower(trim(p_custom_slug)), ''), nullif(lower(trim(p_custom_domain)), ''), p_is_published)
  on conflict (shop_id) do update set
    display_name = excluded.display_name,
    tagline = excluded.tagline,
    theme_key = excluded.theme_key,
    primary_color = excluded.primary_color,
    logo_storage_key = excluded.logo_storage_key,
    custom_slug = excluded.custom_slug,
    custom_domain = excluded.custom_domain,
    is_published = excluded.is_published,
    updated_at = now()
  returning shop_id into v_id;
  insert into audit_events(actor_user_id, action, resource_type, resource_id, metadata)
  values(v_user, 'merchant.storefront_saved', 'shop', v_id::text, jsonb_build_object('theme_key', p_theme_key, 'published', p_is_published));
  return jsonb_build_object('shop_id', v_id, 'published', p_is_published);
exception when unique_violation then
  raise exception using errcode = '23505', message = 'STOREFRONT_SLUG_OR_DOMAIN_EXISTS';
end;
$$;
revoke all on function private.save_storefront_settings(uuid, text, text, text, text, text, text, text, boolean) from public, anon;
grant execute on function private.save_storefront_settings(uuid, text, text, text, text, text, text, text, boolean) to authenticated, service_role;

create or replace function public.save_storefront_settings(
  p_shop_id uuid,
  p_display_name text,
  p_tagline text,
  p_theme_key text,
  p_primary_color text,
  p_logo_storage_key text,
  p_custom_slug text,
  p_custom_domain text,
  p_is_published boolean
)
returns jsonb
language sql
security invoker
set search_path = public, pg_catalog
as $$
  select private.save_storefront_settings(p_shop_id, p_display_name, p_tagline, p_theme_key, p_primary_color, p_logo_storage_key, p_custom_slug, p_custom_domain, p_is_published);
$$;
revoke all on function public.save_storefront_settings(uuid, text, text, text, text, text, text, text, boolean) from public, anon;
grant execute on function public.save_storefront_settings(uuid, text, text, text, text, text, text, text, boolean) to authenticated;
