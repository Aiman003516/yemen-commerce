-- Market operations governance and review moderation.
-- All privileged changes require scoped capability/role checks, reasons, and audits.

create or replace function private.creator_save_service_area(
  p_id uuid,
  p_market_id uuid,
  p_name_ar text,
  p_name_en text,
  p_area_code text,
  p_status text,
  p_delivery_enabled boolean,
  p_pickup_enabled boolean,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = public, private, pg_catalog
as $$
declare
  v_user uuid := (select auth.uid());
  v_id uuid;
begin
  if v_user is null then raise exception using errcode = '28000', message = 'AUTH_REQUIRED'; end if;
  if not private.current_user_has_capability('manage_markets', p_market_id) then raise exception using errcode = '42501', message = 'FORBIDDEN'; end if;
  if not exists(select 1 from markets where id = p_market_id) then raise exception using errcode = 'P0001', message = 'MARKET_NOT_FOUND'; end if;
  if length(trim(coalesce(p_name_ar, ''))) < 2 or length(trim(coalesce(p_area_code, ''))) < 2
     or p_status not in ('draft','active','paused') or length(trim(coalesce(p_reason, ''))) < 3 then
    raise exception using errcode = 'P0001', message = 'INVALID_SERVICE_AREA';
  end if;
  if p_id is null then
    insert into market_service_areas(market_id, name_ar, name_en, area_code, status, delivery_enabled, pickup_enabled)
    values(p_market_id, trim(p_name_ar), nullif(trim(p_name_en), ''), upper(trim(p_area_code)), p_status, p_delivery_enabled, p_pickup_enabled)
    returning id into v_id;
  else
    update market_service_areas
    set market_id = p_market_id,
        name_ar = trim(p_name_ar),
        name_en = nullif(trim(p_name_en), ''),
        area_code = upper(trim(p_area_code)),
        status = p_status,
        delivery_enabled = p_delivery_enabled,
        pickup_enabled = p_pickup_enabled,
        updated_at = now()
    where id = p_id
    returning id into v_id;
    if v_id is null then raise exception using errcode = 'P0001', message = 'SERVICE_AREA_NOT_FOUND'; end if;
  end if;
  insert into audit_events(actor_user_id, action, resource_type, resource_id, metadata)
  values(v_user, 'creator.service_area_saved', 'market_service_area', v_id::text,
         jsonb_build_object('market_id', p_market_id, 'status', p_status, 'reason', trim(p_reason)));
  return jsonb_build_object('service_area_id', v_id, 'status', p_status);
exception when unique_violation then
  raise exception using errcode = '23505', message = 'SERVICE_AREA_CODE_EXISTS';
end;
$$;
revoke all on function private.creator_save_service_area(uuid, uuid, text, text, text, text, boolean, boolean, text) from public, anon, authenticated;
grant execute on function private.creator_save_service_area(uuid, uuid, text, text, text, text, boolean, boolean, text) to authenticated, service_role;

create or replace function public.creator_save_service_area(
  p_id uuid,
  p_market_id uuid,
  p_name_ar text,
  p_name_en text default null,
  p_area_code text default null,
  p_status text default 'draft',
  p_delivery_enabled boolean default true,
  p_pickup_enabled boolean default true,
  p_reason text default null
)
returns jsonb
language sql
security invoker
set search_path = public, pg_catalog
as $$
  select private.creator_save_service_area(p_id, p_market_id, p_name_ar, p_name_en, p_area_code, p_status, p_delivery_enabled, p_pickup_enabled, p_reason);
$$;
revoke all on function public.creator_save_service_area(uuid, uuid, text, text, text, text, boolean, boolean, text) from public, anon;
grant execute on function public.creator_save_service_area(uuid, uuid, text, text, text, text, boolean, boolean, text) to authenticated;

create or replace function private.creator_save_pickup_point(
  p_id uuid,
  p_market_id uuid,
  p_service_area_id uuid,
  p_name_ar text,
  p_name_en text,
  p_address_details text,
  p_contact_phone text,
  p_operating_hours text,
  p_status text,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = public, private, pg_catalog
as $$
declare
  v_user uuid := (select auth.uid());
  v_id uuid;
begin
  if v_user is null then raise exception using errcode = '28000', message = 'AUTH_REQUIRED'; end if;
  if not private.current_user_has_capability('manage_markets', p_market_id) then raise exception using errcode = '42501', message = 'FORBIDDEN'; end if;
  if p_service_area_id is not null and not exists(select 1 from market_service_areas where id = p_service_area_id and market_id = p_market_id) then
    raise exception using errcode = 'P0001', message = 'SERVICE_AREA_NOT_FOUND';
  end if;
  if length(trim(coalesce(p_name_ar, ''))) < 2 or length(trim(coalesce(p_address_details, ''))) < 5
     or p_status not in ('draft','active','paused') or length(trim(coalesce(p_reason, ''))) < 3 then
    raise exception using errcode = 'P0001', message = 'INVALID_PICKUP_POINT';
  end if;
  if p_id is null then
    insert into pickup_points(market_id, service_area_id, name_ar, name_en, address_details, contact_phone, operating_hours, status)
    values(p_market_id, p_service_area_id, trim(p_name_ar), nullif(trim(p_name_en), ''), trim(p_address_details), nullif(trim(p_contact_phone), ''), nullif(trim(p_operating_hours), ''), p_status)
    returning id into v_id;
  else
    update pickup_points
    set market_id = p_market_id,
        service_area_id = p_service_area_id,
        name_ar = trim(p_name_ar),
        name_en = nullif(trim(p_name_en), ''),
        address_details = trim(p_address_details),
        contact_phone = nullif(trim(p_contact_phone), ''),
        operating_hours = nullif(trim(p_operating_hours), ''),
        status = p_status,
        updated_at = now()
    where id = p_id
    returning id into v_id;
    if v_id is null then raise exception using errcode = 'P0001', message = 'PICKUP_POINT_NOT_FOUND'; end if;
  end if;
  insert into audit_events(actor_user_id, action, resource_type, resource_id, metadata)
  values(v_user, 'creator.pickup_point_saved', 'pickup_point', v_id::text,
         jsonb_build_object('market_id', p_market_id, 'status', p_status, 'reason', trim(p_reason)));
  return jsonb_build_object('pickup_point_id', v_id, 'status', p_status);
end;
$$;
revoke all on function private.creator_save_pickup_point(uuid, uuid, uuid, text, text, text, text, text, text, text) from public, anon, authenticated;
grant execute on function private.creator_save_pickup_point(uuid, uuid, uuid, text, text, text, text, text, text, text) to authenticated, service_role;

create or replace function public.creator_save_pickup_point(
  p_id uuid,
  p_market_id uuid,
  p_service_area_id uuid,
  p_name_ar text,
  p_name_en text default null,
  p_address_details text default null,
  p_contact_phone text default null,
  p_operating_hours text default null,
  p_status text default 'draft',
  p_reason text default null
)
returns jsonb
language sql
security invoker
set search_path = public, pg_catalog
as $$
  select private.creator_save_pickup_point(p_id, p_market_id, p_service_area_id, p_name_ar, p_name_en, p_address_details, p_contact_phone, p_operating_hours, p_status, p_reason);
$$;
revoke all on function public.creator_save_pickup_point(uuid, uuid, uuid, text, text, text, text, text, text, text) from public, anon;
grant execute on function public.creator_save_pickup_point(uuid, uuid, uuid, text, text, text, text, text, text, text) to authenticated;

create or replace function private.moderate_product_review(
  p_review_id uuid,
  p_status text,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = public, private, pg_catalog
as $$
declare
  v_user uuid := (select auth.uid());
  v_previous text;
begin
  if v_user is null then raise exception using errcode = '28000', message = 'AUTH_REQUIRED'; end if;
  if not private.is_admin() and not private.has_role('review_agent', null) and not private.current_user_has_capability('manage_reports', null) then
    raise exception using errcode = '42501', message = 'FORBIDDEN';
  end if;
  if p_status not in ('published','hidden') or length(trim(coalesce(p_reason, ''))) < 3 then
    raise exception using errcode = 'P0001', message = 'INVALID_REVIEW_DECISION';
  end if;
  select status into v_previous from product_reviews where id = p_review_id for update;
  if not found then raise exception using errcode = 'P0001', message = 'REVIEW_NOT_FOUND'; end if;
  update product_reviews
  set status = p_status, moderated_by_user_id = v_user, moderated_at = now(), updated_at = now()
  where id = p_review_id;
  insert into audit_events(actor_user_id, action, resource_type, resource_id, metadata)
  values(v_user, 'review.moderated', 'product_review', p_review_id::text,
         jsonb_build_object('previous_status', v_previous, 'status', p_status, 'reason', trim(p_reason)));
  return jsonb_build_object('review_id', p_review_id, 'status', p_status);
end;
$$;
revoke all on function private.moderate_product_review(uuid, text, text) from public, anon, authenticated;
grant execute on function private.moderate_product_review(uuid, text, text) to authenticated, service_role;

create or replace function public.moderate_product_review(
  p_review_id uuid,
  p_status text,
  p_reason text
)
returns jsonb
language sql
security invoker
set search_path = public, pg_catalog
as $$
  select private.moderate_product_review(p_review_id, p_status, p_reason);
$$;
revoke all on function public.moderate_product_review(uuid, text, text) from public, anon;
grant execute on function public.moderate_product_review(uuid, text, text) to authenticated;
