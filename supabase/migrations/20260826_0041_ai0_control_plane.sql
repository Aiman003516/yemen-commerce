-- AI-0 control plane: run state, typed tool-call lifecycle, resumable approvals,
-- and versioned policy records. This migration does not call an AI provider and
-- does not grant the model direct table or service-role access.

create table if not exists public.ai_runs (
  id uuid primary key default gen_random_uuid(),
  actor_user_id uuid not null references public.profiles(id) on delete restrict,
  app_surface text not null check (app_surface in ('customer', 'merchant', 'developer')),
  actor_role text not null check (actor_role in ('customer', 'merchant', 'creator')),
  scope_type text not null check (scope_type in ('customer', 'shop', 'market', 'global')),
  scope_id uuid,
  intent_key text not null check (length(trim(intent_key)) between 1 and 120),
  request_hash text not null check (length(trim(request_hash)) between 16 and 256),
  requested_locale text not null default 'ar' check (requested_locale in ('ar', 'en')),
  policy_key text not null default 'default',
  policy_version integer check (policy_version is null or policy_version > 0),
  status text not null default 'queued' check (status in ('queued', 'running', 'waiting_approval', 'succeeded', 'failed', 'cancelled', 'expired')),
  max_tool_calls integer not null default 12 check (max_tool_calls between 0 and 50),
  tool_call_count integer not null default 0 check (tool_call_count between 0 and 50),
  idempotency_key text check (idempotency_key is null or length(trim(idempotency_key)) between 1 and 200),
  metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata) = 'object'),
  created_at timestamptz not null default now(),
  started_at timestamptz,
  completed_at timestamptz,
  constraint ai_runs_scope_consistency check (
    (scope_type = 'global' and scope_id is null)
    or (scope_type <> 'global' and scope_id is not null)
  ),
  constraint ai_runs_timestamps_consistent check (
    completed_at is null or completed_at >= created_at
  )
);

create unique index if not exists ai_runs_actor_idempotency_uidx
  on public.ai_runs(actor_user_id, idempotency_key)
  where idempotency_key is not null;
create index if not exists ai_runs_actor_created_idx
  on public.ai_runs(actor_user_id, created_at desc, id desc);
create index if not exists ai_runs_scope_created_idx
  on public.ai_runs(app_surface, scope_type, scope_id, created_at desc, id desc);
create index if not exists ai_runs_status_created_idx
  on public.ai_runs(status, created_at desc);

create table if not exists public.ai_tool_calls (
  id uuid primary key default gen_random_uuid(),
  run_id uuid not null references public.ai_runs(id) on delete restrict,
  sequence_no integer not null check (sequence_no between 1 and 50),
  tool_name text not null check (length(trim(tool_name)) between 1 and 160),
  tool_version text not null default '1' check (length(trim(tool_version)) between 1 and 40),
  action_class text not null check (action_class in ('read', 'draft', 'reversible_write', 'high_impact_write', 'external_side_effect', 'sensitive_read')),
  status text not null default 'proposed' check (status in ('proposed', 'blocked', 'awaiting_approval', 'approved', 'running', 'succeeded', 'failed', 'rejected', 'expired')),
  arguments_hash text not null check (length(trim(arguments_hash)) between 16 and 256),
  arguments_redacted jsonb not null default '{}'::jsonb check (jsonb_typeof(arguments_redacted) = 'object'),
  required_capability text check (required_capability is null or length(trim(required_capability)) between 1 and 120),
  approval_required boolean not null default false,
  policy_decision text not null check (policy_decision in ('allow', 'deny', 'needs_approval')),
  idempotency_key text check (idempotency_key is null or length(trim(idempotency_key)) between 1 and 200),
  result_summary jsonb check (result_summary is null or jsonb_typeof(result_summary) = 'object'),
  error_code text check (error_code is null or length(trim(error_code)) between 1 and 160),
  created_at timestamptz not null default now(),
  approved_at timestamptz,
  started_at timestamptz,
  completed_at timestamptz,
  unique (run_id, sequence_no)
);

create unique index if not exists ai_tool_calls_run_idempotency_uidx
  on public.ai_tool_calls(run_id, idempotency_key)
  where idempotency_key is not null;
create index if not exists ai_tool_calls_run_sequence_idx
  on public.ai_tool_calls(run_id, sequence_no);
create index if not exists ai_tool_calls_status_created_idx
  on public.ai_tool_calls(status, created_at desc);
create index if not exists ai_tool_calls_tool_created_idx
  on public.ai_tool_calls(tool_name, created_at desc);

create table if not exists public.ai_approvals (
  id uuid primary key default gen_random_uuid(),
  run_id uuid not null references public.ai_runs(id) on delete restrict,
  tool_call_id uuid not null references public.ai_tool_calls(id) on delete restrict,
  approver_user_id uuid not null references public.profiles(id) on delete restrict,
  tool_name text not null check (length(trim(tool_name)) between 1 and 160),
  arguments_hash text not null check (length(trim(arguments_hash)) between 16 and 256),
  approval_token_hash text not null unique check (length(trim(approval_token_hash)) between 32 and 256),
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected', 'expired', 'cancelled')),
  decision_reason text check (decision_reason is null or length(trim(decision_reason)) between 1 and 1000),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  decided_at timestamptz,
  constraint ai_approvals_expiry_after_creation check (expires_at > created_at)
);

create unique index if not exists ai_approvals_one_pending_per_tool_uidx
  on public.ai_approvals(tool_call_id)
  where status = 'pending';
create index if not exists ai_approvals_approver_status_idx
  on public.ai_approvals(approver_user_id, status, created_at desc);
create index if not exists ai_approvals_run_created_idx
  on public.ai_approvals(run_id, created_at desc);

create table if not exists public.ai_policies (
  id uuid primary key default gen_random_uuid(),
  policy_key text not null check (length(trim(policy_key)) between 1 and 120),
  app_surface text not null check (app_surface in ('global', 'customer', 'merchant', 'developer')),
  principal_role text not null default 'all' check (length(trim(principal_role)) between 1 and 80),
  tool_name text not null default '*' check (length(trim(tool_name)) between 1 and 160),
  version integer not null check (version > 0),
  status text not null default 'draft' check (status in ('draft', 'active', 'retired')),
  rules jsonb not null default '{}'::jsonb check (jsonb_typeof(rules) = 'object'),
  source text not null default 'creator' check (source in ('system', 'creator')),
  created_by_user_id uuid references public.profiles(id) on delete set null,
  reason text,
  created_at timestamptz not null default now(),
  effective_at timestamptz,
  unique (policy_key, app_surface, principal_role, tool_name, version),
  constraint ai_policies_reason_for_creator check (
    source = 'system' or (reason is not null and length(trim(reason)) between 3 and 1000)
  )
);

