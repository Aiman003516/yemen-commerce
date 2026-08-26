-- Trust and merchant growth foundation.
-- Reviews are only eligible after a completed paid order. Promotions are
-- configuration records; checkout application remains a separate, audited
-- increment so historical totals stay immutable.

create table if not exists public.product_reviews (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete restrict,
  merchant_order_id uuid not null references public.merchant_orders(id) on delete cascade,
  customer_user_id uuid not null references public.profiles(id) on delete restrict,
  rating integer not null check (rating between 1 and 5),
  comment text,
  status text not null default 'pending' check (status in ('pending','published','hidden')),
  moderated_by_user_id uuid references public.profiles(id) on delete set null,
  moderated_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (product_id, merchant_order_id, customer_user_id)
);
create index if not exists product_reviews_product_status_idx
  on public.product_reviews(product_id, status, created_at desc);

create table if not exists public.merchant_promotions (
  id uuid primary key default gen_random_uuid(),
  merchant_id uuid not null references public.merchants(id) on delete cascade,
  shop_id uuid not null references public.shops(id) on delete cascade,
  code text not null,
  kind text not null check (kind in ('percent','fixed')),
  value_minor bigint not null check (value_minor > 0),
  starts_at timestamptz,
  ends_at timestamptz,
  max_redemptions integer check (max_redemptions is null or max_redemptions > 0),
  redemption_count integer not null default 0 check (redemption_count >= 0),
  status text not null default 'draft' check (status in ('draft','active','paused','expired')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (shop_id, code)
);
create index if not exists merchant_promotions_shop_status_idx
  on public.merchant_promotions(shop_id, status, starts_at, ends_at);

alter table public.product_reviews enable row level security;
alter table public.merchant_promotions enable row level security;
grant select on public.product_reviews to anon, authenticated;
grant select on public.merchant_promotions to anon, authenticated;

drop policy if exists product_reviews_public_read on public.product_reviews;
create policy product_reviews_public_read
on public.product_reviews for select to anon, authenticated
using (
  status = 'published'
  and exists (
    select 1 from products p
    join shops s on s.id = p.shop_id
    join markets m on m.id = s.market_id
    where p.id = product_id and p.status = 'active' and s.status = 'approved' and m.status = 'active'
  )
);
drop policy if exists product_reviews_customer_read on public.product_reviews;
create policy product_reviews_customer_read
on public.product_reviews for select to authenticated
using (customer_user_id = (select auth.uid()) or private.is_admin());
drop policy if exists product_reviews_merchant_read on public.product_reviews;
create policy product_reviews_merchant_read
on public.product_reviews for select to authenticated
using (
  exists (
    select 1 from products p
    join shops s on s.id = p.shop_id
    where p.id = product_id and (s.merchant_id in (select private.current_merchant_ids()) or private.is_admin())
  )
);

drop policy if exists merchant_promotions_public_read on public.merchant_promotions;
create policy merchant_promotions_public_read
on public.merchant_promotions for select to anon, authenticated
using (
  status = 'active'
  and (starts_at is null or starts_at <= now())
  and (ends_at is null or ends_at > now())
  and (max_redemptions is null or redemption_count < max_redemptions)
  and exists (select 1 from shops s join markets m on m.id = s.market_id where s.id = shop_id and s.status = 'approved' and m.status = 'active')
);
drop policy if exists merchant_promotions_owner_read on public.merchant_promotions;
create policy merchant_promotions_owner_read
on public.merchant_promotions for select to authenticated
using (merchant_id in (select private.current_merchant_ids()) or private.is_admin());

create or replace function private.submit_product_review(
  p_product_id uuid,
  p_merchant_order_id uuid,
  p_rating integer,
  p_comment text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, private, pg_catalog
as $$
declare
  v_user uuid := (select auth.uid());
  v_review product_reviews%rowtype;
begin
  if v_user is null then
    raise exception using errcode = '28000', message = 'AUTH_REQUIRED';
  end if;
  if p_rating < 1 or p_rating > 5 or length(trim(coalesce(p_comment, ''))) > 1000 then
    raise exception using errcode = 'P0001', message = 'INVALID_REVIEW';
  end if;
  if not exists (
    select 1 from merchant_orders o
    join merchant_order_items item on item.merchant_order_id = o.id and item.product_id = p_product_id
    where o.id = p_merchant_order_id
      and o.customer_user_id = v_user
      and o.payment_status = 'paid'
      and o.fulfilment_status = 'completed'
  ) then
    raise exception using errcode = 'P0001', message = 'REVIEW_NOT_ELIGIBLE';
  end if;

  insert into product_reviews(product_id, merchant_order_id, customer_user_id, rating, comment)
  values(p_product_id, p_merchant_order_id, v_user, p_rating, nullif(trim(coalesce(p_comment, '')), ''))
  returning * into v_review;

  insert into audit_events(actor_user_id, action, resource_type, resource_id, metadata)
  values(v_user, 'customer.product_review_submitted', 'product_review', v_review.id::text,
         jsonb_build_object('product_id', p_product_id, 'rating', p_rating));
  return jsonb_build_object('review_id', v_review.id, 'status', v_review.status);
exception when unique_violation then
  raise exception using errcode = '23505', message = 'REVIEW_ALREADY_SUBMITTED';
end;
$$;
revoke all on function private.submit_product_review(uuid, uuid, integer, text) from public, anon;
grant execute on function private.submit_product_review(uuid, uuid, integer, text) to authenticated, service_role;

create or replace function public.submit_product_review(
  p_product_id uuid,
  p_merchant_order_id uuid,
  p_rating integer,
  p_comment text default null
)
returns jsonb
language sql
security invoker
set search_path = public, pg_catalog
as $$
  select private.submit_product_review(p_product_id, p_merchant_order_id, p_rating, p_comment);
$$;
revoke all on function public.submit_product_review(uuid, uuid, integer, text) from public, anon;
grant execute on function public.submit_product_review(uuid, uuid, integer, text) to authenticated;

create or replace function private.save_merchant_promotion(
  p_id uuid,
  p_shop_id uuid,
  p_code text,
  p_kind text,
  p_value_minor bigint,
  p_starts_at timestamptz,
  p_ends_at timestamptz,
  p_max_redemptions integer,
  p_status text
)
returns jsonb
language plpgsql
security definer
set search_path = public, private, pg_catalog
as $$
declare
  v_user uuid := (select auth.uid());
  v_merchant_id uuid;
  v_id uuid;
begin
  if v_user is null then raise exception using errcode = '28000', message = 'AUTH_REQUIRED'; end if;
  select merchant_id into v_merchant_id from shops where id = p_shop_id;
  if v_merchant_id is null or not exists(select 1 from merchants where id = v_merchant_id and owner_user_id = v_user) then
    raise exception using errcode = '42501', message = 'SHOP_NOT_OWNED';
  end if;
  if length(trim(coalesce(p_code, ''))) < 3
     or p_kind not in ('percent','fixed')
     or p_value_minor <= 0
     or p_status not in ('draft','active','paused','expired')
     or (p_ends_at is not null and p_starts_at is not null and p_ends_at <= p_starts_at) then
    raise exception using errcode = 'P0001', message = 'INVALID_PROMOTION';
  end if;
  if p_id is null then
    insert into merchant_promotions(merchant_id, shop_id, code, kind, value_minor, starts_at, ends_at, max_redemptions, status)
    values(v_merchant_id, p_shop_id, upper(trim(p_code)), p_kind, p_value_minor, p_starts_at, p_ends_at, p_max_redemptions, p_status)
    returning id into v_id;
  else
    update merchant_promotions
    set code = upper(trim(p_code)), kind = p_kind, value_minor = p_value_minor,
        starts_at = p_starts_at, ends_at = p_ends_at, max_redemptions = p_max_redemptions,
        status = p_status, updated_at = now()
    where id = p_id and merchant_id = v_merchant_id and shop_id = p_shop_id
    returning id into v_id;
    if v_id is null then raise exception using errcode = '42501', message = 'PROMOTION_NOT_FOUND'; end if;
  end if;
  insert into audit_events(actor_user_id, action, resource_type, resource_id, metadata)
  values(v_user, 'merchant.promotion_saved', 'merchant_promotion', v_id::text, jsonb_build_object('shop_id', p_shop_id, 'status', p_status));
  return jsonb_build_object('promotion_id', v_id, 'status', p_status);
exception when unique_violation then
  raise exception using errcode = '23505', message = 'PROMOTION_CODE_EXISTS';
end;
$$;
revoke all on function private.save_merchant_promotion(uuid, uuid, text, text, bigint, timestamptz, timestamptz, integer, text) from public, anon;
grant execute on function private.save_merchant_promotion(uuid, uuid, text, text, bigint, timestamptz, timestamptz, integer, text) to authenticated, service_role;

create or replace function public.save_merchant_promotion(
  p_id uuid,
  p_shop_id uuid,
  p_code text,
  p_kind text,
  p_value_minor bigint,
  p_starts_at timestamptz,
  p_ends_at timestamptz,
  p_max_redemptions integer,
  p_status text
)
returns jsonb
language sql
security invoker
set search_path = public, pg_catalog
as $$
  select private.save_merchant_promotion(p_id, p_shop_id, p_code, p_kind, p_value_minor, p_starts_at, p_ends_at, p_max_redemptions, p_status);
$$;
revoke all on function public.save_merchant_promotion(uuid, uuid, text, text, bigint, timestamptz, timestamptz, integer, text) from public, anon;
grant execute on function public.save_merchant_promotion(uuid, uuid, text, text, bigint, timestamptz, timestamptz, integer, text) to authenticated;
