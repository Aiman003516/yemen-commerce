# Yemen Commerce ERP Evolution Blueprint

## Scope

This blueprint translates the supplied 2026 enterprise ERP roadmap into a Yemen Commerce implementation that remains a **modular commerce operating system**, not an unbounded monolithic accounting package. Existing Supabase/Postgres/RPC/RLS/audit authority remains the source of truth. Flutter remains the client layer for customer, merchant, and creator applications. Features that require external tax, OCR, bank-feed, messaging, signing, carrier, or AI providers are represented by safe provider adapters and mock/staged states; they are never silently enabled.

The design keeps the current Yemen constraints intact: the platform does not custody merchant funds; payment methods remain merchant-owned and manual where applicable; payment proof is not payment confirmation; order, payment, and financial history are append-only or reversal-based; identity and evidence remain private; external URLs and providers are allowlisted; and sensitive credentials remain server-side.

## Implementation status

The first executable ERP expansion is now applied to the connected Supabase project through migrations `20260826_0059_erp_foundation.sql` through `20260827_0071_universal_journal_creator_only.sql`. Migration 0059 establishes the 32-feature registry and the scoped accounting, procurement, CRM, projects, funds, contracts, subscriptions, field-service, provider, event, workflow, graph, anomaly, forecast, and rollup foundations. Migration 0060 adds the foreign-key indexes identified by the Performance Advisor. Migration 0061 exposes merchant-safe feature catalog and own-organization dashboard projections. Migration 0062 adds audited authoring RPCs for legal entities, accounting books, chart-of-account entries, draft journal lines, and balanced journal posting. Migration 0063 closes the organization uniqueness-conflict path so one merchant cannot overwrite another merchant’s organization by reusing a market/code pair. Migration 0064 adds scoped operational projection tables for intercompany netting, AR invoices and collections, dunning drafts, customer 360 summaries, vendor quote and negotiation drafts, CPQ quotes, and field assignments. Migration 0065 adds covering indexes for those projections; migration 0066 hardens journal-line organization validation; migration 0067 requires a non-empty audit reason for Creator ERP authoring mutations; migration 0068 adds the composable module/contract registry, versioned event envelope metadata, inbox deduplication, projection checkpoints, universal-journal read projection, and metadata-only extension manifests; migration 0069 adds the resulting foreign-key indexes; and migration 0070 ensures merchant clients receive only non-creator enabled module metadata while event-mesh and universal-journal controls remain Creator-only; migration 0071 hardens the universal-journal base-table policy so direct PostgREST reads are Creator-only as well.

The Creator Console now includes an Arabic-first ERP control center with the complete capability catalog, bounded organization dashboard, reason-required accounting authoring, and a **Composable ERP Control Center** showing enabled module descriptors, API versions, event-mesh health, projection counts, and metadata-only extension manifests. The merchant application includes a merchant-scoped ERP card next to its existing catalog, B2B, POS, inventory, analytics, copilot, and action-review tools; it now shows only merchant-safe composable module status. These screens are intentionally staged: provider-backed capabilities remain disabled, extension manifests cannot execute code, financial rows are not exposed through broad table access, and no ledger is posted automatically from a forecast, AI score, or webhook.

## Blueprint expansion decision

The attached AI-first blueprint contributes universal-journal projections, parallel-ledger semantics, worktags, revenue-recognition depth, tax/CECL/ABC proposals, audit-risk explanations, AP extraction drafts, semantic memory, event envelopes, and analytical separation. The attached composable blueprint contributes bounded contexts, anti-corruption translation, modular-monolith discipline, extension manifests, event sourcing/CQRS concepts, bitemporal facts, saga readiness, and composable UI slots. Yemen Commerce adopts these ideas as **logical contracts and projections first**. It deliberately defers physical Kafka/CDC/ClickHouse infrastructure, schema-per-tenant databases, third-party WASM execution, React micro-frontends, unrestricted autonomous agents, and any payment or ledger bypass.

The detailed gap matrix and staged delivery plan are documented in [`docs/BLUEPRINT_EXPANSION_PLAN.md`](BLUEPRINT_EXPANSION_PLAN.md). The current code increment implements B-0 through B-2: module ownership metadata, versioned contracts, event envelope fields, inbox dedupe, projection checkpoints, a universal-journal projection path for already-posted journal batches, and reviewed metadata-only extension manifests. No external worker or event sender was activated. The final live anonymous boundary run passed 133 checks and skipped 5 authenticated role cases because isolated tokens were not supplied. Security Advisor remains clean; Performance Advisor reports 347 informational unused-index observations only, with no warnings, errors, or ERP foreign-key findings.

