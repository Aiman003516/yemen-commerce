# Yemen Commerce Supabase workspace

This directory contains the version-controlled PostgreSQL and Supabase backend foundation for Yemen Commerce. The connected project is the dedicated Supabase project `mtaujfgkqvzwauqiegkl`.

## Runtime boundary

The application clients are Flutter/Dart for Android, iOS, and Web. They use the public Supabase project URL and publishable key through `supabase_flutter`. The service-role key, database connection string, and any provider credentials remain server-side project secrets and must never be committed or embedded in Flutter/browser builds.

The authoritative backend is Supabase PostgreSQL, Auth, Storage, RLS, triggers, and SQL RPC functions. No Node.js, Express, tRPC, Drizzle, or Forge storage service is required in the final production runtime. Edge Functions are intentionally not used in this first Dart-only increment.

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
```

Migrations 0005 and 0006 add explicit access controls, capabilities, delegated operator assignments, creator-only access helpers, people search, dashboard summaries, role delegation/revocation, account suspension/restoration, and capability grants. Migration 0007 adds creator-only RPCs for merchant verification, shop status moderation, market status moderation, market/policy/capability listing, policy-version creation, and per-market capability toggles. These operations are audited and remain behind creator authorization checks; the Creator Console exposes them through the Merchant Governance and Global Policies screens. Privileged implementations remain in the `private` schema; Flutter sees only narrow public RPC wrappers. The migrations do not create a creator account and do not grant a creator role automatically.

The matching security test starter is `supabase/tests/creator_authorization.test.sql`. It must be expanded and run against an isolated project with synthetic Auth users before any production creator account is bootstrapped.

## Authorization boundary runner

Run the available boundary test from the repository root:

```bash
./supabase/tests/run_creator_authorization.sh
```

The runner verifies the public client boundary against the connected project and exercises anonymous denial for all creator-control, checkout, operations, trust, provider, governance, and review RPCs plus protected creator tables. The latest run produced `RESULT passed=43 skipped=5`. The five skipped cases are authenticated customer, merchant, review-agent, support-agent, and creator scenarios because isolated synthetic-user access tokens are not configured. To run those cases, provide the corresponding `SUPABASE_TEST_*_ACCESS_TOKEN` values from an isolated test project or branch; never use a production service-role key or commit tokens. The harness checks creator dashboard allowance and non-creator dashboard denial, while the SQL pgTAP starters document the remaining role-escalation and cross-role cases.

## Payment provider boundary and Jaib readiness

Migration `20260825_0008_payment_provider_boundary.sql` adds provider-aware payment metadata to merchant payment methods and immutable merchant-order snapshots. The supported provider codes are `manual`, `jaib`, `kuraimi`, `cash`, and `other`. All methods remain `mode = 'manual'` and `provider_verification = 'manual_only'` in this increment.

The Flutter customer/merchant app now shares a provider catalog and lets merchants label a method as Jaib, Al Kuraimi, cash, or a generic manual method. Jaib is presented as a manual QR/POS-capable option: customers are instructed to complete payment in Jaib and submit a transaction reference for merchant review. The system does not claim automatic verification, does not hold funds, and does not mark an order paid from proof alone.

Jaib’s official public consumer pages describe purchase payments, QR/POS identifiers, transfers, cash-in/cash-out, online shopping, and a service network, but no public developer API, webhook, SDK, sandbox, or settlement specification was identified. A formal Jaib provider implementation must wait for AHD/Alhazmi documentation, merchant-acquiring approval, sandbox credentials, callback security, settlement/reconciliation rules, refund behavior, and legal/compliance review. Until that gate is complete, use the manual/QR/POS flow.

The provider catalog is shared through `packages/commerce_core/lib/src/payment_providers.dart`, so future approved providers can be added without putting provider-specific logic into checkout or order state transitions.

Migrations 0009 through 0020 extend the pilot with market service areas, pickup points, private customer address ownership, merchant delivery zones, product variants, customer order cases for cancellation/return/dispute review, courier assignment and handoff operations, durable recipient-scoped notification events, completed-order product reviews, merchant promotion configuration, storefront/theme settings, inventory locations, aggregate merchant analytics, delivery-address and pickup snapshots at checkout, location-level inventory reservations, append-only cash-on-delivery reconciliation, server-side reservation release/finalization commands, support tickets, internal risk signals, explainable merchant quality metrics, provider catalog/configuration metadata, webhook-event storage foundations, staged market feature rollouts, Creator service-area/pickup governance, and review moderation. These additions remain optional and fail safely when no service area, courier, notification, storefront, or external provider adapter is configured.
