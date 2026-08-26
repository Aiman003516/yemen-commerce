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

All migrations use UUIDs, explicit grants, narrow public wrappers, fixed `search_path` for security-definer code, RLS, ownership/market checks, and audit events where writes affect operations or governance. Payment state remains separate from fulfilment and recovery cases; no migration gives the platform custody of merchant funds.

## Flutter implementation

The customer/merchant Flutter app now has typed contracts and repository methods for service areas, pickup points, private customer addresses, delivery zones, product variants, order cases, notifications, reviews, promotions, storefront settings, inventory locations, merchant analytics, delivery-aware checkout, and COD collection. The customer UI includes an address book, notification inbox, address/pickup/zone selection at checkout, order cancellation/return/dispute request flow, and merchant workspace catalog/product creation. The merchant workspace now surfaces aggregate insights, lets merchants save promotion drafts, includes a provider-ready advanced-services preview, and exposes a server-controlled COD collection action. The customer app has a separate advanced-services destination with clearly labeled mock/manual/blocked states. The Creator Console includes a provider hub for WhatsApp/SMS, local delivery, maps, external sales channels, financing, and advanced analytics. These screens never send messages, create provider shipments, verify payments, move funds, or publish to external channels. The shared command-outbox contract now has an encrypted Flutter secure-storage implementation with deterministic ordering and corruption recovery; replay orchestration and server-side idempotency adoption remain staged work.

## Validation

The Supabase security advisor returned no lints after the deployed migrations. The anonymous authorization runner covers all creator, provider, address, variant, order-case, courier, review, promotion, and notification RPCs, plus protected creator tables. The latest run is `34 passed / 5 skipped`; authenticated synthetic customer, merchant, review-agent, support-agent, and creator checks remain skipped until isolated access tokens or an isolated test project are supplied. Both Flutter apps pass analysis/tests, and customer/Creator Console production Web builds pass with public Supabase build-time configuration.

## Remaining staged work

The next increments should add outbox replay orchestration with RPC idempotency keys, real courier/dispatch screens, service-area and pickup configuration UI in Creator Console, promotion application inside checkout with immutable discount snapshots, review moderation UI, storefront/theme rendering, multi-location stock allocation, POS, B2B purchasing, API/webhook controls, approved wallet adapters, and Android/iOS release validation where platform toolchains are available. Provider adapters must remain independently gated by credentials, terms, webhook verification, consent, settlement behavior, and compliance review; the current provider pages are mock/demo surfaces only.
 Automatic Jaib verification remains blocked on official AHD/Alhazmi API, sandbox, callback, settlement, refund, and approval documentation.
