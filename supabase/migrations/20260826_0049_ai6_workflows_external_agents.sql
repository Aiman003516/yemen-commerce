begin;

create table if not exists public.ai_workflows (
  id uuid primary key default gen_random_uuid(),
  run_id uuid references public.ai_runs(id),
  actor_user_id uuid not null references auth.users(id),
  app_surface text not null check (app_surface in ('customer','merchant','developer')),
  scope_type text not null check (scope_type in ('customer','shop','market','global')),
  scope_id uuid,
  workflow_key text not null check (length(trim(workflow_key)) between 3 and 100),
  status text not null default 'queued' check (status in ('queued','running','waiting_approval','succeeded','failed','cancelled','expired')),
  input_hash text not null check (length(trim(input_hash)) between 16 and 128),
  payload_redacted jsonb not null default '{}'::jsonb check (jsonb_typeof(payload_redacted) = 'object'),
  idempotency_key text not null check (length(trim(idempotency_key)) between 8 and 200),
  attempts integer not null default 0 check (attempts between 0 and 10),
  max_attempts integer not null default 3 check (max_attempts between 1 and 10),
  next_run_at timestamptz not null default now(),
  lease_token_hash text,
  leased_until timestamptz,
  last_error_code text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  completed_at timestamptz,
  unique(actor_user_id, idempotency_key),
  check ((scope_type = 'global' and scope_id is null) or (scope_type <> 'global' and scope_id is not null))
);

create table if not exists public.ai_external_clients (
  client_id text primary key check (length(trim(client_id)) between 3 and 120),
  name text not null check (length(trim(name)) between 2 and 160),
  redirect_uri text not null check (length(trim(redirect_uri)) between 10 and 500),
  status text not null default 'active' check (status in ('active','revoked')),
  created_by_user_id uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  revoked_at timestamptz
);

create table if not exists public.ai_external_consents (
  id uuid primary key default gen_random_uuid(),
  client_id text not null references public.ai_external_clients(client_id),
  user_id uuid not null references auth.users(id),
  redirect_uri text not null check (length(trim(redirect_uri)) between 10 and 500),
  scopes text[] not null check (cardinality(scopes) between 1 and 2),
  status text not null default 'granted' check (status in ('granted','revoked')),
  granted_at timestamptz not null default now(),
  revoked_at timestamptz,
  unique(client_id, user_id, redirect_uri)
);

alter table public.ai_workflows enable row level security;
alter table public.ai_external_clients enable row level security;
alter table public.ai_external_consents enable row level security;
revoke all on public.ai_workflows, public.ai_external_clients, public.ai_external_consents from anon, authenticated;
grant select on public.ai_workflows, public.ai_external_consents to authenticated;
drop policy if exists ai_workflows_actor_select on public.ai_workflows;
create policy ai_workflows_actor_select on public.ai_workflows for select to authenticated using (actor_user_id = auth.uid() or private.current_user_is_creator());
drop policy if exists ai_external_consents_owner_select on public.ai_external_consents;
create policy ai_external_consents_owner_select on public.ai_external_consents for select to authenticated using (user_id = auth.uid() or private.current_user_is_creator());
drop policy if exists ai_external_clients_creator_select on public.ai_external_clients;
create policy ai_external_clients_creator_select on public.ai_external_clients for select to authenticated using (private.current_user_is_creator());

create index if not exists ai_workflows_actor_status_idx on public.ai_workflows(actor_user_id, status, created_at desc);
create index if not exists ai_workflows_claim_idx on public.ai_workflows(status, next_run_at, attempts, leased_until);
create index if not exists ai_workflows_run_idx on public.ai_workflows(run_id);
create index if not exists ai_workflows_created_by_idx on public.ai_workflows(actor_user_id);
create index if not exists ai_external_clients_created_by_idx on public.ai_external_clients(created_by_user_id);
create index if not exists ai_external_consents_user_status_idx on public.ai_external_consents(user_id, status, client_id);
create index if not exists ai_external_consents_client_status_idx on public.ai_external_consents(client_id, status, user_id);

