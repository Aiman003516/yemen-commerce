begin;

create index if not exists ai_platform_settings_created_by_idx
  on public.ai_platform_settings_versions(created_by_user_id);

create table if not exists public.ai_knowledge_sources (
  id uuid primary key default gen_random_uuid(),
  scope_type text not null check (scope_type in ('global','market','shop')),
  scope_id uuid,
  source_key text not null,
  title text not null,
  source_kind text not null check (source_kind in ('policy','catalog','faq','guide','support','other')),
  source_uri text,
  source_version integer not null default 1 check (source_version > 0),
  status text not null default 'draft' check (status in ('draft','ready','archived')),
  trust_class text not null default 'internal' check (trust_class in ('internal','merchant_provided','external_unverified')),
  content_hash text not null,
  metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata) = 'object'),
  created_by_user_id uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(scope_type, scope_id, source_key, source_version),
  check ((scope_type = 'global' and scope_id is null) or (scope_type <> 'global' and scope_id is not null)),
  check (length(trim(source_key)) between 2 and 160),
  check (length(trim(title)) between 2 and 240),
  check (length(trim(content_hash)) between 16 and 128)
);

create table if not exists public.ai_knowledge_chunks (
  id uuid primary key default gen_random_uuid(),
  source_id uuid not null references public.ai_knowledge_sources(id) on delete cascade,
  ordinal integer not null check (ordinal between 0 and 10000),
  content text not null check (length(trim(content)) between 1 and 8000),
  content_hash text not null check (length(trim(content_hash)) between 16 and 128),
  search_document tsvector generated always as (to_tsvector('simple', content)) stored,
  created_at timestamptz not null default now(),
  unique(source_id, ordinal)
);

alter table public.ai_knowledge_sources enable row level security;
alter table public.ai_knowledge_chunks enable row level security;
revoke all on public.ai_knowledge_sources, public.ai_knowledge_chunks from anon, authenticated;
grant select on public.ai_knowledge_sources, public.ai_knowledge_chunks to authenticated;
drop policy if exists ai_knowledge_sources_creator_select on public.ai_knowledge_sources;
create policy ai_knowledge_sources_creator_select on public.ai_knowledge_sources for select to authenticated using (private.current_user_is_creator());
drop policy if exists ai_knowledge_chunks_creator_select on public.ai_knowledge_chunks;
create policy ai_knowledge_chunks_creator_select on public.ai_knowledge_chunks for select to authenticated using (private.current_user_is_creator());

create index if not exists ai_knowledge_sources_scope_status_idx on public.ai_knowledge_sources(scope_type, scope_id, status, source_key, source_version desc);
create index if not exists ai_knowledge_sources_created_by_idx on public.ai_knowledge_sources(created_by_user_id);
create index if not exists ai_knowledge_chunks_source_ordinal_idx on public.ai_knowledge_chunks(source_id, ordinal);
create index if not exists ai_knowledge_chunks_search_idx on public.ai_knowledge_chunks using gin(search_document);

