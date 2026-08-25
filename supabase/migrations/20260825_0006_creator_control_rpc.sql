-- Creator control-plane RPCs. Implementations stay in private; public wrappers are invoker functions.

create or replace function private.creator_current_access()
returns jsonb language plpgsql security definer set search_path = public, private, pg_catalog as $$
declare v_user uuid := (select auth.uid());
begin
  if v_user is null then return jsonb_build_object('is_creator', false, 'capabilities', '[]'::jsonb, 'account_status', 'anonymous'); end if;
  return jsonb_build_object(
    'is_creator', private.current_user_is_creator(),
    'capabilities', coalesce((select jsonb_agg(distinct uc.capability) from user_capabilities uc where uc.user_id = v_user and (uc.expires_at is null or uc.expires_at > now())), '[]'::jsonb),
    'account_status', coalesce((select account_status from user_access_controls where user_id = v_user), 'active')
  );
end;
$$;
revoke all on function private.creator_current_access() from public, anon, authenticated;
grant execute on function private.creator_current_access() to authenticated, service_role;
create or replace function public.creator_current_access()
returns jsonb language sql security invoker set search_path = public, pg_catalog as $$ select private.creator_current_access(); $$;
revoke all on function public.creator_current_access() from public, anon;
grant execute on function public.creator_current_access() to authenticated;

create or replace function private.creator_dashboard_summary()
returns jsonb language plpgsql security definer set search_path = public, private, pg_catalog as $$
declare v_user uuid := (select auth.uid());
begin
  if not private.current_user_has_capability('manage_people', null) then raise exception using errcode = '42501', message = 'FORBIDDEN'; end if;
  return jsonb_build_object(
    'active_markets', (select count(*) from markets where status = 'active'),
    'pending_merchants', (select count(*) from merchants where verification_status in ('pending','draft')),
    'pending_identity_cases', (select count(*) from identity_verification_cases where status in ('submitted','under_review')),
    'pending_shop_approvals', (select count(*) from shops where status = 'pending'),
    'payment_claims_under_review', (select count(*) from merchant_orders where payment_status = 'payment_under_review'),
    'open_reports', (select count(*) from reports where status in ('open','reviewing')),
    'generated_at', now()
  );
end;
$$;
revoke all on function private.creator_dashboard_summary() from public, anon, authenticated;
grant execute on function private.creator_dashboard_summary() to authenticated, service_role;
create or replace function public.creator_dashboard_summary()
returns jsonb language sql security invoker set search_path = public, pg_catalog as $$ select private.creator_dashboard_summary(); $$;
revoke all on function public.creator_dashboard_summary() from public, anon;
grant execute on function public.creator_dashboard_summary() to authenticated;

create or replace function private.creator_people_search(p_query text default null, p_role text default null, p_market_id uuid default null, p_limit integer default 50, p_offset integer default 0)
returns setof jsonb language plpgsql security definer set search_path = public, private, pg_catalog as $$
declare v_user uuid := (select auth.uid());
begin
  if not private.current_user_has_capability('manage_people', null) then raise exception using errcode = '42501', message = 'FORBIDDEN'; end if;
  return query
  select jsonb_build_object(
    'user_id', p.id,
    'display_name', p.display_name,
    'email', p.email,
    'phone', p.phone,
    'account_status', coalesce(uac.account_status, 'active'),
    'roles', coalesce((select jsonb_agg(distinct ur.role order by ur.role) from user_roles ur where ur.user_id = p.id), '[]'::jsonb),
    'market_ids', coalesce((select jsonb_agg(distinct ur.market_id) from user_roles ur where ur.user_id = p.id and ur.market_id is not null), '[]'::jsonb),
    'last_signed_in', null
  )
  from profiles p
  left join user_access_controls uac on uac.user_id = p.id
  where (p_query is null or p_query = '' or p.display_name ilike '%' || p_query || '%' or p.email ilike '%' || p_query || '%' or p.phone ilike '%' || p_query || '%')
    and (p_role is null or exists(select 1 from user_roles urf where urf.user_id = p.id and urf.role = p_role))
    and (p_market_id is null or exists(select 1 from user_roles urm where urm.user_id = p.id and (urm.market_id is null or urm.market_id = p_market_id)))
  order by p.created_at desc
  limit greatest(1, least(p_limit, 100)) offset greatest(0, p_offset);
end;
$$;
revoke all on function private.creator_people_search(text, text, uuid, integer, integer) from public, anon, authenticated;
grant execute on function private.creator_people_search(text, text, uuid, integer, integer) to authenticated, service_role;
create or replace function public.creator_people_search(p_query text default null, p_role text default null, p_market_id uuid default null, p_limit integer default 50, p_offset integer default 0)
returns setof jsonb language sql security invoker set search_path = public, pg_catalog as $$ select * from private.creator_people_search(p_query, p_role, p_market_id, p_limit, p_offset); $$;
revoke all on function public.creator_people_search(text, text, uuid, integer, integer) from public, anon;
grant execute on function public.creator_people_search(text, text, uuid, integer, integer) to authenticated;

