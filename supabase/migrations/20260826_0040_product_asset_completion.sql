-- Complete the private catalog-image optimization lifecycle after storage upload.
-- Storage objects remain private and are always namespaced under the actor user.

create or replace function private.complete_product_asset_variant(p_asset_variant_id uuid, p_optimized_storage_key text)
returns jsonb language plpgsql security definer set search_path = public, private, pg_catalog
as $$
declare v_user uuid := (select auth.uid()); v_variant product_asset_variants%rowtype; v_path text;
begin
  if v_user is null then raise exception using errcode = '28000', message = 'AUTH_REQUIRED'; end if;
  v_path := trim(coalesce(p_optimized_storage_key, ''));
  if length(v_path) < 3 or split_part(v_path, '/', 1) <> v_user::text then
    raise exception using errcode = 'P0001', message = 'INVALID_ASSET_PATH';
  end if;
  select av.* into v_variant
  from product_asset_variants av
  join products p on p.id = av.product_id
  join shops s on s.id = p.shop_id
  where av.id = p_asset_variant_id
    and (s.merchant_id in (select private.current_merchant_ids()) or private.is_admin())
  for update;
  if not found then raise exception using errcode = '42501', message = 'ASSET_VARIANT_NOT_FOUND'; end if;
  update product_asset_variants
  set optimized_storage_key = v_path, status = 'ready', failure_code = null, updated_at = now()
  where id = p_asset_variant_id;
  update products
  set image_path = v_path, updated_at = now()
  where id = v_variant.product_id;
  insert into audit_events(actor_user_id, action, resource_type, resource_id, metadata)
  values(v_user, 'merchant.product_asset_variant_completed', 'product_asset_variant', p_asset_variant_id::text, jsonb_build_object('product_id', v_variant.product_id, 'format', v_variant.format));
  return jsonb_build_object('asset_variant_id', p_asset_variant_id, 'product_id', v_variant.product_id, 'optimized_storage_key', v_path, 'status', 'ready');
end;
$$;
revoke all on function private.complete_product_asset_variant(uuid, text) from public, anon, authenticated;
grant execute on function private.complete_product_asset_variant(uuid, text) to authenticated, service_role;
create or replace function public.complete_product_asset_variant(p_asset_variant_id uuid, p_optimized_storage_key text)
returns jsonb language sql security invoker set search_path = public, pg_catalog
as $$ select private.complete_product_asset_variant(p_asset_variant_id, p_optimized_storage_key); $$;
revoke all on function public.complete_product_asset_variant(uuid, text) from public, anon;
grant execute on function public.complete_product_asset_variant(uuid, text) to authenticated;