create or replace function private.ai_upsert_knowledge_source(
  p_scope_type text,
  p_scope_id uuid,
  p_source_key text,
  p_title text,
  p_source_kind text,
  p_source_uri text,
  p_source_version integer,
  p_status text,
  p_trust_class text,
  p_content_hash text,
  p_metadata jsonb default '{}'::jsonb,
  p_reason text default null
)
returns jsonb language plpgsql security definer
set search_path = public, private, pg_catalog
as $$
declare v_actor uuid := (select auth.uid()); v_source public.ai_knowledge_sources%rowtype;
begin
  if v_actor is null then raise exception using errcode = '28000', message = 'AUTH_REQUIRED'; end if;
  if not private.current_user_is_creator() then raise exception using errcode = '42501', message = 'AI_DEVELOPER_CREATOR_REQUIRED'; end if;
  if p_scope_type not in ('global','market','shop') or ((p_scope_type = 'global') <> (p_scope_id is null)) then raise exception using errcode = 'P0001', message = 'AI_KNOWLEDGE_SCOPE_INVALID'; end if;
  if length(trim(coalesce(p_source_key,''))) not between 2 and 160 or length(trim(coalesce(p_title,''))) not between 2 and 240 then raise exception using errcode = 'P0001', message = 'AI_KNOWLEDGE_SOURCE_INVALID'; end if;
  if p_source_kind not in ('policy','catalog','faq','guide','support','other') or p_status not in ('draft','ready','archived') or p_trust_class not in ('internal','merchant_provided','external_unverified') then raise exception using errcode = 'P0001', message = 'AI_KNOWLEDGE_SOURCE_INVALID'; end if;
  if p_source_version < 1 or length(trim(coalesce(p_content_hash,''))) < 16 or jsonb_typeof(coalesce(p_metadata, '{}'::jsonb)) <> 'object' then raise exception using errcode = 'P0001', message = 'AI_KNOWLEDGE_SOURCE_INVALID'; end if;
  if length(trim(coalesce(p_reason,''))) < 3 then raise exception using errcode = 'P0001', message = 'AI_REASON_REQUIRED'; end if;
  insert into public.ai_knowledge_sources(scope_type, scope_id, source_key, title, source_kind, source_uri, source_version, status, trust_class, content_hash, metadata, created_by_user_id, updated_at)
  values(p_scope_type, p_scope_id, trim(p_source_key), trim(p_title), p_source_kind, nullif(trim(p_source_uri),''), p_source_version, p_status, p_trust_class, trim(p_content_hash), coalesce(p_metadata, '{}'::jsonb), v_actor, now())
  on conflict (scope_type, scope_id, source_key, source_version) do update set title = excluded.title, source_kind = excluded.source_kind, source_uri = excluded.source_uri, status = excluded.status, trust_class = excluded.trust_class, content_hash = excluded.content_hash, metadata = excluded.metadata, updated_at = now()
  returning * into v_source;
  insert into public.audit_events(actor_user_id, action, resource_type, resource_id, metadata)
  values(v_actor, 'ai.knowledge_source_upserted', 'ai_knowledge_source', v_source.id::text, jsonb_build_object('scope_type', v_source.scope_type, 'scope_id', v_source.scope_id, 'source_key', v_source.source_key, 'source_version', v_source.source_version, 'status', v_source.status, 'reason', trim(p_reason)));
  return jsonb_build_object('source_id', v_source.id, 'source_key', v_source.source_key, 'source_version', v_source.source_version, 'status', v_source.status, 'content_hash', v_source.content_hash);
end;
$$;
revoke all on function private.ai_upsert_knowledge_source(text, uuid, text, text, text, text, integer, text, text, text, jsonb, text) from public, anon, authenticated;
grant execute on function private.ai_upsert_knowledge_source(text, uuid, text, text, text, text, integer, text, text, text, jsonb, text) to authenticated, service_role;
create or replace function public.ai_upsert_knowledge_source(p_scope_type text, p_scope_id uuid, p_source_key text, p_title text, p_source_kind text, p_source_uri text, p_source_version integer, p_status text, p_trust_class text, p_content_hash text, p_metadata jsonb default '{}'::jsonb, p_reason text default null)
returns jsonb language sql security invoker set search_path = public, pg_catalog
as $$ select private.ai_upsert_knowledge_source(p_scope_type, p_scope_id, p_source_key, p_title, p_source_kind, p_source_uri, p_source_version, p_status, p_trust_class, p_content_hash, p_metadata, p_reason); $$;
revoke all on function public.ai_upsert_knowledge_source(text, uuid, text, text, text, text, integer, text, text, text, jsonb, text) from public, anon;
grant execute on function public.ai_upsert_knowledge_source(text, uuid, text, text, text, text, integer, text, text, text, jsonb, text) to authenticated;

create or replace function private.ai_add_knowledge_chunk(p_source_id uuid, p_ordinal integer, p_content text, p_content_hash text, p_reason text)
returns jsonb language plpgsql security definer
set search_path = public, private, pg_catalog
as $$
declare v_actor uuid := (select auth.uid()); v_chunk public.ai_knowledge_chunks%rowtype; v_source public.ai_knowledge_sources%rowtype;
begin
  if v_actor is null then raise exception using errcode = '28000', message = 'AUTH_REQUIRED'; end if;
  if not private.current_user_is_creator() then raise exception using errcode = '42501', message = 'AI_DEVELOPER_CREATOR_REQUIRED'; end if;
  if p_ordinal < 0 or p_ordinal > 10000 or length(trim(coalesce(p_content,''))) not between 1 and 8000 or length(trim(coalesce(p_content_hash,''))) < 16 or length(trim(coalesce(p_reason,''))) < 3 then raise exception using errcode = 'P0001', message = 'AI_KNOWLEDGE_CHUNK_INVALID'; end if;
  select * into v_source from public.ai_knowledge_sources where id = p_source_id;
  if not found then raise exception using errcode = 'P0001', message = 'AI_KNOWLEDGE_SOURCE_NOT_FOUND'; end if;
  insert into public.ai_knowledge_chunks(source_id, ordinal, content, content_hash)
  values(p_source_id, p_ordinal, trim(p_content), trim(p_content_hash))
  on conflict (source_id, ordinal) do update set content = excluded.content, content_hash = excluded.content_hash
  returning * into v_chunk;
  insert into public.audit_events(actor_user_id, action, resource_type, resource_id, metadata)
  values(v_actor, 'ai.knowledge_chunk_upserted', 'ai_knowledge_chunk', v_chunk.id::text, jsonb_build_object('source_id', p_source_id, 'ordinal', p_ordinal, 'reason', trim(p_reason)));
  return jsonb_build_object('chunk_id', v_chunk.id, 'source_id', v_chunk.source_id, 'ordinal', v_chunk.ordinal, 'content_hash', v_chunk.content_hash);