create or replace function private.creator_set_user_role(p_user_id uuid, p_role text, p_market_id uuid, p_expires_at timestamptz, p_reason text)
returns jsonb language plpgsql security definer set search_path = public, private, pg_catalog as $$
declare v_actor uuid := (select auth.uid()); v_existing boolean;
begin
  if not private.current_user_has_capability('manage_people', p_market_id) then raise exception using errcode = '42501', message = 'FORBIDDEN'; end if;
  if p_role not in ('customer','merchant','admin','creator','platform_operator','review_agent','support_agent') or nullif(trim(p_reason), '') is null then raise exception using errcode = 'P0001', message = 'INVALID_ROLE_CHANGE'; end if;
  if not exists(select 1 from profiles where id = p_user_id) then raise exception using errcode = 'P0001', message = 'USER_NOT_FOUND'; end if;
  if p_role = 'creator' and not private.current_user_is_creator() then raise exception using errcode = '42501', message = 'CREATOR_ROLE_REQUIRES_CREATOR'; end if;
  if p_role in ('admin','platform_operator','review_agent','support_agent') and not private.current_user_is_creator() then raise exception using errcode = '42501', message = 'PRIVILEGED_ROLE_REQUIRES_CREATOR'; end if;
  select exists(select 1 from user_roles where user_id = p_user_id and role = p_role and ((p_market_id is null and market_id is null) or market_id = p_market_id)) into v_existing;
  if not v_existing then insert into user_roles(user_id, role, market_id) values(p_user_id, p_role, p_market_id); end if;
  insert into creator_operator_assignments(user_id, role, market_id, granted_by_user_id, reason, expires_at)
  select p_user_id, p_role, p_market_id, v_actor, trim(p_reason), p_expires_at
  where p_role in ('platform_operator','review_agent','support_agent');
  perform private.record_role_audit(v_actor, 'creator.role_granted', p_user_id, jsonb_build_object('role', p_role, 'market_id', p_market_id, 'reason', p_reason, 'expires_at', p_expires_at));
  return jsonb_build_object('success', true, 'user_id', p_user_id, 'role', p_role);
end;
$$;
revoke all on function private.creator_set_user_role(uuid, text, uuid, timestamptz, text) from public, anon, authenticated;
grant execute on function private.creator_set_user_role(uuid, text, uuid, timestamptz, text) to authenticated, service_role;
create or replace function public.creator_set_user_role(p_user_id uuid, p_role text, p_market_id uuid default null, p_expires_at timestamptz default null, p_reason text default null)
returns jsonb language sql security invoker set search_path = public, pg_catalog as $$ select private.creator_set_user_role(p_user_id, p_role, p_market_id, p_expires_at, p_reason); $$;
revoke all on function public.creator_set_user_role(uuid, text, uuid, timestamptz, text) from public, anon;
grant execute on function public.creator_set_user_role(uuid, text, uuid, timestamptz, text) to authenticated;

create or replace function private.creator_revoke_user_role(p_user_id uuid, p_role text, p_market_id uuid, p_reason text)
returns jsonb language plpgsql security definer set search_path = public, private, pg_catalog as $$
declare v_actor uuid := (select auth.uid());
begin
  if not private.current_user_has_capability('manage_people', p_market_id) then raise exception using errcode = '42501', message = 'FORBIDDEN'; end if;
  if p_role = 'creator' or (p_user_id = v_actor and p_role in ('admin','platform_operator','review_agent','support_agent')) then raise exception using errcode = '42501', message = 'ROLE_REVOCATION_NOT_ALLOWED'; end if;
  if nullif(trim(p_reason), '') is null then raise exception using errcode = 'P0001', message = 'REASON_REQUIRED'; end if;
  delete from user_roles where user_id = p_user_id and role = p_role and (p_market_id is null or market_id = p_market_id);
  update creator_operator_assignments set revoked_at = now(), revoked_by_user_id = v_actor where user_id = p_user_id and role = p_role and revoked_at is null and (p_market_id is null or market_id = p_market_id);
  perform private.record_role_audit(v_actor, 'creator.role_revoked', p_user_id, jsonb_build_object('role', p_role, 'market_id', p_market_id, 'reason', p_reason));
  return jsonb_build_object('success', true, 'user_id', p_user_id, 'role', p_role);
end;
$$;
revoke all on function private.creator_revoke_user_role(uuid, text, uuid, text) from public, anon, authenticated;
grant execute on function private.creator_revoke_user_role(uuid, text, uuid, text) to authenticated, service_role;
create or replace function public.creator_revoke_user_role(p_user_id uuid, p_role text, p_market_id uuid default null, p_reason text default null)
returns jsonb language sql security invoker set search_path = public, pg_catalog as $$ select private.creator_revoke_user_role(p_user_id, p_role, p_market_id, p_reason); $$;
revoke all on function public.creator_revoke_user_role(uuid, text, uuid, text) from public, anon;
grant execute on function public.creator_revoke_user_role(uuid, text, uuid, text) to authenticated;

