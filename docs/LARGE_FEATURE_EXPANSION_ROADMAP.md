# Yemen Commerce Large Feature Expansion Roadmap

**Author:** Manus AI
**Reference date:** 27 August 2026
**Scope:** ERP, composable commerce, AI-assisted operations, logistics, payments, local services, trust, and scale.

## Executive direction

Yemen Commerce can support a large, multi-year implementation, but the correct strategy is not to copy a vendor’s entire product surface. The platform should become a **modular commerce operating system**: Supabase remains the authority for identity, organizations, orders, payment claims, immutable financial history, audit, and row-level authorization; Flutter remains the customer/merchant/Creator surface; and each capability is delivered as a versioned bounded context with a narrow RPC or typed query contract.

The research supports this direction. Shopify demonstrates the value of unified B2C, retail, B2B, fulfillment, API, and developer surfaces [1]. Odoo demonstrates the value of a broad integrated module catalog spanning commerce, finance, inventory, services, and productivity [2]. Microsoft and Oracle demonstrate that useful ERP AI is contextual and role-scoped, combining embedded assistance, authorized data inquiry, workflow summaries, extraction drafts, matching, forecasting, and agent governance rather than unrestricted mutation [3] [4]. SAP and Oracle SCM emphasize planning, procurement, execution, warehouse, transportation, risk, and exception workflows [5] [6]. commercetools and BigCommerce show that independent versioned APIs and multi-storefront management are differentiators beyond a conventional monolith [7] [8].

Yemen-specific research changes the prioritization. Connectivity limitations, cash-heavy transactions, weak trust in digital payments, disrupted transport networks, fraud exposure, and regulatory uncertainty make offline-tolerant flows, manual merchant-owned payment confirmation, private proof evidence, service-area modeling, delivery exceptions, pickup, customer education, and human review more valuable than card-first or fully autonomous automation [9] [10]. Jaib’s public listing documents wallet transfers, bill payment, recharge, agent cash-out, QR/POS purchase payment, and statements, but does not document a public developer API, webhook, SDK, sandbox, or settlement contract [11]. Therefore Jaib and similar services must remain provider-gated adapters, not assumed integrations.

> **Invariant:** A payment proof is evidence for merchant review, not proof that payment is settled. The platform never holds merchant funds, never exposes private evidence publicly, and never allows AI or an external provider to mark an order paid without the existing audited authority boundary.

## Capability matrix