create index if not exists ai_policies_effective_lookup_idx
  on public.ai_policies(app_surface, principal_role, tool_name, status, version desc);
create index if not exists ai_policies_created_idx
  on public.ai_policies(created_at desc, id desc);

alter table public.ai_runs enable row level security;
alter table public.ai_tool_calls enable row level security;
alter table public.ai_approvals enable row level security;
alter table public.ai_policies enable row level security;

-- No direct client writes. AI lifecycle changes are only through private
-- SECURITY DEFINER implementations and narrow authenticated wrappers.
revoke all on public.ai_runs, public.ai_tool_calls, public.ai_approvals, public.ai_policies from public, anon, authenticated;
grant select on public.ai_runs, public.ai_tool_calls, public.ai_approvals to authenticated;

drop policy if exists ai_runs_actor_read on public.ai_runs;
create policy ai_runs_actor_read on public.ai_runs for select to authenticated
using (actor_user_id = (select auth.uid()) or private.current_user_is_creator());

drop policy if exists ai_tool_calls_actor_read on public.ai_tool_calls;
create policy ai_tool_calls_actor_read on public.ai_tool_calls for select to authenticated
using (exists (
  select 1 from public.ai_runs r
  where r.id = run_id
    and (r.actor_user_id = (select auth.uid()) or private.current_user_is_creator())
));

drop policy if exists ai_approvals_participant_read on public.ai_approvals;
create policy ai_approvals_participant_read on public.ai_approvals for select to authenticated
using (
  approver_user_id = (select auth.uid())
  or exists (
    select 1 from public.ai_runs r
    where r.id = run_id
      and (r.actor_user_id = (select auth.uid()) or private.current_user_is_creator())
  )
  or private.current_user_is_creator()
);

create or replace function private.ai_actor_role()
returns text
language sql
stable
security definer
set search_path = public, private, pg_catalog
as $$
  select case
    when private.current_user_is_creator() then 'creator'
    when exists (select 1 from public.user_roles where user_id = (select auth.uid()) and role = 'merchant') then 'merchant'
    else 'customer'
  end;
$$;
revoke all on function private.ai_actor_role() from public, anon, authenticated;
grant execute on function private.ai_actor_role() to authenticated, service_role;

