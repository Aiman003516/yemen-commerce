-- Keep products.stock_quantity consistent with location-level inventory.
-- Once a product has location rows, stock is managed only by inventory RPCs.

create or replace function private.guard_product_location_stock()
returns trigger
language plpgsql
security definer
set search_path = public, private, pg_catalog
as $$
declare
  v_location_total integer;
begin
  select coalesce(sum(stock_quantity), 0) into v_location_total
  from product_location_inventory
  where product_id = new.id;
  if exists (select 1 from product_location_inventory where product_id = new.id)
     and new.stock_quantity <> v_location_total then
    raise exception using errcode = 'P0001', message = 'PRODUCT_STOCK_MANAGED_BY_LOCATIONS';
  end if;
  return new;
end;
$$;
revoke all on function private.guard_product_location_stock() from public, anon, authenticated;
grant execute on function private.guard_product_location_stock() to service_role;

drop trigger if exists products_location_stock_guard on public.products;
create trigger products_location_stock_guard
before insert or update of stock_quantity on public.products
for each row execute function private.guard_product_location_stock();
