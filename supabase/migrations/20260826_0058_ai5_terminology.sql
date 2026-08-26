-- AI-5 Arabic terminology memory. Entries are managed by the creator and
-- retrieved only inside the caller's authenticated merchant/shop scope.

create table if not exists public.ai_terminology_entries (
  id uuid primary key default gen_random_uuid(),
  scope_type text not null check (scope_type in ('global','market','shop')),
  scope_id uuid,
  term_key text not null check (length(trim(term_key)) between 2 and 160),
  term_ar text not null check (length(trim(term_ar)) between 1 and 240),
  canonical_term text not null check (length(trim(canonical_term)) between 1 and 240),
  aliases text[] not null default '{}'::text[] check (cardinality(aliases) <= 20),
  definition text not null default '' check (length(trim(definition)) <= 2000),
  source_id uuid references public.ai_knowledge_sources(id) on delete set null,
  status text not null default 'draft' check (status in ('draft','ready','archived')),
  content_hash text not null check (length(trim(content_hash)) between 16 and 128),
  metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata) = 'object'),
  created_by_user_id uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((scope_type = 'global' and scope_id is null) or (scope_type <> 'global' and scope_id is not null))
);

create unique index if not exists ai_terminology_scope_key_uidx
  on public.ai_terminology_entries(scope_type, coalesce(scope_id, '00000000-0000-0000-0000-000000000000'::uuid), term_key);

alter table public.ai_terminology_entries enable row level security;
revoke all on public.ai_terminology_entries from anon, authenticated;
grant select on public.ai_terminology_entries to authenticated;
drop policy if exists ai_terminology_entries_creator_select on public.ai_terminology_entries;
create policy ai_terminology_entries_creator_select
on public.ai_terminology_entries
for select to authenticated
using (private.current_user_is_creator());

alter table public.ai_terminology_entries
  add column if not exists search_document tsvector not null default ''::tsvector;

create or replace function private.ai_terminology_search_document_trigger()
returns trigger
language plpgsql
set search_path = public, private, pg_catalog
as $$
begin
  new.search_document := to_tsvector('simple'::regconfig,
    trim(coalesce(new.term_ar, '')) || ' ' ||
    trim(coalesce(new.canonical_term, '')) || ' ' ||
    array_to_string(coalesce(new.aliases, '{}'::text[]), ' ') || ' ' ||
    trim(coalesce(new.definition, ''))
  );
  return new;
end;
$$;
revoke all on function private.ai_terminology_search_document_trigger() from public, anon, authenticated;
create trigger ai_terminology_search_document_update
before insert or update of term_ar, canonical_term, aliases, definition
on public.ai_terminology_entries
for each row execute function private.ai_terminology_search_document_trigger();

create index if not exists ai_terminology_entries_search_idx
  on public.ai_terminology_entries using gin(search_document);
create index if not exists ai_terminology_entries_scope_status_idx
  on public.ai_terminology_entries(scope_type, scope_id, status, updated_at desc);
create index if not exists ai_terminology_entries_source_idx
  on public.ai_terminology_entries(source_id);
create index if not exists ai_terminology_entries_created_by_idx
  on public.ai_terminology_entries(created_by_user_id);

