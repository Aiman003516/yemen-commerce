-- AI-1 policy resolver: expose only the single effective policy for the
-- authenticated app/role/tool context. The engine still applies hard-coded
-- fail-closed boundaries in addition to these rules.

create or replace function private.ai_get_effective_policy(
  p_app_surface text,
  p_tool_name text default '*'
)
returns jsonb
language plpgsql
security definer
set search_path = public, private, pg_catalog
as $$
declare
  v_actor uuid := (select auth.uid());
  v_role text;
  v_policy public.ai_policies%rowtype;
begin
  if v_actor is null then
    raise exception using errcode = '28000', message = 'AUTH_REQUIRED';
  end if;
  if p_app_surface not in ('customer', 'merchant', 'developer') then
    raise exception using errcode = 'P0001', message = 'AI_APP_SURFACE_INVALID';
  end if;
  if p_app_surface = 'developer' and not private.current_user_is_creator() then
    raise exception using errcode = '42501', message = 'AI_DEVELOPER_CREATOR_REQUIRED';
  end if;
  v_role := private.ai_actor_role();

  select * into v_policy
  from public.ai_policies p
  where p.status = 'active'
    and p.app_surface in (p_app_surface, 'global')
    and p.principal_role in (v_role, 'all')
    and p.tool_name in (coalesce(nullif(trim(p_tool_name), ''), '*'), '*')
  order by
    case when p.app_surface = p_app_surface then 0 else 1 end,
    case when p.principal_role = v_role then 0 else 1 end,
    case when p.tool_name = coalesce(nullif(trim(p_tool_name), ''), '*') then 0 else 1 end,
    p.version desc,
    p.created_at desc
  limit 1;

  if not found then
    return jsonb_build_object('policy_key', 'implicit-deny', 'app_surface', p_app_surface, 'principal_role', v_role, 'tool_name', coalesce(nullif(trim(p_tool_name), ''), '*'), 'version', null, 'status', 'implicit_deny', 'rules', jsonb_build_object('allowed_action_classes', jsonb_build_array('read'), 'max_tool_calls', 0, 'provider_calls_enabled', false));
  end if;

  return jsonb_build_object(
    'policy_id', v_policy.id,
    'policy_key', v_policy.policy_key,
    'app_surface', v_policy.app_surface,
    'principal_role', v_policy.principal_role,
    'tool_name', v_policy.tool_name,
    'version', v_policy.version,
    'status', v_policy.status,
    'rules', v_policy.rules,
    'effective_at', v_policy.effective_at,
    'source', v_policy.source
  );
end;
$$;
revoke all on function private.ai_get_effective_policy(text, text) from public, anon, authenticated;
grant execute on function private.ai_get_effective_policy(text, text) to authenticated, service_role;

create or replace function public.ai_get_effective_policy(
  p_app_surface text,
  p_tool_name text default '*'
)
returns jsonb language sql security invoker set search_path = public, pg_catalog
as $$ select private.ai_get_effective_policy(p_app_surface, p_tool_name); $$;
revoke all on function public.ai_get_effective_policy(text, text) from public, anon;
grant execute on function public.ai_get_effective_policy(text, text) to authenticated;
