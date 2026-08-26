# Yemen Commerce Supabase workspace

This directory contains the version-controlled PostgreSQL and Supabase backend foundation for Yemen Commerce. The connected project is the dedicated Supabase project `mtaujfgkqvzwauqiegkl`.

## Runtime boundary

The application clients are Flutter/Dart for Android, iOS, and Web. They use the public Supabase project URL and publishable key through `supabase_flutter`. The service-role key, database connection string, and any provider credentials remain server-side project secrets and must never be committed or embedded in Flutter/browser builds.

The authoritative backend is Supabase PostgreSQL, Auth, Storage, RLS, triggers, SQL RPC functions, and narrowly scoped Supabase Edge Functions where a server-side secret or request orchestration boundary is required. No Node.js, Express, tRPC, Drizzle, or Forge storage service is required in the final production runtime. The request-triggered `ai-run` Edge Function is the first such boundary; it verifies Supabase JWTs, calls user-scoped RPCs, and keeps provider credentials server-side. Background workers and scheduled AI jobs are not part of this increment.

## Migrations

Apply migrations in filename order to a fresh development or staging project before production. The first migration creates the translated PostgreSQL schema, Ibb configuration, RLS policies, private Storage buckets, and core checkout/payment/fulfilment RPC implementations. The second migration moves privileged RPC implementations into the `private` schema and leaves narrowly exposed `SECURITY INVOKER` wrappers for Flutter calls.

The project was initially empty. The baseline `public.rls_auto_enable()` helper was hardened before application tables were created by revoking public and client-role execution. Security advisories must be checked again after every migration that adds functions, policies, or Storage behavior.

## Local commands

From the repository root, use the Supabase CLI or the connected project management workflow to apply and inspect migrations. The repository does not commit credentials. Flutter builds receive public configuration at build time, for example:

```text
flutter run -d chrome --dart-define=SUPABASE_URL=https://your-project.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=your-publishable-key
flutter build web --dart-define-from-file=config/web.supabase.json
```

`config/web.supabase.json` and equivalent mobile configuration files must remain ignored by Git. Only publishable client credentials belong in those files.

## Security rules

Every exposed application table must have explicit grants and RLS policies. Public reads are limited to active markets, enabled capabilities/policies, approved shops, active products, and active fulfilment options. Customer, merchant, and administrator access is derived from `auth.uid()` and database role membership. Identity evidence and payment proofs use private Storage buckets and must never be represented by permanent public URLs.

The checkout RPC is the transaction boundary for grouped carts. It must create exactly one merchant order per merchant group, preserve the payment snapshot, snapshot delivery address/pickup/zone data, apply server-side delivery fees, reserve stock atomically, write history and audit records, and clear the cart only when the complete transaction succeeds. Cash-on-delivery collection is recorded separately in an append-only reconciliation table; an order becomes paid only when the collected amount exactly matches the server-recorded expected amount.

## Creator Console migrations

The creator-control plane is deployed after the foundation migrations in this order:

```text
20260825_0005_creator_authorization.sql
20260825_0006_creator_control_rpc.sql
20260825_0007_creator_governance.sql
20260825_0008_payment_provider_boundary.sql
20260825_0009_market_delivery_foundation.sql
20260826_0010_product_variants.sql
20260826_0011_order_cases.sql
20260826_0012_courier_operations.sql
20260826_0013_notification_events.sql
20260826_0014_reviews_promotions.sql
20260826_0015_storefront_inventory.sql
20260826_0016_merchant_analytics.sql
20260826_0017_checkout_operations.sql
20260826_0018_trust_support_quality.sql
20260826_0019_provider_integrations_rollouts.sql
20260826_0020_market_governance_reviews.sql
20260826_0021_loyalty_b2b_pos_inventory.sql
20260826_0022_idempotency_promotions.sql
20260826_0023_dispatch_b2b_pos_close.sql
20260826_0024_b2b_pos_analytics_export.sql
20260826_0025_performance_advisor_remediation.sql
20260826_0026_export_pagination_guard.sql
20260826_0027_promotion_command_idempotency.sql
20260826_0028_order_command_keys_deny_policy.sql
20260826_0029_inventory_operations_bulk_catalog.sql
20260826_0030_product_barcodes.sql
20260826_0031_inventory_stock_consistency.sql
20260826_0032_inventory_fk_indexes.sql
20260826_0033_order_workbench_cod_reconciliation.sql
20260826_0034_cod_reconciliation_fk_indexes.sql
20260826_0035_cod_batch_date_guard.sql
20260826_0036_b2b_scale_quotes_rollups_assets.sql
20260826_0037_b2b_scale_fk_indexes.sql
20260826_0038_quote_projections.sql
20260826_0039_wholesale_request_quote_context.sql
20260826_0040_product_asset_completion.sql
20260826_0041_ai0_control_plane.sql
20260826_0042_ai0_policy_read_guard.sql
20260826_0043_ai0_fk_indexes.sql
20260826_0044_ai1_effective_policy.sql
  ```

