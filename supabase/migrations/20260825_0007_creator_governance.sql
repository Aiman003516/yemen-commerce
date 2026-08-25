-- Creator governance and global policy RPCs.

create or replace function private.creator_list_merchants(p_status text default null, p_limit integer default 50, p_offset integer default 0)
returns setof jsonb language plpgsql security definer set search_path = public, private, pg_catalog as $$
begin
  if not private.current_user_has_capability('manage_merchants', null) and not private.current_user_has_capability('manage_people', null) then raise exception using errcode = '42501', message = 'FORBIDDEN'; end if;
  return query select jsonb_build_object('id', m.id, 'owner_user_id', m.owner_user_id, 'owner_name', m.owner_name, 'phone', m.phone, 'market_id', m.market_id, 'verification_status', m.verification_status, 'phone_verification_status', m.phone_verification_status, 'created_at', m.created_at)
  from merchants m where p_status is null or m.verification_status = p_status order by m.created_at desc limit greatest(1, least(p_limit, 100)) offset greatest(0, p_offset);
end;
$$;
revoke all on function private.creator_list_merchants(text, integer, integer) from public, anon, authenticated;
grant execute on function private.creator_list_merchants(text, integer, integer) to authenticated, service_role;
create or replace function public.creator_list_merchants(p_status text default null, p_limit integer default 50, p_offset integer default 0)
returns setof jsonb language sql security invoker set search_path = public, pg_catalog as $$ select * from private.creator_list_merchants(p_status, p_limit, p_offset); $$;
revoke all on function public.creator_list_merchants(text, integer, integer) from public, anon;
grant execute on function public.creator_list_merchants(text, integer, integer) to authenticated;

create or replace function private.creator_set_merchant_verification(p_merchant_id uuid, p_status text, p_reason text)
returns jsonb language plpgsql security definer set search_path = public, private, pg_catalog as $$
declare v_actor uuid := (select auth.uid());
begin
  if not private.current_user_has_capability('manage_merchants', null) then raise exception using errcode = '42501', message = 'FORBIDDEN'; end if;
  if p_status not in ('pending','verified','rejected') or nullif(trim(p_reason), '') is null then raise exception using errcode = 'P0001', message = 'INVALID_MERCHANT_DECISION'; end if;
  update merchants set verification_status = p_status, updated_at = now() where id = p_merchant_id;
  if not found then raise exception using errcode = 'P0001', message = 'MERCHANT_NOT_FOUND'; end if;
  perform private.record_role_audit(v_actor, 'creator.merchant_verification_changed', p_merchant_id, jsonb_build_object('status', p_status, 'reason', p_reason));
  return jsonb_build_object('success', true, 'merchant_id', p_merchant_id, 'verification_status', p_status);
end;
$$;
revoke all on function private.creator_set_merchant_verification(uuid, text, text) from public, anon, authenticated;
grant execute on function private.creator_set_merchant_verification(uuid, text, text) to authenticated, service_role;
create or replace function public.creator_set_merchant_verification(p_merchant_id uuid, p_status text, p_reason text default null)
returns jsonb language sql security invoker set search_path = public, pg_catalog as $$ select private.creator_set_merchant_verification(p_merchant_id, p_status, p_reason); $$;
revoke all on function public.creator_set_merchant_verification(uuid, text, text) from public, anon;
grant execute on function public.creator_set_merchant_verification(uuid, text, text) to authenticated;

create or replace function private.creator_list_shops(p_status text default null, p_limit integer default 50, p_offset integer default 0)
returns setof jsonb language plpgsql security definer set search_path = public, private, pg_catalog as $$
begin
  if not private.current_user_has_capability('manage_merchants', null) then raise exception using errcode = '42501', message = 'FORBIDDEN'; end if;
  return query select jsonb_build_object('id', s.id, 'merchant_id', s.merchant_id, 'market_id', s.market_id, 'name', s.name, 'slug', s.slug, 'area_label', s.area_label, 'status', s.status, 'created_at', s.created_at)
  from shops s where p_status is null or s.status = p_status order by s.created_at desc limit greatest(1, least(p_limit, 100)) offset greatest(0, p_offset);
