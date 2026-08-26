-- ERP operational projections for the remaining roadmap surfaces.
-- These are reviewable records and projections only; no platform custody or autonomous external sending.

create table if not exists public.erp_intercompany_netting_batches (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.erp_organizations(id) on delete restrict,
  reporting_date date not null,
  currency text not null default 'YER' check (char_length(currency) = 3),
  gross_debit_minor bigint not null default 0 check (gross_debit_minor >= 0),
  gross_credit_minor bigint not null default 0 check (gross_credit_minor >= 0),
  net_settlement_minor bigint not null default 0 check (net_settlement_minor >= 0),
  status text not null default 'preview' check (status in ('preview','approved','posted','cancelled')),
  proposal jsonb not null default '{}'::jsonb,
  created_by_user_id uuid not null references public.profiles(id) on delete restrict,
  approved_by_user_id uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);
create index if not exists erp_ic_netting_org_date_idx on public.erp_intercompany_netting_batches(organization_id, reporting_date desc, status);

create table if not exists public.erp_intercompany_netting_items (
  id uuid primary key default gen_random_uuid(),
  batch_id uuid not null references public.erp_intercompany_netting_batches(id) on delete restrict,
  from_entity_id uuid not null references public.erp_legal_entities(id) on delete restrict,
  to_entity_id uuid not null references public.erp_legal_entities(id) on delete restrict,
  source_type text not null,
  source_id text not null,
  amount_minor bigint not null check (amount_minor >= 0),
  direction text not null check (direction in ('receivable','payable')),
  created_at timestamptz not null default now(),
  check (from_entity_id <> to_entity_id)
);
create index if not exists erp_ic_netting_items_batch_idx on public.erp_intercompany_netting_items(batch_id);
create index if not exists erp_ic_netting_items_entities_idx on public.erp_intercompany_netting_items(from_entity_id, to_entity_id);

create table if not exists public.erp_ar_invoices (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.erp_organizations(id) on delete restrict,
  crm_account_id uuid references public.erp_crm_accounts(id) on delete set null,
  merchant_order_id uuid references public.merchant_orders(id) on delete set null,
  invoice_reference text not null,
  currency text not null default 'YER' check (char_length(currency) = 3),
  subtotal_minor bigint not null default 0 check (subtotal_minor >= 0),
  tax_minor bigint not null default 0 check (tax_minor >= 0),
  total_minor bigint not null default 0 check (total_minor >= 0),
  balance_minor bigint not null default 0 check (balance_minor >= 0),
  issue_date date not null default current_date,
  due_date date,
  status text not null default 'draft' check (status in ('draft','issued','partially_paid','paid','overdue','voided')),
  payment_instructions_redacted jsonb not null default '{}'::jsonb,
  created_by_user_id uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  unique (organization_id, invoice_reference),
  check (due_date is null or due_date >= issue_date),
  check (balance_minor <= total_minor)
);
create index if not exists erp_ar_invoices_org_due_idx on public.erp_ar_invoices(organization_id, due_date, status);
create index if not exists erp_ar_invoices_crm_status_idx on public.erp_ar_invoices(crm_account_id, status, due_date);
create index if not exists erp_ar_invoices_order_idx on public.erp_ar_invoices(merchant_order_id);

create table if not exists public.erp_ar_invoice_lines (
  id uuid primary key default gen_random_uuid(),
  invoice_id uuid not null references public.erp_ar_invoices(id) on delete restrict,
  description_ar text not null,
  quantity numeric(18,3) not null check (quantity > 0),
  unit_price_minor bigint not null check (unit_price_minor >= 0),
  line_total_minor bigint not null check (line_total_minor >= 0),
  revenue_contract_id uuid references public.erp_revenue_contracts(id) on delete set null,
  created_at timestamptz not null default now()
);
create index if not exists erp_ar_invoice_lines_invoice_idx on public.erp_ar_invoice_lines(invoice_id);

create table if not exists public.erp_ar_collection_records (
  id uuid primary key default gen_random_uuid(),
  invoice_id uuid not null references public.erp_ar_invoices(id) on delete restrict,
  amount_minor bigint not null check (amount_minor > 0),
  received_date date not null default current_date,
  collection_mode text not null check (collection_mode in ('manual_reference','cash_record','external_provider')),
  external_reference_redacted text,
  status text not null default 'submitted' check (status in ('submitted','reviewed','rejected')),
  recorded_by_user_id uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now()
);
create index if not exists erp_ar_collection_invoice_idx on public.erp_ar_collection_records(invoice_id, created_at desc);

