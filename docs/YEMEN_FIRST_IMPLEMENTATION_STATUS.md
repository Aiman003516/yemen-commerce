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

All migrations use UUIDs, explicit grants, narrow public wrappers, fixed `search_path` for security-definer code, RLS, ownership/market checks, and audit events where writes affect operations or governance. Payment state remains separate from fulfilment and recovery cases; no migration gives the platform custody of merchant funds.

## Flutter implementation

The customer/merchant Flutter app now has typed contracts and repository methods for service areas, pickup points, private customer addresses, product variants, order cases, notifications, reviews, promotions, storefront settings, inventory locations, and merchant analytics. The customer UI includes an address book, notification inbox, order cancellation/return/dispute request flow, and merchant workspace catalog/product creation. A shared command-outbox contract provides idempotency-key semantics for future persistent offline replay; the current reference implementation is in-memory and is not yet a production offline database.

## Validation

The Supabase security advisor returned no lints after the deployed migrations. The anonymous authorization runner covers all creator, provider, address, variant, order-case, courier, review, promotion, and notification RPCs, plus protected creator tables. Authenticated synthetic customer, merchant, review-agent, support-agent, and creator checks remain skipped until isolated access tokens or an isolated test project are supplied. Flutter analysis and tests pass for `packages/commerce_core` and `flutter_app` after the increment.

## Remaining staged work

The next increments should add persistent encrypted outbox storage and replay, real courier/dispatch screens, service-area and pickup configuration UI in Creator Console, promotion application inside checkout with immutable discount snapshots, review moderation UI, storefront/theme rendering, multi-location stock allocation, POS, B2B purchasing, API/webhook controls, approved wallet adapters, and release validation across both Flutter apps. Automatic Jaib verification remains blocked on official AHD/Alhazmi API, sandbox, callback, settlement, refund, and approval documentation.
