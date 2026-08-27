# Blueprint Expansion Plan: AI-First and Composable ERP

**Status:** Analysis and implementation plan for the next Yemen Commerce increment
**Source documents:** The attached `AI-FirstERPArchitectureBlueprint.pdf` and `ComposableERPArchitectureBlueprint.pdf`
**Platform constraints:** Arabic-first Flutter customer/merchant apps, independent Flutter Creator Console, Supabase Auth/Postgres/RPC/RLS/audit authority, merchant-owned manual payments, no platform fund custody, immutable financial/order/payment history, private evidence, server-only secrets, provider gates disabled by default, and no merge to `main`.

## Executive conclusion

The two blueprints are valuable as **target-state architecture documents**, but they must not be copied literally into the current product. They combine enterprise accounting ideas, machine-learning research directions, distributed-systems patterns, WebAssembly plugins, ClickHouse/Kafka/CDC infrastructure, and React micro-frontends. Yemen Commerce already has a safer and more practical starting point: a modular Supabase-backed commerce operating system with a deployed ERP foundation, immutable journal boundaries, RLS, audit records, bounded AI governance, managed knowledge foundations, reviewable actions, and Arabic-first Flutter surfaces.

The correct strategy is a **modular monolith with explicit bounded contexts, versioned contracts, transactional outbox metadata, append-only financial facts, projection tables, and provider-neutral extension points**. We should not prematurely introduce physical microservices, Kafka, ClickHouse, schema-per-tenant databases, WASM execution, or JavaScript Module Federation. Those are future distribution options, not prerequisites for making the platform composable today.

> **Target architecture:** Supabase/Postgres remains the authoritative modular core; Flutter remains the three-app presentation layer; module boundaries are enforced through SQL ownership, narrow RPCs, typed Dart contracts, event envelopes, projection tables, and tests. Physical distribution is deferred until measured scale or organizational requirements justify it.

## What the AI-first blueprint adds

| Blueprint capability | Current Yemen Commerce position | Decision |
|---|---|---|
| Universal journal combining financial and management dimensions | Existing immutable journal batches and lines plus dimensions; no unified journal projection | Add a read-optimized universal-journal projection without replacing the authoritative journal tables. |
| Parallel leading, local, extension, prediction, and simulation ledgers | Multi-book accounting exists; extension/prediction/simulation semantics are incomplete | Add explicit ledger classes and simulation metadata as append-only projections; never let simulation entries post to the real ledger. |
| Worktags/dimensional accounting | JSONB journal dimensions and dimension definitions exist | Add validated worktag definitions/values and a journal-line validation/read model. |
| Activity-based and time-driven cost accounting | Allocation foundations exist; operational driver capture is incomplete | Add driver snapshots and allocation previews before any posting automation. |
| R&D/software capitalization and CECL | Project/capitalization and anomaly/forecast foundations exist; policy engines do not | Add policy/proposal records only; require review and reversal-based posting. |
| ASC 606/IFRS 15 five-step recognition | Revenue contracts and schedules exist | Add performance obligations, SSP allocation, contract modification, and catch-up/prospective proposal records. |
| Dynamic global tax and e-invoicing | Tax rules/provider adapter registry exists; external providers disabled | Add deterministic local tax evaluation contracts and e-invoice readiness metadata; do not claim government connectivity. |
| Graph anomaly detection and JournalGuard-style risk attribution | Anomaly findings and graph edges exist | Add explainable risk feature snapshots and review queues; no automatic payment/account action. |
| LLM audit copilot | AI gateway and approvals exist, but ERP audit tools are not in the fixed registry | Add read-only audit projections and advisory explanations with provenance/confidence. |
| AP document vision and probabilistic three-way matching | Private evidence/AP/bill/match foundations exist; OCR provider disabled | Add extraction draft and match-review records; keep OCR and external document parsing disabled. |
| Agentic memory and vector RAG | Managed knowledge and full-text retrieval exist; embeddings are not active | Add embedding-provider-neutral columns and provenance contracts first; activate vector generation only after provider/privacy review. |
| Usage-based subscriptions, proration, overage, minimum commitments | Subscription/entitlement structures exist | Add usage events and billing-preview projections; no card charging or automatic custody. |
| Predictive customer health | Health and customer-360 snapshots exist | Add feature snapshots and explanation traces; scores remain advisory. |
| Transaction-scoped tenant context | Organization visibility helpers and RLS exist | Keep actor-derived organization scope as the current authority; consider transaction-local context only for a future worker boundary, not as a client-controlled setting. |
| PostgreSQL + ClickHouse dual engine | PostgreSQL rollups and bounded exports exist | Continue PostgreSQL projections first; add an analytics-export contract and scale gate before introducing ClickHouse. |
| HNSW/IVFFlat pgvector | Full-text knowledge retrieval exists | Keep the first semantic layer provider-neutral; do not introduce an extension or embedding model without a verified deployment and retention plan. |