## Domain modules

| Module | Main responsibility | Primary users | Source of authority |
|---|---|---|---|
| Organization and accounting | Entities, books, chart of accounts, journal entries, dimensions, consolidation, eliminations, allocations, tax configuration, revenue schedules | Creator, merchant finance operator | Supabase Postgres/RPC/audit |
| Procure-to-pay | Vendors, purchase orders, bills, three-way matching, approvals, AP aging, payment proposals | Merchant, finance operator, creator | Supabase Postgres/RPC/audit |
| Order-to-cash | Quotes, contracts, invoices, AR, collections, revenue recognition, customer balances | Merchant, customer, finance operator | Existing immutable commerce records plus accounting projections |
| CRM and service | Accounts, contacts, tickets, customer health, self-service views, routing, field work orders | Merchant, customer, support operator | Supabase Postgres/RPC/RLS |
| Inventory and operations | Existing multi-location inventory, demand forecasts, purchasing suggestions, field consumption, fulfillment | Merchant, warehouse operator, creator | Existing inventory RPCs plus forecast projections |
| Automation and events | Outbox events, webhook subscriptions, delivery attempts, rules, workflow runs, retry/lease state | Creator, merchant operator | Supabase queue tables/RPCs/audit |
| Analytics and graph | Financial/customer/operational dimensions, materialized rollups, safe exports, relationship projections | Creator, merchant | Bounded SQL/RPC projections |
| Provider adapters | OCR, tax, bank feeds, messaging, e-signature, carriers, search, AI/ML | Creator, approved operators | Server-only adapter contracts and gates |

## All 32 supplied features mapped to implementation

