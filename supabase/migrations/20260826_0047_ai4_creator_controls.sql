begin;

create table if not exists public.ai_platform_settings_versions (
  id uuid primary key default gen_random_uuid(),
  version integer not null,
  status text not null default 'active' check (status in ('draft','active','retired')),
  model text,
  provider_enabled boolean not null default false,
  background_enabled boolean not null default false,
  knowledge_enabled boolean not null default false,
  external_agent_enabled boolean not null default false,
  max_tool_calls integer not null default 8 check (max_tool_calls between 0 and 20),
  max_workflow_attempts integer not null default 3 check (max_workflow_attempts between 0 and 10),
  reason text,
  created_by_user_id uuid references auth.users(id),
  created_at timestamptz not null default now(),
  unique(version)
);

alter table public.ai_platform_settings_versions enable row level security;
revoke all on public.ai_platform_settings_versions from anon, authenticated;
grant select on public.ai_platform_settings_versions to authenticated;
drop policy if exists ai_platform_settings_creator_select on public.ai_platform_settings_versions;
create policy ai_platform_settings_creator_select
on public.ai_platform_settings_versions for select to authenticated
using (private.current_user_is_creator());
create index if not exists ai_platform_settings_status_version_idx on public.ai_platform_settings_versions(status, version desc);

insert into public.ai_platform_settings_versions(version, status, model, provider_enabled, background_enabled, knowledge_enabled, external_agent_enabled, reason)
values (1, 'active', null, false, false, false, false, 'Conservative AI-4 system default')
on conflict (version) do nothing;

create or replace function private.ai_get_platform_settings()
returns jsonb language plpgsql security definer
set search_path = public, private, pg_catalog
as $$
declare v_setting public.ai_platform_settings_versions%rowtype;
begin
  if (select auth.uid()) is null then raise exception using errcode = '28000', message = 'AUTH_REQUIRED'; end if;
  if not private.current_user_is_creator() then raise exception using errcode = '42501', message = 'AI_DEVELOPER_CREATOR_REQUIRED'; end if;
  select * into v_setting from public.ai_platform_settings_versions where status = 'active' order by version desc limit 1;
  return jsonb_build_object('version', v_setting.version, 'status', v_setting.status, 'model', v_setting.model, 'provider_enabled', v_setting.provider_enabled, 'background_enabled', v_setting.background_enabled, 'knowledge_enabled', v_setting.knowledge_enabled, 'external_agent_enabled', v_setting.external_agent_enabled, 'max_tool_calls', v_setting.max_tool_calls, 'max_workflow_attempts', v_setting.max_workflow_attempts, 'created_at', v_setting.created_at);
end;
$$;
revoke all on function private.ai_get_platform_settings() from public, anon, authenticated;
grant execute on function private.ai_get_platform_settings() to authenticated, service_role;
create or replace function public.ai_get_platform_settings()
returns jsonb language sql security invoker set search_path = public, pg_catalog
as $$ select private.ai_get_platform_settings(); $$;
revoke all on function public.ai_get_platform_settings() from public, anon;
grant execute on function public.ai_get_platform_settings() to authenticated;

create or replace function private.ai_publish_platform_settings(
  p_model text default null,
  p_provider_enabled boolean default false,
  p_background_enabled boolean default false,
  p_knowledge_enabled boolean default false,
  p_external_agent_enabled boolean default false,
  p_max_tool_calls integer default 8,
  p_max_workflow_attempts integer default 3,
  p_reason text default null
)
returns jsonb language plpgsql security definer
set search_path = public, private, pg_catalog
as $$
declare v_actor uuid := (select auth.uid()); v_next integer;
begin
  if v_actor is null then raise exception using errcode = '28000', message = 'AUTH_REQUIRED'; end if;
  if not private.current_user_is_creator() then raise exception using errcode = '42501', message = 'AI_DEVELOPER_CREATOR_REQUIRED'; end if;
  if length(trim(coalesce(p_reason, ''))) < 3 then raise exception using errcode = 'P0001', message = 'AI_REASON_REQUIRED'; end if;
  if p_model is not null and (length(trim(p_model)) < 3 or length(trim(p_model)) > 120) then raise exception using errcode = 'P0001', message = 'AI_MODEL_INVALID'; end if;
  if p_max_tool_calls < 0 or p_max_tool_calls > 20 or p_max_workflow_attempts < 0 or p_max_workflow_attempts > 10 then raise exception using errcode = 'P0001', message = 'AI_BUDGET_INVALID'; end if;
  select coalesce(max(version), 0) + 1 into v_next from public.ai_platform_settings_versions;
  update public.ai_platform_settings_versions set status = 'retired' where status = 'active';
  insert into public.ai_platform_settings_versions(version, status, model, provider_enabled, background_enabled, knowledge_enabled, external_agent_enabled, max_tool_calls, max_workflow_attempts, reason, created_by_user_id)
  values (v_next, 'active', nullif(trim(p_model), ''), coalesce(p_provider_enabled, false), coalesce(p_background_enabled, false), coalesce(p_knowledge_enabled, false), coalesce(p_external_agent_enabled, false), p_max_tool_calls, p_max_workflow_attempts, trim(p_reason), v_actor);
  insert into public.audit_events(actor_user_id, action, resource_type, resource_id, metadata)
  values (v_actor, 'ai.platform_settings_published', 'ai_platform_settings_version', v_next::text, jsonb_build_object('version', v_next, 'provider_enabled', p_provider_enabled, 'background_enabled', p_background_enabled, 'knowledge_enabled', p_knowledge_enabled, 'external_agent_enabled', p_external_agent_enabled, 'reason', trim(p_reason)));
  return jsonb_build_object('version', v_next, 'status', 'active');