create or replace function private.ai_enqueue_workflow(p_app_surface text, p_scope_type text, p_scope_id uuid, p_workflow_key text, p_input_hash text, p_payload_redacted jsonb, p_idempotency_key text, p_max_attempts integer default 3)
returns jsonb language plpgsql security definer
set search_path = public, private, pg_catalog
as $$
declare v_actor uuid := (select auth.uid()); v_workflow public.ai_workflows%rowtype; v_policy jsonb; v_max integer;
begin
  if v_actor is null then raise exception using errcode = '28000', message = 'AUTH_REQUIRED'; end if;
  if p_app_surface not in ('customer','merchant','developer') or p_scope_type not in ('customer','shop','market','global') or ((p_scope_type = 'global') <> (p_scope_id is null)) then raise exception using errcode = 'P0001', message = 'AI_SCOPE_INVALID'; end if;
  if p_app_surface = 'merchant' and (p_scope_type <> 'shop' or not exists (select 1 from shops s join merchants m on m.id = s.merchant_id where s.id = p_scope_id and m.owner_user_id = v_actor)) then raise exception using errcode = '42501', message = 'AI_SHOP_SCOPE_FORBIDDEN'; end if;
  if p_app_surface = 'developer' and (p_scope_type <> 'global' or not private.current_user_is_creator()) then raise exception using errcode = '42501', message = 'AI_DEVELOPER_CREATOR_REQUIRED'; end if;
  if length(trim(coalesce(p_workflow_key,''))) not between 3 and 100 or length(trim(coalesce(p_input_hash,''))) < 16 or length(trim(coalesce(p_idempotency_key,''))) not between 8 and 200 or jsonb_typeof(coalesce(p_payload_redacted, '{}'::jsonb)) <> 'object' or octet_length(coalesce(p_payload_redacted, '{}'::jsonb)::text) > 4000 then raise exception using errcode = 'P0001', message = 'AI_WORKFLOW_INVALID'; end if;
  if p_max_attempts < 1 or p_max_attempts > 10 then raise exception using errcode = 'P0001', message = 'AI_WORKFLOW_INVALID'; end if;
  v_policy := private.ai_get_effective_policy(p_app_surface, '*');
  if coalesce((v_policy->'rules'->>'background_enabled')::boolean, false) is not true then raise exception using errcode = 'P0001', message = 'AI_BACKGROUND_DISABLED'; end if;
  insert into public.ai_workflows(actor_user_id, app_surface, scope_type, scope_id, workflow_key, input_hash, payload_redacted, idempotency_key, max_attempts)
  values(v_actor, p_app_surface, p_scope_type, p_scope_id, trim(p_workflow_key), trim(p_input_hash), p_payload_redacted, trim(p_idempotency_key), p_max_attempts)
  on conflict (actor_user_id, idempotency_key) do update set updated_at = now()
  returning * into v_workflow;
  insert into public.audit_events(actor_user_id, action, resource_type, resource_id, metadata)
  values(v_actor, 'ai.workflow_enqueued', 'ai_workflow', v_workflow.id::text, jsonb_build_object('workflow_key', v_workflow.workflow_key, 'scope_type', v_workflow.scope_type, 'scope_id', v_workflow.scope_id, 'idempotency_key', v_workflow.idempotency_key));
  return jsonb_build_object('workflow_id', v_workflow.id, 'status', v_workflow.status, 'idempotent', v_workflow.created_at < now() - interval '1 second');
end;
$$;
revoke all on function private.ai_enqueue_workflow(text, text, uuid, text, text, jsonb, text, integer) from public, anon, authenticated;
grant execute on function private.ai_enqueue_workflow(text, text, uuid, text, text, jsonb, text, integer) to authenticated, service_role;
create or replace function public.ai_enqueue_workflow(p_app_surface text, p_scope_type text, p_scope_id uuid, p_workflow_key text, p_input_hash text, p_payload_redacted jsonb, p_idempotency_key text, p_max_attempts integer default 3)
returns jsonb language sql security invoker set search_path = public, pg_catalog
as $$ select private.ai_enqueue_workflow(p_app_surface, p_scope_type, p_scope_id, p_workflow_key, p_input_hash, p_payload_redacted, p_idempotency_key, p_max_attempts); $$;
revoke all on function public.ai_enqueue_workflow(text, text, uuid, text, text, jsonb, text, integer) from public, anon;
grant execute on function public.ai_enqueue_workflow(text, text, uuid, text, text, jsonb, text, integer) to authenticated;

