-- Composable ERP core contracts and projection foundations.
-- This is a modular-monolith increment: no external broker, provider, WASM runtime,
-- schema-per-tenant move, or direct financial mutation is enabled here.

create table if not exists public.erp_module_registry (
  module_key text primary key check (module_key ~ '^[a-z][a-z0-9_]{1,63}$'),
  bounded_context text not null,
  owner_surface text not null check (owner_surface in ('customer','merchant','creator','system')),
  api_version text not null default 'v1',
  implementation_status text not null default 'foundation' check (implementation_status in ('foundation','reviewable','enabled','disabled','planned')),
  provider_required boolean not null default false,
  enabled boolean not null default false,
  route_key text,
  name_ar text not null,
  description_ar text not null,
  extension_slots jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

insert into public.erp_module_registry(module_key, bounded_context, owner_surface, api_version, implementation_status, provider_required, enabled, route_key, name_ar, description_ar, extension_slots)
values
 ('core_commerce','commerce','customer','v1','enabled',false,true,'commerce','التجارة الأساسية','التصفح والسلة والطلبات والدفع اليدوي غير الحاضن.','[]'::jsonb),
 ('ledger','ledger','creator','v1','reviewable',false,true,'erp-ledger','دفتر الأستاذ','الحقائق المالية غير القابلة للتعديل وإسقاط دفتر الأستاذ الموحد.','["ledger.summary","ledger.review"]'::jsonb),
 ('accounts_receivable','accounts_receivable','merchant','v1','foundation',false,false,'erp-ar','الذمم المدينة','الفواتير والتحصيلات المسجلة يدوياً ومسودات المتابعة.','["invoice.summary","customer.finance"]'::jsonb),
 ('procure_to_pay','procure_to_pay','merchant','v1','foundation',false,false,'erp-ap','المشتريات والدائنون','الموردون وأوامر الشراء والفواتير والمطابقة.','["bill.review","vendor.summary"]'::jsonb),
 ('crm_sales','crm_sales','merchant','v1','foundation',false,false,'erp-crm','إدارة العملاء والمبيعات','الحسابات والعقود والعروض وصحة العميل.','["customer.summary","quote.widgets"]'::jsonb),
 ('inventory_supply','inventory_supply','merchant','v1','enabled',false,true,'inventory','المخزون والتوريد','المخزون متعدد المواقع والتحويلات والتوقعات.','["inventory.summary"]'::jsonb),
 ('tax','tax','creator','v1','disabled',true,false,'erp-tax','الضرائب','قواعد ضريبية محلية ومهايئات مزود خارجية معطلة افتراضياً.','["tax.breakdown"]'::jsonb),
 ('ai_governance','ai_governance','creator','v1','reviewable',true,true,'ai-governance','حوكمة الذكاء الاصطناعي','السياسات والموافقات والذاكرة والتقييمات.','["ai.explanation","ai.review"]'::jsonb),
 ('events_workflows','events_workflows','creator','v1','reviewable',false,true,'erp-events','الأحداث وسير العمل','غلاف أحداث قابل للتكرار ونقاط تحقق للإسقاط.','["event.health"]'::jsonb),
 ('analytics_graph','analytics_graph','creator','v1','foundation',false,true,'erp-analytics','التحليلات والعلاقات','إسقاطات bounded وتقارير تشغيلية دون أن تصبح مصدر الحقيقة.','["analytics.summary","graph.summary"]'::jsonb)
on conflict (module_key) do update set bounded_context = excluded.bounded_context, owner_surface = excluded.owner_surface, api_version = excluded.api_version, provider_required = excluded.provider_required, route_key = excluded.route_key, name_ar = excluded.name_ar, description_ar = excluded.description_ar, extension_slots = excluded.extension_slots, updated_at = now();

-- Correct the deliberate boolean literal in the tax seed after keeping the seed readable above.
update public.erp_module_registry set enabled = false where module_key = 'tax';

create table if not exists public.erp_module_contracts (
  id uuid primary key default gen_random_uuid(),
  module_key text not null references public.erp_module_registry(module_key) on delete cascade,
  contract_key text not null,
  contract_kind text not null check (contract_kind in ('query','command','event','hook','extension_slot')),
  api_version text not null default 'v1',
  input_schema jsonb not null default '{}'::jsonb,
  output_schema jsonb not null default '{}'::jsonb,
  required_capability text,
  status text not null default 'draft' check (status in ('draft','active','deprecated','disabled')),
  created_at timestamptz not null default now(),
  unique (module_key, contract_key, api_version)
);
create index if not exists erp_module_contracts_module_status_idx on public.erp_module_contracts(module_key, status, contract_kind);

insert into public.erp_module_contracts(module_key, contract_key, contract_kind, api_version, required_capability, status)
values
 ('ledger','posted_journal_projection','command','v1','manage_reports','active'),
 ('events_workflows','event_envelope','event','v1','manage_reports','active'),
 ('events_workflows','projection_checkpoint','query','v1','manage_reports','active'),
 ('ai_governance','extension_manifest','extension_slot','v1','manage_policies','active')
on conflict (module_key, contract_key, api_version) do update set required_capability = excluded.required_capability, status = excluded.status;

alter table public.erp_event_outbox add column if not exists schema_version integer not null default 1;
alter table public.erp_event_outbox add column if not exists occurred_at timestamptz not null default now();
alter table public.erp_event_outbox add column if not exists valid_at timestamptz;
alter table public.erp_event_outbox add column if not exists correlation_id uuid not null default gen_random_uuid();
alter table public.erp_event_outbox add column if not exists causation_id uuid;
alter table public.erp_event_outbox add column if not exists payload_hash text;
alter table public.erp_event_outbox add column if not exists event_key text;
create index if not exists erp_event_outbox_event_key_idx on public.erp_event_outbox(event_key, created_at desc);
create index if not exists erp_event_outbox_correlation_idx on public.erp_event_outbox(correlation_id, created_at desc);

create table if not exists public.erp_event_inbox (
  id uuid primary key default gen_random_uuid(),
  consumer_key text not null,
  event_id uuid not null references public.erp_event_outbox(id) on delete restrict,
  event_schema_version integer not null default 1,
  payload_hash text,
  status text not null default 'received' check (status in ('received','processing','processed','failed','dead_letter')),
  attempts integer not null default 0 check (attempts >= 0),
  processed_at timestamptz,
  last_error_code text,
  created_at timestamptz not null default now(),
  unique (consumer_key, event_id)
);
create index if not exists erp_event_inbox_consumer_status_idx on public.erp_event_inbox(consumer_key, status, created_at);

create table if not exists public.erp_projection_checkpoints (
  consumer_key text primary key,
  module_key text not null references public.erp_module_registry(module_key) on delete restrict,
  last_event_id uuid references public.erp_event_outbox(id) on delete set null,
  last_event_created_at timestamptz,
  event_schema_version integer not null default 1,
  status text not null default 'idle' check (status in ('idle','running','blocked','failed')),
  lease_token_hash text,
  leased_until timestamptz,
  last_error_code text,
  updated_at timestamptz not null default now()
);
create index if not exists erp_projection_checkpoints_module_status_idx on public.erp_projection_checkpoints(module_key, status, updated_at desc);

create table if not exists public.erp_universal_journal_entries (
  id uuid primary key default gen_random_uuid(),
  source_journal_line_id uuid not null unique references public.erp_journal_lines(id) on delete restrict,
  organization_id uuid not null references public.erp_organizations(id) on delete restrict,
  book_id uuid not null references public.erp_accounting_books(id) on delete restrict,
  account_id uuid not null references public.erp_accounts(id) on delete restrict,
  ledger_class text not null check (ledger_class in ('leading','non_leading','extension','prediction','simulation')),
  entry_status text not null check (entry_status in ('posted','reversed','prediction','simulation')),
  posting_date date not null,
  transaction_time timestamptz not null,
  valid_from timestamptz not null,
  valid_to timestamptz,
  debit_minor bigint not null default 0 check (debit_minor >= 0),
  credit_minor bigint not null default 0 check (credit_minor >= 0),
  currency text not null check (char_length(currency) = 3),
  source_type text not null,
  source_id text,
  worktags jsonb not null default '{}'::jsonb,
  event_schema_version integer not null default 1,
  anomaly_score numeric(5,4),
  projected_at timestamptz not null default now(),
  check ((debit_minor > 0 and credit_minor = 0) or (credit_minor > 0 and debit_minor = 0)),
  check (valid_to is null or valid_to >= valid_from)
);
create index if not exists erp_universal_journal_org_date_idx on public.erp_universal_journal_entries(organization_id, posting_date desc, ledger_class);
create index if not exists erp_universal_journal_account_date_idx on public.erp_universal_journal_entries(account_id, posting_date desc);
create index if not exists erp_universal_journal_worktags_gin_idx on public.erp_universal_journal_entries using gin(worktags);

create table if not exists public.erp_extension_manifests (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid references public.erp_organizations(id) on delete cascade,
  owner_user_id uuid not null references public.profiles(id) on delete restrict,
  extension_key text not null check (extension_key ~ '^[a-z][a-z0-9_.-]{2,79}$'),
  name_ar text not null,
  version text not null check (char_length(version) between 1 and 40),
  runtime text not null default 'metadata_only' check (runtime in ('metadata_only','wasm_pending')),
  artifact_sha256 text,
  requested_capabilities jsonb not null default '[]'::jsonb,
  hook_keys jsonb not null default '[]'::jsonb,
  status text not null default 'draft' check (status in ('draft','review','approved','disabled','revoked')),
  rollout_scope jsonb not null default '{}'::jsonb,
  reason text not null check (char_length(trim(reason)) >= 3),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, extension_key, version)
);
create index if not exists erp_extension_manifests_scope_status_idx on public.erp_extension_manifests(organization_id, status, updated_at desc);
create index if not exists erp_extension_manifests_owner_idx on public.erp_extension_manifests(owner_user_id, updated_at desc);

