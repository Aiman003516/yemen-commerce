-- Merchant catalog productivity foundation.
-- Variants inherit the parent product's merchant ownership and are exposed
-- only through approved product reads or the owning merchant scope.

create table if not exists public.product_variants (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  name text not null,
  sku text,
  price_minor bigint not null check (price_minor > 0),
  stock_quantity integer not null default 0 check (stock_quantity >= 0),
  status text not null default 'active' check (status in ('draft', 'active', 'archived', 'out_of_stock')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (product_id, name),
  unique (sku)
);
create index if not exists product_variants_product_status_idx
  on public.product_variants(product_id, status);

alter table public.product_variants enable row level security;
grant select on public.product_variants to anon, authenticated;

drop policy if exists product_variants_public_read on public.product_variants;
create policy product_variants_public_read
on public.product_variants for select to anon, authenticated
using (
  status = 'active'
  and exists (
    select 1 from public.products p
    join public.shops s on s.id = p.shop_id
    join public.markets m on m.id = s.market_id
    where p.id = product_id and p.status = 'active' and s.status = 'approved' and m.status = 'active'
  )
);

drop policy if exists product_variants_owner_read on public.product_variants;
create policy product_variants_owner_read
on public.product_variants for select to authenticated
using (
  exists (
    select 1 from public.products p
    join public.shops s on s.id = p.shop_id
    join public.merchants merchant on merchant.id = s.merchant_id
    where p.id = product_id and (merchant.owner_user_id = (select auth.uid()) or private.is_admin())
  )
);

create or replace function private.save_product_variant(
  p_id uuid,
  p_product_id uuid,
  p_name text,
  p_sku text,
  p_price_minor bigint,
  p_stock_quantity integer,
  p_status text
)
returns jsonb
language plpgsql
security definer
set search_path = public, private, pg_catalog
as $$
declare
  v_user uuid := (select auth.uid());
  v_variant_id uuid;
  v_status text;
begin
  if v_user is null then
    raise exception using errcode = '28000', message = 'AUTH_REQUIRED';
  end if;
  if length(trim(coalesce(p_name, ''))) < 1
     or p_price_minor <= 0
     or p_stock_quantity < 0
     or p_stock_quantity > 100000
     or p_status not in ('draft', 'active', 'archived', 'out_of_stock') then
    raise exception using errcode = 'P0001', message = 'INVALID_PRODUCT_VARIANT';
  end if;
  if not exists (
    select 1 from products p
    join shops s on s.id = p.shop_id
    join merchants merchant on merchant.id = s.merchant_id
    where p.id = p_product_id and merchant.owner_user_id = v_user
  ) then
    raise exception using errcode = '42501', message = 'PRODUCT_NOT_OWNED';
  end if;
  v_status := case when p_stock_quantity = 0 and p_status = 'active' then 'out_of_stock' else p_status end;

  if p_id is null then
    insert into product_variants(product_id, name, sku, price_minor, stock_quantity, status)
    values (p_product_id, trim(p_name), nullif(trim(coalesce(p_sku, '')), ''), p_price_minor, p_stock_quantity, v_status)
    returning id into v_variant_id;
  else
    update product_variants
    set name = trim(p_name),
        sku = nullif(trim(coalesce(p_sku, '')), ''),
        price_minor = p_price_minor,
        stock_quantity = p_stock_quantity,
        status = v_status,
        updated_at = now()
    where id = p_id and product_id = p_product_id
    returning id into v_variant_id;
    if v_variant_id is null then
      raise exception using errcode = '42501', message = 'PRODUCT_VARIANT_NOT_FOUND';
    end if;
  end if;

  insert into audit_events(actor_user_id, action, resource_type, resource_id, metadata)
  values(v_user, 'merchant.product_variant_saved', 'product_variant', v_variant_id::text,
         jsonb_build_object('product_id', p_product_id, 'status', v_status));
  return jsonb_build_object('variant_id', v_variant_id, 'status', v_status);
exception when unique_violation then
  raise exception using errcode = '23505', message = 'PRODUCT_VARIANT_DUPLICATE';
end;
$$;
revoke all on function private.save_product_variant(uuid, uuid, text, text, bigint, integer, text) from public, anon;
grant execute on function private.save_product_variant(uuid, uuid, text, text, bigint, integer, text) to authenticated, service_role;

create or replace function public.save_product_variant(
  p_id uuid,
  p_product_id uuid,
  p_name text,
  p_sku text,
  p_price_minor bigint,
  p_stock_quantity integer,
  p_status text
)
returns jsonb
language sql
security invoker
set search_path = public, pg_catalog
as $$
  select private.save_product_variant(
    p_id, p_product_id, p_name, p_sku, p_price_minor, p_stock_quantity, p_status
  );
$$;
revoke all on function public.save_product_variant(uuid, uuid, text, text, bigint, integer, text) from public, anon;
grant execute on function public.save_product_variant(uuid, uuid, text, text, bigint, integer, text) to authenticated;
