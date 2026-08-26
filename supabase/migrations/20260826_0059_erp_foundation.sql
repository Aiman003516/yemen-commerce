-- ERP Foundation: modular accounting, CRM, operations, events, and provider gates.
-- This migration adds safe foundations for the supplied 32-feature roadmap.
-- It never creates a wallet, settles funds, verifies payment proof, or stores secrets.

create table if not exists public.erp_feature_registry (
  feature_key text primary key,
  module_key text not null,
  name_ar text not null,
  name_en text not null,
  implementation_status text not null default 'foundation' check (implementation_status in ('foundation','reviewable','provider_ready','disabled','planned')),
  provider_required boolean not null default false,
  enabled boolean not null default false,
  description text not null,
  updated_at timestamptz not null default now()
);

insert into public.erp_feature_registry(feature_key, module_key, name_ar, name_en, implementation_status, provider_required, enabled, description) values
('multi_entity_consolidation','accounting','توحيد الكيانات والاستبعادات','Multi-entity consolidation and elimination','foundation',false,false,'Entity hierarchy, consolidation previews, and intercompany elimination proposals.'),
('multi_book_accounting','accounting','دفاتر محاسبية متعددة','Multi-book accounting','foundation',false,false,'Parallel local, IFRS, US GAAP, and management books.'),
('revenue_recognition','accounting','الاعتراف بالإيراد','Revenue recognition','foundation',false,false,'Contract schedules and milestone-based recognition proposals.'),
('dimensional_reporting','analytics','التقارير متعددة الأبعاد','Dimensional reporting','foundation',false,false,'Extensible dimensions for location, department, project, and fund.'),
('cost_allocation','accounting','توزيع التكاليف','Advanced cost allocation','foundation',false,false,'Driver-based allocation previews with approval before posting.'),
('intercompany_netting','accounting','المقاصة بين الكيانات','Intercompany netting','foundation',false,false,'Netting batches and settlement proposals without platform custody.'),
('tax_engine','providers','محرك الضرائب','Tax engine','provider_ready',true,false,'Local tax rules and optional server-side tax-provider adapter.'),
('project_accounting','accounting','محاسبة المشاريع','Project accounting and capitalization','foundation',false,false,'Project costs and capitalization proposals.'),
('grant_fund_accounting','accounting','محاسبة المنح والصناديق','Grant and fund accounting','foundation',false,false,'Restricted and unrestricted fund dimensions.'),
('ap_ocr','procure_to_pay','استخراج فواتير الموردين','Accounts payable OCR','provider_ready',true,false,'Private invoice evidence, extraction drafts, and approval queues.'),
('bank_reconciliation','procure_to_pay','مطابقة كشوف الحساب','Bank reconciliation','provider_ready',true,false,'Statement imports and confidence-ranked match candidates.'),
('cashflow_forecasting','analytics','توقع التدفق النقدي','Cash-flow forecasting','reviewable',false,false,'Advisory AR/AP forecast snapshots with confidence bands.'),
('fraud_anomaly_detection','risk','كشف الشذوذ والاحتيال','Fraud and anomaly detection','reviewable',false,false,'Explainable findings; no automatic payment or account action.'),
('dunning_collections','crm','التحصيل والمتابعة','Dunning and collections','reviewable',false,false,'Merchant-approved collection plans and message drafts.'),
('demand_forecasting','inventory','توقع الطلب والمخزون','Demand and inventory forecasting','reviewable',false,false,'Forecast snapshots and purchase suggestions.'),
('discount_optimization','procure_to_pay','تحسين خصومات السداد','Dynamic discount optimization','reviewable',false,false,'Advisory working-capital scenarios.'),
('vendor_negotiation','procure_to_pay','التفاوض مع الموردين','Agentic vendor negotiation','provider_ready',true,false,'Bounded quote drafts; no autonomous external ordering.'),
('cpq','sales','التسعير والعروض المركبة','Configure, price, quote','foundation',false,false,'Bundle configuration, deterministic rules, and quote versions.'),
('customer_health','crm','صحة العميل والاحتفاظ به','Customer health and churn','reviewable',false,false,'Explainable customer-health snapshots.'),
('contract_lifecycle','crm','دورة حياة العقود','Contract lifecycle management','provider_ready',true,false,'Private contract versions and optional signature adapter.'),
('self_service_portals','crm','بوابات الخدمة الذاتية','Omnichannel self-service','foundation',false,false,'Scoped order, invoice, ticket, and contract views.'),
('ticket_routing','crm','توجيه التذاكر','Multi-agent ticket routing','foundation',false,false,'Rule-based support routing with department queues.'),
('subscriptions_entitlements','sales','الاشتراكات والاستحقاقات','Subscriptions and entitlements','foundation',false,false,'Plans, subscriptions, prorations, and entitlement projections.'),
('field_service','operations','الخدمة الميدانية','Field service and dispatch','provider_ready',true,false,'Work orders, assignments, and inventory consumption.'),
('financial_customer_360','analytics','الرؤية المالية الشاملة للعميل','Financial customer 360','foundation',false,false,'Bounded profitability, AR, LTV proxy, and support summary.'),
('api_first_composable','platform','معمارية API قابلة للتركيب','API-first composable architecture','foundation',false,false,'Versioned RPC and adapter contracts.'),
('event_pubsub_webhooks','platform','الأحداث وWebhooks','Event-driven webhooks','foundation',true,false,'Signed, retried, idempotent delivery foundations.'),
('multi_tenant_rls','platform','عزل المستأجرين عبر RLS','Multi-tenant RLS','foundation',false,false,'Organization, market, and shop scope at the database boundary.'),
('unified_graph','analytics','نموذج العلاقات الموحد','Unified relationship graph','foundation',false,false,'Redacted relationship projection for reporting.'),
('rule_workflows','platform','محرك قواعد سير العمل','Rule-based workflow engine','foundation',false,false,'Versioned trigger, condition, action, and approval definitions.'),
('olap_rollups','analytics','التحليلات المرحلية','OLAP-oriented rollups','foundation',false,false,'Bounded daily/hourly rollups separate from transactional reads.'),
('idempotent_api','platform','واجهات مقاومة للتكرار','Idempotent API design','foundation',false,false,'Idempotency keys and replay-safe RPC boundaries.')
on conflict (feature_key) do update set module_key = excluded.module_key, name_ar = excluded.name_ar, name_en = excluded.name_en, description = excluded.description, provider_required = excluded.provider_required;

