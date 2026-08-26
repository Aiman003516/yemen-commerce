begin;

create or replace function private.ai_check_external_consent(p_client_id text, p_redirect_uri text)
returns jsonb language plpgsql security definer
set search_path = public, private, pg_catalog
as $$
declare v_actor uuid := (select auth.uid()); v_consent public.ai_external_consents%rowtype; v_client public.ai_external_clients%rowtype;
begin
  if v_actor is null then raise exception using errcode = '28000', message = 'AUTH_REQUIRED'; end if;
  if length(trim(coalesce(p_client_id,''))) not between 3 and 120 or length(trim(coalesce(p_redirect_uri,''))) not between 10 and 500 then raise exception using errcode = 'P0001', message = 'AI_EXTERNAL_REQUEST_INVALID'; end if;
  select * into v_client from public.ai_external_clients where client_id = trim(p_client_id) and status = 'active';
  if not found or v_client.redirect_uri <> trim(p_redirect_uri) then raise exception using errcode = 'P0001', message = 'AI_EXTERNAL_REDIRECT_MISMATCH'; end if;
  select * into v_consent from public.ai_external_consents where client_id = v_client.client_id and user_id = v_actor and redirect_uri = v_client.redirect_uri and status = 'granted' and 'ai.read' = any(scopes) limit 1;
  if not found then raise exception using errcode = '42501', message = 'AI_EXTERNAL_CONSENT_REQUIRED'; end if;
  return jsonb_build_object('consent_id', v_consent.id, 'client_id', v_client.client_id, 'user_id', v_actor, 'scope', 'ai.read', 'status', 'granted');
end;
$$;
revoke all on function private.ai_check_external_consent(text, text) from public, anon, authenticated;
grant execute on function private.ai_check_external_consent(text, text) to authenticated, service_role;
create or replace function public.ai_check_external_consent(p_client_id text, p_redirect_uri text)
returns jsonb language sql security invoker set search_path = public, pg_catalog
as $$ select private.ai_check_external_consent(p_client_id, p_redirect_uri); $$;
revoke all on function public.ai_check_external_consent(text, text) from public, anon;
grant execute on function public.ai_check_external_consent(text, text) to authenticated;

create or replace function private.ai_list_my_workflows(p_status text default null)
returns setof jsonb language plpgsql security definer
set search_path = public, private, pg_catalog
as $$
declare v_actor uuid := (select auth.uid());
begin
  if v_actor is null then raise exception using errcode = '28000', message = 'AUTH_REQUIRED'; end if;
  if p_status is not null and p_status not in ('queued','running','waiting_approval','succeeded','failed','cancelled','expired') then raise exception using errcode = 'P0001', message = 'AI_WORKFLOW_STATUS_INVALID'; end if;
  return query select jsonb_build_object('workflow_id', w.id, 'run_id', w.run_id, 'app_surface', w.app_surface, 'scope_type', w.scope_type, 'scope_id', w.scope_id, 'workflow_key', w.workflow_key, 'status', w.status, 'attempts', w.attempts, 'max_attempts', w.max_attempts, 'next_run_at', w.next_run_at, 'last_error_code', w.last_error_code, 'created_at', w.created_at, 'completed_at', w.completed_at)
  from public.ai_workflows w where w.actor_user_id = v_actor and (p_status is null or w.status = p_status) order by w.created_at desc limit 100;
end;
$$;
revoke all on function private.ai_list_my_workflows(text) from public, anon, authenticated;
grant execute on function private.ai_list_my_workflows(text) to authenticated, service_role;
create or replace function public.ai_list_my_workflows(p_status text default null)
returns setof jsonb language sql security invoker set search_path = public, pg_catalog
as $$ select * from private.ai_list_my_workflows(p_status); $$;
revoke all on function public.ai_list_my_workflows(text) from public, anon;
grant execute on function public.ai_list_my_workflows(text) to authenticated;

commit;
