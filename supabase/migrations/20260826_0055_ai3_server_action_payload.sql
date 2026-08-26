-- AI-3 execution payloads remain server-retained and owner-scoped. The client receives
-- only arguments_redacted for review; execution may retrieve the exact payload by ID.

alter table public.ai_tool_calls
  add column if not exists arguments_payload jsonb;

-- Tool-call projections are served through redacted RPCs; never expose the raw
-- execution payload through direct PostgREST table reads.
revoke all on public.ai_tool_calls from anon, authenticated;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.ai_tool_calls'::regclass
      and conname = 'ai_tool_calls_arguments_payload_object'
  ) then
    alter table public.ai_tool_calls
      add constraint ai_tool_calls_arguments_payload_object
      check (arguments_payload is null or jsonb_typeof(arguments_payload) = 'object');
  end if;
end;
$$;

create or replace function private.ai_propose_action_tool_call(
  p_run_id uuid,
  p_sequence_no integer,
  p_tool_name text,
  p_action_class text,
  p_arguments_hash text,
  p_arguments_redacted jsonb,
  p_arguments_payload jsonb,
  p_required_capability text default null,
  p_approval_required boolean default true,
  p_policy_decision text default 'needs_approval',
  p_idempotency_key text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, private, pg_catalog
as $$
declare
  v_result jsonb;
  v_tool_call_id uuid;
  v_existing_hash text;
begin
  if p_arguments_payload is null or jsonb_typeof(p_arguments_payload) <> 'object' then
    raise exception using errcode = 'P0001', message = 'AI_ARGUMENTS_INVALID';
  end if;

  v_result := private.ai_propose_tool_call(
    p_run_id,
    p_sequence_no,
    p_tool_name,
    p_action_class,
    p_arguments_hash,
    p_arguments_redacted,
    p_required_capability,
    p_approval_required,
    p_policy_decision,
    p_idempotency_key
  );
  v_tool_call_id := (v_result->>'tool_call_id')::uuid;

  select c.arguments_hash into v_existing_hash
  from public.ai_tool_calls c
  join public.ai_runs r on r.id = c.run_id
  where c.id = v_tool_call_id
    and r.actor_user_id = (select auth.uid())
  for update;
  if not found then
    raise exception using errcode = '42501', message = 'AI_TOOL_CALL_FORBIDDEN';
  end if;
  if v_existing_hash <> trim(p_arguments_hash) then
    raise exception using errcode = 'P0001', message = 'AI_ARGUMENTS_MISMATCH';
  end if;

  update public.ai_tool_calls
  set arguments_payload = coalesce(arguments_payload, p_arguments_payload)
  where id = v_tool_call_id;

  return v_result;
end;
$$;
revoke all on function private.ai_propose_action_tool_call(uuid, integer, text, text, text, jsonb, jsonb, text, boolean, text, text) from public, anon, authenticated;
grant execute on function private.ai_propose_action_tool_call(uuid, integer, text, text, text, jsonb, jsonb, text, boolean, text, text) to authenticated, service_role;

create or replace function public.ai_propose_action_tool_call(
  p_run_id uuid,
  p_sequence_no integer,
  p_tool_name text,
  p_action_class text,
  p_arguments_hash text,
  p_arguments_redacted jsonb,
  p_arguments_payload jsonb,
  p_required_capability text default null,
  p_approval_required boolean default true,
  p_policy_decision text default 'needs_approval',
  p_idempotency_key text default null
)
returns jsonb
language sql
security invoker
set search_path = public, pg_catalog
as $$
  select private.ai_propose_action_tool_call(p_run_id, p_sequence_no, p_tool_name, p_action_class, p_arguments_hash, p_arguments_redacted, p_arguments_payload, p_required_capability, p_approval_required, p_policy_decision, p_idempotency_key);
$$;
revoke all on function public.ai_propose_action_tool_call(uuid, integer, text, text, text, jsonb, jsonb, text, boolean, text, text) from public, anon;
grant execute on function public.ai_propose_action_tool_call(uuid, integer, text, text, text, jsonb, jsonb, text, boolean, text, text) to authenticated;

create or replace function private.ai_get_action_payload(p_tool_call_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, private, pg_catalog
as $$
declare
  v_actor uuid := (select auth.uid());
  v_payload jsonb;
begin
  if v_actor is null then
    raise exception using errcode = '28000', message = 'AUTH_REQUIRED';
  end if;
  select c.arguments_payload into v_payload
  from public.ai_tool_calls c
  join public.ai_runs r on r.id = c.run_id
  where c.id = p_tool_call_id
    and r.actor_user_id = v_actor;
  if not found then
    raise exception using errcode = '42501', message = 'AI_TOOL_CALL_FORBIDDEN';
  end if;
  if v_payload is null then
    raise exception using errcode = 'P0001', message = 'AI_ACTION_PAYLOAD_UNAVAILABLE';
  end if;
  return v_payload;
end;
$$;
revoke all on function private.ai_get_action_payload(uuid) from public, anon, authenticated;
grant execute on function private.ai_get_action_payload(uuid) to authenticated, service_role;

create or replace function public.ai_get_action_payload(p_tool_call_id uuid)
returns jsonb
language sql
security invoker
set search_path = public, pg_catalog
as $$
  select private.ai_get_action_payload(p_tool_call_id);
$$;
revoke all on function public.ai_get_action_payload(uuid) from public, anon;
grant execute on function public.ai_get_action_payload(uuid) to authenticated;

commit;