end;
$$;
revoke all on function private.creator_list_shops(text, integer, integer) from public, anon, authenticated;
grant execute on function private.creator_list_shops(text, integer, integer) to authenticated, service_role;
create or replace function public.creator_list_shops(p_status text default null, p_limit integer default 50, p_offset integer default 0)
returns setof jsonb language sql security invoker set search_path = public, pg_catalog as $$ select * from private.creator_list_shops(p_status, p_limit, p_offset); $$;
revoke all on function public.creator_list_shops(text, integer, integer) from public, anon;
grant execute on function public.creator_list_shops(text, integer, integer) to authenticated;

create or replace function private.creator_set_shop_status(p_shop_id uuid, p_status text, p_reason text)
returns jsonb language plpgsql security definer set search_path = public, private, pg_catalog as $$
declare v_actor uuid := (select auth.uid());
begin
  if not private.current_user_has_capability('manage_merchants', null) then raise exception using errcode = '42501', message = 'FORBIDDEN'; end if;
  if p_status not in ('draft','pending','approved','suspended') or nullif(trim(p_reason), '') is null then raise exception using errcode = 'P0001', message = 'INVALID_SHOP_DECISION'; end if;
  update shops set status = p_status, updated_at = now() where id = p_shop_id;
  if not found then raise exception using errcode = 'P0001', message = 'SHOP_NOT_FOUND'; end if;
  perform private.record_role_audit(v_actor, 'creator.shop_status_changed', p_shop_id, jsonb_build_object('status', p_status, 'reason', p_reason));
  return jsonb_build_object('success', true, 'shop_id', p_shop_id, 'status', p_status);
end;
$$;
revoke all on function private.creator_set_shop_status(uuid, text, text) from public, anon, authenticated;
grant execute on function private.creator_set_shop_status(uuid, text, text) to authenticated, service_role;
create or replace function public.creator_set_shop_status(p_shop_id uuid, p_status text, p_reason text default null)
returns jsonb language sql security invoker set search_path = public, pg_catalog as $$ select private.creator_set_shop_status(p_shop_id, p_status, p_reason); $$;
revoke all on function public.creator_set_shop_status(uuid, text, text) from public, anon;
grant execute on function public.creator_set_shop_status(uuid, text, text) to authenticated;

create or replace function private.creator_list_markets()
returns setof jsonb language plpgsql security definer set search_path = public, private, pg_catalog as $$
begin
  if not private.current_user_has_capability('manage_markets', null) and not private.current_user_has_capability('manage_policies', null) then raise exception using errcode = '42501', message = 'FORBIDDEN'; end if;
  return query select jsonb_build_object('id', m.id, 'governorate', m.governorate, 'city', m.city, 'district', m.district, 'service_area', m.service_area, 'status', m.status, 'currency', m.currency, 'is_pilot', m.is_pilot, 'created_at', m.created_at)
  from markets m order by m.created_at;
end;
$$;
revoke all on function private.creator_list_markets() from public, anon, authenticated;
grant execute on function private.creator_list_markets() to authenticated, service_role;
create or replace function public.creator_list_markets()
returns setof jsonb language sql security invoker set search_path = public, pg_catalog as $$ select * from private.creator_list_markets(); $$;
revoke all on function public.creator_list_markets() from public, anon;
grant execute on function public.creator_list_markets() to authenticated;