create table if not exists public.erp_dunning_runs (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.erp_organizations(id) on delete restrict,
  invoice_id uuid not null references public.erp_ar_invoices(id) on delete restrict,
  plan_id uuid references public.erp_dunning_plans(id) on delete set null,
  days_overdue integer not null check (days_overdue >= 0),
  risk_level text not null default 'unknown' check (risk_level in ('low','medium','high','unknown')),
  draft_message_ar text not null,
  channel text not null check (channel in ('in_app','email','sms','whatsapp','manual')),
  provider_enabled boolean not null default false,
  status text not null default 'draft' check (status in ('draft','approved','sent','cancelled')),
  approved_by_user_id uuid references public.profiles(id) on delete set null,
  created_by_user_id uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now()
);
create index if not exists erp_dunning_runs_org_status_idx on public.erp_dunning_runs(organization_id, status, created_at desc);
create index if not exists erp_dunning_runs_invoice_idx on public.erp_dunning_runs(invoice_id, created_at desc);

create table if not exists public.erp_customer_360_snapshots (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.erp_organizations(id) on delete restrict,
  crm_account_id uuid not null references public.erp_crm_accounts(id) on delete restrict,
  period_start date not null,
  period_end date not null,
  revenue_minor bigint not null default 0 check (revenue_minor >= 0),
  gross_margin_minor bigint,
  open_ar_minor bigint not null default 0 check (open_ar_minor >= 0),
  support_ticket_count integer not null default 0 check (support_ticket_count >= 0),
  order_count integer not null default 0 check (order_count >= 0),
  ltv_proxy_minor bigint not null default 0 check (ltv_proxy_minor >= 0),
  summary_redacted jsonb not null default '{}'::jsonb,
  computed_at timestamptz not null default now(),
  check (period_end >= period_start),
  unique (organization_id, crm_account_id, period_start, period_end)
);
create index if not exists erp_customer_360_org_period_idx on public.erp_customer_360_snapshots(organization_id, period_end desc);
create index if not exists erp_customer_360_account_period_idx on public.erp_customer_360_snapshots(crm_account_id, period_end desc);

create table if not exists public.erp_vendor_quote_requests (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.erp_organizations(id) on delete restrict,
  vendor_id uuid not null references public.erp_vendors(id) on delete restrict,
  purchase_order_id uuid references public.erp_purchase_orders(id) on delete set null,
  request_reference text not null,
  request_payload_redacted jsonb not null default '{}'::jsonb,
  status text not null default 'draft' check (status in ('draft','approved','sent','responses_received','closed','cancelled')),
  provider_enabled boolean not null default false,
  created_by_user_id uuid not null references public.profiles(id) on delete restrict,
  approved_by_user_id uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  unique (organization_id, request_reference)
);
create index if not exists erp_vendor_quote_requests_org_status_idx on public.erp_vendor_quote_requests(organization_id, status, created_at desc);

create table if not exists public.erp_vendor_quote_bids (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.erp_vendor_quote_requests(id) on delete cascade,
  vendor_id uuid not null references public.erp_vendors(id) on delete restrict,
  quote_reference text,
  amount_minor bigint not null check (amount_minor >= 0),
  currency text not null default 'YER' check (char_length(currency) = 3),
  terms_redacted jsonb not null default '{}'::jsonb,
  score numeric(5,4) check (score between 0 and 1),
  status text not null default 'candidate' check (status in ('candidate','shortlisted','accepted','rejected')),
  created_at timestamptz not null default now()
);
create index if not exists erp_vendor_quote_bids_request_idx on public.erp_vendor_quote_bids(request_id, status, score desc);

create table if not exists public.erp_vendor_negotiation_drafts (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.erp_vendor_quote_requests(id) on delete restrict,
  vendor_id uuid not null references public.erp_vendors(id) on delete restrict,
  draft_message_ar text not null,
  budget_limit_minor bigint,
  requested_terms_redacted jsonb not null default '{}'::jsonb,
  status text not null default 'draft' check (status in ('draft','approved','sent','cancelled')),
  provider_enabled boolean not null default false,
  created_by_user_id uuid not null references public.profiles(id) on delete restrict,
  approved_by_user_id uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);
create index if not exists erp_vendor_negotiation_request_idx on public.erp_vendor_negotiation_drafts(request_id, status);

create table if not exists public.erp_cpq_quotes (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.erp_organizations(id) on delete restrict,
  crm_account_id uuid references public.erp_crm_accounts(id) on delete set null,
  quote_reference text not null,
  currency text not null default 'YER' check (char_length(currency) = 3),
  subtotal_minor bigint not null default 0 check (subtotal_minor >= 0),
  discount_minor bigint not null default 0 check (discount_minor >= 0),
  tax_minor bigint not null default 0 check (tax_minor >= 0),
  total_minor bigint not null default 0 check (total_minor >= 0),
  status text not null default 'draft' check (status in ('draft','pending_approval','approved','sent','accepted','expired','rejected')),
  configuration_redacted jsonb not null default '{}'::jsonb,
  bom_redacted jsonb not null default '[]'::jsonb,
  valid_until date,
  created_by_user_id uuid not null references public.profiles(id) on delete restrict,
  approved_by_user_id uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  unique (organization_id, quote_reference)
);
create index if not exists erp_cpq_quotes_org_status_idx on public.erp_cpq_quotes(organization_id, status, valid_until);

