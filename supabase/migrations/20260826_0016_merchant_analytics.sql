-- Read-only merchant analytics for the pilot.
-- Only aggregate values are returned; customer identities, payment proofs, and
-- provider credentials remain outside this projection.

create or replace function private.merchant_dashboard_metrics(p_shop_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, private, pg_catalog
as $$
declare
  v_user uuid := (select auth.uid());
  v_market_id uuid;
  v_result jsonb;
begin
  if v_user is null then raise exception using errcode = '28000', message = 'AUTH_REQUIRED'; end if;
  select market_id into v_market_id
  from shops s
  join merchants merchant on merchant.id = s.merchant_id
  where s.id = p_shop_id and (merchant.owner_user_id = v_user or private.is_admin());
  if v_market_id is null then raise exception using errcode = '42501', message = 'SHOP_NOT_OWNED'; end if;

  select jsonb_build_object(
    'shop_id', p_shop_id,
    'orders_count', (select count(*) from merchant_orders where shop_id = p_shop_id),
    'paid_orders_count', (select count(*) from merchant_orders where shop_id = p_shop_id and payment_status = 'paid'),
    'completed_orders_count', (select count(*) from merchant_orders where shop_id = p_shop_id and fulfilment_status = 'completed'),
    'gross_paid_minor', coalesce((select sum(total_minor) from merchant_orders where shop_id = p_shop_id and payment_status = 'paid'), 0),
    'active_products_count', (select count(*) from products where shop_id = p_shop_id and status = 'active'),
    'low_stock_products_count', (select count(*) from products where shop_id = p_shop_id and status in ('active','out_of_stock') and stock_quantity <= 5),
    'open_cases_count', (select count(*) from order_cases c join merchant_orders o on o.id = c.merchant_order_id where o.shop_id = p_shop_id and c.status in ('open','reviewing'))
  ) into v_result;
  return v_result;
end;
$$;
revoke all on function private.merchant_dashboard_metrics(uuid) from public, anon, authenticated;
grant execute on function private.merchant_dashboard_metrics(uuid) to authenticated, service_role;

create or replace function public.merchant_dashboard_metrics(p_shop_id uuid)
returns jsonb
language sql
security invoker
set search_path = public, pg_catalog
as $$
  select private.merchant_dashboard_metrics(p_shop_id);
$$;
revoke all on function public.merchant_dashboard_metrics(uuid) from public, anon;
grant execute on function public.merchant_dashboard_metrics(uuid) to authenticated;
