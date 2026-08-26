begin;

create table if not exists public.ai_evaluation_suites (
  id uuid primary key default gen_random_uuid(),
  suite_key text not null,
  version integer not null default 1 check (version > 0),
  name text not null,
  description text not null default '',
  locale text not null default 'ar' check (locale in ('ar','en','mixed')),
  status text not null default 'draft' check (status in ('draft','active','retired')),
  created_by_user_id uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  unique(suite_key, version)
);

create table if not exists public.ai_evaluation_cases (
  id uuid primary key default gen_random_uuid(),
  suite_id uuid not null references public.ai_evaluation_suites(id) on delete cascade,
  case_key text not null,
  input_hash text not null check (length(trim(input_hash)) between 16 and 128),
  expected_output jsonb not null default '{}'::jsonb check (jsonb_typeof(expected_output) = 'object'),
  rubric jsonb not null default '{}'::jsonb check (jsonb_typeof(rubric) = 'object'),
  status text not null default 'active' check (status in ('active','retired')),
  created_at timestamptz not null default now(),
  unique(suite_id, case_key)
);

create table if not exists public.ai_evaluation_runs (
  id uuid primary key default gen_random_uuid(),
  suite_id uuid not null references public.ai_evaluation_suites(id),
  model text,
  policy_version integer,
  status text not null default 'running' check (status in ('running','succeeded','failed','cancelled')),
  input_hash text not null check (length(trim(input_hash)) between 16 and 128),
  metrics jsonb not null default '{}'::jsonb check (jsonb_typeof(metrics) = 'object'),
  created_by_user_id uuid not null references auth.users(id),
  started_at timestamptz not null default now(),
  finished_at timestamptz
);

create table if not exists public.ai_evaluation_results (
  id uuid primary key default gen_random_uuid(),
  run_id uuid not null references public.ai_evaluation_runs(id) on delete cascade,
  case_id uuid not null references public.ai_evaluation_cases(id),
  status text not null check (status in ('passed','failed','skipped','error')),
  score numeric(5,4) check (score is null or (score >= 0 and score <= 1)),
  output_hash text not null check (length(trim(output_hash)) between 16 and 128),
  rubric_result jsonb not null default '{}'::jsonb check (jsonb_typeof(rubric_result) = 'object'),
  error_code text,
  created_at timestamptz not null default now(),
  unique(run_id, case_id)
);

alter table public.ai_evaluation_suites enable row level security;
alter table public.ai_evaluation_cases enable row level security;
alter table public.ai_evaluation_runs enable row level security;
alter table public.ai_evaluation_results enable row level security;
revoke all on public.ai_evaluation_suites, public.ai_evaluation_cases, public.ai_evaluation_runs, public.ai_evaluation_results from anon, authenticated;
grant select on public.ai_evaluation_suites, public.ai_evaluation_cases, public.ai_evaluation_runs, public.ai_evaluation_results to authenticated;
drop policy if exists ai_evaluation_suites_creator_select on public.ai_evaluation_suites;
create policy ai_evaluation_suites_creator_select on public.ai_evaluation_suites for select to authenticated using (private.current_user_is_creator());
drop policy if exists ai_evaluation_cases_creator_select on public.ai_evaluation_cases;
create policy ai_evaluation_cases_creator_select on public.ai_evaluation_cases for select to authenticated using (private.current_user_is_creator());
drop policy if exists ai_evaluation_runs_creator_select on public.ai_evaluation_runs;
create policy ai_evaluation_runs_creator_select on public.ai_evaluation_runs for select to authenticated using (private.current_user_is_creator());
drop policy if exists ai_evaluation_results_creator_select on public.ai_evaluation_results;
create policy ai_evaluation_results_creator_select on public.ai_evaluation_results for select to authenticated using (private.current_user_is_creator());

create index if not exists ai_evaluation_suites_creator_status_idx on public.ai_evaluation_suites(created_by_user_id, status, suite_key, version desc);
create index if not exists ai_evaluation_cases_suite_status_idx on public.ai_evaluation_cases(suite_id, status, case_key);
create index if not exists ai_evaluation_runs_suite_started_idx on public.ai_evaluation_runs(suite_id, started_at desc, status);
create index if not exists ai_evaluation_runs_creator_idx on public.ai_evaluation_runs(created_by_user_id);
create index if not exists ai_evaluation_results_run_status_idx on public.ai_evaluation_results(run_id, status);
create index if not exists ai_evaluation_results_case_idx on public.ai_evaluation_results(case_id, status);

