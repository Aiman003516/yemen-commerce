# Yemen-first implementation status

This document records the broad Yemen-first expansion increment implemented on branch `migration/flutter-supabase-foundation`.

## Deployed Supabase increments

| Migration | Capability | State |
|---|---|---|
| `20260825_0009_market_delivery_foundation.sql` | Market service areas, pickup points, customer addresses, merchant delivery zones, scoped RLS, address-save RPC | Deployed |
| `20260826_0010_product_variants.sql` | Product variants, SKU, variant price/stock/status, merchant ownership RPC | Deployed |
| `20260826_0011_order_cases.sql` | Customer cancellation, return, dispute cases and merchant/admin review RPCs | Deployed |
| `20260826_0012_courier_operations.sql` | Courier role, courier profiles, order assignment, pickup/delivery handoff RPCs | Deployed |
| `20260826_0013_notification_events.sql` | Durable recipient-scoped notification events and read acknowledgement RPC | Deployed |
| `20260826_0014_reviews_promotions.sql` | Completed-order product reviews and merchant promotion configuration | Deployed |
| `20260826_0015_storefront_inventory.sql` | Storefront settings, theme/custom-domain fields, inventory locations, location stock foundation | Deployed |
| `20260826_0016_merchant_analytics.sql` | Aggregate merchant dashboard metrics without customer or payment-evidence exposure | Deployed |
| `20260826_0017_checkout_operations.sql` | Delivery address/pickup snapshots, server-side delivery fees, location reservations, append-only COD reconciliation, reservation release/finalization RPCs | Deployed |
| `20260826_0018_trust_support_quality.sql` | Support tickets, internal risk signals, and explainable merchant quality summaries | Deployed |
| `20260826_0019_provider_integrations_rollouts.sql` | Provider catalog, secret-reference-only merchant integrations, webhook-event storage foundation, and market feature rollouts | Deployed |
| `20260826_0020_market_governance_reviews.sql` | Creator service-area/pickup-point governance and review moderation RPCs | Deployed |
| `20260826_0021_loyalty_b2b_pos_inventory.sql` | Loyalty ledger, business profiles, wholesale requests, local POS sessions/sales, and non-custodial operational records | Deployed |
| `20260826_0022_idempotency_promotions.sql` | Retry-safe checkout command keys and server-side promotion application into order pricing snapshots | Deployed |
| `20260826_0023_dispatch_b2b_pos_close.sql` | Courier dispatch events, B2B wholesale price lists and review pricing approval, and POS close/reconciliation | Deployed |
| `20260826_0024_b2b_pos_analytics_export.sql` | Merchant-scoped B2B/POS aggregates, bounded privacy-safe exports, audit events, and analytics indexes | Deployed |

All migrations use UUIDs, explicit grants, narrow public wrappers, fixed `search_path` for security-definer code, RLS, ownership/market checks, and audit events where writes affect operations or governance. Payment state remains separate from fulfilment and recovery cases; no migration gives the platform custody of merchant funds.

## Flutter implementation

The customer/merchant Flutter app now has typed contracts and repository methods for service areas, pickup points, private customer addresses, delivery zones, product variants, order cases, notifications, reviews, promotions, storefront settings, inventory locations, merchant analytics, delivery-aware checkout, retry-safe checkout, server-side promotion application, COD collection, merchant quality, support tickets, provider catalog metadata, B2B business profiles/wholesale requests and merchant price-list review, courier dispatch handoff events, POS operations, B2B/POS aggregate analytics, and bounded CSV export. Checkout failures now persist an idempotent non-financial command into a user-scoped encrypted outbox, and the customer app exposes a sync center with pending/failed/blocked diagnostics, retry, discard, attempt counts, masked command identifiers, and privacy-safe error messaging. The foreground app listens for connectivity changes, while Android/iOS use a WorkManager best-effort periodic and connectivity-constrained one-off task; Web remains session/network/manual driven. Replay has a process-wide mutex and never includes payment finalization, payment proof, or fund movement. The customer UI includes an address book, notification inbox, address/pickup/zone selection at checkout, support-ticket creation, order cancellation/return/dispute request flow, and merchant workspace catalog/product creation. The merchant workspace now surfaces aggregate insights, explainable quality metrics, provider catalog configuration in preview/manual states, promotion drafts, advanced-services previews, server-controlled COD collection, courier dispatch handoff actions, B2B wholesale request review and price-list drafts, B2B funnel/pricing analytics with CSV export, and POS session/sale recording with structured line items, close/match controls, reconciliation analytics, and CSV export. The Creator Console includes provider, trust/support, and live market-operations pages for service-area and pickup-point governance. These screens never send messages, create provider shipments, verify payments, move funds, publish to external channels, or activate a provider without a server-side approval path.

## Validation

The Supabase security advisor returned no lints after migration 0024. The performance advisor still reports baseline informational findings for legacy unindexed foreign keys and permissive-policy patterns; the new B2B/POS query paths have supporting shop/date indexes and bounded limits. The anonymous authorization runner covers the four new analytics/export RPCs as well as creator, provider, address, variant, order-case, courier, review, promotion, and notification RPCs, plus protected creator tables. The latest run is `61 passed / 5 skipped`; authenticated synthetic customer, merchant, review-agent, support-agent, and creator checks remain skipped until isolated access tokens or an isolated test project are supplied. Customer/Creator Console analysis/tests and production Web builds remain the required validation gates; Android/iOS device and archive validation are still platform-toolchain gates.

## Remaining staged work

Remaining staged work includes courier provisioning and richer dispatch filtering, review moderation list UI, storefront/theme rendering, full multi-location stock write/transfer/count workflows, B2B price-list item editing and negotiated checkout pricing, provider event ingestion through a server-side adapter, approved wallet adapters, isolated authenticated RLS tests, and Android/iOS release validation where platform toolchains are available. Provider adapters must remain independently gated by credentials, terms, webhook verification, consent, settlement behavior, and compliance review; the current provider pages are mock/demo surfaces only. The new audit report documents the scheduler timing caveat, user-scope decision, privacy boundary, performance findings, and follow-up device testing.
 Automatic Jaib verification remains blocked on official AHD/Alhazmi API, sandbox, callback, settlement, refund, and approval documentation.
