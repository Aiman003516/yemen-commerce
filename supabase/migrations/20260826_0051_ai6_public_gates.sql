begin;

create or replace function private.ai_external_agent_gate()
returns boolean language sql security definer
set search_path = public, private, pg_catalog
as $$
  select coalesce((select external_agent_enabled from public.ai_platform_settings_versions where status = 'active' order by version desc limit 1), false);
$$;
revoke all on function private.ai_external_agent_gate() from public, anon, authenticated;
grant execute on function private.ai_external_agent_gate() to authenticated, service_role;
create or replace function public.ai_external_agent_gate()
returns boolean language sql security invoker set search_path = public, pg_catalog
as $$ select private.ai_external_agent_gate(); $$;
revoke all on function public.ai_external_agent_gate() from public, anon;
grant execute on function public.ai_external_agent_gate() to authenticated;

create or replace function private.ai_background_gate()
returns boolean language sql security definer
set search_path = public, private, pg_catalog
as $$
  select coalesce((select background_enabled from public.ai_platform_settings_versions where status = 'active' order by version desc limit 1), false);
$$;
revoke all on function private.ai_background_gate() from public, anon, authenticated;
grant execute on function private.ai_background_gate() to authenticated, service_role;
create or replace function public.ai_background_gate()
returns boolean language sql security invoker set search_path = public, pg_catalog
as $$ select private.ai_background_gate(); $$;
revoke all on function public.ai_background_gate() from public, anon;
grant execute on function public.ai_background_gate() to authenticated;

commit;
