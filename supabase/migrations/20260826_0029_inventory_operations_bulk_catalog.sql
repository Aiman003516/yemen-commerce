-- Inventory operations and bounded bulk catalog import.
-- All writes are merchant-owned, idempotent, atomic, and audited.
-- This migration does not move funds or mark payments/fulfilment states.

alter table public.products add column if not exists barcode text;
create unique index if not exists products_barcode_unique_idx
  on public.products(barcode)
  where barcode is not null and length(trim(barcode)) > 0;

create table if not exists public.inventory_movements (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  location_id uuid not null references public.inventory_locations(id) on delete restrict,
  movement_type text not null check (movement_type in ('receive','adjust','count','transfer_in','transfer_out','sale','reservation','release')),
  quantity_delta integer not null check (quantity_delta <> 0),
  previous_quantity integer not null check (previous_quantity >= 0),
  resulting_quantity integer not null check (resulting_quantity >= 0),
  reason text not null,
  reference_type text,
  reference_id uuid,
  idempotency_key text not null,
  recorded_by_user_id uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  unique (shop_id, idempotency_key)
);
create index if not exists inventory_movements_product_created_idx
  on public.inventory_movements(product_id, created_at desc);
create index if not exists inventory_movements_location_created_idx
  on public.inventory_movements(location_id, created_at desc);

create table if not exists public.inventory_transfers (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  from_location_id uuid not null references public.inventory_locations(id) on delete restrict,
  to_location_id uuid not null references public.inventory_locations(id) on delete restrict,
  status text not null default 'completed' check (status in ('completed','cancelled')),
  reason text not null,
  idempotency_key text not null,
  created_by_user_id uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  completed_at timestamptz not null default now(),
  unique (shop_id, idempotency_key),
  check (from_location_id <> to_location_id)
);
create index if not exists inventory_transfers_shop_created_idx
  on public.inventory_transfers(shop_id, created_at desc);