create or replace function private.ai_normalize_scope(
  p_app_surface text,
  p_scope_type text,
  p_scope_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, private, pg_catalog
as $$
declare
  v_actor uuid := (select auth.uid());
  v_scope_type text := lower(trim(coalesce(p_scope_type, 'global')));
  v_actor_role text := private.ai_actor_role();
begin
  if v_actor is null then
    raise exception using errcode = '28000', message = 'AUTH_REQUIRED';
  end if;

  if p_app_surface not in ('customer', 'merchant', 'developer') then
    raise exception using errcode = 'P0001', message = 'AI_APP_SURFACE_INVALID';
  end if;

  if p_app_surface = 'customer' then
    if v_scope_type not in ('customer', 'global') or (p_scope_id is not null and p_scope_id <> v_actor) then
      raise exception using errcode = '42501', message = 'AI_CUSTOMER_SCOPE_FORBIDDEN';
    end if;
    return jsonb_build_object('actor_role', 'customer', 'scope_type', 'customer', 'scope_id', v_actor);
  end if;

  if p_app_surface = 'merchant' then
    if v_scope_type <> 'shop' or p_scope_id is null then
      raise exception using errcode = 'P0001', message = 'AI_MERCHANT_SCOPE_REQUIRED';
    end if;
    if not exists (
      select 1 from public.shops s
      where s.id = p_scope_id
        and (s.merchant_id in (select private.current_merchant_ids()) or private.is_admin())
    ) then
      raise exception using errcode = '42501', message = 'AI_SHOP_SCOPE_FORBIDDEN';
    end if;
    return jsonb_build_object('actor_role', v_actor_role, 'scope_type', 'shop', 'scope_id', p_scope_id);
  end if;

  if not private.current_user_is_creator() then
    raise exception using errcode = '42501', message = 'AI_DEVELOPER_CREATOR_REQUIRED';
  end if;
  if v_scope_type not in ('global', 'market', 'shop') then
    raise exception using errcode = 'P0001', message = 'AI_DEVELOPER_SCOPE_INVALID';
  end if;
  if v_scope_type = 'global' then
    return jsonb_build_object('actor_role', 'creator', 'scope_type', 'global', 'scope_id', null);
  end if;
  if v_scope_type = 'market' and not exists (select 1 from public.markets where id = p_scope_id) then
    raise exception using errcode = 'P0001', message = 'AI_MARKET_NOT_FOUND';
  end if;
  if v_scope_type = 'shop' and not exists (select 1 from public.shops where id = p_scope_id) then
    raise exception using errcode = 'P0001', message = 'AI_SHOP_NOT_FOUND';
  end if;
  return jsonb_build_object('actor_role', 'creator', 'scope_type', v_scope_type, 'scope_id', p_scope_id);
end;
$$;
revoke all on function private.ai_normalize_scope(text, text, uuid) from public, anon, authenticated;
grant execute on function private.ai_normalize_scope(text, text, uuid) to authenticated, service_role;

create or replace function private.ai_start_run(
  p_app_surface text,
  p_scope_type text default 'global',
  p_scope_id uuid default null,
  p_intent_key text default 'general',
  p_request_hash text default null,
  p_requested_locale text default 'ar',
  p_idempotency_key text default null,
  p_metadata jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, private, pg_catalog
as $$
declare
  v_actor uuid := (select auth.uid());
  v_scope jsonb;
  v_existing public.ai_runs%rowtype;
  v_run public.ai_runs%rowtype;
  v_policy_version integer;
  v_scope_id uuid;
  v_scope_type text;
begin
  v_scope := private.ai_normalize_scope(p_app_surface, p_scope_type, p_scope_id);
  if p_request_hash is null or length(trim(p_request_hash)) < 16 then
    raise exception using errcode = 'P0001', message = 'AI_REQUEST_HASH_REQUIRED';
  end if;
  if p_metadata is null or jsonb_typeof(p_metadata) <> 'object' then
    raise exception using errcode = 'P0001', message = 'AI_METADATA_INVALID';
  end if;
  if length(trim(coalesce(p_intent_key, ''))) = 0 or length(trim(p_intent_key)) > 120 then
    raise exception using errcode = 'P0001', message = 'AI_INTENT_INVALID';
  end if;
  if coalesce(p_requested_locale, 'ar') not in ('ar', 'en') then
    raise exception using errcode = 'P0001', message = 'AI_LOCALE_UNSUPPORTED';
  end if;

  if p_idempotency_key is not null then
    select * into v_existing
    from public.ai_runs
    where actor_user_id = v_actor and idempotency_key = trim(p_idempotency_key)
    limit 1;
    if found then
      return jsonb_build_object('run_id', v_existing.id, 'status', v_existing.status, 'idempotent', true);
    end if;
  end if;

  v_scope_type := v_scope->>'scope_type';
  v_scope_id := nullif(v_scope->>'scope_id', '')::uuid;
  select max(version) into v_policy_version
  from public.ai_policies
  where app_surface in (p_app_surface, 'global')
    and principal_role in ((v_scope->>'actor_role'), 'all')
    and status = 'active';

  insert into public.ai_runs(
    actor_user_id, app_surface, actor_role, scope_type, scope_id,
    intent_key, request_hash, requested_locale, policy_version,
    idempotency_key, metadata
  )
  values (
    v_actor, p_app_surface, v_scope->>'actor_role', v_scope_type, v_scope_id,
    trim(p_intent_key), trim(p_request_hash), coalesce(p_requested_locale, 'ar'), v_policy_version,
    nullif(trim(p_idempotency_key), ''), p_metadata
  )
  returning * into v_run;

  insert into public.audit_events(actor_user_id, action, resource_type, resource_id, metadata)
  values (
    v_actor, 'ai.run_started', 'ai_run', v_run.id::text,
    jsonb_build_object(
      'app_surface', v_run.app_surface,
      'actor_role', v_run.actor_role,
      'scope_type', v_run.scope_type,
      'scope_id', v_run.scope_id,
      'intent_key', v_run.intent_key,
      'request_hash', v_run.request_hash,
      'policy_version', v_run.policy_version
    )
  );

  return jsonb_build_object(
    'run_id', v_run.id,
    'status', v_run.status,
    'app_surface', v_run.app_surface,
    'actor_role', v_run.actor_role,
    'scope_type', v_run.scope_type,
    'scope_id', v_run.scope_id,
    'policy_version', v_run.policy_version,
    'idempotent', false
  );
end;
$$;
revoke all on function private.ai_start_run(text, text, uuid, text, text, text, text, jsonb) from public, anon, authenticated;
grant execute on function private.ai_start_run(text, text, uuid, text, text, text, text, jsonb) to authenticated, service_role;
create or replace function public.ai_start_run(
  p_app_surface text,
  p_scope_type text default 'global',
  p_scope_id uuid default null,
  p_intent_key text default 'general',
  p_request_hash text default null,
  p_requested_locale text default 'ar',
  p_idempotency_key text default null,
  p_metadata jsonb default '{}'::jsonb
)
returns jsonb language sql security invoker set search_path = public, pg_catalog
as $$ select private.ai_start_run(p_app_surface, p_scope_type, p_scope_id, p_intent_key, p_request_hash, p_requested_locale, p_idempotency_key, p_metadata); $$;
revoke all on function public.ai_start_run(text, text, uuid, text, text, text, text, jsonb) from public, anon;
grant execute on function public.ai_start_run(text, text, uuid, text, text, text, text, jsonb) to authenticated;

create or replace function private.ai_propose_tool_call(
  p_run_id uuid,
  p_sequence_no integer,
  p_tool_name text,
  p_action_class text,
  p_arguments_hash text,
  p_arguments_redacted jsonb default '{}'::jsonb,
  p_required_capability text default null,
  p_approval_required boolean default false,
  p_policy_decision text default 'allow',
  p_idempotency_key text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, private, pg_catalog
as $$
declare
  v_actor uuid := (select auth.uid());
  v_run public.ai_runs%rowtype;
  v_call public.ai_tool_calls%rowtype;
  v_forced_approval boolean := p_action_class in ('high_impact_write', 'external_side_effect', 'sensitive_read');
  v_status text;
begin
  select * into v_run from public.ai_runs where id = p_run_id and actor_user_id = v_actor for update;
  if not found then raise exception using errcode = '42501', message = 'AI_RUN_FORBIDDEN'; end if;
  if v_run.status in ('succeeded', 'failed', 'cancelled', 'expired') then
    raise exception using errcode = 'P0001', message = 'AI_RUN_TERMINAL';
  end if;
  if p_sequence_no <> v_run.tool_call_count + 1 or p_sequence_no > v_run.max_tool_calls then
    raise exception using errcode = 'P0001', message = 'AI_TOOL_CALL_LIMIT';
  end if;
  if p_action_class not in ('read', 'draft', 'reversible_write', 'high_impact_write', 'external_side_effect', 'sensitive_read') then
    raise exception using errcode = 'P0001', message = 'AI_ACTION_CLASS_INVALID';
  end if;
  if p_policy_decision not in ('allow', 'deny', 'needs_approval') then
    raise exception using errcode = 'P0001', message = 'AI_POLICY_DECISION_INVALID';
  end if;
  if p_arguments_redacted is null or jsonb_typeof(p_arguments_redacted) <> 'object' then
    raise exception using errcode = 'P0001', message = 'AI_ARGUMENTS_INVALID';
  end if;
  if p_arguments_hash is null or length(trim(p_arguments_hash)) < 16 then
    raise exception using errcode = 'P0001', message = 'AI_ARGUMENTS_HASH_REQUIRED';
  end if;

  if p_idempotency_key is not null then
    select * into v_call from public.ai_tool_calls
    where run_id = p_run_id and idempotency_key = trim(p_idempotency_key)
    limit 1;
    if found then
      return jsonb_build_object('tool_call_id', v_call.id, 'status', v_call.status, 'idempotent', true);
    end if;
  end if;

  v_status := case
    when p_policy_decision = 'deny' then 'blocked'
    when p_policy_decision = 'needs_approval' or p_approval_required or v_forced_approval then 'awaiting_approval'
    else 'proposed'
  end;

  insert into public.ai_tool_calls(
    run_id, sequence_no, tool_name, action_class, status,
    arguments_hash, arguments_redacted, required_capability,
    approval_required, policy_decision, idempotency_key
  )
  values (
    p_run_id, p_sequence_no, trim(p_tool_name), trim(p_action_class), v_status,
    trim(p_arguments_hash), p_arguments_redacted, nullif(trim(p_required_capability), ''),
    (p_approval_required or v_forced_approval), p_policy_decision, nullif(trim(p_idempotency_key), '')
  )
  returning * into v_call;

  update public.ai_runs
  set tool_call_count = tool_call_count + 1,
      status = case when v_status = 'awaiting_approval' then 'waiting_approval' else 'running' end,
      started_at = coalesce(started_at, now())
  where id = p_run_id;

  insert into public.audit_events(actor_user_id, action, resource_type, resource_id, metadata)
  values (
    v_actor, 'ai.tool_call_proposed', 'ai_tool_call', v_call.id::text,
    jsonb_build_object(
      'run_id', p_run_id,
      'sequence_no', p_sequence_no,
      'tool_name', v_call.tool_name,
      'action_class', v_call.action_class,
      'status', v_call.status,
      'approval_required', v_call.approval_required,
      'policy_decision', v_call.policy_decision,
      'arguments_hash', v_call.arguments_hash
    )
  );

  return jsonb_build_object('tool_call_id', v_call.id, 'status', v_call.status, 'approval_required', v_call.approval_required, 'idempotent', false);
end;
$$;
revoke all on function private.ai_propose_tool_call(uuid, integer, text, text, text, jsonb, text, boolean, text, text) from public, anon, authenticated;
grant execute on function private.ai_propose_tool_call(uuid, integer, text, text, text, jsonb, text, boolean, text, text) to authenticated, service_role;
create or replace function public.ai_propose_tool_call(
  p_run_id uuid,
  p_sequence_no integer,
  p_tool_name text,
  p_action_class text,
  p_arguments_hash text,
  p_arguments_redacted jsonb default '{}'::jsonb,
  p_required_capability text default null,
  p_approval_required boolean default false,
  p_policy_decision text default 'allow',
  p_idempotency_key text default null
)
returns jsonb language sql security invoker set search_path = public, pg_catalog
as $$ select private.ai_propose_tool_call(p_run_id, p_sequence_no, p_tool_name, p_action_class, p_arguments_hash, p_arguments_redacted, p_required_capability, p_approval_required, p_policy_decision, p_idempotency_key); $$;
revoke all on function public.ai_propose_tool_call(uuid, integer, text, text, text, jsonb, text, boolean, text, text) from public, anon;
grant execute on function public.ai_propose_tool_call(uuid, integer, text, text, text, jsonb, text, boolean, text, text) to authenticated;

create or replace function private.ai_request_approval(
  p_tool_call_id uuid,
  p_expires_in_seconds integer default 900
)
returns jsonb
language plpgsql
security definer
set search_path = public, private, pg_catalog
as $$
declare
  v_actor uuid := (select auth.uid());
  v_call public.ai_tool_calls%rowtype;
  v_run public.ai_runs%rowtype;
  v_approval public.ai_approvals%rowtype;
  v_expires timestamptz;
  v_token_hash text := encode(gen_random_bytes(32), 'hex');
begin
  if p_expires_in_seconds < 60 or p_expires_in_seconds > 86400 then
    raise exception using errcode = 'P0001', message = 'AI_APPROVAL_EXPIRY_INVALID';
  end if;
  select c.* into v_call
  from public.ai_tool_calls c
  join public.ai_runs r on r.id = c.run_id
  where c.id = p_tool_call_id and r.actor_user_id = v_actor
  for update;
  if not found then raise exception using errcode = '42501', message = 'AI_TOOL_CALL_FORBIDDEN'; end if;
  if not v_call.approval_required or v_call.status <> 'awaiting_approval' then
    raise exception using errcode = 'P0001', message = 'AI_APPROVAL_NOT_REQUIRED';
  end if;
  select * into v_run from public.ai_runs where id = v_call.run_id;
  v_expires := least(now() + make_interval(secs => p_expires_in_seconds), now() + interval '24 hours');
  insert into public.ai_approvals(
    run_id, tool_call_id, approver_user_id, tool_name, arguments_hash,
    approval_token_hash, expires_at
  )
  values (
    v_call.run_id, v_call.id, v_actor, v_call.tool_name, v_call.arguments_hash,
    v_token_hash, v_expires
  )
  returning * into v_approval;

  insert into public.audit_events(actor_user_id, action, resource_type, resource_id, metadata)
  values (
    v_actor, 'ai.approval_requested', 'ai_approval', v_approval.id::text,
    jsonb_build_object('run_id', v_call.run_id, 'tool_call_id', v_call.id, 'tool_name', v_call.tool_name, 'expires_at', v_expires, 'arguments_hash', v_call.arguments_hash)
  );

  return jsonb_build_object('approval_id', v_approval.id, 'run_id', v_call.run_id, 'tool_call_id', v_call.id, 'status', v_approval.status, 'expires_at', v_approval.expires_at);
end;
$$;
revoke all on function private.ai_request_approval(uuid, integer) from public, anon, authenticated;
grant execute on function private.ai_request_approval(uuid, integer) to authenticated, service_role;
create or replace function public.ai_request_approval(p_tool_call_id uuid, p_expires_in_seconds integer default 900)
returns jsonb language sql security invoker set search_path = public, pg_catalog
as $$ select private.ai_request_approval(p_tool_call_id, p_expires_in_seconds); $$;
revoke all on function public.ai_request_approval(uuid, integer) from public, anon;
grant execute on function public.ai_request_approval(uuid, integer) to authenticated;

create or replace function private.ai_decide_approval(
  p_approval_id uuid,
  p_decision text,
  p_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, private, pg_catalog
as $$
declare
  v_actor uuid := (select auth.uid());
  v_approval public.ai_approvals%rowtype;
  v_call public.ai_tool_calls%rowtype;
  v_status text;
begin
  if p_decision not in ('approved', 'rejected') then
    raise exception using errcode = 'P0001', message = 'AI_APPROVAL_DECISION_INVALID';
  end if;
  if p_decision = 'rejected' and length(trim(coalesce(p_reason, ''))) < 3 then
    raise exception using errcode = 'P0001', message = 'AI_APPROVAL_REASON_REQUIRED';
  end if;
  select * into v_approval from public.ai_approvals where id = p_approval_id and approver_user_id = v_actor for update;
  if not found then raise exception using errcode = '42501', message = 'AI_APPROVAL_FORBIDDEN'; end if;
  if v_approval.status <> 'pending' then
    raise exception using errcode = 'P0001', message = 'AI_APPROVAL_NOT_PENDING';
  end if;
  if v_approval.expires_at <= now() then
    update public.ai_approvals set status = 'expired', decided_at = now(), decision_reason = 'expired' where id = v_approval.id;
    update public.ai_tool_calls set status = 'expired', completed_at = now(), error_code = 'AI_APPROVAL_EXPIRED' where id = v_approval.tool_call_id;
    update public.ai_runs set status = 'expired', completed_at = now() where id = v_approval.run_id and status = 'waiting_approval';
    raise exception using errcode = 'P0001', message = 'AI_APPROVAL_EXPIRED';
  end if;

  v_status := p_decision;
  update public.ai_approvals
  set status = v_status, decision_reason = nullif(trim(p_reason), ''), decided_at = now()
  where id = v_approval.id;
  update public.ai_tool_calls
  set status = case when p_decision = 'approved' then 'approved' else 'rejected' end,
      approved_at = case when p_decision = 'approved' then now() else approved_at end,
      completed_at = case when p_decision = 'rejected' then now() else completed_at end,
      error_code = case when p_decision = 'rejected' then 'AI_APPROVAL_REJECTED' else null end
  where id = v_approval.tool_call_id
  returning * into v_call;
  update public.ai_runs set status = case when p_decision = 'approved' then 'running' else 'failed' end where id = v_approval.run_id;

  insert into public.audit_events(actor_user_id, action, resource_type, resource_id, metadata)
  values (
    v_actor, case when p_decision = 'approved' then 'ai.approval_approved' else 'ai.approval_rejected' end,
    'ai_approval', v_approval.id::text,
    jsonb_build_object('run_id', v_approval.run_id, 'tool_call_id', v_approval.tool_call_id, 'tool_name', v_approval.tool_name, 'arguments_hash', v_approval.arguments_hash, 'reason', nullif(trim(p_reason), ''))
  );

  return jsonb_build_object('approval_id', v_approval.id, 'tool_call_id', v_call.id, 'status', v_approval.status, 'tool_status', v_call.status);
end;
$$;
revoke all on function private.ai_decide_approval(uuid, text, text) from public, anon, authenticated;
grant execute on function private.ai_decide_approval(uuid, text, text) to authenticated, service_role;
create or replace function public.ai_decide_approval(p_approval_id uuid, p_decision text, p_reason text default null)
returns jsonb language sql security invoker set search_path = public, pg_catalog
as $$ select private.ai_decide_approval(p_approval_id, p_decision, p_reason); $$;
revoke all on function public.ai_decide_approval(uuid, text, text) from public, anon;
grant execute on function public.ai_decide_approval(uuid, text, text) to authenticated;

create or replace function private.ai_transition_tool_call(
  p_tool_call_id uuid,
  p_status text,
  p_result_summary jsonb default null,
  p_error_code text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, private, pg_catalog
as $$
declare
  v_actor uuid := (select auth.uid());
  v_call public.ai_tool_calls%rowtype;
  v_run public.ai_runs%rowtype;
begin
  select c.* into v_call
  from public.ai_tool_calls c
  join public.ai_runs r on r.id = c.run_id
  where c.id = p_tool_call_id and r.actor_user_id = v_actor
  for update;
  if not found then raise exception using errcode = '42501', message = 'AI_TOOL_CALL_FORBIDDEN'; end if;
  if p_status not in ('running', 'succeeded', 'failed', 'blocked', 'rejected', 'expired') then
    raise exception using errcode = 'P0001', message = 'AI_TOOL_STATUS_INVALID';
  end if;
  if p_result_summary is not null and jsonb_typeof(p_result_summary) <> 'object' then
    raise exception using errcode = 'P0001', message = 'AI_RESULT_INVALID';
  end if;
  if p_status in ('succeeded', 'failed') and v_call.status in ('succeeded', 'failed', 'rejected', 'expired') then
    raise exception using errcode = 'P0001', message = 'AI_TOOL_CALL_TERMINAL';
  end if;
  if p_status = 'running' and v_call.status not in ('proposed', 'approved') then
    raise exception using errcode = 'P0001', message = 'AI_TOOL_CALL_NOT_EXECUTABLE';
  end if;
  if p_status = 'succeeded' and v_call.status not in ('running', 'approved') then
    raise exception using errcode = 'P0001', message = 'AI_TOOL_CALL_NOT_RUNNING';
  end if;

  update public.ai_tool_calls
  set status = p_status,
      result_summary = coalesce(p_result_summary, result_summary),
      error_code = nullif(trim(p_error_code), ''),
      started_at = case when p_status = 'running' then coalesce(started_at, now()) else started_at end,
      completed_at = case when p_status in ('succeeded', 'failed', 'blocked', 'rejected', 'expired') then coalesce(completed_at, now()) else completed_at end
  where id = v_call.id
  returning * into v_call;

  select * into v_run from public.ai_runs where id = v_call.run_id;
  update public.ai_runs
  set status = case
    when p_status = 'running' then 'running'
    when p_status in ('blocked', 'rejected', 'expired', 'failed') then 'failed'
    else status
  end
  where id = v_run.id and status <> 'cancelled';

  insert into public.audit_events(actor_user_id, action, resource_type, resource_id, metadata)
  values (
    v_actor, 'ai.tool_call_' || p_status, 'ai_tool_call', v_call.id::text,
    jsonb_build_object('run_id', v_call.run_id, 'tool_name', v_call.tool_name, 'status', v_call.status, 'error_code', v_call.error_code, 'arguments_hash', v_call.arguments_hash)
  );

  return jsonb_build_object('tool_call_id', v_call.id, 'status', v_call.status, 'error_code', v_call.error_code);
end;
$$;
revoke all on function private.ai_transition_tool_call(uuid, text, jsonb, text) from public, anon, authenticated;
grant execute on function private.ai_transition_tool_call(uuid, text, jsonb, text) to authenticated, service_role;
create or replace function public.ai_transition_tool_call(p_tool_call_id uuid, p_status text, p_result_summary jsonb default null, p_error_code text default null)
returns jsonb language sql security invoker set search_path = public, pg_catalog
as $$ select private.ai_transition_tool_call(p_tool_call_id, p_status, p_result_summary, p_error_code); $$;
revoke all on function public.ai_transition_tool_call(uuid, text, jsonb, text) from public, anon;
grant execute on function public.ai_transition_tool_call(uuid, text, jsonb, text) to authenticated;

create or replace function private.ai_finish_run(
  p_run_id uuid,
  p_status text,
  p_output_hash text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, private, pg_catalog
as $$
declare
  v_actor uuid := (select auth.uid());
  v_run public.ai_runs%rowtype;
  v_pending integer;
begin
  select * into v_run from public.ai_runs where id = p_run_id and actor_user_id = v_actor for update;
  if not found then raise exception using errcode = '42501', message = 'AI_RUN_FORBIDDEN'; end if;
  if p_status not in ('succeeded', 'failed', 'cancelled', 'expired') then
    raise exception using errcode = 'P0001', message = 'AI_RUN_STATUS_INVALID';
  end if;
  if p_status = 'succeeded' and (p_output_hash is null or length(trim(p_output_hash)) < 16) then
    raise exception using errcode = 'P0001', message = 'AI_OUTPUT_HASH_REQUIRED';
  end if;
  select count(*) into v_pending from public.ai_tool_calls where run_id = p_run_id and status in ('proposed', 'awaiting_approval', 'approved', 'running');
  if v_pending > 0 then
    raise exception using errcode = 'P0001', message = 'AI_RUN_HAS_PENDING_TOOLS';
  end if;
  if v_run.status in ('succeeded', 'failed', 'cancelled', 'expired') then
    raise exception using errcode = 'P0001', message = 'AI_RUN_TERMINAL';
  end if;

  update public.ai_runs
  set status = p_status, completed_at = now(), metadata = case when p_output_hash is null then metadata else metadata || jsonb_build_object('output_hash', trim(p_output_hash)) end
  where id = p_run_id
  returning * into v_run;

  insert into public.audit_events(actor_user_id, action, resource_type, resource_id, metadata)
  values (
    v_actor, 'ai.run_' || p_status, 'ai_run', v_run.id::text,
    jsonb_build_object('app_surface', v_run.app_surface, 'scope_type', v_run.scope_type, 'scope_id', v_run.scope_id, 'tool_call_count', v_run.tool_call_count, 'output_hash', nullif(trim(p_output_hash), ''))
  );

  return jsonb_build_object('run_id', v_run.id, 'status', v_run.status, 'completed_at', v_run.completed_at);
end;
$$;
revoke all on function private.ai_finish_run(uuid, text, text) from public, anon, authenticated;
grant execute on function private.ai_finish_run(uuid, text, text) to authenticated, service_role;
create or replace function public.ai_finish_run(p_run_id uuid, p_status text, p_output_hash text default null)
returns jsonb language sql security invoker set search_path = public, pg_catalog
as $$ select private.ai_finish_run(p_run_id, p_status, p_output_hash); $$;
revoke all on function public.ai_finish_run(uuid, text, text) from public, anon;
grant execute on function public.ai_finish_run(uuid, text, text) to authenticated;

create or replace function private.ai_publish_policy(
  p_policy_key text,
  p_app_surface text,
  p_principal_role text default 'all',
  p_tool_name text default '*',
  p_version integer default null,
  p_status text default 'draft',
  p_rules jsonb default '{}'::jsonb,
  p_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, private, pg_catalog
as $$
declare
  v_actor uuid := (select auth.uid());
  v_version integer;
  v_policy public.ai_policies%rowtype;
begin
  if not private.current_user_is_creator() then raise exception using errcode = '42501', message = 'AI_POLICY_CREATOR_REQUIRED'; end if;
  if length(trim(coalesce(p_policy_key, ''))) = 0 or length(trim(p_policy_key)) > 120 then raise exception using errcode = 'P0001', message = 'AI_POLICY_KEY_INVALID'; end if;
  if p_app_surface not in ('global', 'customer', 'merchant', 'developer') then raise exception using errcode = 'P0001', message = 'AI_POLICY_APP_SURFACE_INVALID'; end if;
  if p_status not in ('draft', 'active') then raise exception using errcode = 'P0001', message = 'AI_POLICY_STATUS_INVALID'; end if;
  if p_rules is null or jsonb_typeof(p_rules) <> 'object' then raise exception using errcode = 'P0001', message = 'AI_POLICY_RULES_INVALID'; end if;
  if length(trim(coalesce(p_reason, ''))) < 3 then raise exception using errcode = 'P0001', message = 'AI_POLICY_REASON_REQUIRED'; end if;
  select coalesce(max(version), 0) + 1 into v_version
  from public.ai_policies
  where policy_key = trim(p_policy_key)
    and app_surface = p_app_surface
    and principal_role = coalesce(nullif(trim(p_principal_role), ''), 'all')
    and tool_name = coalesce(nullif(trim(p_tool_name), ''), '*');
  if p_version is not null and p_version <> v_version then raise exception using errcode = 'P0001', message = 'AI_POLICY_VERSION_MUST_ADVANCE'; end if;

  insert into public.ai_policies(policy_key, app_surface, principal_role, tool_name, version, status, rules, source, created_by_user_id, reason, effective_at)
  values (trim(p_policy_key), p_app_surface, coalesce(nullif(trim(p_principal_role), ''), 'all'), coalesce(nullif(trim(p_tool_name), ''), '*'), v_version, p_status, p_rules, 'creator', v_actor, trim(p_reason), case when p_status = 'active' then now() else null end)
  returning * into v_policy;

  insert into public.audit_events(actor_user_id, action, resource_type, resource_id, metadata)
  values (v_actor, 'ai.policy_published', 'ai_policy', v_policy.id::text, jsonb_build_object('policy_key', v_policy.policy_key, 'app_surface', v_policy.app_surface, 'principal_role', v_policy.principal_role, 'tool_name', v_policy.tool_name, 'version', v_policy.version, 'status', v_policy.status, 'reason', v_policy.reason));

  return jsonb_build_object('policy_id', v_policy.id, 'policy_key', v_policy.policy_key, 'app_surface', v_policy.app_surface, 'version', v_policy.version, 'status', v_policy.status);
end;
$$;
revoke all on function private.ai_publish_policy(text, text, text, text, integer, text, jsonb, text) from public, anon, authenticated;
grant execute on function private.ai_publish_policy(text, text, text, text, integer, text, jsonb, text) to authenticated, service_role;
create or replace function public.ai_publish_policy(
  p_policy_key text,
  p_app_surface text,
  p_principal_role text default 'all',
  p_tool_name text default '*',
  p_version integer default null,
  p_status text default 'draft',
  p_rules jsonb default '{}'::jsonb,
  p_reason text default null
)
returns jsonb language sql security invoker set search_path = public, pg_catalog
as $$ select private.ai_publish_policy(p_policy_key, p_app_surface, p_principal_role, p_tool_name, p_version, p_status, p_rules, p_reason); $$;
revoke all on function public.ai_publish_policy(text, text, text, text, integer, text, jsonb, text) from public, anon;
grant execute on function public.ai_publish_policy(text, text, text, text, integer, text, jsonb, text) to authenticated;

create or replace function private.ai_list_effective_policies(p_app_surface text default null)
returns setof jsonb
language plpgsql
security definer
set search_path = public, private, pg_catalog
as $$
declare
  v_actor uuid := (select auth.uid());
  v_role text := private.ai_actor_role();
begin
  if v_actor is null then raise exception using errcode = '28000', message = 'AUTH_REQUIRED'; end if;
  if p_app_surface is not null and p_app_surface not in ('customer', 'merchant', 'developer') then raise exception using errcode = 'P0001', message = 'AI_APP_SURFACE_INVALID'; end if;
  if p_app_surface = 'developer' and not private.current_user_is_creator() then raise exception using errcode = '42501', message = 'AI_DEVELOPER_CREATOR_REQUIRED'; end if;
  return query
  select jsonb_build_object(
    'policy_key', p.policy_key,
    'app_surface', p.app_surface,
    'principal_role', p.principal_role,
    'tool_name', p.tool_name,
    'version', p.version,
    'status', p.status,
    'effective_at', p.effective_at,
    'source', p.source
  )
  from public.ai_policies p
  where p.status = 'active'
    and (p_app_surface is null or p.app_surface in ('global', p_app_surface))
    and p.principal_role in ('all', v_role)
  order by p.app_surface, p.policy_key, p.version desc
  limit 100;
end;
$$;
revoke all on function private.ai_list_effective_policies(text) from public, anon, authenticated;
grant execute on function private.ai_list_effective_policies(text) to authenticated, service_role;
create or replace function public.ai_list_effective_policies(p_app_surface text default null)
returns setof jsonb language sql security invoker set search_path = public, pg_catalog
as $$ select * from private.ai_list_effective_policies(p_app_surface); $$;
revoke all on function public.ai_list_effective_policies(text) from public, anon;
grant execute on function public.ai_list_effective_policies(text) to authenticated;

create or replace function private.ai_get_run(p_run_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, private, pg_catalog
as $$
declare
  v_run public.ai_runs%rowtype;
  v_actor uuid := (select auth.uid());
begin
  select * into v_run from public.ai_runs where id = p_run_id and (actor_user_id = v_actor or private.current_user_is_creator());
  if not found then raise exception using errcode = '42501', message = 'AI_RUN_FORBIDDEN'; end if;
  return jsonb_build_object('run_id', v_run.id, 'app_surface', v_run.app_surface, 'actor_role', v_run.actor_role, 'scope_type', v_run.scope_type, 'scope_id', v_run.scope_id, 'intent_key', v_run.intent_key, 'requested_locale', v_run.requested_locale, 'policy_key', v_run.policy_key, 'policy_version', v_run.policy_version, 'status', v_run.status, 'max_tool_calls', v_run.max_tool_calls, 'tool_call_count', v_run.tool_call_count, 'created_at', v_run.created_at, 'started_at', v_run.started_at, 'completed_at', v_run.completed_at);
end;
$$;
revoke all on function private.ai_get_run(uuid) from public, anon, authenticated;
grant execute on function private.ai_get_run(uuid) to authenticated, service_role;
create or replace function public.ai_get_run(p_run_id uuid)
returns jsonb language sql security invoker set search_path = public, pg_catalog
as $$ select private.ai_get_run(p_run_id); $$;
revoke all on function public.ai_get_run(uuid) from public, anon;
grant execute on function public.ai_get_run(uuid) to authenticated;

create or replace function private.ai_list_run_tool_calls(p_run_id uuid)
returns setof jsonb
language plpgsql
security definer
set search_path = public, private, pg_catalog
as $$
declare
  v_actor uuid := (select auth.uid());
begin
  if not exists (select 1 from public.ai_runs where id = p_run_id and (actor_user_id = v_actor or private.current_user_is_creator())) then
    raise exception using errcode = '42501', message = 'AI_RUN_FORBIDDEN';
  end if;
  return query
  select jsonb_build_object('tool_call_id', c.id, 'run_id', c.run_id, 'sequence_no', c.sequence_no, 'tool_name', c.tool_name, 'tool_version', c.tool_version, 'action_class', c.action_class, 'status', c.status, 'arguments_hash', c.arguments_hash, 'arguments_redacted', c.arguments_redacted, 'required_capability', c.required_capability, 'approval_required', c.approval_required, 'policy_decision', c.policy_decision, 'result_summary', c.result_summary, 'error_code', c.error_code, 'created_at', c.created_at, 'approved_at', c.approved_at, 'started_at', c.started_at, 'completed_at', c.completed_at)
  from public.ai_tool_calls c
  where c.run_id = p_run_id
  order by c.sequence_no
  limit 50;
end;
$$;
revoke all on function private.ai_list_run_tool_calls(uuid) from public, anon, authenticated;
grant execute on function private.ai_list_run_tool_calls(uuid) to authenticated, service_role;
create or replace function public.ai_list_run_tool_calls(p_run_id uuid)
returns setof jsonb language sql security invoker set search_path = public, pg_catalog
as $$ select * from private.ai_list_run_tool_calls(p_run_id); $$;
revoke all on function public.ai_list_run_tool_calls(uuid) from public, anon;
grant execute on function public.ai_list_run_tool_calls(uuid) to authenticated;

create or replace function private.ai_list_my_approvals(p_status text default null)
returns setof jsonb
language plpgsql
security definer
set search_path = public, private, pg_catalog
as $$
declare
  v_actor uuid := (select auth.uid());
begin
  if v_actor is null then raise exception using errcode = '28000', message = 'AUTH_REQUIRED'; end if;
  if p_status is not null and p_status not in ('pending', 'approved', 'rejected', 'expired', 'cancelled') then raise exception using errcode = 'P0001', message = 'AI_APPROVAL_STATUS_INVALID'; end if;
  return query
  select jsonb_build_object('approval_id', a.id, 'run_id', a.run_id, 'tool_call_id', a.tool_call_id, 'tool_name', a.tool_name, 'arguments_hash', a.arguments_hash, 'status', a.status, 'decision_reason', a.decision_reason, 'created_at', a.created_at, 'expires_at', a.expires_at, 'decided_at', a.decided_at)
  from public.ai_approvals a
  where a.approver_user_id = v_actor
    and (p_status is null or a.status = p_status)
  order by a.created_at desc
  limit 100;
end;
$$;
revoke all on function private.ai_list_my_approvals(text) from public, anon, authenticated;
grant execute on function private.ai_list_my_approvals(text) to authenticated, service_role;
create or replace function public.ai_list_my_approvals(p_status text default null)
returns setof jsonb language sql security invoker set search_path = public, pg_catalog
as $$ select * from private.ai_list_my_approvals(p_status); $$;
revoke all on function public.ai_list_my_approvals(text) from public, anon;
grant execute on function public.ai_list_my_approvals(text) to authenticated;

-- System defaults are intentionally conservative. Creator-published versions are
-- append-only and must carry a reason. These rows contain policy metadata only;
-- they do not enable any provider or model.
insert into public.ai_policies(policy_key, app_surface, principal_role, tool_name, version, status, rules, source, reason, effective_at)
values
  ('default', 'customer', 'customer', '*', 1, 'active', '{"max_tool_calls":4,"allowed_action_classes":["read","draft"],"approval_required_for":["reversible_write","high_impact_write","external_side_effect","sensitive_read"],"background_enabled":false}'::jsonb, 'system', null, now()),
  ('default', 'merchant', 'merchant', '*', 1, 'active', '{"max_tool_calls":8,"allowed_action_classes":["read","draft","reversible_write"],"approval_required_for":["reversible_write","high_impact_write","external_side_effect","sensitive_read"],"background_enabled":false}'::jsonb, 'system', null, now()),
  ('default', 'developer', 'creator', '*', 1, 'active', '{"max_tool_calls":20,"allowed_action_classes":["read","draft","reversible_write","high_impact_write"],"approval_required_for":["high_impact_write","external_side_effect","sensitive_read"],"background_enabled":false,"dual_approval_for":["role_grant","provider_activation","global_policy_change","destructive_export"]}'::jsonb, 'system', null, now()),
  ('default', 'global', 'all', '*', 1, 'active', '{"provider_calls_enabled":false,"payment_custody_enabled":false,"direct_table_writes_enabled":false,"raw_evidence_retrieval_enabled":false}'::jsonb, 'system', null, now())
on conflict (policy_key, app_surface, principal_role, tool_name, version) do nothing;

create or replace function private.ai_runs_immutable_core()
returns trigger
language plpgsql
security invoker
set search_path = public, pg_catalog
as $$
begin
  if new.actor_user_id <> old.actor_user_id
     or new.app_surface <> old.app_surface
     or new.actor_role <> old.actor_role
     or new.scope_type <> old.scope_type
     or new.scope_id is distinct from old.scope_id
     or new.intent_key <> old.intent_key
     or new.request_hash <> old.request_hash
     or new.requested_locale <> old.requested_locale
     or new.policy_key <> old.policy_key
     or new.policy_version is distinct from old.policy_version
     or new.idempotency_key is distinct from old.idempotency_key
     or new.created_at <> old.created_at then
    raise exception using errcode = 'P0001', message = 'AI_RUN_IMMUTABLE_FIELDS';
  end if;
  return new;
end;
$$;
revoke all on function private.ai_runs_immutable_core() from public, anon, authenticated;
grant execute on function private.ai_runs_immutable_core() to authenticated, service_role;
drop trigger if exists ai_runs_immutable_core_trigger on public.ai_runs;
create trigger ai_runs_immutable_core_trigger before update on public.ai_runs for each row execute function private.ai_runs_immutable_core();

create or replace function private.ai_tool_calls_immutable_core()
returns trigger
language plpgsql
security invoker
set search_path = public, pg_catalog
as $$
begin
  if new.run_id <> old.run_id
     or new.sequence_no <> old.sequence_no
     or new.tool_name <> old.tool_name
     or new.tool_version <> old.tool_version
     or new.action_class <> old.action_class
     or new.arguments_hash <> old.arguments_hash
     or new.arguments_redacted <> old.arguments_redacted
     or new.required_capability is distinct from old.required_capability
     or new.approval_required <> old.approval_required
     or new.idempotency_key is distinct from old.idempotency_key
     or new.created_at <> old.created_at then
    raise exception using errcode = 'P0001', message = 'AI_TOOL_CALL_IMMUTABLE_FIELDS';
  end if;
  return new;
end;
$$;
revoke all on function private.ai_tool_calls_immutable_core() from public, anon, authenticated;
grant execute on function private.ai_tool_calls_immutable_core() to authenticated, service_role;
drop trigger if exists ai_tool_calls_immutable_core_trigger on public.ai_tool_calls;
create trigger ai_tool_calls_immutable_core_trigger before update on public.ai_tool_calls for each row execute function private.ai_tool_calls_immutable_core();

create or replace function private.ai_approvals_immutable_core()
returns trigger
language plpgsql
security invoker
set search_path = public, pg_catalog
as $$
begin
  if new.run_id <> old.run_id
     or new.tool_call_id <> old.tool_call_id
     or new.approver_user_id <> old.approver_user_id
     or new.tool_name <> old.tool_name
     or new.arguments_hash <> old.arguments_hash
     or new.approval_token_hash <> old.approval_token_hash
     or new.created_at <> old.created_at
     or new.expires_at <> old.expires_at then
    raise exception using errcode = 'P0001', message = 'AI_APPROVAL_IMMUTABLE_FIELDS';
  end if;
  return new;
end;
$$;
revoke all on function private.ai_approvals_immutable_core() from public, anon, authenticated;
grant execute on function private.ai_approvals_immutable_core() to authenticated, service_role;
drop trigger if exists ai_approvals_immutable_core_trigger on public.ai_approvals;
create trigger ai_approvals_immutable_core_trigger before update on public.ai_approvals for each row execute function private.ai_approvals_immutable_core();

create or replace function private.ai_policies_append_only()
returns trigger
language plpgsql
security invoker
set search_path = public, pg_catalog
as $$
begin
  raise exception using errcode = 'P0001', message = 'AI_POLICY_APPEND_ONLY';
end;
$$;
revoke all on function private.ai_policies_append_only() from public, anon, authenticated;
grant execute on function private.ai_policies_append_only() to authenticated, service_role;
drop trigger if exists ai_policies_no_update_trigger on public.ai_policies;
create trigger ai_policies_no_update_trigger before update or delete on public.ai_policies for each row execute function private.ai_policies_append_only();