## What the composable blueprint adds

| Blueprint capability | Current Yemen Commerce position | Decision |
|---|---|---|
| Domain-driven bounded contexts | Existing docs and modules already separate geography, identity, merchant, catalog, checkout, orders, payments, administration, files, events, and analytics | Formalize a machine-readable module registry and ownership contract. |
| No cross-module SQL joins | Current Supabase projections use scoped SQL and some joins | Do not ban all database joins immediately; prohibit client-side direct table access and define cross-context projections/RPCs as the public contract. Add static checks for forbidden direct access in Dart and future worker code. |
| Anti-corruption layers | Typed repositories and narrow RPCs exist; ERP operational projections are still close to source tables | Add explicit DTO/event translation functions for AR-to-ledger, commerce-to-ledger, and inventory-to-analytics flows. |
| Modular monolith before microservices | Strong fit for current Flutter/Supabase deployment | Adopt as the near-term architecture. Maintain stable module APIs and event envelopes so later extraction remains possible. |
| WASM plugin engine | No safe runtime or approved extension host exists | Add a signed plugin registry, capability manifest, hook registry, and review state only. Do not execute third-party WASM in Supabase or Flutter yet. |
| Pure-function hook pipeline | Provider adapter registry exists but lifecycle hooks are not formalized | Add deterministic hook contracts where the host validates proposed changes before persistence. |
| Schema-per-module | Current ERP tables are in `public` with RLS and explicit grants | Do not undertake a destructive schema move. Introduce logical module ownership metadata and migrate only new internal structures to dedicated schemas when justified. |
| Event sourcing/CQRS | Immutable journals, audit events, outbox, and rollups exist | Add append-only domain-event facts and projection checkpoints; do not replace the proven journal tables with a full event-sourced rewrite. |
| Upcasting and bi-temporal data | Current records have created/posted timestamps but not systematic valid-time/version semantics | Add event schema versions, occurred/valid timestamps, and correction/reversal metadata to new event/projection records. |
| Saga orchestration | Workflow tables exist; no ERP compensation catalog | Add a deterministic saga definition and compensation registry for reversible operational workflows, never for payment custody or immutable history rewriting. |
| Micro-frontends/Module Federation | Flutter apps are the mandated client stack | Implement Flutter extension slots and a registry-driven module navigation model; do not introduce React remotes or runtime JavaScript modules. |
| Dynamic widgets/Web Components | Not applicable to Flutter | Use typed Flutter `ErpModuleCard`/`ExtensionSlot` contracts with safe fallback and capability checks. |

## Architecture we will implement

### 1. Bounded contexts and ownership

The platform will use these logical contexts: **Core Commerce**, **Ledger**, **Accounts Receivable**, **Procure-to-Pay**, **CRM/Sales**, **Inventory/Supply**, **Tax**, **AI/Governance**, **Events/Workflows**, and **Analytics/Graph**. Each context owns its mutation RPCs and source records. Cross-context screens consume bounded RPC projections or materialized read models rather than broad table access.

A new registry will record `module_key`, owner context, API version, enabled state, provider requirement, scope type, allowed extension slots, and migration version. The registry is governance metadata; it does not grant access by itself. Database authorization and existing capability policies remain authoritative.

### 2. Universal journal projection, not a destructive rewrite

The existing `erp_journal_batches` and `erp_journal_lines` remain the authoritative posting path. A new append-only `erp_universal_journal_entries` projection will normalize posted/reversed facts with ledger class, organization, legal entity, book, account, amount, currency, posting date, transaction date, valid-from/valid-to, source reference, worktags, event version, and anomaly metadata. It will be populated only by audited server-side projection RPCs or a future approved worker. Simulation and prediction rows are explicitly non-posting.

### 3. Versioned event envelope and projection checkpoints

The existing event outbox will gain a versioned envelope: event name, schema version, occurred-at, valid-at, correlation ID, causation ID, aggregate reference, payload hash, redacted payload, delivery status, and idempotency key. New inbox/consumer records will make downstream handling idempotent. A projection checkpoint table will record consumer name, last event, schema version, lease, and failure state. No active external event sender will be enabled by this increment.

### 4. Safe extensibility

The first extension engine will be metadata-only. Creator Console will manage extension manifests, hook contracts, requested capabilities, versions, checksum, approval state, and rollout scope. A manifest cannot execute code. Future WASM execution, if approved, must run outside the database with explicit capability-based host functions, CPU/memory/time limits, signed artifacts, no direct database credentials, no implicit network, and a kill switch.

### 5. Flutter composability

