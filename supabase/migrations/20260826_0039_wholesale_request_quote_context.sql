-- Add the buyer scope identifier to the merchant-owned request projection.
-- This is an authorization-scoped UUID used to target a quote; no new identity
-- or payment evidence is exposed.

create or replace function private.list_merchant_wholesale_requests(p_shop_id uuid)
returns setof jsonb language sql security definer set search_path = public, private, pg_catalog
as $$
  select jsonb_build_object(
    'id', r.id,
    'shop_id', r.shop_id,
    'buyer_user_id', r.buyer_user_id,
    'business_name', b.business_name,
    'contact_phone', b.contact_phone,
    'note', r.note,
    'estimated_monthly_minor', r.estimated_monthly_minor,
    'status', r.status,
    'approved_price_list_id', r.approved_price_list_id,
    'review_note', r.review_note,
    'created_at', r.created_at
  )
  from wholesale_requests r
  join business_profiles b on b.id = r.business_profile_id
  where r.shop_id = p_shop_id
    and (r.merchant_id in (select private.current_merchant_ids()) or private.is_admin())
  order by r.created_at desc
  limit 100;
$$;
revoke all on function private.list_merchant_wholesale_requests(uuid) from public, anon, authenticated;
grant execute on function private.list_merchant_wholesale_requests(uuid) to authenticated, service_role;
create or replace function public.list_merchant_wholesale_requests(p_shop_id uuid)
returns setof jsonb language sql security invoker set search_path = public, pg_catalog
as $$ select * from private.list_merchant_wholesale_requests(p_shop_id); $$;
revoke all on function public.list_merchant_wholesale_requests(uuid) from public, anon;
grant execute on function public.list_merchant_wholesale_requests(uuid) to authenticated;