create or replace function private.creator_set_account_status(p_user_id uuid, p_status text, p_until timestamptz, p_reason text)
returns jsonb language plpgsql security definer set search_path = public, private, pg_catalog as $$
declare v_actor uuid := (select auth.uid());
begin
  if not private.current_user_has_capability('manage_people', null) then raise exception using errcode = '42501', message = 'FORBIDDEN'; end if;
  if p_status not in ('active','suspended') or nullif(trim(p_reason), '') is null then raise exception using errcode = 'P0001', message = 'INVALID_ACCESS_CONTROL'; end if;
  if not exists(select 1 from profiles where id = p_user_id) then raise exception using errcode = 'P0001', message = 'USER_NOT_FOUND'; end if;
  if p_user_id = v_actor or exists(select 1 from user_roles where user_id = p_user_id and role = 'creator') then raise exception using errcode = '42501', message = 'CREATOR_ACCOUNT_PROTECTED'; end if;
  insert into user_access_controls(user_id, account_status, suspended_at, suspended_by_user_id, suspension_reason, suspension_until) values(p_user_id, p_status, case when p_status = 'suspended' then now() else null end, case when p_status = 'suspended' then v_actor else null end, case when p_status = 'suspended' then trim(p_reason) else null end, p_until)
  on conflict (user_id) do update set account_status = excluded.account_status, suspended_at = excluded.suspended_at, suspended_by_user_id = excluded.suspended_by_user_id, suspension_reason = excluded.suspension_reason, suspension_until = excluded.suspension_until, updated_at = now();
  perform private.record_role_audit(v_actor, case when p_status = 'suspended' then 'creator.user_suspended' else 'creator.user_restored' end, p_user_id, jsonb_build_object('status', p_status, 'reason', p_reason, 'until', p_until));
  return jsonb_build_object('success', true, 'user_id', p_user_id, 'account_status', p_status);
end;
$$;
revoke all on function private.creator_set_account_status(uuid, text, timestamptz, text) from public, anon, authenticated;
grant execute on function private.creator_set_account_status(uuid, text, timestamptz, text) to authenticated, service_role;
create or replace function public.creator_set_account_status(p_user_id uuid, p_status text, p_until timestamptz default null, p_reason text default null)
returns jsonb language sql security invoker set search_path = public, pg_catalog as $$ select private.creator_set_account_status(p_user_id, p_status, p_until, p_reason); $$;
revoke all on function public.creator_set_account_status(uuid, text, timestamptz, text) from public, anon;
grant execute on function public.creator_set_account_status(uuid, text, timestamptz, text) to authenticated;

create or replace function private.creator_set_capability(p_user_id uuid, p_capability text, p_market_id uuid, p_expires_at timestamptz, p_reason text)
returns jsonb language plpgsql security definer set search_path = public, private, pg_catalog as $$
declare v_actor uuid := (select auth.uid());
begin
  if not private.current_user_is_creator() then raise exception using errcode = '42501', message = 'CREATOR_REQUIRED'; end if;
  if not exists(select 1 from profiles where id = p_user_id) then raise exception using errcode = 'P0001', message = 'USER_NOT_FOUND'; end if;
  if p_capability not in ('manage_people','manage_merchants','review_identity','manage_markets','manage_policies','manage_capabilities','view_audit','view_sensitive_evidence','manage_reports','export_operational_data') or nullif(trim(p_reason), '') is null then raise exception using errcode = 'P0001', message = 'INVALID_CAPABILITY_GRANT'; end if;
  delete from user_capabilities where user_id = p_user_id and capability = p_capability and ((p_market_id is null and market_id is null) or market_id = p_market_id);
  insert into user_capabilities(user_id, capability, market_id, granted_by_user_id, reason, expires_at) values(p_user_id, p_capability, p_market_id, v_actor, trim(p_reason), p_expires_at);
  perform private.record_role_audit(v_actor, 'creator.capability_granted', p_user_id, jsonb_build_object('capability', p_capability, 'market_id', p_market_id, 'reason', p_reason, 'expires_at', p_expires_at));
  return jsonb_build_object('success', true, 'user_id', p_user_id, 'capability', p_capability);
end;
$$;
revoke all on function private.creator_set_capability(uuid, text, uuid, timestamptz, text) from public, anon, authenticated;
grant execute on function private.creator_set_capability(uuid, text, uuid, timestamptz, text) to authenticated, service_role;
create or replace function public.creator_set_capability(p_user_id uuid, p_capability text, p_market_id uuid default null, p_expires_at timestamptz default null, p_reason text default null)
returns jsonb language sql security invoker set search_path = public, pg_catalog as $$ select private.creator_set_capability(p_user_id, p_capability, p_market_id, p_expires_at, p_reason); $$;
revoke all on function public.creator_set_capability(uuid, text, uuid, timestamptz, text) from public, anon;
grant execute on function public.creator_set_capability(uuid, text, uuid, timestamptz, text) to authenticated;