The customer/merchant app and Creator Console will use typed module descriptors and extension slots. A module card must declare its label, icon, route key, audience, capability requirement, provider status, and safe fallback message. Disabled modules remain visible as staged or unavailable where appropriate, but cannot create false operational affordances. This preserves the Flutter-only requirement while providing the user experience benefit of composable modules.

## Delivery sequence

| Increment | Main outcome | Backend | Flutter/UI | Gate |
|---|---|---|---|---|
| B-0 | Contract and module registry | Module descriptors, API versions, ownership, extension slots | Creator module catalog and safe module cards | Anonymous denial, registry does not grant access |
| B-1 | Universal journal and temporal facts | Universal-journal projection, ledger classes, worktag validation, bitemporal event metadata | Creator ledger explorer, projection health, simulation warning | No direct writes, posted history immutable, bounded reads |
| B-2 | Event mesh durability | Versioned outbox envelope, inbox dedupe, projection checkpoints, retry diagnostics | Creator event mesh center and failed-projection review | No active external publishing; idempotent replay only |
| B-3 | Finance intelligence | SSP/performance obligations, tax decision drafts, cost drivers, CECL/ABC proposal records | Finance review workbench and Arabic explanations | Advisory/proposal-only; no automatic posting or payment action |
| B-4 | AI audit and knowledge | Audit-risk features, provenance, confidence, read-only audit tools, optional embeddings | Creator AuditCopilot and merchant risk explanation cards | Provider/generative gates disabled; human review required |
| B-5 | Composable extensions | Signed manifest registry, hook contracts, capability manifests, rollout versions | Creator extension marketplace and Flutter extension slots | No third-party code execution until separate security review |
| B-6 | Subscription/CPQ/CRM depth | Usage events, proration previews, contract modifications, health explanations | Merchant sales/CRM workbench and customer entitlement view | No charging/custody; scoped projections only |
| B-7 | Scale-out readiness | Export contract, CDC readiness metadata, analytics partition strategy, module extraction records | Creator scale/readiness dashboard | Require measured load and approved durable host before external infrastructure |

## Immediate implementation choice

The first code increment should implement **B-0 through B-2 together as a coherent platform slice**. They are high leverage, deployable without external providers, and make later AI, finance, and composable UI work safer. They also directly address the most important architectural gap in both blueprints: the current system has many ERP tables and RPCs, but the module/event contracts are not yet explicit enough for long-term independent evolution.

The first visible UI should be a Creator-only **Composable ERP Control Center** with three tabs: module registry, event mesh/projection health, and extension manifests. The merchant app should receive a safe module-card update showing only the merchant-visible modules and their state. No customer-facing financial or governance data will be exposed.

## Hard non-goals for this increment

This increment will not add a platform wallet, payment settlement, automatic payment verification, unrestricted AI mutation, autonomous vendor negotiation, arbitrary SQL or URL tools, third-party WASM execution, Kafka/Debezium/ClickHouse production infrastructure, schema-per-tenant databases, React micro-frontends, or a destructive rewrite of the existing journal. These remain future options behind explicit scale, security, provider, and compliance gates.

## Acceptance criteria

A blueprint increment is complete only when its schema, indexes, RLS, public RPC wrappers, audit events, idempotency behavior, typed Dart contracts, Arabic-first UI, anonymous denial checks, available builds/tests, documentation, and activation gates are present. The system must demonstrate that disabling the new module registry or event worker leaves browsing, cart, checkout, manual payment review, order history, and existing ERP accounting paths unchanged.

## Source references

[1]: `pasted_file_H023Wd_AI-FirstERPArchitectureBlueprint.pdf` — attached AI-first ERP architecture, financial engineering, AI/ML, event mesh, dual-engine, vector-search, and security blueprint.

[2]: `pasted_file_jSeRZL_ComposableERPArchitectureBlueprint.pdf` — attached composable ERP bounded-context, modular-monolith, extension, event-sourcing, CQRS, outbox, saga, and frontend-composition blueprint.

[3]: `docs/AI_AGENTIC_WORKFLOW_AND_AUTHORITY_PLAN.md` — Yemen Commerce AI authority and staged workflow contract.

[4]: `docs/modular-expansion.md` — Yemen Commerce modularity, adapter, feature-flag, and acceptance contract.

[5]: `docs/ERP_INCREMENT_20260827_REPORT.md` — current deployed ERP baseline and validation report.

## Implemented status for this increment