Migrations 0005 and 0006 add explicit access controls, capabilities, delegated operator assignments, creator-only access helpers, people search, dashboard summaries, role delegation/revocation, account suspension/restoration, and capability grants. Migration 0007 adds creator-only RPCs for merchant verification, shop status moderation, market status moderation, market/policy/capability listing, policy-version creation, and per-market capability toggles. These operations are audited and remain behind creator authorization checks; the Creator Console exposes them through the Merchant Governance and Global Policies screens. Privileged implementations remain in the `private` schema; Flutter sees only narrow public RPC wrappers. The migrations do not create a creator account and do not grant a creator role automatically.

The matching security test starter is `supabase/tests/creator_authorization.test.sql`. It must be expanded and run against an isolated project with synthetic Auth users before any production creator account is bootstrapped.

## Authorization boundary runner

Run the available boundary test from the repository root:

```bash
./supabase/tests/run_creator_authorization.sh
```

The runner verifies the public client boundary against creator-control, checkout, operations, trust, provider, governance, review, loyalty, B2B, POS, idempotent-checkout, promotion, courier-dispatch, price-list, wholesale-review, POS-close, B2B analytics/export, POS analytics/export, inventory operations, bulk catalog import, barcode product-save, merchant order-workbench, COD reconciliation, quote projections, rollup refresh, asset completion, provider-operation, AI-0 lifecycle RPCs, the AI-1 effective-policy resolver, and protected creator tables. The latest recorded run produced `RESULT passed=95 skipped=5`. The five skipped cases are authenticated customer, merchant, review-agent, support-agent, and creator scenarios because isolated synthetic-user access tokens are not configured. The dedicated `supabase/tests/run_inventory_integration.sh` runner exercises a real authenticated multi-line transfer and inventory-count idempotency pair when isolated merchant credentials and fixture IDs are supplied; it refuses to run unless `SUPABASE_TEST_ISOLATED=1`. The `supabase/tests/run_order_workbench_cod_integration.sh` runner exercises owned workbench visibility, COD projection visibility, batch-open idempotency, cross-date batch rejection, exact collection, latest-record summary, close, and re-close denial. The new `supabase/tests/run_b2b_scale_integration.sh` runner exercises isolated request/price-list projections, immutable quote-version creation, merchant/customer quote visibility, acceptance, negotiated-price application and re-application denial, daily-rollup refresh, and the disabled provider-operation gate. Both authenticated runners safely skip until their isolated short-lived token and fixture variables are provided. To run those cases, use only an isolated test project or branch and never a production service-role key; do not commit tokens. The harness checks creator dashboard allowance and non-creator dashboard denial, while the SQL pgTAP starters document the remaining role-escalation and cross-role cases.

## Payment provider boundary and Jaib readiness

Migration `20260825_0008_payment_provider_boundary.sql` adds provider-aware payment metadata to merchant payment methods and immutable merchant-order snapshots. The supported provider codes are `manual`, `jaib`, `kuraimi`, `cash`, and `other`. All methods remain `mode = 'manual'` and `provider_verification = 'manual_only'` in this increment.

The Flutter customer/merchant app now shares a provider catalog and lets merchants label a method as Jaib, Al Kuraimi, cash, or a generic manual method. Jaib is presented as a manual QR/POS-capable option: customers are instructed to complete payment in Jaib and submit a transaction reference for merchant review. The system does not claim automatic verification, does not hold funds, and does not mark an order paid from proof alone.

Jaib’s official public consumer pages describe purchase payments, QR/POS identifiers, transfers, cash-in/cash-out, online shopping, and a service network, but no public developer API, webhook, SDK, sandbox, or settlement specification was identified. A formal Jaib provider implementation must wait for AHD/Alhazmi documentation, merchant-acquiring approval, sandbox credentials, callback security, settlement/reconciliation rules, refund behavior, and legal/compliance review. Until that gate is complete, use the manual/QR/POS flow.

The provider catalog is shared through `packages/commerce_core/lib/src/payment_providers.dart`, so future approved providers can be added without putting provider-specific logic into checkout or order state transitions.

The Flutter customer app now includes an encrypted sync center. Failed idempotent checkout, promotion, and merchant inventory commands are retained locally under the authenticated user’s secure-storage scope with their attempt count and bounded error context. Users can request replay, reset a failed command, or discard it with an explicit confirmation dialog. Foreground connectivity events trigger a best-effort constrained task, and Android/iOS register an OS-managed periodic task; Web remains session/network/manual driven. A replay mutex prevents duplicate local execution, all Secure Storage operations for the same user scope are serialized, and checkout, promotion, and inventory commands use server idempotency keys. Transport failures remain retryable; authorization, validation, stock-conflict, and other business-rule failures are persisted as blocked and are not retried blindly. The UI receives only a sanitized diagnostic projection without command payloads. The replay worker only invokes allowlisted authenticated non-financial RPCs; payment finalization, payment-proof submission, and fund movement remain outside offline replay. Exact timing after app termination is not guaranteed by Android or iOS. Inventory replay now includes transport-failure queueing and persistent blocked states for non-retryable conflicts.