| # | Supplied feature | Yemen Commerce module | Delivery shape | Guardrail |
|---:|---|---|---|---|
| 1 | Multi-entity consolidation and elimination | Organization and accounting | Entity hierarchy, intercompany journals, consolidation runs, elimination templates | No automatic posting without approved rules and audit trail |
| 2 | Multi-book accounting | Organization and accounting | Parallel books with explicit accounting basis and posting policy | Books are append-only; corrections use reversals |
| 3 | ASC 606 / IFRS 15 revenue recognition | Order-to-cash | Recognition contracts, schedules, milestones, recognition runs | Configurable policy; accounting review required before posting |
| 4 | Dimensional tagging and reporting | Analytics and graph | Extensible dimensions and journal/report tags | Tenant/shop scope and bounded dimensions |
| 5 | Advanced cost allocation | Organization and accounting | Allocation rules, drivers, calculated allocations, review runs | Preview first; no silent ledger mutation |
| 6 | Intercompany netting and settlement | Organization and accounting | Netting batches and settlement proposals | Proposal-only until authorized; no platform money movement |
| 7 | Automated global tax engine | Provider adapters and accounting | Tax rules plus provider operation adapter | Local rules are configuration; external tax provider disabled by default |
| 8 | Project accounting and capitalization | Organization and accounting | Projects, tasks, costs, capitalization proposals | Capitalization requires approval and immutable journal entries |
| 9 | Grant and fund accounting | Organization and accounting | Funds, restrictions, grant budgets, fund dimensions | Optional module; restricted/unrestricted balances cannot mix |
| 10 | Zero-touch AP OCR and AI | Procure-to-pay and AI | Private invoice evidence, extraction drafts, PO matching, approval queue | OCR/provider disabled by default; evidence private; human approval required |
| 11 | Probabilistic bank reconciliation | Procure-to-pay and AI | Bank statement imports, match candidates, confidence, review | No bank credentials in Flutter; no automatic settlement by confidence alone |
| 12 | Predictive cash-flow forecasting | Analytics and AI | AR/AP/ordering projections, forecast runs, confidence bands | Forecast is advisory and labelled as prediction |
| 13 | Fraud and anomaly detection | Risk and AI | Explainable anomaly findings linked to source transactions | Flag only; no automatic account/payment action |
| 14 | Intelligent dunning and collections | Order-to-cash and CRM | Collections plans, message drafts, pause reasons | Merchant approves messaging; no automatic harassment or payment custody |
| 15 | Demand ML and inventory forecasting | Inventory and AI | Forecast snapshots, seasonality inputs, purchase suggestions | Suggestions do not create POs automatically |
| 16 | Dynamic discount optimization | Procure-to-pay and AI | Discount scenarios and working-capital comparison | Advisory only; merchant approves vendor terms |
| 17 | Agentic vendor negotiation | Procure-to-pay and AI | Bounded vendor quote requests and comparison drafts | No autonomous external sending/order placement; provider and approval gates |
| 18 | CPQ engine | Sales and order-to-cash | Bundle rules, configuration validation, price/quote versions, BOM projections | Deterministic rule engine; quote approval before commitment |
| 19 | Predictive customer health and churn | CRM and AI | Explainable health snapshots from support/order/AR signals | No discriminatory or irreversible action; advisory score |
| 20 | Contract lifecycle management | CRM and order-to-cash | Contract versions, approvals, renewal dates, signature-provider adapter | Private documents; e-sign provider disabled by default |
| 21 | Omnichannel self-service portals | CRM and customer app | Scoped invoice/order/contract/ticket views and payment instructions | No evidence leakage; merchant-owned payment instructions only |
| 22 | Multi-agent workflow routing | CRM and automation | Rule-based ticket routing and department queues | Deterministic routing first; AI suggestions require review |
| 23 | Subscription and entitlement management | Order-to-cash | Plans, subscriptions, entitlements, prorations, MRR/ARR projections | No card charging or custody; manual/provider adapters gated |
| 24 | Field service and dispatch optimization | Operations and CRM | Work orders, assignments, technician status, inventory consumption | Dispatch and consumption use audited RPCs; route provider optional |
| 25 | 360-degree financial customer view | CRM and analytics | Scoped customer profitability, AR, LTV proxy, support summary | Role and shop scope; no private evidence in summary |
| 26 | API-first composable architecture | Architecture | Versioned public RPCs, Edge Functions, typed Dart contracts, adapter registry | No arbitrary RPC/SQL passthrough |
| 27 | Event-driven pub/sub webhooks | Automation and events | Outbox, subscriptions, signed delivery, retries, replay/disable | HTTPS allowlist, SSRF defense, signed payloads, idempotency |
| 28 | Multi-tenant RLS | Existing Supabase authority | Tenant/shop/entity scope policies and capability checks | RLS/RPC is authoritative; client filters are not security |
| 29 | Unified graph data model | Analytics and graph | Relationship projection across customer/order/invoice/payment/bank statement | Projections redact sensitive evidence and remain bounded |
| 30 | Rule-based workflow engine | Automation and events | Versioned triggers, conditions, actions, approval nodes | Fixed action registry; no arbitrary script execution |
| 31 | OLAP-oriented analytics separation | Analytics and graph | Daily/hourly rollups and export projections | Heavy reporting does not run against unbounded transactional reads |
| 32 | Idempotent API design | All mutation modules | Request keys, unique constraints, replay-safe RPCs, immutable history | Duplicate requests return the original result; conflicts are explicit |

## Delivery increments

### Increment ERP-Foundation

Create organization/entity, books, chart of accounts, accounting dimensions, journal batches, immutable journal lines, vendors, customers-as-accounting-parties, tax configuration, provider adapter registry, event outbox, webhook subscriptions, and workflow-rule version tables. Add creator/merchant RLS, audit events, idempotency keys, bounded list RPCs, and safe no-provider defaults.

### Increment Finance-Core

Add quote-to-invoice projections, AP bills and purchase orders, three-way matching, AR/AP aging, reversal-based journal posting, consolidation/elimination previews, cost-allocation previews, project accounting, grants/funds, and revenue schedules. Add Creator and merchant finance review surfaces, with no automatic money movement.

### Increment CRM-Ops

Add CRM accounts/contacts, customer health snapshots, contract versions, subscription/entitlement records, ticket routing rules, field work orders, technician assignments, omnichannel self-service projections, and 360-degree customer summaries. Connect these to existing orders, support tickets, inventory locations, and merchant analytics using read projections.

### Increment AI-Providers

Extend the existing AI-0 through AI-6 control plane with OCR extraction, reconciliation candidates, forecast snapshots, anomaly findings, dunning drafts, demand forecasts, discount scenarios, vendor quote drafts, churn scores, and CPQ suggestions. All outputs are drafts or reviewable actions, with provenance, confidence, policy checks, explicit approval, and server-only provider credentials.

