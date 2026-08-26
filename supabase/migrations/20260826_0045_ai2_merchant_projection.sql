-- AI-2 merchant projection: read-only catalog context for scoped drafting.
-- No customer identity, payment evidence, private storage key, or provider secret is returned.

create or replace function private.merchant_ai_catalog(
  p_shop_id uuid,
  p_query text default null,
  p_limit integer default 30,
  p_offset integer default 0
)
returns setof jsonb
language plpgsql
security definer
set search_path = public, private, pg_catalog
as $$
declare
  v_user uuid := (select auth.uid());
  v_limit integer := least(greatest(coalesce(p_limit, 30), 1), 40);
  v_offset integer := least(greatest(coalesce(p_offset, 0), 0), 10000);
  v_query text := nullif(trim(p_query), '');
begin
  if v_user is null then
    raise exception using errcode = '28000', message = 'AUTH_REQUIRED';
  end if;
  if p_shop_id is null then
    raise exception using errcode = 'P0001', message = 'AI_SHOP_SCOPE_REQUIRED';
  end if;
  if v_query is not null and length(v_query) > 120 then
    raise exception using errcode = 'P0001', message = 'AI_QUERY_TOO_LONG';
  end if;
  if not exists (
    select 1
    from public.shops s
    where s.id = p_shop_id
      and (s.merchant_id in (select private.current_merchant_ids()) or private.is_admin())
  ) then
    raise exception using errcode = '42501', message = 'AI_SHOP_SCOPE_FORBIDDEN';
  end if;

  return query
  select jsonb_build_object(
    'product_id', p.id,
    'shop_id', p.shop_id,
    'name', p.name,
    'description', p.description,
    'price_minor', p.price_minor,
    'currency', p.currency,
    'stock_quantity', p.stock_quantity,
    'status', p.status,
    'barcode', p.barcode
  )
  from public.products p
  where p.shop_id = p_shop_id
    and (v_query is null or p.name ilike '%' || v_query || '%' or coalesce(p.description, '') ilike '%' || v_query || '%')
  order by p.updated_at desc, p.id desc
  limit v_limit offset v_offset;
end;
$$;
revoke all on function private.merchant_ai_catalog(uuid, text, integer, integer) from public, anon, authenticated;
grant execute on function private.merchant_ai_catalog(uuid, text, integer, integer) to authenticated, service_role;

create or replace function public.merchant_ai_catalog(
  p_shop_id uuid,
  p_query text default null,
  p_limit integer default 30,
  p_offset integer default 0
)
returns setof jsonb
language sql
security invoker
set search_path = public, pg_catalog
as $$
  select * from private.merchant_ai_catalog(p_shop_id, p_query, p_limit, p_offset);
$$;
revoke all on function public.merchant_ai_catalog(uuid, text, integer, integer) from public, anon;
grant execute on function public.merchant_ai_catalog(uuid, text, integer, integer) to authenticated;