create table if not exists public.inventory_transfer_items (
  id uuid primary key default gen_random_uuid(),
  transfer_id uuid not null references public.inventory_transfers(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  quantity integer not null check (quantity > 0),
  unique (transfer_id, product_id)
);
create index if not exists inventory_transfer_items_product_idx
  on public.inventory_transfer_items(product_id, transfer_id);

create table if not exists public.inventory_counts (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  location_id uuid not null references public.inventory_locations(id) on delete restrict,
  status text not null default 'completed' check (status in ('completed','cancelled')),
  reason text not null,
  idempotency_key text not null,
  created_by_user_id uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  completed_at timestamptz not null default now(),
  unique (shop_id, idempotency_key)
);
create index if not exists inventory_counts_location_created_idx
  on public.inventory_counts(location_id, created_at desc);

create table if not exists public.inventory_count_items (
  id uuid primary key default gen_random_uuid(),
  count_id uuid not null references public.inventory_counts(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  expected_quantity integer not null check (expected_quantity >= 0),
  counted_quantity integer not null check (counted_quantity >= 0),
  variance integer not null,
  unique (count_id, product_id)
);
create index if not exists inventory_count_items_product_idx
  on public.inventory_count_items(product_id, count_id);

create table if not exists public.catalog_import_batches (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  status text not null default 'applied' check (status in ('applied','failed','cancelled')),
  source_format text not null default 'csv' check (source_format in ('csv','xlsx','json')),
  row_count integer not null check (row_count between 1 and 500),
  applied_count integer not null check (applied_count between 0 and 500),
  idempotency_key text not null,
  created_by_user_id uuid not null references public.profiles(id) on delete restrict,
  result jsonb not null default '[]'::jsonb check (jsonb_typeof(result) = 'array' and length(result::text) <= 64000),
  created_at timestamptz not null default now(),
  applied_at timestamptz,
  unique (shop_id, idempotency_key)
);
create index if not exists catalog_import_batches_shop_created_idx
  on public.catalog_import_batches(shop_id, created_at desc);

alter table public.inventory_movements enable row level security;
alter table public.inventory_transfers enable row level security;
alter table public.inventory_transfer_items enable row level security;
alter table public.inventory_counts enable row level security;
alter table public.inventory_count_items enable row level security;
alter table public.catalog_import_batches enable row level security;

grant select on public.inventory_movements, public.inventory_transfers, public.inventory_transfer_items,
  public.inventory_counts, public.inventory_count_items, public.catalog_import_batches to authenticated;

drop policy if exists inventory_movements_owner_read on public.inventory_movements;
create policy inventory_movements_owner_read on public.inventory_movements for select to authenticated
using (shop_id in (select s.id from shops s join merchants m on m.id = s.merchant_id where m.owner_user_id = (select auth.uid())) or private.is_admin());
drop policy if exists inventory_transfers_owner_read on public.inventory_transfers;
create policy inventory_transfers_owner_read on public.inventory_transfers for select to authenticated
using (shop_id in (select s.id from shops s join merchants m on m.id = s.merchant_id where m.owner_user_id = (select auth.uid())) or private.is_admin());
drop policy if exists inventory_transfer_items_owner_read on public.inventory_transfer_items;
create policy inventory_transfer_items_owner_read on public.inventory_transfer_items for select to authenticated
using (transfer_id in (select t.id from inventory_transfers t where t.shop_id in (select s.id from shops s join merchants m on m.id = s.merchant_id where m.owner_user_id = (select auth.uid()))) or private.is_admin());
drop policy if exists inventory_counts_owner_read on public.inventory_counts;
create policy inventory_counts_owner_read on public.inventory_counts for select to authenticated
using (shop_id in (select s.id from shops s join merchants m on m.id = s.merchant_id where m.owner_user_id = (select auth.uid())) or private.is_admin());
drop policy if exists inventory_count_items_owner_read on public.inventory_count_items;
create policy inventory_count_items_owner_read on public.inventory_count_items for select to authenticated
using (count_id in (select c.id from inventory_counts c where c.shop_id in (select s.id from shops s join merchants m on m.id = s.merchant_id where m.owner_user_id = (select auth.uid()))) or private.is_admin());
drop policy if exists catalog_import_batches_owner_read on public.catalog_import_batches;
create policy catalog_import_batches_owner_read on public.catalog_import_batches for select to authenticated
using (shop_id in (select s.id from shops s join merchants m on m.id = s.merchant_id where m.owner_user_id = (select auth.uid())) or private.is_admin());

create or replace function private.save_inventory_location(
  p_shop_id uuid,
  p_name text,
  p_area_label text default null,
  p_status text default 'active',
  p_is_default boolean default false
)
returns jsonb language plpgsql security definer set search_path = public, private, pg_catalog as $$
declare
  v_user uuid := (select auth.uid());
  v_id uuid;
begin
  if v_user is null then raise exception using errcode = '28000', message = 'AUTH_REQUIRED'; end if;
  if not exists (select 1 from shops s join merchants m on m.id = s.merchant_id where s.id = p_shop_id and m.owner_user_id = v_user) then
    raise exception using errcode = '42501', message = 'SHOP_NOT_OWNED';
  end if;
  if length(trim(coalesce(p_name, ''))) < 2 or p_status not in ('active','paused','archived') then
    raise exception using errcode = 'P0001', message = 'INVALID_INVENTORY_LOCATION';
  end if;
  if p_is_default then
    update inventory_locations set is_default = false, updated_at = now() where shop_id = p_shop_id;
  end if;
  insert into inventory_locations(shop_id, name, area_label, status, is_default)
  values(p_shop_id, trim(p_name), nullif(trim(coalesce(p_area_label, '')), ''), p_status, p_is_default)
  on conflict (shop_id, name) do update set area_label = excluded.area_label, status = excluded.status, is_default = excluded.is_default, updated_at = now()
  returning id into v_id;
  insert into audit_events(actor_user_id, action, resource_type, resource_id, metadata)
  values(v_user, 'merchant.inventory_location_saved', 'inventory_location', v_id::text, jsonb_build_object('shop_id', p_shop_id, 'status', p_status, 'is_default', p_is_default));
  return jsonb_build_object('location_id', v_id, 'status', p_status, 'is_default', p_is_default);
exception when unique_violation then
  raise exception using errcode = '23505', message = 'INVENTORY_LOCATION_DUPLICATE';
end;
$$;
revoke all on function private.save_inventory_location(uuid, text, text, text, boolean) from public, anon;
grant execute on function private.save_inventory_location(uuid, text, text, text, boolean) to authenticated, service_role;
create or replace function public.save_inventory_location(p_shop_id uuid, p_name text, p_area_label text default null, p_status text default 'active', p_is_default boolean default false)
returns jsonb language sql security invoker set search_path = public, pg_catalog as $$ select private.save_inventory_location(p_shop_id, p_name, p_area_label, p_status, p_is_default); $$;
revoke all on function public.save_inventory_location(uuid, text, text, text, boolean) from public, anon;
grant execute on function public.save_inventory_location(uuid, text, text, text, boolean) to authenticated;

create or replace function private.record_inventory_adjustment(
  p_shop_id uuid,
  p_product_id uuid,
  p_location_id uuid,
  p_quantity_delta integer,
  p_reason text,
  p_idempotency_key text
)
returns jsonb language plpgsql security definer set search_path = public, private, pg_catalog as $$
declare
  v_user uuid := (select auth.uid());
  v_product products%rowtype;
  v_location inventory_locations%rowtype;
  v_inventory product_location_inventory%rowtype;
  v_previous integer;
  v_result integer;
  v_total integer;
  v_id uuid;
  v_existing inventory_movements%rowtype;
begin
  if v_user is null then raise exception using errcode = '28000', message = 'AUTH_REQUIRED'; end if;
  if length(trim(coalesce(p_reason, ''))) < 3 or length(trim(coalesce(p_idempotency_key, ''))) < 8 or p_quantity_delta = 0 then
    raise exception using errcode = 'P0001', message = 'INVALID_INVENTORY_ADJUSTMENT';
  end if;
  select * into v_existing from inventory_movements where shop_id = p_shop_id and idempotency_key = trim(p_idempotency_key);
  if found then
    return jsonb_build_object('movement_id', v_existing.id, 'product_id', v_existing.product_id, 'location_id', v_existing.location_id, 'quantity_delta', v_existing.quantity_delta, 'resulting_quantity', v_existing.resulting_quantity, 'idempotent', true);
  end if;
  select p.* into v_product from products p where p.id = p_product_id and p.shop_id = p_shop_id for update;
  if not found then raise exception using errcode = 'P0001', message = 'PRODUCT_NOT_FOUND'; end if;
  select il.* into v_location from inventory_locations il where il.id = p_location_id and il.shop_id = p_shop_id and il.status <> 'archived' for update;
  if not found then raise exception using errcode = 'P0001', message = 'INVENTORY_LOCATION_NOT_FOUND'; end if;
  if not exists (select 1 from merchants m join shops s on s.merchant_id = m.id where s.id = p_shop_id and m.owner_user_id = v_user) then
    raise exception using errcode = '42501', message = 'SHOP_NOT_OWNED';
  end if;
  if not exists (select 1 from product_location_inventory where product_id = p_product_id) then
    insert into product_location_inventory(product_id, location_id, stock_quantity, reserved_quantity)
    values(p_product_id, p_location_id, v_product.stock_quantity, 0);
  else
    insert into product_location_inventory(product_id, location_id, stock_quantity, reserved_quantity)
    values(p_product_id, p_location_id, 0, 0)
    on conflict (product_id, location_id) do nothing;
  end if;
  select * into v_inventory from product_location_inventory where product_id = p_product_id and location_id = p_location_id for update;
  v_previous := v_inventory.stock_quantity;
  v_result := v_previous + p_quantity_delta;
  if v_result < v_inventory.reserved_quantity or v_result < 0 or v_result > 100000 then
    raise exception using errcode = 'P0001', message = 'INVENTORY_STOCK_CONFLICT';
  end if;
  update product_location_inventory set stock_quantity = v_result, updated_at = now() where product_id = p_product_id and location_id = p_location_id;
  select coalesce(sum(stock_quantity), 0) into v_total from product_location_inventory where product_id = p_product_id;
  update products set stock_quantity = v_total, status = case when stock_quantity = 0 and status = 'active' then 'out_of_stock' when stock_quantity > 0 and status = 'out_of_stock' then 'active' else status end where id = p_product_id;
  insert into inventory_movements(shop_id, product_id, location_id, movement_type, quantity_delta, previous_quantity, resulting_quantity, reason, idempotency_key, recorded_by_user_id)
  values(p_shop_id, p_product_id, p_location_id, case when p_quantity_delta > 0 then 'receive' else 'adjust' end, p_quantity_delta, v_previous, v_result, trim(p_reason), trim(p_idempotency_key), v_user)
  returning id into v_id;
  insert into audit_events(actor_user_id, action, resource_type, resource_id, metadata)
  values(v_user, 'merchant.inventory_adjusted', 'inventory_movement', v_id::text, jsonb_build_object('shop_id', p_shop_id, 'product_id', p_product_id, 'location_id', p_location_id, 'quantity_delta', p_quantity_delta));
  return jsonb_build_object('movement_id', v_id, 'product_id', p_product_id, 'location_id', p_location_id, 'previous_quantity', v_previous, 'resulting_quantity', v_result, 'total_product_quantity', v_total, 'idempotent', false);
exception when unique_violation then
  select * into v_existing from inventory_movements where shop_id = p_shop_id and idempotency_key = trim(p_idempotency_key);
  if found then return jsonb_build_object('movement_id', v_existing.id, 'product_id', v_existing.product_id, 'location_id', v_existing.location_id, 'quantity_delta', v_existing.quantity_delta, 'resulting_quantity', v_existing.resulting_quantity, 'idempotent', true); end if;
  raise;
end;
$$;
revoke all on function private.record_inventory_adjustment(uuid, uuid, uuid, integer, text, text) from public, anon;
grant execute on function private.record_inventory_adjustment(uuid, uuid, uuid, integer, text, text) to authenticated, service_role;
create or replace function public.record_inventory_adjustment(p_shop_id uuid, p_product_id uuid, p_location_id uuid, p_quantity_delta integer, p_reason text, p_idempotency_key text)
returns jsonb language sql security invoker set search_path = public, pg_catalog as $$ select private.record_inventory_adjustment(p_shop_id, p_product_id, p_location_id, p_quantity_delta, p_reason, p_idempotency_key); $$;
revoke all on function public.record_inventory_adjustment(uuid, uuid, uuid, integer, text, text) from public, anon;
grant execute on function public.record_inventory_adjustment(uuid, uuid, uuid, integer, text, text) to authenticated;

create or replace function private.complete_inventory_transfer(
  p_shop_id uuid,
  p_from_location_id uuid,
  p_to_location_id uuid,
  p_items jsonb,
  p_reason text,
  p_idempotency_key text
)
returns jsonb language plpgsql security definer set search_path = public, private, pg_catalog as $$
declare
  v_user uuid := (select auth.uid());
  v_transfer_id uuid;
  v_existing inventory_transfers%rowtype;
  v_item record;
  v_product products%rowtype;
  v_from product_location_inventory%rowtype;
  v_to product_location_inventory%rowtype;
  v_from_after integer;
  v_to_after integer;
  v_id uuid;
  v_count integer := 0;
begin
  if v_user is null then raise exception using errcode = '28000', message = 'AUTH_REQUIRED'; end if;
  if p_from_location_id = p_to_location_id or jsonb_typeof(coalesce(p_items, '[]'::jsonb)) <> 'array' or jsonb_array_length(coalesce(p_items, '[]'::jsonb)) < 1 or jsonb_array_length(p_items) > 200 or length(trim(coalesce(p_reason, ''))) < 3 or length(trim(coalesce(p_idempotency_key, ''))) < 8 then
    raise exception using errcode = 'P0001', message = 'INVALID_INVENTORY_TRANSFER';
  end if;
  select * into v_existing from inventory_transfers where shop_id = p_shop_id and idempotency_key = trim(p_idempotency_key);
  if found then return jsonb_build_object('transfer_id', v_existing.id, 'status', v_existing.status, 'idempotent', true); end if;
  if not exists (select 1 from shops s join merchants m on m.id = s.merchant_id where s.id = p_shop_id and m.owner_user_id = v_user) then raise exception using errcode = '42501', message = 'SHOP_NOT_OWNED'; end if;
  if not exists (select 1 from inventory_locations where id = p_from_location_id and shop_id = p_shop_id and status <> 'archived') or not exists (select 1 from inventory_locations where id = p_to_location_id and shop_id = p_shop_id and status <> 'archived') then raise exception using errcode = 'P0001', message = 'INVENTORY_LOCATION_NOT_FOUND'; end if;
  insert into inventory_transfers(shop_id, from_location_id, to_location_id, reason, idempotency_key, created_by_user_id) values(p_shop_id, p_from_location_id, p_to_location_id, trim(p_reason), trim(p_idempotency_key), v_user) returning id into v_transfer_id;
  for v_item in select * from jsonb_to_recordset(p_items) as x(product_id uuid, quantity integer) loop
    if v_item.product_id is null or v_item.quantity is null or v_item.quantity <= 0 or v_item.quantity > 100000 then raise exception using errcode = 'P0001', message = 'INVALID_INVENTORY_TRANSFER_ITEM'; end if;
    select * into v_product from products where id = v_item.product_id and shop_id = p_shop_id for update;
    if not found then raise exception using errcode = 'P0001', message = 'PRODUCT_NOT_FOUND'; end if;
    select * into v_from from product_location_inventory where product_id = v_item.product_id and location_id = p_from_location_id for update;
    if not found or v_from.stock_quantity - v_from.reserved_quantity < v_item.quantity then raise exception using errcode = 'P0001', message = 'INVENTORY_TRANSFER_STOCK_CONFLICT'; end if;
    insert into product_location_inventory(product_id, location_id, stock_quantity, reserved_quantity) values(v_item.product_id, p_to_location_id, 0, 0) on conflict (product_id, location_id) do nothing;
    select * into v_to from product_location_inventory where product_id = v_item.product_id and location_id = p_to_location_id for update;
    v_from_after := v_from.stock_quantity - v_item.quantity;
    v_to_after := v_to.stock_quantity + v_item.quantity;
    if v_to_after > 100000 then raise exception using errcode = 'P0001', message = 'INVENTORY_STOCK_LIMIT'; end if;
    update product_location_inventory set stock_quantity = v_from_after, updated_at = now() where product_id = v_item.product_id and location_id = p_from_location_id;
    update product_location_inventory set stock_quantity = v_to_after, updated_at = now() where product_id = v_item.product_id and location_id = p_to_location_id;
    insert into inventory_transfer_items(transfer_id, product_id, quantity) values(v_transfer_id, v_item.product_id, v_item.quantity);
    insert into inventory_movements(shop_id, product_id, location_id, movement_type, quantity_delta, previous_quantity, resulting_quantity, reason, reference_type, reference_id, idempotency_key, recorded_by_user_id)
    values(p_shop_id, v_item.product_id, p_from_location_id, 'transfer_out', -v_item.quantity, v_from.stock_quantity, v_from_after, trim(p_reason), 'inventory_transfer', v_transfer_id, trim(p_idempotency_key) || ':out:' || v_item.product_id::text, v_user),
          (p_shop_id, v_item.product_id, p_to_location_id, 'transfer_in', v_item.quantity, v_to.stock_quantity, v_to_after, trim(p_reason), 'inventory_transfer', v_transfer_id, trim(p_idempotency_key) || ':in:' || v_item.product_id::text, v_user);
    select coalesce(sum(stock_quantity), 0) into v_count from product_location_inventory where product_id = v_item.product_id;
    update products set stock_quantity = v_count, status = case when v_count = 0 and status = 'active' then 'out_of_stock' when v_count > 0 and status = 'out_of_stock' then 'active' else status end where id = v_item.product_id;
  end loop;
  if not exists (select 1 from inventory_transfer_items where transfer_id = v_transfer_id) then raise exception using errcode = 'P0001', message = 'EMPTY_INVENTORY_TRANSFER'; end if;
  insert into audit_events(actor_user_id, action, resource_type, resource_id, metadata) values(v_user, 'merchant.inventory_transferred', 'inventory_transfer', v_transfer_id::text, jsonb_build_object('shop_id', p_shop_id, 'item_count', (select count(*) from inventory_transfer_items where transfer_id = v_transfer_id)));
  return jsonb_build_object('transfer_id', v_transfer_id, 'status', 'completed', 'idempotent', false);
exception when unique_violation then
  select * into v_existing from inventory_transfers where shop_id = p_shop_id and idempotency_key = trim(p_idempotency_key);
  if found then return jsonb_build_object('transfer_id', v_existing.id, 'status', v_existing.status, 'idempotent', true); end if;
  raise;
end;
$$;
revoke all on function private.complete_inventory_transfer(uuid, uuid, uuid, jsonb, text, text) from public, anon;
grant execute on function private.complete_inventory_transfer(uuid, uuid, uuid, jsonb, text, text) to authenticated, service_role;
create or replace function public.complete_inventory_transfer(p_shop_id uuid, p_from_location_id uuid, p_to_location_id uuid, p_items jsonb, p_reason text, p_idempotency_key text)
returns jsonb language sql security invoker set search_path = public, pg_catalog as $$ select private.complete_inventory_transfer(p_shop_id, p_from_location_id, p_to_location_id, p_items, p_reason, p_idempotency_key); $$;
revoke all on function public.complete_inventory_transfer(uuid, uuid, uuid, jsonb, text, text) from public, anon;
grant execute on function public.complete_inventory_transfer(uuid, uuid, uuid, jsonb, text, text) to authenticated;

create or replace function private.apply_inventory_count(
  p_shop_id uuid,
  p_location_id uuid,
  p_items jsonb,
  p_reason text,
  p_idempotency_key text
)
returns jsonb language plpgsql security definer set search_path = public, private, pg_catalog as $$
declare
  v_user uuid := (select auth.uid());
  v_count_id uuid;
  v_existing inventory_counts%rowtype;
  v_item record;
  v_product products%rowtype;
  v_inventory product_location_inventory%rowtype;
  v_after integer;
  v_delta integer;
  v_total integer;
  v_item_count integer := 0;
begin
  if v_user is null then raise exception using errcode = '28000', message = 'AUTH_REQUIRED'; end if;
  if jsonb_typeof(coalesce(p_items, '[]'::jsonb)) <> 'array' or jsonb_array_length(coalesce(p_items, '[]'::jsonb)) < 1 or jsonb_array_length(p_items) > 500 or length(trim(coalesce(p_reason, ''))) < 3 or length(trim(coalesce(p_idempotency_key, ''))) < 8 then
    raise exception using errcode = 'P0001', message = 'INVALID_INVENTORY_COUNT';
  end if;
  select * into v_existing from inventory_counts where shop_id = p_shop_id and idempotency_key = trim(p_idempotency_key);
  if found then return jsonb_build_object('count_id', v_existing.id, 'status', v_existing.status, 'idempotent', true); end if;
  if not exists (select 1 from shops s join merchants m on m.id = s.merchant_id where s.id = p_shop_id and m.owner_user_id = v_user) then raise exception using errcode = '42501', message = 'SHOP_NOT_OWNED'; end if;
  if not exists (select 1 from inventory_locations where id = p_location_id and shop_id = p_shop_id and status <> 'archived') then raise exception using errcode = 'P0001', message = 'INVENTORY_LOCATION_NOT_FOUND'; end if;
  insert into inventory_counts(shop_id, location_id, reason, idempotency_key, created_by_user_id) values(p_shop_id, p_location_id, trim(p_reason), trim(p_idempotency_key), v_user) returning id into v_count_id;
  for v_item in select * from jsonb_to_recordset(p_items) as x(product_id uuid, counted_quantity integer) loop
    if v_item.product_id is null or v_item.counted_quantity is null or v_item.counted_quantity < 0 or v_item.counted_quantity > 100000 then raise exception using errcode = 'P0001', message = 'INVALID_INVENTORY_COUNT_ITEM'; end if;
    select * into v_product from products where id = v_item.product_id and shop_id = p_shop_id for update;
    if not found then raise exception using errcode = 'P0001', message = 'PRODUCT_NOT_FOUND'; end if;
    insert into product_location_inventory(product_id, location_id, stock_quantity, reserved_quantity) values(v_item.product_id, p_location_id, 0, 0) on conflict (product_id, location_id) do nothing;
    select * into v_inventory from product_location_inventory where product_id = v_item.product_id and location_id = p_location_id for update;
    if v_item.counted_quantity < v_inventory.reserved_quantity then raise exception using errcode = 'P0001', message = 'INVENTORY_COUNT_BELOW_RESERVED'; end if;
    v_after := v_item.counted_quantity;
    v_delta := v_after - v_inventory.stock_quantity;
    update product_location_inventory set stock_quantity = v_after, updated_at = now() where product_id = v_item.product_id and location_id = p_location_id;
    insert into inventory_count_items(count_id, product_id, expected_quantity, counted_quantity, variance) values(v_count_id, v_item.product_id, v_inventory.stock_quantity, v_after, v_delta);
    if v_delta <> 0 then
      insert into inventory_movements(shop_id, product_id, location_id, movement_type, quantity_delta, previous_quantity, resulting_quantity, reason, reference_type, reference_id, idempotency_key, recorded_by_user_id)
      values(p_shop_id, v_item.product_id, p_location_id, 'count', v_delta, v_inventory.stock_quantity, v_after, trim(p_reason), 'inventory_count', v_count_id, trim(p_idempotency_key) || ':count:' || v_item.product_id::text, v_user);
    end if;
    select coalesce(sum(stock_quantity), 0) into v_total from product_location_inventory where product_id = v_item.product_id;
    update products set stock_quantity = v_total, status = case when v_total = 0 and status = 'active' then 'out_of_stock' when v_total > 0 and status = 'out_of_stock' then 'active' else status end where id = v_item.product_id;
    v_item_count := v_item_count + 1;
  end loop;
  if v_item_count = 0 then raise exception using errcode = 'P0001', message = 'EMPTY_INVENTORY_COUNT'; end if;
  insert into audit_events(actor_user_id, action, resource_type, resource_id, metadata) values(v_user, 'merchant.inventory_count_applied', 'inventory_count', v_count_id::text, jsonb_build_object('shop_id', p_shop_id, 'item_count', v_item_count));
  return jsonb_build_object('count_id', v_count_id, 'status', 'completed', 'item_count', v_item_count, 'idempotent', false);
exception when unique_violation then
  select * into v_existing from inventory_counts where shop_id = p_shop_id and idempotency_key = trim(p_idempotency_key);
  if found then return jsonb_build_object('count_id', v_existing.id, 'status', v_existing.status, 'idempotent', true); end if;
  raise;
end;
$$;
revoke all on function private.apply_inventory_count(uuid, uuid, jsonb, text, text) from public, anon;
grant execute on function private.apply_inventory_count(uuid, uuid, jsonb, text, text) to authenticated, service_role;
create or replace function public.apply_inventory_count(p_shop_id uuid, p_location_id uuid, p_items jsonb, p_reason text, p_idempotency_key text)
returns jsonb language sql security invoker set search_path = public, pg_catalog as $$ select private.apply_inventory_count(p_shop_id, p_location_id, p_items, p_reason, p_idempotency_key); $$;
revoke all on function public.apply_inventory_count(uuid, uuid, jsonb, text, text) from public, anon;
grant execute on function public.apply_inventory_count(uuid, uuid, jsonb, text, text) to authenticated;

create or replace function private.bulk_save_products(
  p_shop_id uuid,
  p_rows jsonb,
  p_idempotency_key text,
  p_source_format text default 'csv'
)
returns jsonb language plpgsql security definer set search_path = public, private, pg_catalog as $$
declare
  v_user uuid := (select auth.uid());
  v_batch catalog_import_batches%rowtype;
  v_row record;
  v_product products%rowtype;
  v_product_id uuid;
  v_status text;
  v_name text;
  v_description text;
  v_barcode text;
  v_price bigint;
  v_stock integer;
  v_count integer := 0;
  v_results jsonb := '[]'::jsonb;
begin
  if v_user is null then raise exception using errcode = '28000', message = 'AUTH_REQUIRED'; end if;
  if not exists (select 1 from shops s join merchants m on m.id = s.merchant_id where s.id = p_shop_id and m.owner_user_id = v_user) then raise exception using errcode = '42501', message = 'SHOP_NOT_OWNED'; end if;
  if jsonb_typeof(coalesce(p_rows, '[]'::jsonb)) <> 'array' or jsonb_array_length(coalesce(p_rows, '[]'::jsonb)) < 1 or jsonb_array_length(p_rows) > 500 or length(trim(coalesce(p_idempotency_key, ''))) < 8 or p_source_format not in ('csv','xlsx','json') then
    raise exception using errcode = 'P0001', message = 'INVALID_CATALOG_IMPORT';
  end if;
  select * into v_batch from catalog_import_batches where shop_id = p_shop_id and idempotency_key = trim(p_idempotency_key);
  if found then return jsonb_build_object('batch_id', v_batch.id, 'status', v_batch.status, 'row_count', v_batch.row_count, 'applied_count', v_batch.applied_count, 'results', v_batch.result, 'idempotent', true); end if;
  for v_row in select * from jsonb_to_recordset(p_rows) as x(product_id uuid, name text, description text, price_minor bigint, stock_quantity integer, status text, barcode text) loop
    v_name := trim(coalesce(v_row.name, ''));
    v_description := nullif(trim(coalesce(v_row.description, '')), '');
    v_barcode := nullif(trim(coalesce(v_row.barcode, '')), '');
    v_price := v_row.price_minor;
    v_stock := v_row.stock_quantity;
    v_status := coalesce(v_row.status, 'draft');
    if length(v_name) < 2 or v_price is null or v_price <= 0 or v_stock is null or v_stock < 0 or v_stock > 100000 or v_status not in ('draft','active','archived','out_of_stock') or (v_barcode is not null and length(v_barcode) > 128) then
      raise exception using errcode = 'P0001', message = 'INVALID_CATALOG_IMPORT_ROW';
    end if;
    v_status := case when v_stock = 0 and v_status = 'active' then 'out_of_stock' else v_status end;
    v_product_id := v_row.product_id;
    if v_product_id is not null then
      update products set name = v_name, description = v_description, price_minor = v_price, stock_quantity = v_stock, status = v_status, barcode = v_barcode where id = v_product_id and shop_id = p_shop_id returning id into v_product_id;
      if v_product_id is null then raise exception using errcode = 'P0001', message = 'PRODUCT_NOT_FOUND'; end if;
    elsif v_barcode is not null then
      select id into v_product_id from products where shop_id = p_shop_id and barcode = v_barcode for update;
      if v_product_id is null then
        insert into products(shop_id, name, description, price_minor, stock_quantity, status, barcode) values(p_shop_id, v_name, v_description, v_price, v_stock, v_status, v_barcode) returning id into v_product_id;
      else
        update products set name = v_name, description = v_description, price_minor = v_price, stock_quantity = v_stock, status = v_status where id = v_product_id;
      end if;
    else
      insert into products(shop_id, name, description, price_minor, stock_quantity, status) values(p_shop_id, v_name, v_description, v_price, v_stock, v_status) returning id into v_product_id;
    end if;
    v_count := v_count + 1;
    v_results := v_results || jsonb_build_array(jsonb_build_object('row', v_count, 'product_id', v_product_id, 'status', v_status));
  end loop;
  insert into catalog_import_batches(shop_id, status, source_format, row_count, applied_count, idempotency_key, created_by_user_id, result, applied_at)
  values(p_shop_id, 'applied', p_source_format, v_count, v_count, trim(p_idempotency_key), v_user, v_results, now()) returning * into v_batch;
  insert into audit_events(actor_user_id, action, resource_type, resource_id, metadata) values(v_user, 'merchant.catalog_bulk_imported', 'catalog_import_batch', v_batch.id::text, jsonb_build_object('shop_id', p_shop_id, 'row_count', v_count, 'source_format', p_source_format));
  return jsonb_build_object('batch_id', v_batch.id, 'status', v_batch.status, 'row_count', v_count, 'applied_count', v_count, 'results', v_results, 'idempotent', false);
exception when unique_violation then
  raise exception using errcode = '23505', message = 'CATALOG_IMPORT_DUPLICATE_BARCODE';
end;
$$;
revoke all on function private.bulk_save_products(uuid, jsonb, text, text) from public, anon;
grant execute on function private.bulk_save_products(uuid, jsonb, text, text) to authenticated, service_role;
create or replace function public.bulk_save_products(p_shop_id uuid, p_rows jsonb, p_idempotency_key text, p_source_format text default 'csv')
returns jsonb language sql security invoker set search_path = public, pg_catalog as $$ select private.bulk_save_products(p_shop_id, p_rows, p_idempotency_key, p_source_format); $$;
revoke all on function public.bulk_save_products(uuid, jsonb, text, text) from public, anon;
grant execute on function public.bulk_save_products(uuid, jsonb, text, text) to authenticated;