end;
$$;
revoke all on function private.ai_publish_platform_settings(text, boolean, boolean, boolean, boolean, integer, integer, text) from public, anon, authenticated;
grant execute on function private.ai_publish_platform_settings(text, boolean, boolean, boolean, boolean, integer, integer, text) to authenticated, service_role;
create or replace function public.ai_publish_platform_settings(p_model text default null, p_provider_enabled boolean default false, p_background_enabled boolean default false, p_knowledge_enabled boolean default false, p_external_agent_enabled boolean default false, p_max_tool_calls integer default 8, p_max_workflow_attempts integer default 3, p_reason text default null)
returns jsonb language sql security invoker set search_path = public, pg_catalog
as $$ select private.ai_publish_platform_settings(p_model, p_provider_enabled, p_background_enabled, p_knowledge_enabled, p_external_agent_enabled, p_max_tool_calls, p_max_workflow_attempts, p_reason); $$;
revoke all on function public.ai_publish_platform_settings(text, boolean, boolean, boolean, boolean, integer, integer, text) from public, anon;
grant execute on function public.ai_publish_platform_settings(text, boolean, boolean, boolean, boolean, integer, integer, text) to authenticated;

create or replace function private.ai_set_action_enabled(p_action_key text, p_enabled boolean, p_reason text)
returns jsonb language plpgsql security definer
set search_path = public, private, pg_catalog
as $$
declare v_actor uuid := (select auth.uid()); v_action public.ai_action_definitions%rowtype;
begin
  if v_actor is null then raise exception using errcode = '28000', message = 'AUTH_REQUIRED'; end if;
  if not private.current_user_is_creator() then raise exception using errcode = '42501', message = 'AI_DEVELOPER_CREATOR_REQUIRED'; end if;
  if length(trim(coalesce(p_reason, ''))) < 3 then raise exception using errcode = 'P0001', message = 'AI_REASON_REQUIRED'; end if;
  update public.ai_action_definitions set enabled = coalesce(p_enabled, false) where action_key = trim(p_action_key) returning * into v_action;
  if not found then raise exception using errcode = 'P0001', message = 'AI_ACTION_NOT_FOUND'; end if;
  insert into public.audit_events(actor_user_id, action, resource_type, resource_id, metadata)
  values (v_actor, 'ai.action_enabled_changed', 'ai_action_definition', v_action.action_key, jsonb_build_object('enabled', v_action.enabled, 'reason', trim(p_reason)));
  return jsonb_build_object('action_key', v_action.action_key, 'enabled', v_action.enabled);
end;
$$;
revoke all on function private.ai_set_action_enabled(text, boolean, text) from public, anon, authenticated;
grant execute on function private.ai_set_action_enabled(text, boolean, text) to authenticated, service_role;
create or replace function public.ai_set_action_enabled(p_action_key text, p_enabled boolean, p_reason text)
returns jsonb language sql security invoker set search_path = public, pg_catalog
as $$ select private.ai_set_action_enabled(p_action_key, p_enabled, p_reason); $$;
revoke all on function public.ai_set_action_enabled(text, boolean, text) from public, anon;
grant execute on function public.ai_set_action_enabled(text, boolean, text) to authenticated;

commit;