create or replace function private.ai_claim_workflow(p_worker_id text, p_lease_seconds integer default 120)
returns jsonb language plpgsql security definer
set search_path = public, private, pg_catalog
as $$
declare v_workflow public.ai_workflows%rowtype; v_hash text;
begin
  if current_user <> 'service_role' and current_user <> 'postgres' then raise exception using errcode = '42501', message = 'AI_WORKER_FORBIDDEN'; end if;
  if length(trim(coalesce(p_worker_id,''))) not between 8 and 120 or p_lease_seconds < 30 or p_lease_seconds > 900 then raise exception using errcode = 'P0001', message = 'AI_WORKER_INVALID'; end if;
  select * into v_workflow from public.ai_workflows where status = 'queued' and next_run_at <= now() and attempts < max_attempts and (leased_until is null or leased_until < now()) order by next_run_at, created_at for update skip locked limit 1;
  if not found then return null; end if;
  v_hash := encode(digest(trim(p_worker_id) || ':' || v_workflow.id::text || ':' || clock_timestamp()::text, 'sha256'), 'hex');
  update public.ai_workflows set status = 'running', attempts = attempts + 1, lease_token_hash = v_hash, leased_until = now() + make_interval(secs => p_lease_seconds), updated_at = now() where id = v_workflow.id returning * into v_workflow;
  return jsonb_build_object('workflow_id', v_workflow.id, 'run_id', v_workflow.run_id, 'workflow_key', v_workflow.workflow_key, 'app_surface', v_workflow.app_surface, 'scope_type', v_workflow.scope_type, 'scope_id', v_workflow.scope_id, 'payload_redacted', v_workflow.payload_redacted, 'attempts', v_workflow.attempts, 'max_attempts', v_workflow.max_attempts, 'lease_token_hash', v_hash);
end;
$$;
revoke all on function private.ai_claim_workflow(text, integer) from public, anon, authenticated;
grant execute on function private.ai_claim_workflow(text, integer) to service_role;

create or replace function private.ai_complete_workflow(p_workflow_id uuid, p_lease_token_hash text, p_status text, p_error_code text default null, p_next_run_at timestamptz default null)
returns jsonb language plpgsql security definer
set search_path = public, private, pg_catalog
as $$
declare v_workflow public.ai_workflows%rowtype;
begin
  if current_user <> 'service_role' and current_user <> 'postgres' then raise exception using errcode = '42501', message = 'AI_WORKER_FORBIDDEN'; end if;
  if p_status not in ('queued','succeeded','failed','cancelled','expired') then raise exception using errcode = 'P0001', message = 'AI_WORKFLOW_STATUS_INVALID'; end if;
  update public.ai_workflows set status = p_status, last_error_code = nullif(trim(p_error_code), ''), next_run_at = coalesce(p_next_run_at, next_run_at), leased_until = null, lease_token_hash = null, updated_at = now(), completed_at = case when p_status in ('succeeded','failed','cancelled','expired') then now() else null end where id = p_workflow_id and lease_token_hash = trim(p_lease_token_hash) returning * into v_workflow;
  if not found then raise exception using errcode = '42501', message = 'AI_WORKFLOW_LEASE_INVALID'; end if;
  return jsonb_build_object('workflow_id', v_workflow.id, 'status', v_workflow.status, 'attempts', v_workflow.attempts, 'last_error_code', v_workflow.last_error_code);
end;
$$;
revoke all on function private.ai_complete_workflow(uuid, text, text, text, timestamptz) from public, anon, authenticated;
grant execute on function private.ai_complete_workflow(uuid, text, text, text, timestamptz) to service_role;

