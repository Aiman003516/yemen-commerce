# Yemen Commerce ERP Increment Report

**Branch:** `migration/flutter-supabase-foundation`
**ERP implementation commit:** `86e1c0e8d05c6de5778d7520d09a67ef684fd7bf`
**Final branch head:** `3a003ee`
**Scope:** ERP expansion on top of the existing Arabic-first Flutter/Supabase commerce platform.

## Delivered and deployed

Migrations `20260826_0059` through `20260826_0067` are applied to the connected Supabase project. The 32-feature ERP registry and scoped foundation remain in place, including organization/legal-entity accounting, multi-book charts of accounts, immutable journals, dimensions, revenue schedules, consolidation/allocation/funds/projects, procure-to-pay records, CRM/contracts/subscriptions/field service, provider adapters, event/webhook/workflow tables, analytics rollups, graph edges, and merchant-safe catalog/dashboard projections.

The first operational projection slice now adds intercompany netting previews, AR invoices and invoice lines, manual collection records, dunning message drafts, customer-360 snapshots, vendor quote requests/bids/negotiation drafts, CPQ quote and line projections, and field-work-order assignments. These are scoped storage and read-model foundations; they do not autonomously send messages, settle payments, place vendor orders, or post ledgers.

The Creator Console now contains an Arabic-first ERP authoring panel. It supports creation of organizations, legal entities, accounting books, and chart-of-account entries through the deployed RPC boundary. It also creates a two-line balanced journal draft and requires a separate explicit reason-confirmed action before posting. Form labels, UUID direction, reason validation, error feedback, refresh behavior, and the no-custody message are included.

The journal-line boundary was hardened in migration `0066` so the account organization is compared independently with the draft batch organization. Migration `0067` removes the legacy authoring signatures and requires a non-empty audit reason for organization, legal entity, book, account, and journal-batch creation. The typed Dart repository and anonymous authorization runner were updated accordingly.

## Preserved invariants

| Invariant | Current status |
|---|---|
| Arabic-first customer, merchant, and Creator experiences | Preserved; the new Creator ERP forms are Arabic-labelled and RTL-aware. |
| Supabase Auth/Postgres/RPC/RLS/audit as authority | Preserved; direct new-table grants are revoked and mutations use narrow RPCs. |
| Merchant-owned/manual payments and no platform custody | Preserved; ERP screens explicitly do not determine payment or hold funds. |
| Payment proof is not payment confirmation | Preserved; no ERP projection changes payment state. |
| Immutable financial/order/payment history | Preserved; posted journal mutation remains blocked and corrections are reversal-oriented. |
| Private evidence and server-only secrets | Preserved; no evidence or provider secret is exposed by the new ERP surface. |
| Provider gates disabled by default | Preserved; OCR, tax, bank-feed, messaging, routing, signature, and autonomous negotiation remain disabled. |

## Validation

| Area | Result |
|---|---|
| Supabase migration application | `0059`–`0067` applied successfully. |
| Security Advisor | `lints: []` after migration `0067`. |
| Performance Advisor | `0` unindexed-FK findings, `0` warnings, `0` errors; `334` informational unused-index observations remain. |
| ERP RLS structural check | Every returned public ERP base table had `relrowsecurity = true` and at least one policy. The query filtered `relkind = 'r'`. |
| Anonymous RPC boundary | `RESULT passed=128 skipped=5`. |
| Authenticated authorization cases | Skipped only because isolated customer, merchant, reviewer, support-agent, and creator tokens were not supplied; no synthetic users or shared-project fixtures were created. |
| Flutter analysis | Customer and Creator apps: clean. |
| Flutter tests | Customer: `28 passed`; Creator: `2 passed`. |
| Flutter Web release builds | Customer and Creator: both built successfully with the ignored placeholder public configuration. |
| TypeScript | `tsc --noEmit` passed. |
| Vitest | `7` test files, `21` tests passed. |
| Git hygiene | `git diff --check` passed; working tree is clean. |

## Staged or unavailable by design

The implementation does **not** claim that all 32 enterprise features are production-complete. Provider-backed OCR extraction, external tax calculation, bank feeds, automated collections messaging, live route optimization, e-signature, active webhook delivery, durable ERP event workers, broad invoice/AR posting workflows, full purchase-order/bill approval flows, complete CRM operations, and autonomous vendor negotiation remain staged or disabled. They require additional narrow RPCs, isolated authenticated tests, provider contracts, compliance review, and server-only credentials.

The existing AI-3 through AI-6 controls remain governed by creator policy, explicit merchant confirmation, quotas, consent, revocation, and disabled-by-default provider/background gates. No AI, forecast, anomaly, webhook, or ERP projection automatically posts a ledger, marks an order paid, settles a collection, or moves funds.

The branch was pushed successfully to GitHub. The ERP implementation is in commit `86e1c0e8d05c6de5778d7520d09a67ef684fd7bf`; the final branch head is `3a003ee` (verified after push). `main` was not merged.
