-- Product management command for merchant catalog operations.

create or replace function private.save_product(p_id uuid, p_shop_id uuid, p_category_id uuid, p_name text, p_description text, p_price_minor bigint, p_stock_quantity integer, p_status text)
returns jsonb language plpgsql security definer set search_path = public, private, pg_catalog as $$
declare v_user uuid := (select auth.uid()); v_product_id uuid; v_status text;
begin
  if v_user is null then raise exception using errcode = '28000', message = 'AUTH_REQUIRED'; end if;
  if length(trim(p_name)) < 2 or p_price_minor <= 0 or p_stock_quantity < 0 or p_stock_quantity > 100000 or p_status not in ('draft','active','archived','out_of_stock') then raise exception using errcode = 'P0001', message = 'INVALID_PRODUCT'; end if;
  if not exists(select 1 from shops s join merchants m on m.id = s.merchant_id where s.id = p_shop_id and m.owner_user_id = v_user) then raise exception using errcode = '42501', message = 'SHOP_NOT_OWNED'; end if;
  if p_category_id is not null and not exists(select 1 from categories c where c.id = p_category_id and (c.market_id is null or c.market_id = (select market_id from shops where id = p_shop_id))) then raise exception using errcode = 'P0001', message = 'CATEGORY_NOT_AVAILABLE'; end if;
  v_status := case when p_stock_quantity = 0 and p_status = 'active' then 'out_of_stock' else p_status end;
  if p_id is null then
    insert into products(shop_id, category_id, name, description, price_minor, stock_quantity, status) values(p_shop_id, p_category_id, trim(p_name), nullif(trim(p_description), ''), p_price_minor, p_stock_quantity, v_status) returning id into v_product_id;
  else
    update products set category_id = p_category_id, name = trim(p_name), description = nullif(trim(p_description), ''), price_minor = p_price_minor, stock_quantity = p_stock_quantity, status = v_status where id = p_id and shop_id = p_shop_id returning id into v_product_id;
    if v_product_id is null then raise exception using errcode = 'P0001', message = 'PRODUCT_NOT_FOUND'; end if;
  end if;
  insert into audit_events(actor_user_id, action, resource_type, resource_id, metadata) values(v_user, 'merchant.product_saved', 'product', v_product_id::text, jsonb_build_object('shop_id', p_shop_id, 'status', v_status));
  return jsonb_build_object('product_id', v_product_id, 'status', v_status);
end;
$$;
revoke all on function private.save_product(uuid, uuid, uuid, text, text, bigint, integer, text) from public, anon;
grant execute on function private.save_product(uuid, uuid, uuid, text, text, bigint, integer, text) to authenticated, service_role;

create or replace function public.save_product(p_id uuid, p_shop_id uuid, p_category_id uuid, p_name text, p_description text, p_price_minor bigint, p_stock_quantity integer, p_status text)
returns jsonb language sql security invoker set search_path = public, pg_catalog as $$ select private.save_product(p_id, p_shop_id, p_category_id, p_name, p_description, p_price_minor, p_stock_quantity, p_status); $$;
revoke all on function public.save_product(uuid, uuid, uuid, text, text, bigint, integer, text) from public, anon;
grant execute on function public.save_product(uuid, uuid, uuid, text, text, bigint, integer, text) to authenticated;