-- Direct client access remains read-only and scoped. Mutations below use RPCs.
do $$
declare t text;
begin
  foreach t in array array['erp_module_registry','erp_module_contracts','erp_event_inbox','erp_projection_checkpoints','erp_universal_journal_entries','erp_extension_manifests'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on public.%I from anon, authenticated', t);
    execute format('grant select on public.%I to authenticated', t);
  end loop;
end $$;

create policy erp_module_registry_read on public.erp_module_registry for select to authenticated using (enabled or private.current_user_is_creator());
create policy erp_module_contracts_read on public.erp_module_contracts for select to authenticated using (status = 'active' and exists(select 1 from public.erp_module_registry m where m.module_key = public.erp_module_contracts.module_key and (m.enabled or private.current_user_is_creator())));
create policy erp_event_inbox_creator_read on public.erp_event_inbox for select to authenticated using (private.current_user_is_creator());
create policy erp_checkpoint_creator_read on public.erp_projection_checkpoints for select to authenticated using (private.current_user_is_creator());
create policy erp_universal_journal_scope_read on public.erp_universal_journal_entries for select to authenticated using (private.erp_org_visible(organization_id));
create policy erp_extension_manifest_scope_read on public.erp_extension_manifests for select to authenticated using (owner_user_id = (select auth.uid()) or private.current_user_is_creator() or (organization_id is not null and private.erp_org_visible(organization_id)));

create or replace function private.erp_enqueue_event(p_organization_id uuid, p_event_type text, p_aggregate_type text, p_aggregate_id text, p_payload_redacted jsonb, p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path = public, private, pg_catalog as $$
declare v_user uuid := (select auth.uid()); v_id uuid; v_payload jsonb := coalesce(p_payload_redacted, '{}'::jsonb);
begin
  if v_user is null or not private.erp_org_visible(p_organization_id) then raise exception using errcode = '42501', message = 'ERP_SCOPE_DENIED'; end if;
  if length(trim(p_event_type)) < 3 or length(trim(p_aggregate_type)) < 2 or length(trim(p_idempotency_key)) < 8 then raise exception using errcode = '22023', message = 'ERP_EVENT_INPUT_INVALID'; end if;
  insert into public.erp_event_outbox(organization_id, event_type, aggregate_type, aggregate_id, payload_redacted, idempotency_key, schema_version, occurred_at, valid_at, correlation_id, event_key, payload_hash)
  values(p_organization_id, trim(p_event_type), trim(p_aggregate_type), nullif(trim(p_aggregate_id), ''), v_payload, trim(p_idempotency_key), 1, now(), now(), gen_random_uuid(), trim(p_event_type), md5(v_payload::text))
  on conflict (event_type, idempotency_key) do nothing
  returning id into v_id;
  if v_id is null then select id into v_id from public.erp_event_outbox where event_type = trim(p_event_type) and idempotency_key = trim(p_idempotency_key); end if;
  insert into public.audit_events(actor_user_id, action, resource_type, resource_id, metadata) values(v_user, 'erp.event_enqueued', 'erp_event_outbox', v_id::text, jsonb_build_object('event_type', trim(p_event_type), 'schema_version', 1));
  return jsonb_build_object('event_id', v_id, 'status', 'pending');
end;
$$;
revoke all on function private.erp_enqueue_event(uuid, text, text, text, jsonb, text) from public, anon, authenticated;
grant execute on function private.erp_enqueue_event(uuid, text, text, text, jsonb, text) to authenticated, service_role;
create or replace function public.erp_enqueue_event(p_organization_id uuid, p_event_type text, p_aggregate_type text, p_aggregate_id text, p_payload_redacted jsonb, p_idempotency_key text)
returns jsonb language sql security invoker set search_path = public, pg_catalog as $$ select private.erp_enqueue_event(p_organization_id, p_event_type, p_aggregate_type, p_aggregate_id, p_payload_redacted, p_idempotency_key); $$;
revoke all on function public.erp_enqueue_event(uuid, text, text, text, jsonb, text) from public, anon;
grant execute on function public.erp_enqueue_event(uuid, text, text, text, jsonb, text) to authenticated;

create or replace function private.erp_project_posted_journal_batch(p_batch_id uuid, p_reason text)
returns jsonb language plpgsql security definer set search_path = public, private, pg_catalog as $$
declare v_user uuid := (select auth.uid()); v_batch public.erp_journal_batches%rowtype; v_count integer := 0; v_org uuid;
begin
  select * into v_batch from public.erp_journal_batches where id = p_batch_id;
  if not found or not private.erp_org_visible(v_batch.organization_id) then raise exception using errcode = '42501', message = 'ERP_SCOPE_DENIED'; end if;
  if v_batch.status <> 'posted' then raise exception using errcode = '55000', message = 'ERP_JOURNAL_NOT_POSTED'; end if;
  if length(trim(coalesce(p_reason, ''))) < 3 then raise exception using errcode = '22023', message = 'ERP_REASON_REQUIRED'; end if;
  insert into public.erp_universal_journal_entries(source_journal_line_id, organization_id, book_id, account_id, ledger_class, entry_status, posting_date, transaction_time, valid_from, debit_minor, credit_minor, currency, source_type, source_id, worktags, event_schema_version)
  select l.id, v_batch.organization_id, v_batch.book_id, l.account_id, 'leading', case when v_batch.status = 'reversed' then 'reversed' else 'posted' end, v_batch.posting_date, coalesce(v_batch.posted_at, v_batch.created_at), coalesce(v_batch.posted_at, v_batch.created_at), l.debit_minor, l.credit_minor, l.currency, v_batch.source_type, v_batch.source_id, l.dimensions, 1
  from public.erp_journal_lines l
  where l.batch_id = p_batch_id
  on conflict (source_journal_line_id) do nothing;
  get diagnostics v_count = row_count;
  insert into public.audit_events(actor_user_id, action, resource_type, resource_id, metadata) values(v_user, 'erp.universal_journal_projected', 'erp_journal_batch', p_batch_id::text, jsonb_build_object('projected_count', v_count, 'reason', trim(p_reason)));
  return jsonb_build_object('journal_batch_id', p_batch_id, 'projected_count', v_count, 'status', 'projected');
end;
$$;
revoke all on function private.erp_project_posted_journal_batch(uuid, text) from public, anon, authenticated;
grant execute on function private.erp_project_posted_journal_batch(uuid, text) to authenticated, service_role;
create or replace function public.erp_project_posted_journal_batch(p_batch_id uuid, p_reason text)
returns jsonb language sql security invoker set search_path = public, pg_catalog as $$ select private.erp_project_posted_journal_batch(p_batch_id, p_reason); $$;
revoke all on function public.erp_project_posted_journal_batch(uuid, text) from public, anon;
grant execute on function public.erp_project_posted_journal_batch(uuid, text) to authenticated;

create or replace function private.erp_list_composable_modules()
returns table(module_key text, bounded_context text, owner_surface text, api_version text, implementation_status text, provider_required boolean, enabled boolean, route_key text, name_ar text, description_ar text, extension_slots jsonb)
language sql stable security definer set search_path = public, private, pg_catalog as $$
  select module_key, bounded_context, owner_surface, api_version, implementation_status, provider_required, enabled, route_key, name_ar, description_ar, extension_slots
  from public.erp_module_registry
  where enabled or private.current_user_is_creator()
  order by owner_surface, module_key
$$;
revoke all on function private.erp_list_composable_modules() from public, anon, authenticated;
grant execute on function private.erp_list_composable_modules() to authenticated, service_role;
create or replace function public.erp_list_composable_modules()
returns table(module_key text, bounded_context text, owner_surface text, api_version text, implementation_status text, provider_required boolean, enabled boolean, route_key text, name_ar text, description_ar text, extension_slots jsonb)
language sql security invoker set search_path = public, pg_catalog as $$ select * from private.erp_list_composable_modules(); $$;
revoke all on function public.erp_list_composable_modules() from public, anon;
grant execute on function public.erp_list_composable_modules() to authenticated;

create or replace function private.erp_get_event_mesh_dashboard(p_organization_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public, private, pg_catalog as $$
declare v_result jsonb;
begin
  if p_organization_id is null or not private.erp_org_visible(p_organization_id) then raise exception using errcode = '42501', message = 'ERP_SCOPE_DENIED'; end if;
  select jsonb_build_object(
    'pending_event_count', (select count(*) from public.erp_event_outbox where organization_id = p_organization_id and status in ('pending','leased','failed')),
    'dead_letter_event_count', (select count(*) from public.erp_event_outbox where organization_id = p_organization_id and status = 'dead_letter'),
    'inbox_failed_count', (select count(*) from public.erp_event_inbox where status in ('failed','dead_letter')),
    'checkpoint_count', (select count(*) from public.erp_projection_checkpoints),
    'active_module_count', (select count(*) from public.erp_module_registry where enabled),
    'external_delivery_enabled', false,
    'worker_state', 'disabled_by_default'
  ) into v_result;
  return v_result;
end;
$$;
revoke all on function private.erp_get_event_mesh_dashboard(uuid) from public, anon, authenticated;
grant execute on function private.erp_get_event_mesh_dashboard(uuid) to authenticated, service_role;
create or replace function public.erp_get_event_mesh_dashboard(p_organization_id uuid)
returns jsonb language sql security invoker set search_path = public, pg_catalog as $$ select private.erp_get_event_mesh_dashboard(p_organization_id); $$;
revoke all on function public.erp_get_event_mesh_dashboard(uuid) from public, anon;
grant execute on function public.erp_get_event_mesh_dashboard(uuid) to authenticated;

create or replace function private.erp_list_universal_journal(p_organization_id uuid, p_from_date date default null, p_to_date date default null, p_limit integer default 50)
returns table(entry_id uuid, posting_date date, ledger_class text, entry_status text, account_id uuid, debit_minor bigint, credit_minor bigint, currency text, source_type text, source_id text, worktags jsonb, projected_at timestamptz)
language sql stable security definer set search_path = public, private, pg_catalog as $$
  select id, posting_date, ledger_class, entry_status, account_id, debit_minor, credit_minor, currency, source_type, source_id, worktags, projected_at
  from public.erp_universal_journal_entries
  where private.erp_org_visible(p_organization_id)
    and organization_id = p_organization_id
    and (p_from_date is null or posting_date >= p_from_date)
    and (p_to_date is null or posting_date <= p_to_date)
  order by posting_date desc, projected_at desc
  limit least(greatest(coalesce(p_limit, 50), 1), 100)
$$;
revoke all on function private.erp_list_universal_journal(uuid, date, date, integer) from public, anon, authenticated;
grant execute on function private.erp_list_universal_journal(uuid, date, date, integer) to authenticated, service_role;
create or replace function public.erp_list_universal_journal(p_organization_id uuid, p_from_date date default null, p_to_date date default null, p_limit integer default 50)
returns table(entry_id uuid, posting_date date, ledger_class text, entry_status text, account_id uuid, debit_minor bigint, credit_minor bigint, currency text, source_type text, source_id text, worktags jsonb, projected_at timestamptz)
language sql security invoker set search_path = public, pg_catalog as $$ select * from private.erp_list_universal_journal(p_organization_id, p_from_date, p_to_date, p_limit); $$;
revoke all on function public.erp_list_universal_journal(uuid, date, date, integer) from public, anon;
grant execute on function public.erp_list_universal_journal(uuid, date, date, integer) to authenticated;

create or replace function private.erp_save_extension_manifest(p_organization_id uuid, p_extension_key text, p_name_ar text, p_version text, p_runtime text, p_artifact_sha256 text, p_requested_capabilities jsonb, p_hook_keys jsonb, p_rollout_scope jsonb, p_reason text)
returns jsonb language plpgsql security definer set search_path = public, private, pg_catalog as $$
declare v_user uuid := (select auth.uid()); v_id uuid;
begin
  if v_user is null or not private.current_user_is_creator() then raise exception using errcode = '42501', message = 'CREATOR_SCOPE_DENIED'; end if;
  if p_organization_id is not null and not exists(select 1 from public.erp_organizations where id = p_organization_id) then raise exception using errcode = '22023', message = 'ERP_ORGANIZATION_INVALID'; end if;
  if length(trim(p_extension_key)) < 3 or length(trim(p_name_ar)) < 2 or length(trim(p_version)) < 1 or p_runtime not in ('metadata_only','wasm_pending') or length(trim(coalesce(p_reason, ''))) < 3 then raise exception using errcode = '22023', message = 'ERP_EXTENSION_INPUT_INVALID'; end if;
  if p_runtime = 'wasm_pending' and nullif(trim(coalesce(p_artifact_sha256, '')), '') is null then raise exception using errcode = '22023', message = 'ERP_EXTENSION_HASH_REQUIRED'; end if;
  insert into public.erp_extension_manifests(organization_id, owner_user_id, extension_key, name_ar, version, runtime, artifact_sha256, requested_capabilities, hook_keys, status, rollout_scope, reason)
  values(p_organization_id, v_user, lower(trim(p_extension_key)), trim(p_name_ar), trim(p_version), p_runtime, nullif(trim(p_artifact_sha256), ''), coalesce(p_requested_capabilities, '[]'::jsonb), coalesce(p_hook_keys, '[]'::jsonb), 'review', coalesce(p_rollout_scope, '{}'::jsonb), trim(p_reason))
  on conflict (organization_id, extension_key, version) do update set name_ar = excluded.name_ar, runtime = excluded.runtime, artifact_sha256 = excluded.artifact_sha256, requested_capabilities = excluded.requested_capabilities, hook_keys = excluded.hook_keys, status = 'review', rollout_scope = excluded.rollout_scope, reason = excluded.reason, updated_at = now()
  returning id into v_id;
  insert into public.audit_events(actor_user_id, action, resource_type, resource_id, metadata) values(v_user, 'erp.extension_manifest_saved', 'erp_extension_manifest', v_id::text, jsonb_build_object('extension_key', lower(trim(p_extension_key)), 'runtime', p_runtime, 'reason', trim(p_reason)));
  return jsonb_build_object('extension_manifest_id', v_id, 'status', 'review', 'execution_enabled', false);
end;
$$;
revoke all on function private.erp_save_extension_manifest(uuid, text, text, text, text, text, jsonb, jsonb, jsonb, text) from public, anon, authenticated;
grant execute on function private.erp_save_extension_manifest(uuid, text, text, text, text, text, jsonb, jsonb, jsonb, text) to authenticated, service_role;
create or replace function public.erp_save_extension_manifest(p_organization_id uuid, p_extension_key text, p_name_ar text, p_version text, p_runtime text, p_artifact_sha256 text, p_requested_capabilities jsonb, p_hook_keys jsonb, p_rollout_scope jsonb, p_reason text)
returns jsonb language sql security invoker set search_path = public, pg_catalog as $$ select private.erp_save_extension_manifest(p_organization_id, p_extension_key, p_name_ar, p_version, p_runtime, p_artifact_sha256, p_requested_capabilities, p_hook_keys, p_rollout_scope, p_reason); $$;
revoke all on function public.erp_save_extension_manifest(uuid, text, text, text, text, text, jsonb, jsonb, jsonb, text) from public, anon;
grant execute on function public.erp_save_extension_manifest(uuid, text, text, text, text, text, jsonb, jsonb, jsonb, text) to authenticated;