create or replace function private.ai_upsert_terminology_entry(
  p_scope_type text,
  p_scope_id uuid,
  p_term_key text,
  p_term_ar text,
  p_canonical_term text,
  p_aliases text[] default '{}',
  p_definition text default '',
  p_source_id uuid default null,
  p_status text default 'draft',
  p_content_hash text default '',
  p_metadata jsonb default '{}'::jsonb,
  p_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, private, pg_catalog
as $$
declare
  v_actor uuid := (select auth.uid());
  v_entry public.ai_terminology_entries%rowtype;
begin
  if v_actor is null then raise exception using errcode = '28000', message = 'AUTH_REQUIRED'; end if;
  if not private.current_user_is_creator() then raise exception using errcode = '42501', message = 'AI_DEVELOPER_CREATOR_REQUIRED'; end if;
  if p_scope_type not in ('global','market','shop') or ((p_scope_type = 'global') <> (p_scope_id is null)) then raise exception using errcode = 'P0001', message = 'AI_TERMINOLOGY_SCOPE_INVALID'; end if;
  if length(trim(coalesce(p_term_key,''))) not between 2 and 160
     or length(trim(coalesce(p_term_ar,''))) not between 1 and 240
     or length(trim(coalesce(p_canonical_term,''))) not between 1 and 240
     or cardinality(coalesce(p_aliases, '{}'::text[])) > 20
     or length(trim(coalesce(p_definition,''))) > 2000
     or p_status not in ('draft','ready','archived')
     or length(trim(coalesce(p_content_hash,''))) not between 16 and 128
     or jsonb_typeof(coalesce(p_metadata, '{}'::jsonb)) <> 'object'
     or length(trim(coalesce(p_reason,''))) < 3 then
    raise exception using errcode = 'P0001', message = 'AI_TERMINOLOGY_INVALID';
  end if;
  if p_source_id is not null and not exists (select 1 from public.ai_knowledge_sources s where s.id = p_source_id) then
    raise exception using errcode = 'P0001', message = 'AI_KNOWLEDGE_SOURCE_NOT_FOUND';
  end if;
  insert into public.ai_terminology_entries(scope_type, scope_id, term_key, term_ar, canonical_term, aliases, definition, source_id, status, content_hash, metadata, created_by_user_id)
  values(trim(p_scope_type), p_scope_id, trim(p_term_key), trim(p_term_ar), trim(p_canonical_term), coalesce(p_aliases, '{}'::text[]), trim(coalesce(p_definition,'')), p_source_id, p_status, trim(p_content_hash), coalesce(p_metadata, '{}'::jsonb), v_actor)
  on conflict (scope_type, (coalesce(scope_id, '00000000-0000-0000-0000-000000000000'::uuid)), term_key)
  do update set term_ar = excluded.term_ar, canonical_term = excluded.canonical_term, aliases = excluded.aliases, definition = excluded.definition, source_id = excluded.source_id, status = excluded.status, content_hash = excluded.content_hash, metadata = excluded.metadata, updated_at = now()
  returning * into v_entry;
  insert into public.audit_events(actor_user_id, action, resource_type, resource_id, metadata)
  values(v_actor, 'ai.terminology_entry_upserted', 'ai_terminology_entry', v_entry.id::text, jsonb_build_object('scope_type', v_entry.scope_type, 'scope_id', v_entry.scope_id, 'term_key', v_entry.term_key, 'status', v_entry.status, 'reason', trim(p_reason)));
  return jsonb_build_object('entry_id', v_entry.id, 'term_key', v_entry.term_key, 'status', v_entry.status, 'content_hash', v_entry.content_hash);
end;
$$;
revoke all on function private.ai_upsert_terminology_entry(text, uuid, text, text, text, text[], text, uuid, text, text, jsonb, text) from public, anon, authenticated;
grant execute on function private.ai_upsert_terminology_entry(text, uuid, text, text, text, text[], text, uuid, text, text, jsonb, text) to authenticated, service_role;

create or replace function public.ai_upsert_terminology_entry(p_scope_type text, p_scope_id uuid, p_term_key text, p_term_ar text, p_canonical_term text, p_aliases text[] default '{}', p_definition text default '', p_source_id uuid default null, p_status text default 'draft', p_content_hash text default '', p_metadata jsonb default '{}'::jsonb, p_reason text default null)
returns jsonb
language sql
security invoker
set search_path = public, pg_catalog
as $$ select private.ai_upsert_terminology_entry(p_scope_type, p_scope_id, p_term_key, p_term_ar, p_canonical_term, p_aliases, p_definition, p_source_id, p_status, p_content_hash, p_metadata, p_reason); $$;
revoke all on function public.ai_upsert_terminology_entry(text, uuid, text, text, text, text[], text, uuid, text, text, jsonb, text) from public, anon;
grant execute on function public.ai_upsert_terminology_entry(text, uuid, text, text, text, text[], text, uuid, text, text, jsonb, text) to authenticated;

create or replace function private.ai_search_terminology(p_scope_type text, p_scope_id uuid, p_query text, p_limit integer default 8)
returns setof jsonb
language plpgsql
security definer
set search_path = public, private, pg_catalog
as $$
declare
  v_actor uuid := (select auth.uid());
  v_enabled boolean;
begin
  if v_actor is null then raise exception using errcode = '28000', message = 'AUTH_REQUIRED'; end if;
  if p_scope_type not in ('global','market','shop') or ((p_scope_type = 'global') <> (p_scope_id is null)) then raise exception using errcode = 'P0001', message = 'AI_TERMINOLOGY_SCOPE_INVALID'; end if;
  if length(trim(coalesce(p_query,''))) not between 2 and 240 or p_limit < 1 or p_limit > 10 then raise exception using errcode = 'P0001', message = 'AI_TERMINOLOGY_QUERY_INVALID'; end if;
  select knowledge_enabled into v_enabled from public.ai_platform_settings_versions where status = 'active' order by version desc limit 1;
  if coalesce(v_enabled, false) is not true then raise exception using errcode = 'P0001', message = 'AI_KNOWLEDGE_DISABLED'; end if;
  if p_scope_type = 'shop' and not exists (select 1 from shops s join merchants m on m.id = s.merchant_id where s.id = p_scope_id and m.owner_user_id = v_actor) then raise exception using errcode = '42501', message = 'AI_SHOP_SCOPE_FORBIDDEN'; end if;
  return query
  select jsonb_build_object('entry_id', e.id, 'term_key', e.term_key, 'term_ar', e.term_ar, 'canonical_term', e.canonical_term, 'aliases', e.aliases, 'definition', e.definition, 'scope_type', e.scope_type, 'scope_id', e.scope_id, 'source_id', e.source_id, 'content_hash', e.content_hash)
  from public.ai_terminology_entries e
  where e.status = 'ready'
    and (e.scope_type = 'global' or (e.scope_type = p_scope_type and e.scope_id = p_scope_id))
    and e.search_document @@ plainto_tsquery('simple'::regconfig, trim(p_query))
  order by ts_rank(e.search_document, plainto_tsquery('simple'::regconfig, trim(p_query))) desc, e.updated_at desc
  limit p_limit;
end;
$$;
revoke all on function private.ai_search_terminology(text, uuid, text, integer) from public, anon, authenticated;
grant execute on function private.ai_search_terminology(text, uuid, text, integer) to authenticated, service_role;

create or replace function public.ai_search_terminology(p_scope_type text, p_scope_id uuid, p_query text, p_limit integer default 8)
returns setof jsonb
language sql
security invoker
set search_path = public, pg_catalog
as $$ select * from private.ai_search_terminology(p_scope_type, p_scope_id, p_query, p_limit); $$;
revoke all on function public.ai_search_terminology(text, uuid, text, integer) from public, anon;
grant execute on function public.ai_search_terminology(text, uuid, text, integer) to authenticated;

commit;