| Capability family | Research-backed benchmark | Yemen Commerce target | Current state | Activation gate |
|---|---|---|---|---|
| Multi-storefront and channels | Shopify, BigCommerce, commercetools [1] [7] [8] | Merchant-owned web, social, POS, B2B, marketplace, and service channels with channel-specific listings, prices, themes, and availability | **Implemented in current increment:** channel registry, listings, public active catalog query, merchant channel card | Merchant ownership, approved shop, active product, Arabic content, no credential storage |
| Delivery orchestration | SAP and Oracle SCM [5] [6] | Carrier-neutral shipment plans, status timelines, handoff events, exceptions, service areas, pickup, and courier workflows | **Implemented in current increment:** shipment plans/events and delivery exceptions; existing courier operations retained | Confirmed merchant payment before dispatch/in-transit/delivery; provider callbacks remain disabled |
| Returns and exchanges | Enterprise commerce and SCM patterns [1] [5] [6] | Case-based returns, inspected/received states, exchange proposals, customer timelines, and merchant resolution notes | **Implemented in current increment:** return logistics and append-only return events | No automatic refund or settlement; merchant review and reversal-based accounting only |
| Finance and accounting | Odoo, Microsoft, Oracle [2] [3] [4] | Multi-entity, multi-book accounting, immutable journals, AR/AP, revenue recognition, allocation, consolidation, budget/forecast, and audit explanations | **Foundation deployed:** ERP schema, balanced journal authoring/posting, projections, reason-required Creator controls | Isolated authenticated tests, finance policy approval, reversal flows, no custody automation |
| Procurement and supplier operations | Odoo, SAP, Oracle [2] [5] [6] | Vendor master, RFQ/quote comparison, purchase orders, receipt matching, bills, supplier scorecards, negotiation drafts | **Foundation and projections deployed:** vendor/PO/bill/match and vendor negotiation storage | Human approval, private evidence, provider/OCR disabled by default |
| CRM and customer 360 | Odoo, Microsoft, BigCommerce [2] [3] [8] | Accounts, contacts, health, dunning drafts, contracts, subscriptions, entitlements, tickets, field work, and customer timelines | **Foundation and projections deployed:** customer 360, dunning, contracts, subscriptions, tickets, field assignments | Customer consent, role-scoped visibility, no silent outbound messaging |
| AI advisory operations | Microsoft and Oracle [3] [4] | Contextual summaries, demand/warehouse insights, invoice extraction drafts, reconciliation suggestions, anomaly explanations, terminology memory, and provenance | **AI-0 to AI-6 deployed:** governance, tools, reviewable merchant actions, knowledge, queues, quota/consent controls | Creator governance, merchant confirmation for mutations, fixed allowlist, provenance/confidence, no arbitrary SQL/RPC/URL |
| Local payments and services | Jaib and Yemen Mobile public capabilities [11] [12] | Manual payment methods, QR/POS reference capture, service catalogs, recharge/bill-payment order types, reconciliation views, and provider adapters | **Manual payment foundation deployed; provider registry staged** | Public API, credentials, callbacks, reconciliation, compliance, and explicit provider enablement |
| Trust and safety | Yemen policy/academic findings [9] [10] | Evidence privacy, fraud signals, dispute cases, merchant/customer education, access review, delivery-risk flags, and immutable audit | **Partial:** RLS, private evidence, case model, audit, provider gates | Isolated role testing, risk-policy approval, no automated adverse decision without review |
| Event mesh and extensibility | CloudEvents, OpenAPI, composable architecture [7] [13] [14] | Versioned envelopes, inbox deduplication, projection checkpoints, module contracts, reviewed extension manifests, and future OpenAPI description | **Implemented foundation:** migrations 0068–0071 and module registry | Durable worker hosting and secrets approved separately; metadata-only extensions remain default |
| Analytics and graph | Odoo, SAP, Oracle, AI-ERP patterns [2] [4] [5] | Operational rollups, cohorts, profitability dimensions, anomaly queues, relationship graph, and export contracts | **Foundation and bounded rollups deployed** | Analytical projections never become transactional authority; privacy and export controls |
| Workforce and field operations | SAP/Oracle service and asset patterns [5] [6] | Technician/field assignment, checklists, proof-of-work, service areas, and offline handoff | **Projection foundation deployed:** field assignments | Private evidence, assignment scope, explicit completion review |
| Scale and interoperability | BigCommerce, commercetools, OpenAPI, CloudEvents [7] [8] [13] [14] | Typed module contracts, API versioning, import/export, idempotency, partner adapters, and eventual read-model separation | **Composable core deployed**; no external broker or warehouse yet | Measured scale thresholds, contract tests, provider and hosting review |

## Dependency graph and delivery order

The implementation should proceed in dependency order. **Identity and scope** come first, followed by immutable commerce facts, then operational projections, then reviewable automation, and finally provider-backed or high-scale infrastructure.

```text
Auth / roles / markets / RLS
        |
Orders + merchant-owned payment claims + private evidence
        |
Inventory + storefront + channels + service areas
        |
Shipment plans + courier handoffs + exceptions + return cases
        |
ERP journals + AR/AP + procurement + CRM + contracts
        |
Versioned events + inbox/checkpoints + analytics projections
        |
AI advisory + reviewable proposals + knowledge/provenance
        |
Provider adapters + durable workers + external channels
        |
Scale separation: read models / CDC / analytical warehouse
```

A feature is not considered production-ready merely because its table exists. Each increment must include a typed contract, authorization boundary, Arabic UI state model, audit semantics, error localization, bounded reads, no-fixture tests, and an explicit activation gate. Provider-backed capabilities must additionally include documented API behavior, secret storage, callback verification, retry/idempotency, reconciliation, and operational ownership.

## Staged execution backlog

### Wave A — Commerce distribution and resilient fulfillment

This is the highest-value local-commerce wave because it improves merchant reach and customer trust without requiring third-party credentials. The current increment implements the core slice: merchant channels, channel listings, carrier-neutral shipment plans, append-only shipment events, delivery exceptions, return logistics, localized error messages, and merchant operations metrics.