### Increment Analytics-Scale

Add event publication, signed webhook delivery, retry/lease diagnostics, rollup tables, safe exports, and relationship projections. Introduce provider-specific adapters for tax, banking, OCR, messaging, search, route optimization, and e-signature only after creator readiness checks and compliance review.

## Explicit non-goals until separately approved

The implementation does not create a platform wallet, central settlement account, card-charging path, automatic payment-proof verification, autonomous vendor ordering, arbitrary external URL fetching, arbitrary code execution, unrestricted external-agent OAuth tokens, or client-visible service-role/provider credentials. These would violate existing Yemen Commerce authority and payment invariants.

## Acceptance standard

A module is complete only when its schema, indexes, RLS, narrow RPCs, audit events, idempotency behavior, typed repository contract, Arabic-first UI state, anonymous denial checks, available Flutter tests/builds, and activation gates are present. Provider-backed modules may be marked **implemented but disabled** until the provider contract, secrets, privacy review, and isolated authenticated tests are approved.

The current ERP foundation plus operational projection slice meets the schema/RLS/index/audit/typed-contract/UI/build requirements for its staged surface. The latest anonymous boundary run produced `RESULT passed=128 skipped=5`; the five authenticated role scenarios remain pending by design because isolated tokens were not supplied. No synthetic users or shared-project fixtures were created. Security Advisor is clean after migration 0067, and the post-0065 Performance Advisor review contains only informational unused-index observations. The provider registry, OCR, tax, bank-feed, messaging, route, signature, and autonomous negotiation adapters remain disabled until separately approved and configured on the server.


## 0072–0075: Commerce channels, delivery orchestration, returns, and replay safety

The next research-backed operational slice is deployed through migrations `20260827_0072_channels_logistics_returns.sql` through `20260827_0075_channels_logistics_idempotency.sql`. It adds the logical modules `commerce_channels`, `delivery_orchestration`, `returns_logistics`, and `trust_operations` to the composable registry, then hardens their mutations with actor-scoped idempotency.

Merchant-owned `commerce_channels` and `channel_listings` model web, social, POS, B2B, marketplace, and service distribution without storing provider credentials. Listings can carry channel-specific content, price, and metadata overrides. The public catalog wrapper is bounded to 1–100 rows per call and, under the corrected invoker/RLS policy, exposes only active channels and listings belonging to an approved shop in an active market. Anonymous access does not expose merchant operations or private listing data.

Carrier-neutral `shipment_plans`, append-only `shipment_events`, `delivery_exceptions`, `return_logistics`, and append-only `return_logistics_events` establish delivery and return timelines without claiming a courier integration. Shipment progression into dispatch, transit, or delivery requires confirmed `payment_status = 'paid'`; a proof submission cannot satisfy this gate. Delivery completion updates fulfillment only when that payment authority is true. Return closure records logistics completion only and never creates a refund or settlement. All mutations are narrow audited RPCs with required reasons, ownership checks, explicit state transitions, and immutable event history.

The merchant app now includes an Arabic-first channel authoring card and the ERP summary displays channel, shipment, delivery-exception, and return counts. Flutter API adapters and Arabic-safe error mappings cover the new operations. Shipment, exception, and return authoring UI remains staged for the next workbench increment; no provider, webhook sender, courier API, payment custody, background worker, or external secret was introduced.

Migration `0073` adds the six foreign-key indexes identified by the post-0072 Performance Advisor scan. Migration `0074` fixes the public active-channel visibility boundary required by the invoker catalog function. Migration `0075` adds request-hash-checked command idempotency for all channel, shipment, delivery-exception, and return mutations while preserving legacy overloads. The post-0075 Security Advisor is clean. The RLS structural check confirms all seven new base tables have RLS enabled and at least one policy. The Performance Advisor reports 364 informational unused-index observations only and contains no new operational unindexed-FK finding.

The next implementation order is merchant shipment/exception/return workbench dialogs, customer-owned delivery and return timelines, channel-listing authoring and projections, then multi-storefront themes and catalog segmentation. Provider adapters remain a later gated increment requiring official API documentation, server-only credentials, callback verification, reconciliation, compliance approval, and operational ownership.