end;
$$;
revoke all on function private.ai_add_knowledge_chunk(uuid, integer, text, text, text) from public, anon, authenticated;
grant execute on function private.ai_add_knowledge_chunk(uuid, integer, text, text, text) to authenticated, service_role;
create or replace function public.ai_add_knowledge_chunk(p_source_id uuid, p_ordinal integer, p_content text, p_content_hash text, p_reason text)
returns jsonb language sql security invoker set search_path = public, pg_catalog
as $$ select private.ai_add_knowledge_chunk(p_source_id, p_ordinal, p_content, p_content_hash, p_reason); $$;
revoke all on function public.ai_add_knowledge_chunk(uuid, integer, text, text, text) from public, anon;
grant execute on function public.ai_add_knowledge_chunk(uuid, integer, text, text, text) to authenticated;

create or replace function private.ai_search_knowledge(p_scope_type text, p_scope_id uuid, p_query text, p_limit integer default 8)
returns setof jsonb language plpgsql security definer
set search_path = public, private, pg_catalog
as $$
declare v_actor uuid := (select auth.uid()); v_enabled boolean;
begin
  if v_actor is null then raise exception using errcode = '28000', message = 'AUTH_REQUIRED'; end if;
  if p_scope_type not in ('global','market','shop') or ((p_scope_type = 'global') <> (p_scope_id is null)) then raise exception using errcode = 'P0001', message = 'AI_KNOWLEDGE_SCOPE_INVALID'; end if;
  if length(trim(coalesce(p_query,''))) not between 2 and 240 or p_limit < 1 or p_limit > 10 then raise exception using errcode = 'P0001', message = 'AI_KNOWLEDGE_QUERY_INVALID'; end if;
  select knowledge_enabled into v_enabled from public.ai_platform_settings_versions where status = 'active' order by version desc limit 1;
  if coalesce(v_enabled, false) is not true then raise exception using errcode = 'P0001', message = 'AI_KNOWLEDGE_DISABLED'; end if;
  if p_scope_type = 'shop' and not exists (select 1 from public.shops s join public.merchants m on m.id = s.merchant_id where s.id = p_scope_id and m.owner_user_id = v_actor) then raise exception using errcode = '42501', message = 'AI_SHOP_SCOPE_FORBIDDEN'; end if;
  return query
  select jsonb_build_object('source_id', s.id, 'source_key', s.source_key, 'source_title', s.title, 'source_kind', s.source_kind, 'source_version', s.source_version, 'trust_class', s.trust_class, 'content_hash', s.content_hash, 'chunk_id', c.id, 'ordinal', c.ordinal, 'snippet', left(c.content, 1200))
  from public.ai_knowledge_chunks c join public.ai_knowledge_sources s on s.id = c.source_id
  where s.status = 'ready' and (s.scope_type = 'global' or (s.scope_type = p_scope_type and s.scope_id = p_scope_id))
    and c.search_document @@ plainto_tsquery('simple', trim(p_query))
  order by ts_rank(c.search_document, plainto_tsquery('simple', trim(p_query))) desc, s.source_version desc, c.ordinal
  limit p_limit;
end;
$$;
revoke all on function private.ai_search_knowledge(text, uuid, text, integer) from public, anon, authenticated;
grant execute on function private.ai_search_knowledge(text, uuid, text, integer) to authenticated, service_role;
create or replace function public.ai_search_knowledge(p_scope_type text, p_scope_id uuid, p_query text, p_limit integer default 8)
returns setof jsonb language sql security invoker set search_path = public, pg_catalog
as $$ select * from private.ai_search_knowledge(p_scope_type, p_scope_id, p_query, p_limit); $$;
revoke all on function public.ai_search_knowledge(text, uuid, text, integer) from public, anon;
grant execute on function public.ai_search_knowledge(text, uuid, text, integer) to authenticated;

commit;