create or replace function private.creator_set_market_status(p_market_id uuid, p_status text, p_reason text)
returns jsonb language plpgsql security definer set search_path = public, private, pg_catalog as $$
declare v_actor uuid := (select auth.uid());
begin
  if not private.current_user_has_capability('manage_markets', null) then raise exception using errcode = '42501', message = 'FORBIDDEN'; end if;
  if p_status not in ('draft','active','paused') or nullif(trim(p_reason), '') is null then raise exception using errcode = 'P0001', message = 'INVALID_MARKET_STATUS'; end if;
  update markets set status = p_status, updated_at = now() where id = p_market_id;
  if not found then raise exception using errcode = 'P0001', message = 'MARKET_NOT_FOUND'; end if;
  perform private.record_role_audit(v_actor, 'creator.market_status_changed', p_market_id, jsonb_build_object('status', p_status, 'reason', p_reason));
  return jsonb_build_object('success', true, 'market_id', p_market_id, 'status', p_status);
end;
$$;
revoke all on function private.creator_set_market_status(uuid, text, text) from public, anon, authenticated;
grant execute on function private.creator_set_market_status(uuid, text, text) to authenticated, service_role;
create or replace function public.creator_set_market_status(p_market_id uuid, p_status text, p_reason text default null)
returns jsonb language sql security invoker set search_path = public, pg_catalog as $$ select private.creator_set_market_status(p_market_id, p_status, p_reason); $$;
revoke all on function public.creator_set_market_status(uuid, text, text) from public, anon;
grant execute on function public.creator_set_market_status(uuid, text, text) to authenticated;

create or replace function private.creator_list_policies(p_market_id uuid)
returns setof jsonb language plpgsql security definer set search_path = public, private, pg_catalog as $$
begin
  if not private.current_user_has_capability('manage_policies', p_market_id) then raise exception using errcode = '42501', message = 'FORBIDDEN'; end if;
  return query select jsonb_build_object('id', mp.id, 'market_id', mp.market_id, 'key', mp.key, 'version', mp.version, 'value', mp.value, 'is_active', mp.is_active, 'effective_from', mp.effective_from, 'created_at', mp.created_at)
  from market_policy_versions mp where mp.market_id = p_market_id order by mp.key, mp.version desc;
end;
$$;
revoke all on function private.creator_list_policies(uuid) from public, anon, authenticated;
grant execute on function private.creator_list_policies(uuid) to authenticated, service_role;
create or replace function public.creator_list_policies(p_market_id uuid)
returns setof jsonb language sql security invoker set search_path = public, pg_catalog as $$ select * from private.creator_list_policies(p_market_id); $$;
revoke all on function public.creator_list_policies(uuid) from public, anon;
grant execute on function public.creator_list_policies(uuid) to authenticated;

create or replace function private.creator_upsert_policy(p_market_id uuid, p_key text, p_value jsonb, p_effective_from timestamptz, p_reason text)
returns jsonb language plpgsql security definer set search_path = public, private, pg_catalog as $$
declare v_actor uuid := (select auth.uid()); v_version integer;
begin
  if not private.current_user_has_capability('manage_policies', p_market_id) then raise exception using errcode = '42501', message = 'FORBIDDEN'; end if;
  if nullif(trim(p_key), '') is null or p_value is null or nullif(trim(p_reason), '') is null then raise exception using errcode = 'P0001', message = 'INVALID_POLICY'; end if;
  select coalesce(max(version), 0) + 1 into v_version from market_policy_versions where market_id = p_market_id and key = trim(p_key);
  update market_policy_versions set is_active = false where market_id = p_market_id and key = trim(p_key) and is_active;
  insert into market_policy_versions(market_id, key, version, value, is_active, effective_from) values(p_market_id, trim(p_key), v_version, p_value, true, coalesce(p_effective_from, now()));
  perform private.record_role_audit(v_actor, 'creator.policy_version_created', p_market_id, jsonb_build_object('key', p_key, 'version', v_version, 'reason', p_reason));
  return jsonb_build_object('success', true, 'market_id', p_market_id, 'key', trim(p_key), 'version', v_version);