Migrations `20260827_0068_composable_erp_core.sql`, `20260827_0069_composable_erp_fk_indexes.sql`, `20260827_0070_composable_visibility_hardening.sql`, and `20260827_0071_universal_journal_creator_only.sql` are applied to the connected Supabase project. They add the logical module registry, versioned module contracts, event envelope fields, inbox deduplication, projection checkpoints, universal-journal projection records for posted journal lines, metadata-only extension manifests, the Creator event-mesh dashboard, bounded universal-journal reads, and reason-required extension-manifest review. Migrations 0070–0071 ensure merchant clients see only enabled non-Creator module metadata; event-mesh health and universal-journal projections remain Creator-only, including direct PostgREST table reads.

The Creator Console now renders the Composable ERP Control Center in Arabic, including module status, API versions, event health, disabled external delivery state, and a review-only extension form. The merchant ERP card now renders a safe composable module summary. No third-party code, WASM, network, provider, or direct database capability is granted to an extension manifest.

## Validation evidence

The connected anonymous authorization runner passed `133` checks and skipped `5` authenticated role cases because isolated test tokens were not supplied. Security Advisor returned `lints: []` after migration 0071. Performance Advisor returned `347` informational `unused_index` observations only, with no warnings, errors, or ERP unindexed-FK findings after migration 0069. A bounded structural check confirmed all six new public ERP base tables have RLS enabled and one policy each. Both Flutter apps have clean analysis; Creator tests pass (`3`), customer tests pass (`28`), TypeScript passes, Vitest passes (`21`), and both Flutter Web release builds succeed with placeholder public configuration.

## Remaining staged items

The blueprints’ physical distribution and high-autonomy features remain intentionally staged. Kafka/Debezium/CDC, ClickHouse, schema-per-tenant storage, full event-sourced ledger replacement, active projection workers, third-party WASM execution, dynamic JavaScript micro-frontends, vector embedding generation, graph neural networks, vision OCR, global tax-provider calls, autonomous negotiation, automatic collections, and payment/settlement automation require separate scale, provider, security, compliance, and isolated-authenticated-test gates. They are not represented as active functionality by this increment.

## B-8 — Local commerce distribution, resilient fulfillment, and replay safety (0072–0075)

The first post-0071 research increment translates the platform, composable-commerce, SCM, and Yemen-market findings into a carrier-neutral operational slice. Migrations `20260827_0072_channels_logistics_returns.sql` through `20260827_0075_channels_logistics_idempotency.sql` add module contracts for `commerce_channels`, `delivery_orchestration`, `returns_logistics`, and `trust_operations`, then add actor-scoped, request-hash-checked command idempotency.

The slice provides merchant-owned channel records and channel listings for web, social, POS, B2B, marketplace, and service channels; bounded public catalog reads for active channels of approved shops in active markets; shipment plans and append-only status events; delivery exception queues; return logistics and append-only return events; merchant operation summaries; and Arabic-safe Flutter adapters. It deliberately models provider-neutral workflows rather than pretending that a courier, wallet, or marketplace API is connected.

The safety contract is explicit. Shipment transition to dispatch, transit, or delivery requires an actually confirmed paid payment, not a submitted proof. Return closure does not refund or settle anything. Event histories reject updates and deletes. Every mutation has ownership/state checks, an audit reason, and a narrow RPC boundary. The public catalog uses invoker semantics with an anonymous policy limited to active channels attached to approved shops and active markets. Migration `0073` supplies the six operational foreign-key indexes found by the 0072 scan; migration `0074` supplies the missing active-channel public RLS policy.

The merchant hub includes an Arabic-first channel authoring card and operational count chips. Shipment, delivery-exception, and return workbench dialogs are intentionally the next UI increment so that each command can expose its reason, payment gate, no-custody notice, and refreshed timeline. Migration 0075 now provides actor-scoped command keys, request-hash reuse protection, cached results, and explicit `idempotent` responses for these operations. The keyed commands are ready for a future offline replay adapter, but no worker or automatic replay activation is claimed by this increment.

### B-8 validation and next steps

Security Advisor is clean after 0075. The bounded structural RLS query confirms RLS and at least one policy on all seven new base tables: `commerce_channels`, `channel_listings`, `shipment_plans`, `shipment_events`, `delivery_exceptions`, `return_logistics`, and `return_logistics_events`. The anonymous authorization suite passes 150 checks and intentionally skips five authenticated-role vectors because no isolated tokens were provided. Flutter analysis/tests and Web release builds pass for both the customer/merchant app and Creator Console. Performance Advisor reports 364 INFO-only unused-index observations and no new operational unindexed-FK finding.

Next: add merchant operational dialogs, customer-owned delivery/return timelines, channel-listing assignment/read projections, and multi-storefront theme/catalog segmentation. The keyed command layer is now available for later offline replay, but a worker remains disabled until an approved durable host and operational controls exist. External couriers, Jaib, Yemen Mobile, messaging providers, and background workers remain disabled until their API, credential, callback, compliance, hosting, and reconciliation gates are separately approved.