The next A-wave increments should add service-area availability checks, pickup-point selection, delivery promise projections, customer shipment timelines, exchange proposals linked to order cases, and offline-safe courier handoff drafts. All changes should be reviewable and must not alter payment state. A delivery status can become `completed` only under the existing confirmed-paid rule.

### Wave B — Finance-core operations

Build narrow, audited RPCs for AR invoice drafts, customer account statements, vendor bills, three-way match review, budget versions, allocations, intercompany netting previews, and reversal-based corrections. The Creator Console should expose finance review queues and reason-required authoring; the merchant app should expose only merchant-owned summaries, statuses, and actionable exceptions.

AI may extract, summarize, classify, and propose. It may not post a journal, settle a bill, mark an order paid, issue a refund, or execute an external payment. Every proposed financial action must carry source provenance, confidence, exact argument hash, reviewer identity, and an approval record.

### Wave C — CRM, contracts, and service operations

Add customer-360 timeline reads, contact consent, dunning drafts, contract lifecycle, subscription entitlements, support triage, service tickets, and field assignments. The merchant UI should organize work into queues rather than expose raw tables. Customer-facing pages should use concise Arabic explanations and show only the customer’s own orders, cases, delivery events, and messages.

Outbound WhatsApp, SMS, email, and voice actions stay disabled until a provider is selected and verified. Draft messages can be generated and reviewed, but no message is sent automatically from a database trigger or unapproved AI workflow.

### Wave D — Local services and payment adapters

Introduce service products for recharge, bill-payment requests, agent-assisted cash-out, and local utility workflows. Start with a provider-neutral catalog and manual reference capture, then add adapters only after official API, callback, sandbox, settlement, dispute, and compliance documentation is available. Jaib and Yemen Mobile should be treated as research inputs, not assumed technical integrations [11] [12].

The payment UX should explain four states separately: payment instructions shown, customer claim submitted, merchant review pending, and merchant-confirmed paid. No external provider response should bypass the existing audited payment transition.

### Wave E — AI-first operational intelligence

Expand the existing bounded AI runtime with read-only projections: demand and stock risk, delivery-risk explanation, AR aging summary, AP matching suggestions, customer-health rationale, forecast scenarios, and anomaly review. Each tool must declare its scope, input schema, output schema, provenance, confidence, data freshness, and whether it is advisory or reviewable.

The AI control plane should add evaluation datasets, Arabic terminology governance, tool health, quota dashboards, prompt/version lineage, and safe rollback. External agents and MCP remain consent-based, revocable, SSRF-defended, quota-limited, and disabled by default.

### Wave F — Partner ecosystem and scale

Publish machine-readable OpenAPI contracts for approved public reads and narrow partner commands, align event envelopes with CloudEvents concepts, and add contract compatibility tests [13] [14]. Add import/export jobs with idempotency, dry runs, validation reports, and private result files. Only after measured workload thresholds should the platform consider a durable worker, CDC, a separate analytical store, or a broker.

For any near-real-time worker, use an explicitly approved durable host with server-only secrets. Do not use high-frequency Manus sessions as a polling architecture. A future worker must have leases, retry backoff, dead-letter handling, observability, replay controls, and a kill switch.

## UI composition standard

Every new capability should appear in the appropriate app rather than being duplicated everywhere.

| Surface | Primary responsibility | Required UI behavior |
|---|---|---|
| Customer app | Discover, purchase, pay manually, track, open cases, receive explanations | Arabic-first RTL, low-bandwidth states, private evidence upload, clear distinction between claim and confirmation, timeline-first delivery/returns |
| Merchant app | Operate catalog, channels, inventory, orders, fulfillment, CRM, and review queues | Merchant scope only, safe summaries, reason-required mutations, offline-aware retry states, no financial rows belonging to other merchants |
| Creator Console | Govern modules, policies, providers, organizations, ledgers, AI, extensions, and platform-wide risk | Capability-aware navigation, high-impact confirmation, audit reason, staged rollout controls, provider readiness, cross-tenant views only through Creator-authorized projections |

Loading, empty, error, disabled-provider, and permission-denied states are part of the feature contract. Arabic error messages must hide raw database codes while retaining a stable internal signal for diagnostics. Every mutation form should show the relevant safety notice before confirmation.

## Acceptance gates for every increment