create or replace function private.ai_register_external_client(p_client_id text, p_name text, p_redirect_uri text, p_reason text)
returns jsonb language plpgsql security definer
set search_path = public, private, pg_catalog
as $$
declare v_actor uuid := (select auth.uid()); v_client public.ai_external_clients%rowtype;
begin
  if v_actor is null then raise exception using errcode = '28000', message = 'AUTH_REQUIRED'; end if;
  if not private.current_user_is_creator() then raise exception using errcode = '42501', message = 'AI_DEVELOPER_CREATOR_REQUIRED'; end if;
  if length(trim(coalesce(p_reason,''))) < 3 or p_redirect_uri !~ '^https://[^#?[:space:]]+(/[^#?[:space:]]*)?$' then raise exception using errcode = 'P0001', message = 'AI_EXTERNAL_CLIENT_INVALID'; end if;
  insert into public.ai_external_clients(client_id, name, redirect_uri, created_by_user_id)
  values(trim(p_client_id), trim(p_name), trim(p_redirect_uri), v_actor)
  on conflict (client_id) do update set name = excluded.name, redirect_uri = excluded.redirect_uri, status = 'active', revoked_at = null
  returning * into v_client;
  insert into public.audit_events(actor_user_id, action, resource_type, resource_id, metadata) values(v_actor, 'ai.external_client_registered', 'ai_external_client', trim(p_client_id), jsonb_build_object('redirect_uri', trim(p_redirect_uri), 'reason', trim(p_reason)));
  return jsonb_build_object('client_id', trim(p_client_id), 'status', 'active', 'redirect_uri', trim(p_redirect_uri));
end;
$$;
revoke all on function private.ai_register_external_client(text, text, text, text) from public, anon, authenticated;
grant execute on function private.ai_register_external_client(text, text, text, text) to authenticated, service_role;
create or replace function public.ai_register_external_client(p_client_id text, p_name text, p_redirect_uri text, p_reason text)
returns jsonb language sql security invoker set search_path = public, pg_catalog
as $$ select private.ai_register_external_client(p_client_id, p_name, p_redirect_uri, p_reason); $$;
revoke all on function public.ai_register_external_client(text, text, text, text) from public, anon;
grant execute on function public.ai_register_external_client(text, text, text, text) to authenticated;

create or replace function private.ai_revoke_external_client(p_client_id text, p_reason text)
returns jsonb language plpgsql security definer
set search_path = public, private, pg_catalog
as $$
declare v_actor uuid := (select auth.uid());
begin
  if v_actor is null then raise exception using errcode = '28000', message = 'AUTH_REQUIRED'; end if;
  if not private.current_user_is_creator() then raise exception using errcode = '42501', message = 'AI_DEVELOPER_CREATOR_REQUIRED'; end if;
  if length(trim(coalesce(p_reason,''))) < 3 then raise exception using errcode = 'P0001', message = 'AI_REASON_REQUIRED'; end if;
  update public.ai_external_clients set status = 'revoked', revoked_at = now() where client_id = trim(p_client_id) returning client_id;
  if not found then raise exception using errcode = 'P0001', message = 'AI_EXTERNAL_CLIENT_NOT_FOUND'; end if;
  update public.ai_external_consents set status = 'revoked', revoked_at = now() where client_id = trim(p_client_id) and status = 'granted';
  insert into public.audit_events(actor_user_id, action, resource_type, resource_id, metadata) values(v_actor, 'ai.external_client_revoked', 'ai_external_client', trim(p_client_id), jsonb_build_object('reason', trim(p_reason)));
  return jsonb_build_object('client_id', trim(p_client_id), 'status', 'revoked');
end;
$$;
revoke all on function private.ai_revoke_external_client(text, text) from public, anon, authenticated;
grant execute on function private.ai_revoke_external_client(text, text) to authenticated, service_role;
create or replace function public.ai_revoke_external_client(p_client_id text, p_reason text)
returns jsonb language sql security invoker set search_path = public, pg_catalog
as $$ select private.ai_revoke_external_client(p_client_id, p_reason); $$;
revoke all on function public.ai_revoke_external_client(text, text) from public, anon;
grant execute on function public.ai_revoke_external_client(text, text) to authenticated;

