-- Barcode-aware product save command.
-- Delegates core validation/ownership to the existing save_product command.

create or replace function private.save_product_with_barcode(
  p_id uuid,
  p_shop_id uuid,
  p_category_id uuid,
  p_name text,
  p_description text,
  p_price_minor bigint,
  p_stock_quantity integer,
  p_status text,
  p_barcode text default null
)
returns jsonb language plpgsql security definer set search_path = public, private, pg_catalog as $$
declare
  v_result jsonb;
  v_product_id uuid;
  v_barcode text := nullif(trim(coalesce(p_barcode, '')), '');
begin
  if v_barcode is not null and (length(v_barcode) > 128 or v_barcode !~ '^[0-9A-Za-z._-]+$') then
    raise exception using errcode = 'P0001', message = 'INVALID_PRODUCT_BARCODE';
  end if;
  v_result := private.save_product(p_id, p_shop_id, p_category_id, p_name, p_description, p_price_minor, p_stock_quantity, p_status);
  v_product_id := (v_result ->> 'product_id')::uuid;
  update products set barcode = v_barcode where id = v_product_id;
  return v_result || jsonb_build_object('barcode', v_barcode);
exception when unique_violation then
  raise exception using errcode = '23505', message = 'PRODUCT_BARCODE_DUPLICATE';
end;
$$;
revoke all on function private.save_product_with_barcode(uuid, uuid, uuid, text, text, bigint, integer, text, text) from public, anon;
grant execute on function private.save_product_with_barcode(uuid, uuid, uuid, text, text, bigint, integer, text, text) to authenticated, service_role;

create or replace function public.save_product_with_barcode(
  p_id uuid,
  p_shop_id uuid,
  p_category_id uuid,
  p_name text,
  p_description text,
  p_price_minor bigint,
  p_stock_quantity integer,
  p_status text,
  p_barcode text default null
)
returns jsonb language sql security invoker set search_path = public, pg_catalog as $$
  select private.save_product_with_barcode(p_id, p_shop_id, p_category_id, p_name, p_description, p_price_minor, p_stock_quantity, p_status, p_barcode);
$$;
revoke all on function public.save_product_with_barcode(uuid, uuid, uuid, text, text, bigint, integer, text, text) from public, anon;
grant execute on function public.save_product_with_barcode(uuid, uuid, uuid, text, text, bigint, integer, text, text) to authenticated;