create table if not exists public.erp_cpq_quote_lines (
  id uuid primary key default gen_random_uuid(),
  quote_id uuid not null references public.erp_cpq_quotes(id) on delete restrict,
  product_id uuid references public.products(id) on delete set null,
  line_number integer not null check (line_number > 0),
  description_ar text not null,
  quantity numeric(18,3) not null check (quantity > 0),
  unit_price_minor bigint not null check (unit_price_minor >= 0),
  line_total_minor bigint not null check (line_total_minor >= 0),
  rule_trace_redacted jsonb not null default '{}'::jsonb,
  unique (quote_id, line_number)
);
create index if not exists erp_cpq_quote_lines_quote_idx on public.erp_cpq_quote_lines(quote_id);

create table if not exists public.erp_field_work_order_assignments (
  id uuid primary key default gen_random_uuid(),
  work_order_id uuid not null references public.erp_field_work_orders(id) on delete cascade,
  technician_user_id uuid references public.profiles(id) on delete set null,
  assignment_status text not null default 'proposed' check (assignment_status in ('proposed','assigned','accepted','declined','completed','cancelled')),
  route_plan_redacted jsonb not null default '{}'::jsonb,
  assigned_by_user_id uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now()
);
create index if not exists erp_field_assignments_work_order_idx on public.erp_field_work_order_assignments(work_order_id, assignment_status);
create index if not exists erp_field_assignments_technician_idx on public.erp_field_work_order_assignments(technician_user_id, assignment_status);

-- The new tables are read-only to direct clients; their future mutations belong in narrow RPCs.
do $$
declare t text;
begin
  foreach t in array array[
    'erp_intercompany_netting_batches','erp_intercompany_netting_items','erp_ar_invoices','erp_ar_invoice_lines','erp_ar_collection_records','erp_dunning_runs','erp_customer_360_snapshots','erp_vendor_quote_requests','erp_vendor_quote_bids','erp_vendor_negotiation_drafts','erp_cpq_quotes','erp_cpq_quote_lines','erp_field_work_order_assignments'
  ] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on public.%I from anon, authenticated', t);
    execute format('grant select on public.%I to authenticated', t);
  end loop;
end $$;

create policy erp_ic_netting_batch_read on public.erp_intercompany_netting_batches for select to authenticated using (private.erp_org_visible(organization_id));
create policy erp_ic_netting_item_read on public.erp_intercompany_netting_items for select to authenticated using (exists(select 1 from public.erp_intercompany_netting_batches b where b.id = batch_id and private.erp_org_visible(b.organization_id)));
create policy erp_ar_invoice_read on public.erp_ar_invoices for select to authenticated using (private.erp_org_visible(organization_id));
create policy erp_ar_invoice_line_read on public.erp_ar_invoice_lines for select to authenticated using (exists(select 1 from public.erp_ar_invoices i where i.id = invoice_id and private.erp_org_visible(i.organization_id)));
create policy erp_ar_collection_read on public.erp_ar_collection_records for select to authenticated using (exists(select 1 from public.erp_ar_invoices i where i.id = invoice_id and private.erp_org_visible(i.organization_id)));
create policy erp_dunning_read on public.erp_dunning_runs for select to authenticated using (private.erp_org_visible(organization_id));
create policy erp_customer_360_read on public.erp_customer_360_snapshots for select to authenticated using (private.erp_org_visible(organization_id));
create policy erp_vendor_quote_request_read on public.erp_vendor_quote_requests for select to authenticated using (private.erp_org_visible(organization_id));
create policy erp_vendor_quote_bid_read on public.erp_vendor_quote_bids for select to authenticated using (exists(select 1 from public.erp_vendor_quote_requests r where r.id = request_id and private.erp_org_visible(r.organization_id)));
create policy erp_vendor_negotiation_read on public.erp_vendor_negotiation_drafts for select to authenticated using (exists(select 1 from public.erp_vendor_quote_requests r where r.id = request_id and private.erp_org_visible(r.organization_id)));
create policy erp_cpq_quote_read on public.erp_cpq_quotes for select to authenticated using (private.erp_org_visible(organization_id));
create policy erp_cpq_quote_line_read on public.erp_cpq_quote_lines for select to authenticated using (exists(select 1 from public.erp_cpq_quotes q where q.id = quote_id and private.erp_org_visible(q.organization_id)));
create policy erp_field_assignment_read on public.erp_field_work_order_assignments for select to authenticated using (exists(select 1 from public.erp_field_work_orders w where w.id = work_order_id and private.erp_org_visible(w.organization_id)));

create trigger erp_ar_invoices_immutable before update or delete on public.erp_ar_invoices for each row execute function private.erp_block_posted_mutation();
