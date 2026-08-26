-- Bounded quote projections for merchant review and customer acceptance.
-- These projections expose operational quote snapshots only; no payment evidence,
-- private identity evidence, or provider secrets are included.

create or replace function private.list_merchant_wholesale_quotes(p_shop_id uuid)
returns setof jsonb language plpgsql security definer set search_path = public, private, pg_catalog
as $$
begin
  if auth.uid() is null then raise exception using errcode = '28000', message = 'AUTH_REQUIRED'; end if;
  if not exists (select 1 from shops s where s.id = p_shop_id and (s.merchant_id in (select private.current_merchant_ids()) or private.is_admin())) then
    raise exception using errcode = '42501', message = 'SHOP_NOT_OWNED';
  end if;
  return query
  select jsonb_build_object(
    'quote_id', q.id,
    'shop_id', q.shop_id,
    'buyer_user_id', q.buyer_user_id,
    'wholesale_request_id', q.wholesale_request_id,
    'status', q.status,
    'current_version_no', q.current_version_no,
    'updated_at', q.updated_at,
    'latest_version', (
      select jsonb_build_object(
        'quote_id', v.quote_id,
        'quote_version_id', v.id,
        'version_no', v.version_no,
        'status', v.status,
        'currency', v.currency,
        'valid_until', v.valid_until,
        'note', v.note,
        'reason', v.reason,
        'items', coalesce((select jsonb_agg(jsonb_build_object(
          'id', i.id,
          'product_id', i.product_id,
          'product_name_snapshot', i.product_name_snapshot,
          'variant_id', i.variant_id,
          'unit_price_minor', i.unit_price_minor,
          'quantity', i.quantity,
          'line_total_minor', i.line_total_minor
        ) order by i.id) from wholesale_quote_items i where i.quote_version_id = v.id), '[]'::jsonb)
      )
      from wholesale_quote_versions v
      where v.quote_id = q.id
      order by v.version_no desc
      limit 1
    )
  )
  from wholesale_quotes q
  where q.shop_id = p_shop_id and (q.merchant_id in (select private.current_merchant_ids()) or private.is_admin())
  order by q.updated_at desc, q.id desc
  limit 100;
end;
$$;
revoke all on function private.list_merchant_wholesale_quotes(uuid) from public, anon, authenticated;
grant execute on function private.list_merchant_wholesale_quotes(uuid) to authenticated, service_role;
create or replace function public.list_merchant_wholesale_quotes(p_shop_id uuid)
returns setof jsonb language sql security invoker set search_path = public, pg_catalog
as $$ select * from private.list_merchant_wholesale_quotes(p_shop_id); $$;
revoke all on function public.list_merchant_wholesale_quotes(uuid) from public, anon;
grant execute on function public.list_merchant_wholesale_quotes(uuid) to authenticated;

create or replace function private.list_customer_wholesale_quotes()
returns setof jsonb language sql security definer set search_path = public, private, pg_catalog
as $$
  select jsonb_build_object(
    'quote_id', q.id,
    'shop_id', q.shop_id,
    'status', q.status,
    'current_version_no', q.current_version_no,
    'updated_at', q.updated_at,
    'latest_version', (
      select jsonb_build_object(
        'quote_id', v.quote_id,
        'quote_version_id', v.id,
        'version_no', v.version_no,
        'status', v.status,
        'currency', v.currency,
        'valid_until', v.valid_until,
        'note', v.note,
        'reason', v.reason,
        'items', coalesce((select jsonb_agg(jsonb_build_object(
          'id', i.id,
          'product_id', i.product_id,
          'product_name_snapshot', i.product_name_snapshot,
          'variant_id', i.variant_id,
          'unit_price_minor', i.unit_price_minor,
          'quantity', i.quantity,
          'line_total_minor', i.line_total_minor
        ) order by i.id) from wholesale_quote_items i where i.quote_version_id = v.id), '[]'::jsonb)
      )
      from wholesale_quote_versions v
      where v.quote_id = q.id
      order by v.version_no desc
      limit 1
    )
  )
  from wholesale_quotes q
  where q.buyer_user_id = (select auth.uid()) and q.status in ('sent','accepted')
  order by q.updated_at desc, q.id desc
  limit 100;
$$;
revoke all on function private.list_customer_wholesale_quotes() from public, anon, authenticated;
grant execute on function private.list_customer_wholesale_quotes() to authenticated, service_role;
create or replace function public.list_customer_wholesale_quotes()
returns setof jsonb language sql security invoker set search_path = public, pg_catalog
as $$ select * from private.list_customer_wholesale_quotes(); $$;
revoke all on function public.list_customer_wholesale_quotes() from public, anon;
grant execute on function public.list_customer_wholesale_quotes() to authenticated;
