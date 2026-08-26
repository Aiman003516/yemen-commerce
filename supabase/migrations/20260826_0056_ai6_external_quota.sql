-- AI-6 external-agent quota: fixed daily request budget, keyed by authenticated
-- user and registered client. The ledger is not directly readable or writable.

create table if not exists public.ai_external_usage_daily (
  user_id uuid not null references auth.users(id) on delete cascade,
  client_id text not null references public.ai_external_clients(client_id) on delete cascade,
  usage_date date not null default current_date,
  request_count integer not null default 0 check (request_count between 0 and 100000),
  updated_at timestamptz not null default now(),
  primary key (user_id, client_id, usage_date)
);

alter table public.ai_external_usage_daily enable row level security;
revoke all on public.ai_external_usage_daily from anon, authenticated;

create index if not exists ai_external_usage_daily_client_date_idx
  on public.ai_external_usage_daily(client_id, usage_date desc);

create or replace function private.ai_consume_external_quota(p_client_id text, p_redirect_uri text)
returns jsonb
language plpgsql
security definer
set search_path = public, private, pg_catalog
as $$
declare
  v_actor uuid := (select auth.uid());
  v_limit constant integer := 120;
  v_count integer;
begin
  if v_actor is null then
    raise exception using errcode = '28000', message = 'AUTH_REQUIRED';
  end if;
  if length(trim(coalesce(p_client_id, ''))) not between 3 and 120
     or p_redirect_uri !~ '^https://[^#?[:space:]]+(/[^#?[:space:]]*)?$' then
    raise exception using errcode = 'P0001', message = 'AI_EXTERNAL_REQUEST_INVALID';
  end if;
  if not exists (
    select 1
    from public.ai_external_clients c
    join public.ai_external_consents e on e.client_id = c.client_id
      and e.user_id = v_actor
      and e.redirect_uri = c.redirect_uri
      and e.status = 'granted'
      and 'ai.read' = any(e.scopes)
    where c.client_id = trim(p_client_id)
      and c.redirect_uri = trim(p_redirect_uri)
      and c.status = 'active'
  ) then
    raise exception using errcode = '42501', message = 'AI_EXTERNAL_CONSENT_REQUIRED';
  end if;

  insert into public.ai_external_usage_daily(user_id, client_id, usage_date, request_count)
  values (v_actor, trim(p_client_id), current_date, 1)
  on conflict (user_id, client_id, usage_date)
  do update set request_count = public.ai_external_usage_daily.request_count + 1,
                updated_at = now()
  where public.ai_external_usage_daily.request_count < v_limit
  returning request_count into v_count;

  if not found then
    return jsonb_build_object('allowed', false, 'limit', v_limit, 'remaining', 0);
  end if;
  return jsonb_build_object('allowed', true, 'limit', v_limit, 'remaining', greatest(v_limit - v_count, 0));
end;
$$;
revoke all on function private.ai_consume_external_quota(text, text) from public, anon, authenticated;
grant execute on function private.ai_consume_external_quota(text, text) to authenticated, service_role;

create or replace function public.ai_consume_external_quota(p_client_id text, p_redirect_uri text)
returns jsonb
language sql
security invoker
set search_path = public, pg_catalog
as $$
  select private.ai_consume_external_quota(p_client_id, p_redirect_uri);
$$;
revoke all on function public.ai_consume_external_quota(text, text) from public, anon;
grant execute on function public.ai_consume_external_quota(text, text) to authenticated;

commit;