end;
$$;
revoke all on function private.creator_upsert_policy(uuid, text, jsonb, timestamptz, text) from public, anon, authenticated;
grant execute on function private.creator_upsert_policy(uuid, text, jsonb, timestamptz, text) to authenticated, service_role;
create or replace function public.creator_upsert_policy(p_market_id uuid, p_key text, p_value jsonb, p_effective_from timestamptz default null, p_reason text default null)
returns jsonb language sql security invoker set search_path = public, pg_catalog as $$ select private.creator_upsert_policy(p_market_id, p_key, p_value, p_effective_from, p_reason); $$;
revoke all on function public.creator_upsert_policy(uuid, text, jsonb, timestamptz, text) from public, anon;
grant execute on function public.creator_upsert_policy(uuid, text, jsonb, timestamptz, text) to authenticated;

create or replace function private.creator_list_capabilities(p_market_id uuid)
returns setof jsonb language plpgsql security definer set search_path = public, private, pg_catalog as $$
begin
  if not private.current_user_has_capability('manage_capabilities', p_market_id) then raise exception using errcode = '42501', message = 'FORBIDDEN'; end if;
  return query select jsonb_build_object('id', c.id, 'key', c.key, 'default_enabled', c.default_enabled, 'market_id', p_market_id, 'enabled', coalesce(mc.enabled, c.default_enabled), 'reason_ar', mc.reason_ar)
  from capabilities c left join market_capabilities mc on mc.capability_id = c.id and mc.market_id = p_market_id order by c.key;
end;
$$;
revoke all on function private.creator_list_capabilities(uuid) from public, anon, authenticated;
grant execute on function private.creator_list_capabilities(uuid) to authenticated, service_role;
create or replace function public.creator_list_capabilities(p_market_id uuid)
returns setof jsonb language sql security invoker set search_path = public, pg_catalog as $$ select * from private.creator_list_capabilities(p_market_id); $$;
revoke all on function public.creator_list_capabilities(uuid) from public, anon;
grant execute on function public.creator_list_capabilities(uuid) to authenticated;

create or replace function private.creator_set_market_capability(p_market_id uuid, p_capability_id uuid, p_enabled boolean, p_reason text)
returns jsonb language plpgsql security definer set search_path = public, private, pg_catalog as $$
declare v_actor uuid := (select auth.uid());
begin
  if not private.current_user_has_capability('manage_capabilities', p_market_id) then raise exception using errcode = '42501', message = 'FORBIDDEN'; end if;
  if nullif(trim(p_reason), '') is null or not exists(select 1 from markets where id = p_market_id) or not exists(select 1 from capabilities where id = p_capability_id) then raise exception using errcode = 'P0001', message = 'INVALID_CAPABILITY_SCOPE'; end if;
  insert into market_capabilities(market_id, capability_id, enabled, reason_ar, updated_at) values(p_market_id, p_capability_id, p_enabled, trim(p_reason), now()) on conflict (market_id, capability_id) do update set enabled = excluded.enabled, reason_ar = excluded.reason_ar, updated_at = now();
  perform private.record_role_audit(v_actor, 'creator.market_capability_changed', p_market_id, jsonb_build_object('capability_id', p_capability_id, 'enabled', p_enabled, 'reason', p_reason));
  return jsonb_build_object('success', true, 'market_id', p_market_id, 'capability_id', p_capability_id, 'enabled', p_enabled);
end;
$$;
revoke all on function private.creator_set_market_capability(uuid, uuid, boolean, text) from public, anon, authenticated;
grant execute on function private.creator_set_market_capability(uuid, uuid, boolean, text) to authenticated, service_role;
create or replace function public.creator_set_market_capability(p_market_id uuid, p_capability_id uuid, p_enabled boolean, p_reason text default null)
returns jsonb language sql security invoker set search_path = public, pg_catalog as $$ select private.creator_set_market_capability(p_market_id, p_capability_id, p_enabled, p_reason); $$;
revoke all on function public.creator_set_market_capability(uuid, uuid, boolean, text) from public, anon;
grant execute on function public.creator_set_market_capability(uuid, uuid, boolean, text) to authenticated;
