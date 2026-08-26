-- AI-3 runtime action gate: creator enable/disable decisions must be enforced by the proposal and execution paths.

create or replace function private.ai_get_action_definition(p_action_key text)
returns jsonb
language plpgsql
security definer
set search_path = public, private, pg_catalog
as $$
declare
  v_actor uuid := (select auth.uid());
  v_definition public.ai_action_definitions%rowtype;
begin
  if v_actor is null then
    raise exception using errcode = '28000', message = 'AUTH_REQUIRED';
  end if;
  if length(trim(coalesce(p_action_key, ''))) not between 3 and 80 then
    return null;
  end if;

  select * into v_definition
  from public.ai_action_definitions d
  where d.action_key = trim(p_action_key)
    and d.app_surface = 'merchant'
  limit 1;

  if not found then
    return null;
  end if;

  return jsonb_build_object(
    'action_key', v_definition.action_key,
    'app_surface', v_definition.app_surface,
    'action_class', v_definition.action_class,
    'approval_required', v_definition.approval_required,
    'enabled', v_definition.enabled
  );
end;
$$;

revoke all on function private.ai_get_action_definition(text) from public, anon, authenticated;
grant execute on function private.ai_get_action_definition(text) to authenticated, service_role;

create or replace function public.ai_get_action_definition(p_action_key text)
returns jsonb
language sql
security invoker
set search_path = public, pg_catalog
as $$
  select private.ai_get_action_definition(p_action_key);
$$;

revoke all on function public.ai_get_action_definition(text) from public, anon;
grant execute on function public.ai_get_action_definition(text) to authenticated;

insert into public.audit_events(actor_user_id, action, resource_type, resource_id, metadata)
select null, 'ai.action_runtime_gate_enabled', 'ai_action_definitions', 'system', jsonb_build_object('version', 'ai3-runtime-gate')
where not exists (
  select 1 from public.audit_events
  where action = 'ai.action_runtime_gate_enabled'
    and resource_id = 'system'
);

commit;