Migrations 0009 through 0043 extend the pilot with market service areas, pickup points, private customer address ownership, merchant delivery zones, product variants, customer order cases for cancellation/return/dispute review, courier assignment and handoff operations, durable recipient-scoped notification events, completed-order product reviews, merchant promotion configuration, storefront/theme settings, inventory locations, aggregate merchant analytics, delivery-address and pickup snapshots at checkout, location-level inventory reservations, append-only cash-on-delivery reconciliation, server-side reservation release/finalization commands, support tickets, internal risk signals, explainable merchant quality metrics, provider catalog/configuration metadata, webhook-event storage foundations, staged market feature rollouts, Creator service-area/pickup governance, review moderation, loyalty ledgers, B2B business profiles/wholesale requests, local POS sessions/sales, retry-safe checkout command keys, server-side promotion application, courier dispatch events, B2B negotiated price lists and review approvals, immutable quote versions, negotiated checkout application, daily merchant rollups, private product-image variant metadata and completion, provider adapter-operation gates, POS close/reconciliation, merchant B2B/POS aggregates, bounded privacy-safe export RPCs, audit events, shop/date indexes, remediation for foreign-key findings and multiple-permissive-policy findings, explicit export pagination guards, server-side promotion command idempotency with an explicit client-deny policy for its internal key table, audited location-level inventory adjustments, atomic transfers and stock counts, barcode-aware product saves, bounded atomic catalog imports, product-stock consistency guards, targeted inventory foreign-key indexes, merchant order-workbench projections, COD reconciliation batches with append-only batch-linked collection records, bounded operational filters, and COD foreign-key indexes. These additions remain optional and fail safely when no service area, courier, notification, storefront, external provider adapter, or AI runtime is configured. Migrations 0041–0043 add the AI-0 control plane: append-only core fields for authenticated AI runs, typed tool-call lifecycle records, resumable approval records, versioned creator-published policies, conservative system policy defaults, scope-derived lifecycle RPCs, creator-only policy publication, bounded run/tool/approval projections, audit events, immutable-field triggers, RLS, explicit grants, and the required policy-author and lifecycle indexes. Migration 0044 adds the authenticated, read-only effective-policy resolver used by the AI gateway. AI-1 adds `supabase/functions/ai-run`, deployed with JWT verification enabled. It starts and finishes AI-0 runs, resolves policy per run and tool, dispatches only fixed read-only projections through the caller's bearer token, recursively redacts identity/contact/evidence fields, caps tool rounds, and returns an Arabic-safe unavailable response while provider secrets are not configured. It does not call payment providers, retrieve evidence, write operational tables, or accept arbitrary SQL/RPC/URLs. See `docs/AI1_EXECUTION_ENGINE.md` for the tool allowlist, secret names, deployment, and isolated authenticated test gates. The merchant UI supports bounded multi-line inventory transfers, camera barcode capture through `mobile_scanner`, B2B price-list line editing, versioned quote creation, daily rollup refresh, and optional private catalog-image optimization. Android declares the camera permission and iOS declares `NSCameraUsageDescription`. Web camera use depends on browser permission and supported camera/detection APIs.

The final live Security Advisor result after migrations 0036–0044 is `lints: []`. Performance Advisor reports no errors or warnings and no new unindexed-foreign-key or multiple-permissive-policy findings; 174 informational `unused_index` records remain, including newly created AI-0 indexes that have not yet been used by live traffic. These indexes are retained for expected production access paths. Bounded read-only planner checks used the expected `wholesale_quotes_shop_status_idx` and `merchant_daily_rollups_shop_date_idx` paths with estimated total costs of 16.13 and 11.38 respectively. These are planner checks on current statistics, not a substitute for populated scale-load testing.

Migration 0033 adds the merchant-scoped `merchant_order_workbench` projection with bounded status/search pagination and no customer identity or payment-evidence exposure. It also adds `cod_reconciliation_batches`, an optional batch reference on append-only `cod_collection_records`, and RPCs to open, record into, close, and inspect a reconciliation batch. The batch totals are computed from COD orders and the latest append-only collection record per order; the design does not settle, custody, or automatically verify non-COD payments. The public table grants remain read-only for authenticated clients, while mutations are available only through narrow authenticated RPC wrappers with ownership checks and audit events. Migration 0035 adds a database trigger that rejects attaching a collection record to a reconciliation batch whose business date does not match the order date.