create table if not exists public.erp_organizations (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references public.profiles(id) on delete restrict,
  merchant_id uuid references public.merchants(id) on delete restrict,
  market_id uuid not null references public.markets(id) on delete restrict,
  code text not null check (code ~ '^[A-Z0-9][A-Z0-9_-]{1,31}$'),
  name_ar text not null check (char_length(trim(name_ar)) between 2 and 160),
  legal_name text,
  base_currency text not null default 'YER' check (char_length(base_currency) = 3),
  status text not null default 'draft' check (status in ('draft','active','paused','archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (market_id, code)
);
create index if not exists erp_organizations_owner_idx on public.erp_organizations(owner_user_id);
create index if not exists erp_organizations_merchant_idx on public.erp_organizations(merchant_id);

create table if not exists public.erp_legal_entities (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.erp_organizations(id) on delete cascade,
  code text not null check (code ~ '^[A-Z0-9][A-Z0-9_-]{1,31}$'),
  name_ar text not null,
  registration_reference text,
  tax_reference text,
  status text not null default 'draft' check (status in ('draft','active','paused','archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, code)
);
create index if not exists erp_legal_entities_org_idx on public.erp_legal_entities(organization_id);

create table if not exists public.erp_accounting_books (
  id uuid primary key default gen_random_uuid(),
  legal_entity_id uuid not null references public.erp_legal_entities(id) on delete cascade,
  code text not null check (code ~ '^[A-Z0-9][A-Z0-9_-]{1,31}$'),
  name_ar text not null,
  accounting_basis text not null check (accounting_basis in ('local_tax','ifrs','us_gaap','management','fund')),
  currency text not null default 'YER' check (char_length(currency) = 3),
  status text not null default 'draft' check (status in ('draft','active','paused','archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (legal_entity_id, code)
);
create index if not exists erp_books_entity_idx on public.erp_accounting_books(legal_entity_id);

create table if not exists public.erp_accounts (
  id uuid primary key default gen_random_uuid(),
  book_id uuid not null references public.erp_accounting_books(id) on delete cascade,
  parent_account_id uuid references public.erp_accounts(id) on delete restrict,
  code text not null,
  name_ar text not null,
  account_type text not null check (account_type in ('asset','liability','equity','revenue','expense','memorandum')),
  normal_balance text not null check (normal_balance in ('debit','credit')),
  allow_posting boolean not null default true,
  status text not null default 'active' check (status in ('active','archived')),
  created_at timestamptz not null default now(),
  unique (book_id, code)
);
create index if not exists erp_accounts_book_idx on public.erp_accounts(book_id);

create table if not exists public.erp_dimensions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.erp_organizations(id) on delete cascade,
  dimension_key text not null check (dimension_key ~ '^[a-z][a-z0-9_]{1,47}$'),
  label_ar text not null,
  value_type text not null default 'text' check (value_type in ('text','uuid','number','date')),
  is_required boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (organization_id, dimension_key)
);
create index if not exists erp_dimensions_org_idx on public.erp_dimensions(organization_id);

create table if not exists public.erp_dimension_values (
  id uuid primary key default gen_random_uuid(),
  dimension_id uuid not null references public.erp_dimensions(id) on delete cascade,
  value_key text not null,
  label_ar text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (dimension_id, value_key)
);
create index if not exists erp_dimension_values_dimension_idx on public.erp_dimension_values(dimension_id);

create table if not exists public.erp_journal_batches (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.erp_organizations(id) on delete restrict,
  book_id uuid not null references public.erp_accounting_books(id) on delete restrict,
  source_type text not null,
  source_id text,
  idempotency_key text not null,
  posting_date date not null default current_date,
  status text not null default 'draft' check (status in ('draft','posted','reversed','voided')),
  description_ar text,
  created_by_user_id uuid not null references public.profiles(id) on delete restrict,
  posted_by_user_id uuid references public.profiles(id) on delete restrict,
  posted_at timestamptz,
  created_at timestamptz not null default now(),
  unique (organization_id, idempotency_key)
);
create index if not exists erp_journal_batches_org_date_idx on public.erp_journal_batches(organization_id, posting_date desc);
create index if not exists erp_journal_batches_status_idx on public.erp_journal_batches(status, posting_date desc);

create table if not exists public.erp_journal_lines (
  id uuid primary key default gen_random_uuid(),
  batch_id uuid not null references public.erp_journal_batches(id) on delete restrict,
  account_id uuid not null references public.erp_accounts(id) on delete restrict,
  line_number integer not null check (line_number > 0),
  debit_minor bigint not null default 0 check (debit_minor >= 0),
  credit_minor bigint not null default 0 check (credit_minor >= 0),
  currency text not null default 'YER' check (char_length(currency) = 3),
  description_ar text,
  dimensions jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  check ((debit_minor > 0 and credit_minor = 0) or (credit_minor > 0 and debit_minor = 0)),
  unique (batch_id, line_number)
);
create index if not exists erp_journal_lines_batch_idx on public.erp_journal_lines(batch_id);
create index if not exists erp_journal_lines_account_idx on public.erp_journal_lines(account_id, created_at desc);

create table if not exists public.erp_revenue_contracts (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.erp_organizations(id) on delete restrict,
  customer_user_id uuid references public.profiles(id) on delete restrict,
  merchant_order_id uuid references public.merchant_orders(id) on delete set null,
  contract_reference text not null,
  currency text not null default 'YER' check (char_length(currency) = 3),
  total_minor bigint not null check (total_minor >= 0),
  recognition_method text not null check (recognition_method in ('point_in_time','straight_line','milestone','usage')),
  start_date date not null,
  end_date date,
  status text not null default 'draft' check (status in ('draft','approved','active','completed','cancelled')),
  created_by_user_id uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  unique (organization_id, contract_reference),
  check (end_date is null or end_date >= start_date)
);
create index if not exists erp_revenue_contracts_org_status_idx on public.erp_revenue_contracts(organization_id, status);

create table if not exists public.erp_revenue_schedules (
  id uuid primary key default gen_random_uuid(),
  contract_id uuid not null references public.erp_revenue_contracts(id) on delete restrict,
  recognition_date date not null,
  amount_minor bigint not null check (amount_minor >= 0),
  status text not null default 'planned' check (status in ('planned','recognized','reversed')),
  journal_batch_id uuid references public.erp_journal_batches(id) on delete restrict,
  created_at timestamptz not null default now(),
  unique (contract_id, recognition_date)
);
create index if not exists erp_revenue_schedules_contract_idx on public.erp_revenue_schedules(contract_id, recognition_date);

create table if not exists public.erp_consolidation_runs (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.erp_organizations(id) on delete restrict,
  reporting_date date not null,
  source_book_ids jsonb not null default '[]'::jsonb,
  status text not null default 'preview' check (status in ('preview','approved','posted','cancelled')),
  elimination_total_minor bigint not null default 0 check (elimination_total_minor >= 0),
  output jsonb not null default '{}'::jsonb,
  created_by_user_id uuid not null references public.profiles(id) on delete restrict,
  approved_by_user_id uuid references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now()
);
create index if not exists erp_consolidation_runs_org_date_idx on public.erp_consolidation_runs(organization_id, reporting_date desc);

create table if not exists public.erp_allocation_rules (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.erp_organizations(id) on delete cascade,
  name_ar text not null,
  source_account_id uuid references public.erp_accounts(id) on delete restrict,
  driver_key text not null,
  allocation_map jsonb not null default '{}'::jsonb,
  status text not null default 'draft' check (status in ('draft','active','archived')),
  created_by_user_id uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now()
);
create index if not exists erp_allocation_rules_org_idx on public.erp_allocation_rules(organization_id, status);

create table if not exists public.erp_allocation_runs (
  id uuid primary key default gen_random_uuid(),
  rule_id uuid not null references public.erp_allocation_rules(id) on delete restrict,
  period_start date not null,
  period_end date not null,
  status text not null default 'preview' check (status in ('preview','approved','posted','cancelled')),
  preview jsonb not null default '{}'::jsonb,
  journal_batch_id uuid references public.erp_journal_batches(id) on delete restrict,
  created_by_user_id uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  check (period_end >= period_start)
);
create index if not exists erp_allocation_runs_rule_idx on public.erp_allocation_runs(rule_id, period_end desc);

create table if not exists public.erp_funds (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.erp_organizations(id) on delete cascade,
  fund_code text not null,
  name_ar text not null,
  restriction_type text not null check (restriction_type in ('restricted','unrestricted')),
  budget_minor bigint not null default 0 check (budget_minor >= 0),
  status text not null default 'active' check (status in ('draft','active','closed')),
  created_at timestamptz not null default now(),
  unique (organization_id, fund_code)
);
create index if not exists erp_funds_org_idx on public.erp_funds(organization_id, status);

create table if not exists public.erp_grants (
  id uuid primary key default gen_random_uuid(),
  fund_id uuid not null references public.erp_funds(id) on delete restrict,
  grant_reference text not null,
  donor_name text,
  start_date date not null,
  end_date date,
  amount_minor bigint not null check (amount_minor >= 0),
  status text not null default 'draft' check (status in ('draft','active','closed')),
  created_at timestamptz not null default now(),
  unique (fund_id, grant_reference),
  check (end_date is null or end_date >= start_date)
);
create index if not exists erp_grants_fund_idx on public.erp_grants(fund_id, status);

create table if not exists public.erp_projects (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.erp_organizations(id) on delete cascade,
  project_code text not null,
  name_ar text not null,
  budget_minor bigint not null default 0 check (budget_minor >= 0),
  status text not null default 'draft' check (status in ('draft','active','completed','cancelled')),
  start_date date,
  end_date date,
  created_by_user_id uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  unique (organization_id, project_code),
  check (end_date is null or start_date is null or end_date >= start_date)
);
create index if not exists erp_projects_org_status_idx on public.erp_projects(organization_id, status);

create table if not exists public.erp_project_costs (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.erp_projects(id) on delete restrict,
  source_type text not null,
  source_id text,
  amount_minor bigint not null check (amount_minor >= 0),
  currency text not null default 'YER' check (char_length(currency) = 3),
  capitalization_candidate boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists erp_project_costs_project_idx on public.erp_project_costs(project_id, created_at desc);

create table if not exists public.erp_capitalization_proposals (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.erp_projects(id) on delete restrict,
  amount_minor bigint not null check (amount_minor >= 0),
  asset_name_ar text not null,
  useful_life_months integer check (useful_life_months between 1 and 1200),
  status text not null default 'proposed' check (status in ('proposed','approved','posted','rejected')),
  journal_batch_id uuid references public.erp_journal_batches(id) on delete restrict,
  created_by_user_id uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now()
);
create index if not exists erp_capitalization_project_idx on public.erp_capitalization_proposals(project_id, status);

create table if not exists public.erp_vendors (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.erp_organizations(id) on delete cascade,
  display_name text not null,
  phone text,
  email text,
  tax_reference text,
  payment_terms_days integer not null default 0 check (payment_terms_days between 0 and 3650),
  status text not null default 'active' check (status in ('draft','active','blocked','archived')),
  created_at timestamptz not null default now()
);
create index if not exists erp_vendors_org_status_idx on public.erp_vendors(organization_id, status);

create table if not exists public.erp_purchase_orders (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.erp_organizations(id) on delete restrict,
  vendor_id uuid not null references public.erp_vendors(id) on delete restrict,
  purchase_reference text not null,
  currency text not null default 'YER' check (char_length(currency) = 3),
  total_minor bigint not null default 0 check (total_minor >= 0),
  status text not null default 'draft' check (status in ('draft','pending_approval','approved','partially_received','received','cancelled')),
  idempotency_key text not null,
  created_by_user_id uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  unique (organization_id, purchase_reference),
  unique (organization_id, idempotency_key)
);
create index if not exists erp_purchase_orders_vendor_status_idx on public.erp_purchase_orders(vendor_id, status);

create table if not exists public.erp_purchase_order_lines (
  id uuid primary key default gen_random_uuid(),
  purchase_order_id uuid not null references public.erp_purchase_orders(id) on delete restrict,
  product_id uuid references public.products(id) on delete set null,
  description_ar text not null,
  quantity numeric(18,3) not null check (quantity > 0),
  unit_price_minor bigint not null check (unit_price_minor >= 0),
  line_total_minor bigint not null check (line_total_minor >= 0),
  received_quantity numeric(18,3) not null default 0 check (received_quantity >= 0 and received_quantity <= quantity),
  created_at timestamptz not null default now()
);
create index if not exists erp_po_lines_order_idx on public.erp_purchase_order_lines(purchase_order_id);

create table if not exists public.erp_bills (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.erp_organizations(id) on delete restrict,
  vendor_id uuid not null references public.erp_vendors(id) on delete restrict,
  purchase_order_id uuid references public.erp_purchase_orders(id) on delete set null,
  bill_reference text not null,
  currency text not null default 'YER' check (char_length(currency) = 3),
  subtotal_minor bigint not null default 0 check (subtotal_minor >= 0),
  tax_minor bigint not null default 0 check (tax_minor >= 0),
  total_minor bigint not null default 0 check (total_minor >= 0),
  due_date date,
  status text not null default 'draft' check (status in ('draft','pending_match','pending_approval','approved','partially_paid','paid','voided')),
  evidence_storage_key text,
  idempotency_key text not null,
  created_by_user_id uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  unique (organization_id, bill_reference),
  unique (organization_id, idempotency_key)
);
create index if not exists erp_bills_org_due_idx on public.erp_bills(organization_id, due_date, status);

create table if not exists public.erp_bill_matches (
  id uuid primary key default gen_random_uuid(),
  bill_id uuid not null references public.erp_bills(id) on delete restrict,
  purchase_order_id uuid references public.erp_purchase_orders(id) on delete set null,
  confidence numeric(5,4) not null default 0 check (confidence between 0 and 1),
  match_basis jsonb not null default '{}'::jsonb,
  status text not null default 'candidate' check (status in ('candidate','accepted','rejected')),
  reviewed_by_user_id uuid references public.profiles(id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists erp_bill_matches_bill_idx on public.erp_bill_matches(bill_id, status, confidence desc);

create table if not exists public.erp_bank_statement_lines (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.erp_organizations(id) on delete restrict,
  provider_adapter_key text,
  external_reference text,
  posted_date date not null,
  description text,
  amount_minor bigint not null,
  currency text not null default 'YER' check (char_length(currency) = 3),
  raw_payload_redacted jsonb not null default '{}'::jsonb,
  import_hash text not null,
  status text not null default 'unmatched' check (status in ('unmatched','candidate','matched','ignored')),
  created_at timestamptz not null default now(),
  unique (organization_id, import_hash)
);
create index if not exists erp_bank_lines_org_date_idx on public.erp_bank_statement_lines(organization_id, posted_date desc, status);

create table if not exists public.erp_reconciliation_candidates (
  id uuid primary key default gen_random_uuid(),
  statement_line_id uuid not null references public.erp_bank_statement_lines(id) on delete cascade,
  source_type text not null,
  source_id text not null,
  confidence numeric(5,4) not null check (confidence between 0 and 1),
  explanation_ar text not null,
  status text not null default 'candidate' check (status in ('candidate','accepted','rejected')),
  reviewed_by_user_id uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);
create index if not exists erp_recon_candidates_statement_idx on public.erp_reconciliation_candidates(statement_line_id, confidence desc);

create table if not exists public.erp_tax_rules (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.erp_organizations(id) on delete cascade,
  rule_key text not null,
  jurisdiction text not null,
  rate_basis_points integer not null check (rate_basis_points between 0 and 10000),
  applies_to jsonb not null default '{}'::jsonb,
  source_type text not null default 'manual' check (source_type in ('manual','provider')),
  status text not null default 'draft' check (status in ('draft','active','archived')),
  created_by_user_id uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  unique (organization_id, rule_key)
);
create index if not exists erp_tax_rules_org_status_idx on public.erp_tax_rules(organization_id, status);

create table if not exists public.erp_crm_accounts (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.erp_organizations(id) on delete cascade,
  customer_user_id uuid references public.profiles(id) on delete set null,
  business_name text,
  display_name text not null,
  lifecycle_stage text not null default 'lead' check (lifecycle_stage in ('lead','prospect','customer','inactive')),
  credit_limit_minor bigint not null default 0 check (credit_limit_minor >= 0),
  created_at timestamptz not null default now()
);
create index if not exists erp_crm_accounts_org_stage_idx on public.erp_crm_accounts(organization_id, lifecycle_stage);

create table if not exists public.erp_crm_contacts (
  id uuid primary key default gen_random_uuid(),
  crm_account_id uuid not null references public.erp_crm_accounts(id) on delete cascade,
  name text not null,
  phone text,
  email text,
  role_title text,
  is_primary boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists erp_crm_contacts_account_idx on public.erp_crm_contacts(crm_account_id);

create table if not exists public.erp_customer_health_snapshots (
  id uuid primary key default gen_random_uuid(),
  crm_account_id uuid not null references public.erp_crm_accounts(id) on delete cascade,
  score numeric(5,2) not null check (score between 0 and 100),
  risk_level text not null check (risk_level in ('low','medium','high','unknown')),
  explanation_ar text not null,
  signals jsonb not null default '{}'::jsonb,
  computed_at timestamptz not null default now()
);
create index if not exists erp_customer_health_account_idx on public.erp_customer_health_snapshots(crm_account_id, computed_at desc);

create table if not exists public.erp_dunning_plans (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.erp_organizations(id) on delete cascade,
  name_ar text not null,
  trigger_days_overdue integer not null check (trigger_days_overdue >= 0),
  message_template_ar text not null,
  channel text not null check (channel in ('in_app','email','sms','whatsapp','manual')),
  provider_required boolean not null default false,
  status text not null default 'draft' check (status in ('draft','active','paused','archived')),
  created_by_user_id uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now()
);
create index if not exists erp_dunning_plans_org_status_idx on public.erp_dunning_plans(organization_id, status);

create table if not exists public.erp_contracts (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.erp_organizations(id) on delete cascade,
  crm_account_id uuid references public.erp_crm_accounts(id) on delete set null,
  contract_reference text not null,
  title_ar text not null,
  status text not null default 'draft' check (status in ('draft','review','approved','active','expired','terminated')),
  renewal_date date,
  private_storage_key text,
  created_by_user_id uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  unique (organization_id, contract_reference)
);
create index if not exists erp_contracts_org_status_idx on public.erp_contracts(organization_id, status, renewal_date);

create table if not exists public.erp_contract_versions (
  id uuid primary key default gen_random_uuid(),
  contract_id uuid not null references public.erp_contracts(id) on delete restrict,
  version_number integer not null check (version_number > 0),
  terms_redacted jsonb not null default '{}'::jsonb,
  content_hash text not null,
  signature_status text not null default 'not_requested' check (signature_status in ('not_requested','pending','signed','rejected')),
  created_by_user_id uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  unique (contract_id, version_number)
);
create index if not exists erp_contract_versions_contract_idx on public.erp_contract_versions(contract_id, version_number desc);

create table if not exists public.erp_subscriptions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.erp_organizations(id) on delete cascade,
  crm_account_id uuid references public.erp_crm_accounts(id) on delete set null,
  plan_key text not null,
  status text not null default 'draft' check (status in ('draft','trialing','active','paused','cancelled','expired')),
  currency text not null default 'YER' check (char_length(currency) = 3),
  recurring_amount_minor bigint not null check (recurring_amount_minor >= 0),
  interval_unit text not null check (interval_unit in ('week','month','year')),
  interval_count integer not null default 1 check (interval_count between 1 and 120),
  current_period_start date,
  current_period_end date,
  created_at timestamptz not null default now()
);
create index if not exists erp_subscriptions_org_status_idx on public.erp_subscriptions(organization_id, status);

create table if not exists public.erp_entitlements (
  id uuid primary key default gen_random_uuid(),
  subscription_id uuid not null references public.erp_subscriptions(id) on delete cascade,
  entitlement_key text not null,
  quantity numeric(18,3) not null default 0 check (quantity >= 0),
  status text not null default 'active' check (status in ('active','consumed','expired','revoked')),
  expires_at timestamptz,
  unique (subscription_id, entitlement_key)
);
create index if not exists erp_entitlements_subscription_idx on public.erp_entitlements(subscription_id, status);

create table if not exists public.erp_ticket_routes (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.erp_organizations(id) on delete cascade,
  category text not null,
  priority text,
  target_role text not null check (target_role in ('finance','sales','support','warehouse','field_service','creator')),
  stop_dunning boolean not null default false,
  rule_version integer not null default 1 check (rule_version > 0),
  status text not null default 'draft' check (status in ('draft','active','archived')),
  created_by_user_id uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now()
);
create index if not exists erp_ticket_routes_org_status_idx on public.erp_ticket_routes(organization_id, status);

create table if not exists public.erp_field_work_orders (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.erp_organizations(id) on delete cascade,
  crm_account_id uuid references public.erp_crm_accounts(id) on delete set null,
  title_ar text not null,
  description_ar text,
  status text not null default 'draft' check (status in ('draft','scheduled','in_progress','completed','cancelled')),
  scheduled_start timestamptz,
  scheduled_end timestamptz,
  location_redacted jsonb not null default '{}'::jsonb,
  inventory_consumption jsonb not null default '[]'::jsonb,
  created_by_user_id uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  check (scheduled_end is null or scheduled_start is null or scheduled_end >= scheduled_start)
);
create index if not exists erp_field_work_orders_org_status_idx on public.erp_field_work_orders(organization_id, status, scheduled_start);

create table if not exists public.erp_cpq_rules (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.erp_organizations(id) on delete cascade,
  rule_key text not null,
  priority integer not null default 100 check (priority between 0 and 100000),
  condition jsonb not null default '{}'::jsonb,
  effect jsonb not null default '{}'::jsonb,
  status text not null default 'draft' check (status in ('draft','active','archived')),
  created_at timestamptz not null default now(),
  unique (organization_id, rule_key)
);
create index if not exists erp_cpq_rules_org_status_idx on public.erp_cpq_rules(organization_id, status, priority);

create table if not exists public.erp_forecast_snapshots (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.erp_organizations(id) on delete cascade,
  forecast_type text not null check (forecast_type in ('cashflow','demand','ar','ap','churn','discount')),
  period_start date not null,
  period_end date not null,
  prediction jsonb not null default '{}'::jsonb,
  confidence numeric(5,4) check (confidence between 0 and 1),
  methodology text not null default 'advisory',
  status text not null default 'draft' check (status in ('draft','reviewed','archived')),
  generated_by text not null default 'rule_engine',
  created_at timestamptz not null default now(),
  check (period_end >= period_start)
);
create index if not exists erp_forecast_org_type_idx on public.erp_forecast_snapshots(organization_id, forecast_type, period_end desc);

create table if not exists public.erp_anomaly_findings (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.erp_organizations(id) on delete cascade,
  source_type text not null,
  source_id text not null,
  severity text not null check (severity in ('info','low','medium','high','critical')),
  confidence numeric(5,4) check (confidence between 0 and 1),
  explanation_ar text not null,
  evidence_redacted jsonb not null default '{}'::jsonb,
  status text not null default 'open' check (status in ('open','reviewed','dismissed','resolved')),
  reviewed_by_user_id uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);
create index if not exists erp_anomaly_org_status_idx on public.erp_anomaly_findings(organization_id, status, created_at desc);

create table if not exists public.erp_provider_adapters (
  id uuid primary key default gen_random_uuid(),
  provider_key text not null,
  operation_key text not null,
  display_name_ar text not null,
  capability text not null,
  enabled boolean not null default false,
  readiness_status text not null default 'unconfigured' check (readiness_status in ('unconfigured','configured','review_required','approved','disabled')),
  endpoint_allowlist jsonb not null default '[]'::jsonb,
  secret_ref text,
  configuration_public jsonb not null default '{}'::jsonb,
  updated_by_user_id uuid references public.profiles(id) on delete set null,
  updated_at timestamptz not null default now(),
  unique (provider_key, operation_key)
);
create index if not exists erp_provider_adapters_capability_idx on public.erp_provider_adapters(capability, enabled, readiness_status);

insert into public.erp_provider_adapters(provider_key, operation_key, display_name_ar, capability)
values
('manual','tax_calculation','حساب ضريبة يدوي','tax'),
('ocr_placeholder','invoice_extract','استخراج فاتورة تجريبي','ocr'),
('bank_feed_placeholder','statement_import','استيراد كشف تجريبي','bank_feed'),
('messaging_placeholder','collection_message','رسالة تحصيل تجريبية','messaging'),
('signature_placeholder','contract_signature','توقيع عقد تجريبي','signature'),
('routing_placeholder','field_route','تحسين مسار تجريبي','routing')
on conflict (provider_key, operation_key) do nothing;

create table if not exists public.erp_event_outbox (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid references public.erp_organizations(id) on delete set null,
  event_type text not null,
  aggregate_type text not null,
  aggregate_id text,
  payload_redacted jsonb not null default '{}'::jsonb,
  idempotency_key text not null,
  status text not null default 'pending' check (status in ('pending','leased','delivered','failed','dead_letter')),
  attempts integer not null default 0 check (attempts >= 0),
  available_at timestamptz not null default now(),
  lease_token_hash text,
  leased_until timestamptz,
  last_error_code text,
  created_at timestamptz not null default now(),
  unique (event_type, idempotency_key)
);
create index if not exists erp_event_outbox_claim_idx on public.erp_event_outbox(status, available_at, created_at);
create index if not exists erp_event_outbox_org_idx on public.erp_event_outbox(organization_id, created_at desc);

create table if not exists public.erp_webhook_subscriptions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.erp_organizations(id) on delete cascade,
  event_type text not null,
  endpoint_url text not null,
  secret_ref text,
  status text not null default 'draft' check (status in ('draft','active','paused','revoked')),
  created_by_user_id uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now()
);
create index if not exists erp_webhook_subscriptions_org_idx on public.erp_webhook_subscriptions(organization_id, event_type, status);

create table if not exists public.erp_webhook_deliveries (
  id uuid primary key default gen_random_uuid(),
  subscription_id uuid not null references public.erp_webhook_subscriptions(id) on delete cascade,
  outbox_event_id uuid not null references public.erp_event_outbox(id) on delete restrict,
  status text not null default 'pending' check (status in ('pending','leased','delivered','failed','dead_letter')),
  attempt_count integer not null default 0 check (attempt_count >= 0),
  next_attempt_at timestamptz not null default now(),
  response_code integer,
  response_redacted jsonb not null default '{}'::jsonb,
  delivered_at timestamptz,
  created_at timestamptz not null default now(),
  unique (subscription_id, outbox_event_id)
);
create index if not exists erp_webhook_deliveries_claim_idx on public.erp_webhook_deliveries(status, next_attempt_at);

create table if not exists public.erp_workflow_rules (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.erp_organizations(id) on delete cascade,
  rule_key text not null,
  trigger_event_type text not null,
  conditions jsonb not null default '{}'::jsonb,
  action_key text not null,
  action_args_template jsonb not null default '{}'::jsonb,
  requires_approval boolean not null default true,
  status text not null default 'draft' check (status in ('draft','active','paused','archived')),
  version integer not null default 1 check (version > 0),
  created_by_user_id uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  unique (organization_id, rule_key, version)
);
create index if not exists erp_workflow_rules_trigger_idx on public.erp_workflow_rules(organization_id, trigger_event_type, status);

create table if not exists public.erp_workflow_runs (
  id uuid primary key default gen_random_uuid(),
  rule_id uuid not null references public.erp_workflow_rules(id) on delete restrict,
  event_id uuid references public.erp_event_outbox(id) on delete set null,
  status text not null default 'queued' check (status in ('queued','leased','awaiting_approval','running','succeeded','failed','cancelled')),
  attempt_count integer not null default 0 check (attempt_count >= 0),
  next_run_at timestamptz not null default now(),
  lease_token_hash text,
  leased_until timestamptz,
  input_hash text not null,
  output_redacted jsonb not null default '{}'::jsonb,
  last_error_code text,
  created_at timestamptz not null default now()
);
create index if not exists erp_workflow_runs_claim_idx on public.erp_workflow_runs(status, next_run_at, created_at);
create index if not exists erp_workflow_runs_rule_idx on public.erp_workflow_runs(rule_id, created_at desc);

create table if not exists public.erp_analytics_rollups (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.erp_organizations(id) on delete cascade,
  rollup_key text not null,
  period_start date not null,
  period_end date not null,
  dimensions jsonb not null default '{}'::jsonb,
  metrics jsonb not null default '{}'::jsonb,
  computed_at timestamptz not null default now(),
  unique (organization_id, rollup_key, period_start, period_end, dimensions)
);
create index if not exists erp_analytics_rollups_lookup_idx on public.erp_analytics_rollups(organization_id, rollup_key, period_end desc);

create table if not exists public.erp_graph_edges (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.erp_organizations(id) on delete cascade,
  from_type text not null,
  from_id text not null,
  edge_type text not null,
  to_type text not null,
  to_id text not null,
  attributes_redacted jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique (organization_id, from_type, from_id, edge_type, to_type, to_id)
);
create index if not exists erp_graph_edges_from_idx on public.erp_graph_edges(organization_id, from_type, from_id);
create index if not exists erp_graph_edges_to_idx on public.erp_graph_edges(organization_id, to_type, to_id);

create or replace function private.erp_org_visible(p_organization_id uuid)
returns boolean language sql stable security definer set search_path = public, private, pg_catalog as $$
  select exists(
    select 1
    from public.erp_organizations o
    where o.id = p_organization_id
      and (o.owner_user_id = (select auth.uid()) or private.current_user_is_creator())
  );
$$;

create or replace function private.erp_shop_visible(p_shop_id uuid)
returns boolean language sql stable security definer set search_path = public, private, pg_catalog as $$
  select exists(
    select 1
    from public.shops s
    join public.merchants m on m.id = s.merchant_id
    where s.id = p_shop_id
      and (m.owner_user_id = (select auth.uid()) or private.current_user_is_creator())
  );
$$;
revoke all on function private.erp_org_visible(uuid), private.erp_shop_visible(uuid) from public, anon, authenticated;

do $$
declare
  t text;
begin
  foreach t in array array[
    'erp_organizations','erp_legal_entities','erp_accounting_books','erp_accounts','erp_dimensions','erp_dimension_values','erp_journal_batches','erp_journal_lines','erp_revenue_contracts','erp_revenue_schedules','erp_consolidation_runs','erp_allocation_rules','erp_allocation_runs','erp_funds','erp_grants','erp_projects','erp_project_costs','erp_capitalization_proposals','erp_vendors','erp_purchase_orders','erp_purchase_order_lines','erp_bills','erp_bill_matches','erp_bank_statement_lines','erp_reconciliation_candidates','erp_tax_rules','erp_crm_accounts','erp_crm_contacts','erp_customer_health_snapshots','erp_dunning_plans','erp_contracts','erp_contract_versions','erp_subscriptions','erp_entitlements','erp_ticket_routes','erp_field_work_orders','erp_cpq_rules','erp_forecast_snapshots','erp_anomaly_findings','erp_event_outbox','erp_webhook_subscriptions','erp_webhook_deliveries','erp_workflow_rules','erp_workflow_runs','erp_analytics_rollups','erp_graph_edges'
  ] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on public.%I from anon, authenticated', t);
    execute format('grant select on public.%I to authenticated', t);
  end loop;
  alter table public.erp_feature_registry enable row level security;
  alter table public.erp_provider_adapters enable row level security;
  revoke all on public.erp_feature_registry, public.erp_provider_adapters from anon, authenticated;
  grant select on public.erp_feature_registry, public.erp_provider_adapters to authenticated;
end $$;

-- Creator-only global governance tables.
drop policy if exists erp_feature_registry_creator_read on public.erp_feature_registry;
create policy erp_feature_registry_creator_read on public.erp_feature_registry for select to authenticated using (private.current_user_is_creator());
drop policy if exists erp_provider_adapters_creator_read on public.erp_provider_adapters;
create policy erp_provider_adapters_creator_read on public.erp_provider_adapters for select to authenticated using (private.current_user_is_creator());

-- Organization-rooted RLS.
drop policy if exists erp_organizations_scope_read on public.erp_organizations;
create policy erp_organizations_scope_read on public.erp_organizations for select to authenticated using (private.erp_org_visible(id));
drop policy if exists erp_legal_entities_scope_read on public.erp_legal_entities;
create policy erp_legal_entities_scope_read on public.erp_legal_entities for select to authenticated using (private.erp_org_visible(organization_id));
drop policy if exists erp_books_scope_read on public.erp_accounting_books;
create policy erp_books_scope_read on public.erp_accounting_books for select to authenticated using (exists(select 1 from public.erp_legal_entities e where e.id = legal_entity_id and private.erp_org_visible(e.organization_id)));
drop policy if exists erp_accounts_scope_read on public.erp_accounts;
create policy erp_accounts_scope_read on public.erp_accounts for select to authenticated using (exists(select 1 from public.erp_accounting_books b join public.erp_legal_entities e on e.id = b.legal_entity_id where b.id = book_id and private.erp_org_visible(e.organization_id)));
drop policy if exists erp_dimensions_scope_read on public.erp_dimensions;
create policy erp_dimensions_scope_read on public.erp_dimensions for select to authenticated using (private.erp_org_visible(organization_id));
drop policy if exists erp_dimension_values_scope_read on public.erp_dimension_values;
create policy erp_dimension_values_scope_read on public.erp_dimension_values for select to authenticated using (exists(select 1 from public.erp_dimensions d where d.id = dimension_id and private.erp_org_visible(d.organization_id)));
drop policy if exists erp_journal_batches_scope_read on public.erp_journal_batches;
create policy erp_journal_batches_scope_read on public.erp_journal_batches for select to authenticated using (private.erp_org_visible(organization_id));
drop policy if exists erp_journal_lines_scope_read on public.erp_journal_lines;
create policy erp_journal_lines_scope_read on public.erp_journal_lines for select to authenticated using (exists(select 1 from public.erp_journal_batches b where b.id = batch_id and private.erp_org_visible(b.organization_id)));
drop policy if exists erp_revenue_contracts_scope_read on public.erp_revenue_contracts;
create policy erp_revenue_contracts_scope_read on public.erp_revenue_contracts for select to authenticated using (private.erp_org_visible(organization_id));
drop policy if exists erp_revenue_schedules_scope_read on public.erp_revenue_schedules;
create policy erp_revenue_schedules_scope_read on public.erp_revenue_schedules for select to authenticated using (exists(select 1 from public.erp_revenue_contracts c where c.id = contract_id and private.erp_org_visible(c.organization_id)));
drop policy if exists erp_consolidation_scope_read on public.erp_consolidation_runs;
create policy erp_consolidation_scope_read on public.erp_consolidation_runs for select to authenticated using (private.erp_org_visible(organization_id));
drop policy if exists erp_allocation_rules_scope_read on public.erp_allocation_rules;
create policy erp_allocation_rules_scope_read on public.erp_allocation_rules for select to authenticated using (private.erp_org_visible(organization_id));
drop policy if exists erp_allocation_runs_scope_read on public.erp_allocation_runs;
create policy erp_allocation_runs_scope_read on public.erp_allocation_runs for select to authenticated using (exists(select 1 from public.erp_allocation_rules r where r.id = rule_id and private.erp_org_visible(r.organization_id)));
drop policy if exists erp_funds_scope_read on public.erp_funds;
create policy erp_funds_scope_read on public.erp_funds for select to authenticated using (private.erp_org_visible(organization_id));
drop policy if exists erp_grants_scope_read on public.erp_grants;
create policy erp_grants_scope_read on public.erp_grants for select to authenticated using (exists(select 1 from public.erp_funds f where f.id = fund_id and private.erp_org_visible(f.organization_id)));
drop policy if exists erp_projects_scope_read on public.erp_projects;
create policy erp_projects_scope_read on public.erp_projects for select to authenticated using (private.erp_org_visible(organization_id));
drop policy if exists erp_project_costs_scope_read on public.erp_project_costs;
create policy erp_project_costs_scope_read on public.erp_project_costs for select to authenticated using (exists(select 1 from public.erp_projects p where p.id = project_id and private.erp_org_visible(p.organization_id)));
drop policy if exists erp_capitalization_scope_read on public.erp_capitalization_proposals;
create policy erp_capitalization_scope_read on public.erp_capitalization_proposals for select to authenticated using (exists(select 1 from public.erp_projects p where p.id = project_id and private.erp_org_visible(p.organization_id)));
drop policy if exists erp_vendors_scope_read on public.erp_vendors;
create policy erp_vendors_scope_read on public.erp_vendors for select to authenticated using (private.erp_org_visible(organization_id));
drop policy if exists erp_purchase_orders_scope_read on public.erp_purchase_orders;
create policy erp_purchase_orders_scope_read on public.erp_purchase_orders for select to authenticated using (private.erp_org_visible(organization_id));
drop policy if exists erp_purchase_order_lines_scope_read on public.erp_purchase_order_lines;
create policy erp_purchase_order_lines_scope_read on public.erp_purchase_order_lines for select to authenticated using (exists(select 1 from public.erp_purchase_orders p where p.id = purchase_order_id and private.erp_org_visible(p.organization_id)));
drop policy if exists erp_bills_scope_read on public.erp_bills;
create policy erp_bills_scope_read on public.erp_bills for select to authenticated using (private.erp_org_visible(organization_id));
drop policy if exists erp_bill_matches_scope_read on public.erp_bill_matches;
create policy erp_bill_matches_scope_read on public.erp_bill_matches for select to authenticated using (exists(select 1 from public.erp_bills b where b.id = bill_id and private.erp_org_visible(b.organization_id)));
drop policy if exists erp_bank_lines_scope_read on public.erp_bank_statement_lines;
create policy erp_bank_lines_scope_read on public.erp_bank_statement_lines for select to authenticated using (private.erp_org_visible(organization_id));
drop policy if exists erp_recon_candidates_scope_read on public.erp_reconciliation_candidates;
create policy erp_recon_candidates_scope_read on public.erp_reconciliation_candidates for select to authenticated using (exists(select 1 from public.erp_bank_statement_lines s where s.id = statement_line_id and private.erp_org_visible(s.organization_id)));
drop policy if exists erp_tax_rules_scope_read on public.erp_tax_rules;
create policy erp_tax_rules_scope_read on public.erp_tax_rules for select to authenticated using (private.erp_org_visible(organization_id));
drop policy if exists erp_crm_accounts_scope_read on public.erp_crm_accounts;
create policy erp_crm_accounts_scope_read on public.erp_crm_accounts for select to authenticated using (private.erp_org_visible(organization_id));
drop policy if exists erp_crm_contacts_scope_read on public.erp_crm_contacts;
create policy erp_crm_contacts_scope_read on public.erp_crm_contacts for select to authenticated using (exists(select 1 from public.erp_crm_accounts a where a.id = crm_account_id and private.erp_org_visible(a.organization_id)));
drop policy if exists erp_health_scope_read on public.erp_customer_health_snapshots;
create policy erp_health_scope_read on public.erp_customer_health_snapshots for select to authenticated using (exists(select 1 from public.erp_crm_accounts a where a.id = crm_account_id and private.erp_org_visible(a.organization_id)));
drop policy if exists erp_dunning_scope_read on public.erp_dunning_plans;
create policy erp_dunning_scope_read on public.erp_dunning_plans for select to authenticated using (private.erp_org_visible(organization_id));
drop policy if exists erp_contracts_scope_read on public.erp_contracts;
create policy erp_contracts_scope_read on public.erp_contracts for select to authenticated using (private.erp_org_visible(organization_id));
drop policy if exists erp_contract_versions_scope_read on public.erp_contract_versions;
create policy erp_contract_versions_scope_read on public.erp_contract_versions for select to authenticated using (exists(select 1 from public.erp_contracts c where c.id = contract_id and private.erp_org_visible(c.organization_id)));
drop policy if exists erp_subscriptions_scope_read on public.erp_subscriptions;
create policy erp_subscriptions_scope_read on public.erp_subscriptions for select to authenticated using (private.erp_org_visible(organization_id));
drop policy if exists erp_entitlements_scope_read on public.erp_entitlements;
create policy erp_entitlements_scope_read on public.erp_entitlements for select to authenticated using (exists(select 1 from public.erp_subscriptions s where s.id = subscription_id and private.erp_org_visible(s.organization_id)));
drop policy if exists erp_ticket_routes_scope_read on public.erp_ticket_routes;
create policy erp_ticket_routes_scope_read on public.erp_ticket_routes for select to authenticated using (private.erp_org_visible(organization_id));
drop policy if exists erp_field_work_orders_scope_read on public.erp_field_work_orders;
create policy erp_field_work_orders_scope_read on public.erp_field_work_orders for select to authenticated using (private.erp_org_visible(organization_id));
drop policy if exists erp_cpq_rules_scope_read on public.erp_cpq_rules;
create policy erp_cpq_rules_scope_read on public.erp_cpq_rules for select to authenticated using (private.erp_org_visible(organization_id));
drop policy if exists erp_forecast_scope_read on public.erp_forecast_snapshots;
create policy erp_forecast_scope_read on public.erp_forecast_snapshots for select to authenticated using (private.erp_org_visible(organization_id));
drop policy if exists erp_anomaly_scope_read on public.erp_anomaly_findings;
create policy erp_anomaly_scope_read on public.erp_anomaly_findings for select to authenticated using (private.erp_org_visible(organization_id));
drop policy if exists erp_event_scope_read on public.erp_event_outbox;
create policy erp_event_scope_read on public.erp_event_outbox for select to authenticated using (private.erp_org_visible(organization_id));
drop policy if exists erp_webhook_scope_read on public.erp_webhook_subscriptions;
create policy erp_webhook_scope_read on public.erp_webhook_subscriptions for select to authenticated using (private.erp_org_visible(organization_id));
drop policy if exists erp_delivery_scope_read on public.erp_webhook_deliveries;
create policy erp_delivery_scope_read on public.erp_webhook_deliveries for select to authenticated using (exists(select 1 from public.erp_webhook_subscriptions s where s.id = subscription_id and private.erp_org_visible(s.organization_id)));
drop policy if exists erp_rule_scope_read on public.erp_workflow_rules;
create policy erp_rule_scope_read on public.erp_workflow_rules for select to authenticated using (private.erp_org_visible(organization_id));
drop policy if exists erp_run_scope_read on public.erp_workflow_runs;
create policy erp_run_scope_read on public.erp_workflow_runs for select to authenticated using (exists(select 1 from public.erp_workflow_rules r where r.id = rule_id and private.erp_org_visible(r.organization_id)));
drop policy if exists erp_rollup_scope_read on public.erp_analytics_rollups;
create policy erp_rollup_scope_read on public.erp_analytics_rollups for select to authenticated using (private.erp_org_visible(organization_id));
drop policy if exists erp_graph_scope_read on public.erp_graph_edges;
create policy erp_graph_scope_read on public.erp_graph_edges for select to authenticated using (private.erp_org_visible(organization_id));

-- Immutable financial history: posted batches and all journal lines cannot be edited or deleted.
create or replace function private.erp_block_posted_mutation()
returns trigger language plpgsql security definer set search_path = public, pg_catalog as $$
begin
  if tg_table_name = 'erp_journal_lines' then
    if exists(select 1 from public.erp_journal_batches b where b.id = coalesce(old.batch_id, new.batch_id) and b.status in ('posted','reversed','voided')) then
      raise exception using errcode = '55000', message = 'ERP_POSTED_JOURNAL_IMMUTABLE';
    end if;
  elsif old.status in ('posted','reversed','voided') then
    raise exception using errcode = '55000', message = 'ERP_POSTED_BATCH_IMMUTABLE';
  end if;
  return coalesce(new, old);
end;
$$;
revoke all on function private.erp_block_posted_mutation() from public, anon, authenticated;
drop trigger if exists erp_journal_lines_immutable on public.erp_journal_lines;
create trigger erp_journal_lines_immutable before update or delete on public.erp_journal_lines for each row execute function private.erp_block_posted_mutation();
drop trigger if exists erp_journal_batches_immutable on public.erp_journal_batches;
create trigger erp_journal_batches_immutable before update or delete on public.erp_journal_batches for each row execute function private.erp_block_posted_mutation();

create or replace function private.erp_create_organization(p_market_id uuid, p_code text, p_name_ar text, p_legal_name text default null, p_merchant_id uuid default null)
returns jsonb language plpgsql security definer set search_path = public, private, pg_catalog as $$
declare v_user uuid := (select auth.uid()); v_id uuid;
begin
  if v_user is null then raise exception using errcode = '42501', message = 'AUTH_REQUIRED'; end if;
  if p_market_id is null or length(trim(p_code)) < 2 or length(trim(p_name_ar)) < 2 then raise exception using errcode = '22023', message = 'ERP_ORGANIZATION_INPUT_INVALID'; end if;
  if p_merchant_id is not null and not exists(select 1 from public.merchants m where m.id = p_merchant_id and m.owner_user_id = v_user) and not private.current_user_is_creator() then raise exception using errcode = '42501', message = 'ERP_MERCHANT_SCOPE_DENIED'; end if;
  insert into public.erp_organizations(owner_user_id, merchant_id, market_id, code, name_ar, legal_name, status)
  values(v_user, p_merchant_id, p_market_id, upper(trim(p_code)), trim(p_name_ar), nullif(trim(p_legal_name), ''), case when private.current_user_is_creator() then 'active' else 'draft' end)
  on conflict (market_id, code) do update set name_ar = excluded.name_ar, legal_name = excluded.legal_name, updated_at = now()
  returning id into v_id;
  insert into public.audit_events(actor_user_id, action, resource_type, resource_id, metadata) values(v_user, 'erp.organization_saved', 'erp_organization', v_id::text, jsonb_build_object('market_id', p_market_id, 'code', upper(trim(p_code))));
  return jsonb_build_object('organization_id', v_id, 'status', 'saved');
end;
$$;
revoke all on function private.erp_create_organization(uuid, text, text, text, uuid) from public, anon, authenticated;
grant execute on function private.erp_create_organization(uuid, text, text, text, uuid) to authenticated, service_role;
create or replace function public.erp_create_organization(p_market_id uuid, p_code text, p_name_ar text, p_legal_name text default null, p_merchant_id uuid default null)
returns jsonb language sql security invoker set search_path = public, pg_catalog as $$ select private.erp_create_organization(p_market_id, p_code, p_name_ar, p_legal_name, p_merchant_id); $$;
revoke all on function public.erp_create_organization(uuid, text, text, text, uuid) from public, anon;
grant execute on function public.erp_create_organization(uuid, text, text, text, uuid) to authenticated;

create or replace function private.erp_create_journal_batch(p_organization_id uuid, p_book_id uuid, p_source_type text, p_source_id text, p_idempotency_key text, p_description_ar text default null)
returns jsonb language plpgsql security definer set search_path = public, private, pg_catalog as $$
declare v_user uuid := (select auth.uid()); v_id uuid;
begin
  if v_user is null or not private.erp_org_visible(p_organization_id) then raise exception using errcode = '42501', message = 'ERP_SCOPE_DENIED'; end if;
  if not exists(select 1 from public.erp_accounting_books b join public.erp_legal_entities e on e.id = b.legal_entity_id where b.id = p_book_id and e.organization_id = p_organization_id) then raise exception using errcode = '22023', message = 'ERP_BOOK_SCOPE_INVALID'; end if;
  if length(trim(p_source_type)) < 2 or length(trim(p_idempotency_key)) < 8 then raise exception using errcode = '22023', message = 'ERP_JOURNAL_INPUT_INVALID'; end if;
  insert into public.erp_journal_batches(organization_id, book_id, source_type, source_id, idempotency_key, description_ar, created_by_user_id)
  values(p_organization_id, p_book_id, trim(p_source_type), nullif(trim(p_source_id), ''), trim(p_idempotency_key), nullif(trim(p_description_ar), ''), v_user)
  on conflict (organization_id, idempotency_key) do nothing
  returning id into v_id;
  if v_id is null then select id into v_id from public.erp_journal_batches where organization_id = p_organization_id and idempotency_key = trim(p_idempotency_key); end if;
  insert into public.audit_events(actor_user_id, action, resource_type, resource_id, metadata) values(v_user, 'erp.journal_batch_created', 'erp_journal_batch', v_id::text, jsonb_build_object('source_type', trim(p_source_type), 'idempotency_key', trim(p_idempotency_key)));
  return jsonb_build_object('journal_batch_id', v_id, 'status', 'draft');
end;
$$;
revoke all on function private.erp_create_journal_batch(uuid, uuid, text, text, text, text) from public, anon, authenticated;
grant execute on function private.erp_create_journal_batch(uuid, uuid, text, text, text, text) to authenticated, service_role;
create or replace function public.erp_create_journal_batch(p_organization_id uuid, p_book_id uuid, p_source_type text, p_source_id text, p_idempotency_key text, p_description_ar text default null)
returns jsonb language sql security invoker set search_path = public, pg_catalog as $$ select private.erp_create_journal_batch(p_organization_id, p_book_id, p_source_type, p_source_id, p_idempotency_key, p_description_ar); $$;
revoke all on function public.erp_create_journal_batch(uuid, uuid, text, text, text, text) from public, anon;
grant execute on function public.erp_create_journal_batch(uuid, uuid, text, text, text, text) to authenticated;

create or replace function private.erp_post_journal_batch(p_batch_id uuid, p_reason text)
returns jsonb language plpgsql security definer set search_path = public, private, pg_catalog as $$
declare v_user uuid := (select auth.uid()); v_batch public.erp_journal_batches%rowtype; v_debit bigint; v_credit bigint;
begin
  select * into v_batch from public.erp_journal_batches where id = p_batch_id for update;
  if not found or not private.erp_org_visible(v_batch.organization_id) then raise exception using errcode = '42501', message = 'ERP_SCOPE_DENIED'; end if;
  if v_batch.status <> 'draft' then raise exception using errcode = '55000', message = 'ERP_JOURNAL_NOT_DRAFT'; end if;
  if length(trim(coalesce(p_reason, ''))) < 3 then raise exception using errcode = '22023', message = 'ERP_REASON_REQUIRED'; end if;
  select coalesce(sum(debit_minor),0), coalesce(sum(credit_minor),0) into v_debit, v_credit from public.erp_journal_lines where batch_id = p_batch_id;
  if v_debit = 0 or v_debit <> v_credit then raise exception using errcode = '23514', message = 'ERP_JOURNAL_UNBALANCED'; end if;
  update public.erp_journal_batches set status = 'posted', posted_by_user_id = v_user, posted_at = now() where id = p_batch_id;
  insert into public.audit_events(actor_user_id, action, resource_type, resource_id, metadata) values(v_user, 'erp.journal_batch_posted', 'erp_journal_batch', p_batch_id::text, jsonb_build_object('debit_minor', v_debit, 'credit_minor', v_credit, 'reason', trim(p_reason)));
  return jsonb_build_object('journal_batch_id', p_batch_id, 'status', 'posted', 'total_minor', v_debit);
end;
$$;
revoke all on function private.erp_post_journal_batch(uuid, text) from public, anon, authenticated;
grant execute on function private.erp_post_journal_batch(uuid, text) to authenticated, service_role;
create or replace function public.erp_post_journal_batch(p_batch_id uuid, p_reason text)
returns jsonb language sql security invoker set search_path = public, pg_catalog as $$ select private.erp_post_journal_batch(p_batch_id, p_reason); $$;
revoke all on function public.erp_post_journal_batch(uuid, text) from public, anon;
grant execute on function public.erp_post_journal_batch(uuid, text) to authenticated;

create or replace function private.erp_enqueue_event(p_organization_id uuid, p_event_type text, p_aggregate_type text, p_aggregate_id text, p_payload_redacted jsonb, p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path = public, private, pg_catalog as $$
declare v_user uuid := (select auth.uid()); v_id uuid;
begin
  if v_user is null or not private.erp_org_visible(p_organization_id) then raise exception using errcode = '42501', message = 'ERP_SCOPE_DENIED'; end if;
  if length(trim(p_event_type)) < 3 or length(trim(p_aggregate_type)) < 2 or length(trim(p_idempotency_key)) < 8 then raise exception using errcode = '22023', message = 'ERP_EVENT_INPUT_INVALID'; end if;
  insert into public.erp_event_outbox(organization_id, event_type, aggregate_type, aggregate_id, payload_redacted, idempotency_key)
  values(p_organization_id, trim(p_event_type), trim(p_aggregate_type), nullif(trim(p_aggregate_id), ''), coalesce(p_payload_redacted, '{}'::jsonb), trim(p_idempotency_key))
  on conflict (event_type, idempotency_key) do nothing
  returning id into v_id;
  if v_id is null then select id into v_id from public.erp_event_outbox where event_type = trim(p_event_type) and idempotency_key = trim(p_idempotency_key); end if;
  insert into public.audit_events(actor_user_id, action, resource_type, resource_id, metadata) values(v_user, 'erp.event_enqueued', 'erp_event_outbox', v_id::text, jsonb_build_object('event_type', trim(p_event_type)));
  return jsonb_build_object('event_id', v_id, 'status', 'pending');
end;
$$;
revoke all on function private.erp_enqueue_event(uuid, text, text, text, jsonb, text) from public, anon, authenticated;
grant execute on function private.erp_enqueue_event(uuid, text, text, text, jsonb, text) to authenticated, service_role;
create or replace function public.erp_enqueue_event(p_organization_id uuid, p_event_type text, p_aggregate_type text, p_aggregate_id text, p_payload_redacted jsonb, p_idempotency_key text)
returns jsonb language sql security invoker set search_path = public, pg_catalog as $$ select private.erp_enqueue_event(p_organization_id, p_event_type, p_aggregate_type, p_aggregate_id, p_payload_redacted, p_idempotency_key); $$;
revoke all on function public.erp_enqueue_event(uuid, text, text, text, jsonb, text) from public, anon;
grant execute on function public.erp_enqueue_event(uuid, text, text, text, jsonb, text) to authenticated;

create or replace function public.erp_list_feature_registry()
returns table(feature_key text, module_key text, name_ar text, name_en text, implementation_status text, provider_required boolean, enabled boolean, description text)
language sql security invoker set search_path = public, pg_catalog as $$
  select feature_key, module_key, name_ar, name_en, implementation_status, provider_required, enabled, description
  from public.erp_feature_registry
  where private.current_user_is_creator()
  order by module_key, feature_key
  limit 100;
$$;
revoke all on function public.erp_list_feature_registry() from public, anon;
grant execute on function public.erp_list_feature_registry() to authenticated;

create or replace function public.erp_get_org_dashboard(p_organization_id uuid)
returns jsonb language sql security invoker set search_path = public, pg_catalog as $$
  select jsonb_build_object(
    'organization_id', o.id,
    'name_ar', o.name_ar,
    'status', o.status,
    'currency', o.base_currency,
    'legal_entity_count', (select count(*) from public.erp_legal_entities e where e.organization_id = o.id),
    'active_book_count', (select count(*) from public.erp_accounting_books b join public.erp_legal_entities e on e.id = b.legal_entity_id where e.organization_id = o.id and b.status = 'active'),
    'draft_journal_count', (select count(*) from public.erp_journal_batches j where j.organization_id = o.id and j.status = 'draft'),
    'open_bill_count', (select count(*) from public.erp_bills b where b.organization_id = o.id and b.status in ('pending_match','pending_approval','approved','partially_paid')),
    'open_event_count', (select count(*) from public.erp_event_outbox e where e.organization_id = o.id and e.status in ('pending','leased','failed')),
    'open_anomaly_count', (select count(*) from public.erp_anomaly_findings a where a.organization_id = o.id and a.status = 'open')
  )
  from public.erp_organizations o
  where o.id = p_organization_id and private.erp_org_visible(o.id)
  limit 1;
$$;
revoke all on function public.erp_get_org_dashboard(uuid) from public, anon;
grant execute on function public.erp_get_org_dashboard(uuid) to authenticated;

-- Keep all timestamps current without granting direct writes.
 drop trigger if exists erp_organizations_touch on public.erp_organizations;
 create trigger erp_organizations_touch before update on public.erp_organizations for each row execute function private.touch_updated_at();
 drop trigger if exists erp_legal_entities_touch on public.erp_legal_entities;
 create trigger erp_legal_entities_touch before update on public.erp_legal_entities for each row execute function private.touch_updated_at();
 drop trigger if exists erp_books_touch on public.erp_accounting_books;
 create trigger erp_books_touch before update on public.erp_accounting_books for each row execute function private.touch_updated_at();

-- Explicitly document a default-deny posture for sensitive/provider tables.
drop policy if exists erp_bank_lines_no_direct_insert on public.erp_bank_statement_lines;
create policy erp_bank_lines_no_direct_insert on public.erp_bank_statement_lines for insert to authenticated with check (false);
drop policy if exists erp_provider_no_direct_insert on public.erp_provider_adapters;
create policy erp_provider_no_direct_insert on public.erp_provider_adapters for insert to authenticated with check (false);
drop policy if exists erp_event_no_direct_insert on public.erp_event_outbox;
create policy erp_event_no_direct_insert on public.erp_event_outbox for insert to authenticated with check (false);