create or replace function private.ai_grant_external_consent(p_client_id text, p_redirect_uri text, p_scope text)
returns jsonb language plpgsql security definer
set search_path = public, private, pg_catalog
as $$
declare v_actor uuid := (select auth.uid()); v_client public.ai_external_clients%rowtype; v_consent public.ai_external_consents%rowtype;
begin
  if v_actor is null then raise exception using errcode = '28000', message = 'AUTH_REQUIRED'; end if;
  if p_scope <> 'ai.read' then raise exception using errcode = 'P0001', message = 'AI_EXTERNAL_SCOPE_INVALID'; end if;
  select * into v_client from public.ai_external_clients where client_id = trim(p_client_id) and status = 'active';
  if not found or v_client.redirect_uri <> trim(p_redirect_uri) then raise exception using errcode = 'P0001', message = 'AI_EXTERNAL_REDIRECT_MISMATCH'; end if;
  insert into public.ai_external_consents(client_id, user_id, redirect_uri, scopes) values(v_client.client_id, v_actor, v_client.redirect_uri, array[p_scope])
  on conflict (client_id, user_id, redirect_uri) do update set scopes = array[p_scope], status = 'granted', granted_at = now(), revoked_at = null returning * into v_consent;
  insert into public.audit_events(actor_user_id, action, resource_type, resource_id, metadata) values(v_actor, 'ai.external_consent_granted', 'ai_external_consent', v_consent.id::text, jsonb_build_object('client_id', v_client.client_id, 'scope', p_scope, 'redirect_uri', v_client.redirect_uri));
  return jsonb_build_object('consent_id', v_consent.id, 'client_id', v_client.client_id, 'scope', p_scope, 'status', v_consent.status);
end;
$$;
revoke all on function private.ai_grant_external_consent(text, text, text) from public, anon, authenticated;
grant execute on function private.ai_grant_external_consent(text, text, text) to authenticated, service_role;
create or replace function public.ai_grant_external_consent(p_client_id text, p_redirect_uri text, p_scope text)
returns jsonb language sql security invoker set search_path = public, pg_catalog
as $$ select private.ai_grant_external_consent(p_client_id, p_redirect_uri, p_scope); $$;
revoke all on function public.ai_grant_external_consent(text, text, text) from public, anon;
grant execute on function public.ai_grant_external_consent(text, text, text) to authenticated;

create or replace function private.ai_revoke_external_consent(p_consent_id uuid)
returns jsonb language plpgsql security definer
set search_path = public, private, pg_catalog
as $$
declare v_actor uuid := (select auth.uid()); v_id uuid;
begin
  if v_actor is null then raise exception using errcode = '28000', message = 'AUTH_REQUIRED'; end if;
  update public.ai_external_consents set status = 'revoked', revoked_at = now() where id = p_consent_id and user_id = v_actor and status = 'granted' returning id into v_id;
  if not found then raise exception using errcode = '42501', message = 'AI_EXTERNAL_CONSENT_FORBIDDEN'; end if;
  insert into public.audit_events(actor_user_id, action, resource_type, resource_id, metadata) values(v_actor, 'ai.external_consent_revoked', 'ai_external_consent', v_id::text, '{}'::jsonb);
  return jsonb_build_object('consent_id', v_id, 'status', 'revoked');
end;
$$;
revoke all on function private.ai_revoke_external_consent(uuid) from public, anon, authenticated;
grant execute on function private.ai_revoke_external_consent(uuid) to authenticated, service_role;
create or replace function public.ai_revoke_external_consent(p_consent_id uuid)
returns jsonb language sql security invoker set search_path = public, pg_catalog
as $$ select private.ai_revoke_external_consent(p_consent_id); $$;
revoke all on function public.ai_revoke_external_consent(uuid) from public, anon;
grant execute on function public.ai_revoke_external_consent(uuid) to authenticated;

commit;