create or replace function private.ai_upsert_evaluation_suite(p_suite_key text, p_version integer, p_name text, p_description text, p_locale text, p_status text, p_reason text)
returns jsonb language plpgsql security definer
set search_path = public, private, pg_catalog
as $$
declare v_actor uuid := (select auth.uid()); v_suite public.ai_evaluation_suites%rowtype;
begin
  if v_actor is null then raise exception using errcode = '28000', message = 'AUTH_REQUIRED'; end if;
  if not private.current_user_is_creator() then raise exception using errcode = '42501', message = 'AI_DEVELOPER_CREATOR_REQUIRED'; end if;
  if length(trim(coalesce(p_suite_key,''))) not between 2 and 120 or p_version < 1 or length(trim(coalesce(p_name,''))) not between 2 and 200 or p_locale not in ('ar','en','mixed') or p_status not in ('draft','active','retired') or length(trim(coalesce(p_reason,''))) < 3 then raise exception using errcode = 'P0001', message = 'AI_EVALUATION_INVALID'; end if;
  insert into public.ai_evaluation_suites(suite_key, version, name, description, locale, status, created_by_user_id)
  values(trim(p_suite_key), p_version, trim(p_name), trim(coalesce(p_description,'')), p_locale, p_status, v_actor)
  on conflict (suite_key, version) do update set name = excluded.name, description = excluded.description, locale = excluded.locale, status = excluded.status
  returning * into v_suite;
  insert into public.audit_events(actor_user_id, action, resource_type, resource_id, metadata) values(v_actor, 'ai.evaluation_suite_upserted', 'ai_evaluation_suite', v_suite.id::text, jsonb_build_object('suite_key', v_suite.suite_key, 'version', v_suite.version, 'status', v_suite.status, 'reason', trim(p_reason)));
  return jsonb_build_object('suite_id', v_suite.id, 'suite_key', v_suite.suite_key, 'version', v_suite.version, 'status', v_suite.status);
end;
$$;
revoke all on function private.ai_upsert_evaluation_suite(text, integer, text, text, text, text, text) from public, anon, authenticated;
grant execute on function private.ai_upsert_evaluation_suite(text, integer, text, text, text, text, text) to authenticated, service_role;
create or replace function public.ai_upsert_evaluation_suite(p_suite_key text, p_version integer, p_name text, p_description text, p_locale text, p_status text, p_reason text)
returns jsonb language sql security invoker set search_path = public, pg_catalog
as $$ select private.ai_upsert_evaluation_suite(p_suite_key, p_version, p_name, p_description, p_locale, p_status, p_reason); $$;
revoke all on function public.ai_upsert_evaluation_suite(text, integer, text, text, text, text, text) from public, anon;
grant execute on function public.ai_upsert_evaluation_suite(text, integer, text, text, text, text, text) to authenticated;

create or replace function private.ai_list_evaluation_summary()
returns setof jsonb language plpgsql security definer
set search_path = public, private, pg_catalog
as $$
begin
  if (select auth.uid()) is null then raise exception using errcode = '28000', message = 'AUTH_REQUIRED'; end if;
  if not private.current_user_is_creator() then raise exception using errcode = '42501', message = 'AI_DEVELOPER_CREATOR_REQUIRED'; end if;
  return query
  select jsonb_build_object('suite_id', s.id, 'suite_key', s.suite_key, 'version', s.version, 'status', s.status, 'run_count', count(distinct r.id), 'latest_run_status', (array_agg(r.status order by r.started_at desc))[1], 'latest_average_score', (array_agg((select avg(er.score) from public.ai_evaluation_results er where er.run_id = r.id) order by r.started_at desc))[1])
  from public.ai_evaluation_suites s left join public.ai_evaluation_runs r on r.suite_id = s.id
  group by s.id, s.suite_key, s.version, s.status order by s.suite_key, s.version desc limit 100;
end;
$$;
revoke all on function private.ai_list_evaluation_summary() from public, anon, authenticated;
grant execute on function private.ai_list_evaluation_summary() to authenticated, service_role;
create or replace function public.ai_list_evaluation_summary()
returns setof jsonb language sql security invoker set search_path = public, pg_catalog
as $$ select * from private.ai_list_evaluation_summary(); $$;
revoke all on function public.ai_list_evaluation_summary() from public, anon;
grant execute on function public.ai_list_evaluation_summary() to authenticated;

commit;