1. **Data authority:** authoritative facts remain in Supabase; projections and analytics cannot mutate orders, payments, journals, or evidence.
2. **Authorization:** private implementation functions use fixed `search_path`, actor identity from `auth.uid()`, explicit scope checks, narrow public wrappers, and revoked anonymous access where appropriate.
3. **Financial safety:** no platform custody, no payment-proof shortcut, immutable history, balanced journals, and reversal-based corrections.
4. **Privacy:** identity, payment proof, customer contact details, and provider secrets remain private; public catalog queries return only approved public fields.
5. **Idempotency and state machines:** repeated commands are safe, state transitions are explicit, and invalid transitions fail atomically.
6. **UI completeness:** Arabic-first customer/merchant/Creator surfaces include loading, empty, error, disabled, confirmation, and refresh states.
7. **Testing:** anonymous deny suite passes; authenticated role tests run only against isolated tokens/projects; no synthetic users or fixtures are created in the shared project.
8. **Performance:** every new foreign key is indexed or intentionally justified; Security Advisor has no actionable findings; Performance Advisor findings are classified.
9. **Automation:** workers, webhooks, external messaging, and provider callbacks are not activated without an approved durable host, server-only secrets, verification, retries, and an operational owner.
10. **Release:** Dart formatting, Flutter analysis/tests, Web release builds, contract tests, diff hygiene, and branch verification pass before commit.

## Current implementation checkpoint

The current branch has the composable ERP core and the new commerce-distribution/fulfillment slice deployed to Supabase through migrations `0072`–`0075`. Migration `0073` remediates all six new unindexed operational user foreign keys, migration `0074` corrects public active-channel visibility, and migration `0075` adds actor-scoped, request-hash-checked idempotency to every channel, shipment, delivery-exception, and return mutation while preserving legacy overloads. The merchant app now exposes a channel-management card and the ERP operations card includes channel, shipment, delivery-exception, and return counts. The Flutter API boundary includes typed adapters, required command keys, and localized errors for channel and logistics commands.

The current validation checkpoint is:

| Check | Result |
|---|---|
| Security Advisor after migration 0075 | `0` lints |
| Performance Advisor after migration 0075 | `364` lints, all `INFO` unused-index observations; no new operational unindexed-FK findings |
| New operational RLS structural query | All seven new base tables have RLS enabled and at least one policy |
| Anonymous authorization boundary | `150 passed, 5 skipped`; all new protected RPCs, including keyed overloads, denied anonymously |
| Customer/merchant Flutter app | Analysis clean; `29` tests passed; Web release build passed |
| Creator Console | Analysis clean; `3` tests passed; Web release build passed |

The five authenticated cases remain skipped because isolated customer, merchant, reviewer, support, and Creator tokens were not supplied. No synthetic users, production fixtures, provider credentials, or shared-project test mutations were created.

## Research references

[1]: https://www.shopify.com/enterprise "Shopify Enterprise"
[2]: https://www.odoo.com/page/all-apps "Odoo Applications"
[3]: https://learn.microsoft.com/en-us/dynamics365/fin-ops-core/fin-ops/copilot/copilot-for-finance-operations "Microsoft Dynamics 365 Copilot for Finance and Operations"
[4]: https://www.oracle.com/erp/ai-financials/ "Oracle AI for ERP"
[5]: https://www.sap.com/products/scm.html "SAP Supply Chain Management"
[6]: https://www.oracle.com/scm/ "Oracle Supply Chain and Manufacturing"
[7]: https://commercetools.com/commerce-platform "commercetools Commerce Platform"
[8]: https://www.bigcommerce.com/solutions/multi-store/ "BigCommerce Multi-Storefront"
[9]: https://sanaacenter.org/publications/policy-research/25516 "Fostering Opportunities for E-Commerce Growth in Yemen"
[10]: https://www.mdpi.com/2071-1050/15/18/13712 "Unlocking the Potential of E-Commerce in Yemen"
[11]: https://apps.apple.com/us/app/jaib-digital-wallet/id6472856710 "Jaib Digital Wallet App Store Listing"
[12]: https://yemenmobile.com.ye/en "Yemen Mobile"
[13]: https://cloudevents.io/ "CloudEvents"
[14]: https://swagger.io/specification/v3.2/ "OpenAPI Specification"
