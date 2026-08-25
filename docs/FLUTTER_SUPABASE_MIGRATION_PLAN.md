# Yemen Commerce: Flutter/Dart and Supabase Migration Plan

**Prepared by:** Manus AI
**Date:** 25 August 2026
**Repository:** [Aiman003516/yemen-commerce](https://github.com/Aiman003516/yemen-commerce)

## Executive decision

The repository is already moving toward a shared Flutter client, but it is **not yet a Flutter/Supabase application**. The current Flutter app is a Dart UI and HTTP client over a Node.js, Express, tRPC, Drizzle, MySQL-oriented backend. Authentication still uses a Manus-specific OAuth flow, and file uploads still use a Forge/S3-style storage adapter. The Supabase project connected to this session is healthy and reachable, but it is effectively a new empty project with no application tables, migrations, or Edge Functions.

The recommended target is a **single Flutter/Dart codebase for Android, iOS, and Flutter Web**, using `supabase_flutter` for authentication, Postgres Data API access, Realtime where needed, and Storage. The Node/Vite/Express/tRPC server should be removed from the production runtime after the cutover. Supabase should provide the backend platform through Postgres, Auth, Storage, RLS, SQL migrations, triggers, and narrowly scoped Postgres RPC functions.

> “Pure Flutter” can accurately mean that the mobile and web applications, client data layer, routing, state management, validation presentation, and platform UI are all Flutter/Dart. It cannot safely mean that the backend contains only Dart source code: Supabase’s secure backend enforcement is implemented through PostgreSQL schema, RLS policies, SQL functions, triggers, Auth, and Storage. We should avoid Edge Functions unless a later requirement genuinely needs them, because the normal Supabase Edge Function runtime is not Dart.

This approach preserves the project’s most important invariant: **one cross-merchant cart creates one independent merchant order per merchant group, with immutable payment instructions, independent payment review, and independent fulfilment status**.

## 1. Repository-wide assessment

### 1.1 Current structure and implementation status

The repository contains a documentation-first product package, a substantial Flutter Web/mobile foundation, and a legacy Node backend that still owns all authoritative operations. The root web entrypoint already boots Flutter Web, so the React presentation layer has effectively been replaced. The important distinction is that the current Flutter app is only a client: it calls `/api/trpc/...` routes and relies on the Node backend for authentication, authorization, database writes, transactions, and storage.

| Area | Current repository state | Consequence for migration |
|---|---|---|
| Product definition | Ibb, Yemen is the first market; Arabic-first, English-ready; free pilot; no central fund custody. | Preserve as configuration and policy data, not hard-coded client logic. |
| Canonical Flutter client | `flutter_app/` contains the richer app, contract models, API client, responsive shell, merchant workspace, identity UI, grouped cart, and tests. | Make this the canonical application and refactor it into feature/data/domain layers. |
| Secondary Flutter client | `mobile_client/` is a small earlier scaffold with a minimal shell and duplicate contracts. | Consolidate or archive it; do not maintain two competing Flutter applications. |
| Web UI | `client/index.html` loads Flutter Web with an Arabic RTL document root. | Keep Flutter Web as the only web presentation layer. |
| Current transport | `flutter_app/lib/core/api_client.dart` calls tRPC HTTP routes such as `market.active`, `catalog.products`, `cart.checkout`, and `identity.submit`. | Replace the transport with Supabase Auth, PostgREST queries, Storage calls, and SQL RPC commands. |
| Current authentication | Manus OAuth start/callback routes issue a server session cookie and identify users through `openId`. | Replace with Supabase Auth sessions and `auth.uid()`-based authorization. |
| Current database | Drizzle MySQL dialect, numeric IDs, MySQL enums, `DATABASE_URL`, and MySQL migrations. | Translate to PostgreSQL migrations; do not apply the existing MySQL SQL files to Supabase. |
| Current storage | Forge/S3-style presigned uploads and signed downloads. | Replace with private Supabase Storage buckets and Storage RLS policies. |
| Current business logic | Node/tRPC routers implement catalog, cart, checkout, payment, merchant, identity, admin, and order behavior. | Reimplement authoritative multi-row operations in Postgres RPC/functions and enforce reads/writes with RLS. |
| Current validation | Repository tests cover important Node authorization and domain rules; Flutter Web runtime checks are recorded. | Add database policy tests, Dart tests, and concurrency/integration tests against Supabase. |

The current Flutter manifest uses Flutter localization, `http`, `url_launcher`, and `file_picker`, but it does not declare `supabase_flutter`. The existing client therefore proves that the UI direction is viable while also proving that the Supabase connection has not yet been integrated.

### 1.2 Existing functionality that can be retained conceptually

The Flutter shell already contains the principal user contexts and several important screens. It has Arabic-first RTL presentation, responsive desktop/mobile navigation, public catalogue loading, grouped cart presentation, per-shop fulfilment selection, per-merchant manual payment selection, split-checkout confirmation, customer order display, merchant onboarding, merchant settings, identity evidence submission, and administrator identity review. The contract document explicitly keeps pricing, authorization, stock validation, checkout splitting, payment transitions, fulfilment transitions, and audit history authoritative on the server [7].

These screens should not be discarded. They should be refactored away from a monolithic `MarketplaceShell` and the current `MarketplaceApiClient` into typed feature repositories and use cases. The migration must not move authorization or pricing into Dart merely because the HTTP server is being removed.

### 1.3 Current business model and data invariants

The concrete Drizzle schema models users and roles, markets, capabilities, policy versions, merchants, identity cases and evidence, shops, categories, products, fulfilment methods, payment methods, carts, checkout sessions, merchant orders, order items, payment claims, payment proofs, order history, reports, and audit events [6]. The checkout router confirms that the critical workflow is transactional: it validates each merchant group, snapshots payment instructions, creates merchant orders, creates order items, decrements stock, clears the cart, and writes audit events [10].

The target schema must preserve the following invariants without relying on client behavior:

| Invariant | Required target enforcement |
|---|---|
| A cart may contain products from multiple merchants. | Cart and cart-item ownership policies plus server-side catalogue/merchant checks. |
| Checkout creates exactly one merchant order per merchant group. | One Postgres transaction in a `checkout_create_orders` RPC. |
| A merchant order belongs to one checkout session and one merchant. | Foreign keys, unique/reference constraints, and RPC validation. |
| Payment instructions and totals are historical snapshots. | Snapshot columns or a dedicated immutable snapshot table; deny post-creation updates. |
| Payment proof never marks an order paid. | Separate claim submission and merchant review functions with explicit status transitions. |
| Merchant data is isolated. | RLS policies based on `auth.uid()` and merchant ownership, not client-supplied merchant IDs. |
| Identity evidence is private. | Private Storage bucket, restrictive `storage.objects` policies, metadata policies, and short-lived authorized access. |
| Fulfilment cannot begin before payment is confirmed. | Database transition function and a database constraint or trigger. |
| Audit events are append-only and attributable. | Insert-only policy/function, actor identity from `auth.uid()`, and no client-provided actor field. |
| Ibb is configuration rather than a code path. | Market records, capabilities, and versioned policy tables queried by stable IDs. |

## 2. Supabase connection check

The connected Supabase account and project were inspected without changing data or applying migrations.

| Check | Result | Interpretation |
|---|---|---|
| Connected account project | `aart33748's Project` | The account has a Supabase project available for this work. |
| Project reference | `mtaujfgkqvzwauqiegkl` | This is the project ID to use for future migrations and inspection. |
| Project status | `ACTIVE_HEALTHY` | The project is online and healthy. |
| Region | `eu-west-1` | Current project region. |
| Database engine | PostgreSQL 17.6.1 | Suitable for the translated schema and transactional RPCs. |
| Configured URL | `https://mtaujfgkqvzwauqiegkl.supabase.co` | Matches the project URL returned by Supabase. |
| Sandbox URL/key variables | `SUPABASE_URL` set; `SUPABASE_KEY` set | Connection material is available in the session environment; secret values were not exposed or written to the repository. |
| Public application tables | None | No Yemen Commerce schema has been deployed yet. |
| Applied migrations | None | The project is clean for a first reviewed migration. |
| Edge Functions | None | No server-side function code is currently deployed. |

The project is therefore a good **fresh target**, but it is not yet the backend for the repository. No application schema, Auth profile integration, Storage buckets, or RLS policies have been deployed.

### 2.1 Security finding requiring action before schema deployment

The Supabase security advisor reports a warning for `public.rls_auto_enable()`. It is a `SECURITY DEFINER` event-trigger function owned by `postgres` and is callable through the exposed public API by both `anon` and `authenticated` roles. The function appears intended to enable RLS automatically on newly created public tables, but the current privilege exposure is too broad for a production application.

The first Supabase security migration must either remove this helper or revoke public execution and keep all RLS enablement explicit in version-controlled migrations. Every application table must have its grants, RLS state, and policies reviewed together. Supabase’s current guidance emphasizes that RLS policies do not replace table grants, that exposed tables without RLS can be readable or writable, and that service-role access bypasses RLS and must remain server-side [2].

**No migration should be applied until this baseline finding is resolved and rechecked.**

## 3. Target architecture: Flutter/Dart clients with Supabase backend services

### 3.1 Runtime boundary

The production runtime should contain one Flutter application compiled for Android, iOS, and Web. The Flutter client uses only the public Supabase project URL and publishable/anonymous key. The service-role key and database connection string must never be present in Flutter, browser JavaScript, build artifacts, or checked-in configuration [1].

Supabase provides the backend capabilities as follows:

| Capability | Supabase target | Flutter/Dart responsibility |
|---|---|---|
| Authentication | Supabase Auth with a documented launch method and redirect/deep-link configuration. | Start sign-in, observe session changes, handle expiry, and map the authenticated user to a profile and role context. |
| Public reads | Postgres Data API through `supabase_flutter`, protected by explicit `anon`/`authenticated` grants and RLS. | Query typed repositories and render loading, empty, error, and unavailable states. |
| Private reads/writes | Authenticated Data API calls governed by RLS. | Send user-scoped commands without trusting client IDs or status values. |
| Atomic commerce operations | PostgreSQL RPC functions invoked from Dart. | Supply selections and display returned validation/errors; never calculate authoritative totals locally. |
| File uploads | Supabase Storage private buckets with `storage.objects` policies. | Pick files, validate size/type for UX, upload using authorized paths, and store only safe metadata. |
| Realtime | Supabase Realtime for later order/payment refresh where useful. | Subscribe to authorized records and always re-fetch authoritative state after an event. |
| Audit | Database functions/triggers inserting actor and state information. | Display safe history to permitted users; never choose the audit actor. |
| Scheduled deletion/retention | Database or platform-managed operational job, subject to policy approval. | Display retention state only where required; never expose restricted documents. |

Supabase’s Flutter library supports database access, Auth, Storage, Realtime, and Edge Function invocation from Flutter; the official quickstart uses `Supabase.initialize` with the project URL and publishable key [1]. Database RPC is the appropriate client entry point for Postgres functions that encapsulate multi-step operations [4].

### 3.2 Recommended Dart project structure

Use `flutter_app/` as the migration starting point, then converge toward a clearer application boundary. The exact package names can be adjusted during implementation, but the dependency direction should remain stable.

```text
flutter_app/
  lib/
    main.dart
    app/
      app.dart
      router.dart
      theme.dart
      localization/
    core/
      config/
      errors/
      result/
      supabase/
      permissions/
      widgets/
    domain/
      entities/
      enums/
      value_objects/
      repositories/
    data/
      dto/
      mappers/
      repositories/
      services/
    features/
      auth/
      market/
      catalogue/
      cart/
      checkout/
      customer_orders/
      merchant/
      payments/
      identity_verification/
      admin/
      reports/
  test/
  integration_test/
```

The current `MarketplaceShell` should become a responsive shell that consumes feature state instead of instantiating a new API client inside individual widgets. Repositories should receive one `SupabaseClient` instance through a small dependency container. Models should be typed, null-safe, and explicit about whether a field is public, customer-visible, merchant-visible, or administrator-only.

A minimal production dependency set is `supabase_flutter` plus a chosen Dart state-management and routing approach. It is preferable to keep the first migration dependency-light rather than introduce a large framework during the database cutover. Any package added must support Android, iOS, and Web and must not introduce a second backend or JavaScript-only business layer.

### 3.3 Authentication and role context

The current `/api/oauth/start` and `/api/oauth/callback` routes must be removed from the target runtime. Supabase Auth should own the session, token refresh, redirect handling, and sign-out. The Flutter application should listen to `onAuthStateChange`, expose an `AuthSessionState`, and load a profile plus role memberships after authentication.

The product documents recommend phone-number authentication, but the repository also explicitly keeps phone OTP disabled until an approved provider is available. This remains an open launch decision. Before implementation, choose one of the following:

| Authentication choice | Use when | Consequence |
|---|---|---|
| Supabase phone Auth | An approved SMS provider and operational budget are ready. | Configure provider, rate limits, redirect/deep links, abuse controls, and recovery. |
| Email magic link/password for development or pilot | Phone OTP remains disabled. | Faster technical delivery, but it changes the product’s sign-in decision and must be approved. |
| Another approved Auth provider integrated with Supabase | Product requires a local identity method not covered by the initial Supabase setup. | Requires a documented integration and a controlled identity mapping strategy. |

Roles must not be trusted from user-editable metadata. Store role memberships and market scope in database tables, derive authorization from `auth.uid()`, and use server-controlled app metadata only where appropriate. The UI may hide unavailable screens, but RLS and SQL functions remain the actual security boundary.

## 4. Supabase database and security design

### 4.1 PostgreSQL translation

The existing Drizzle schema is a valuable domain source but is not a deployable Supabase migration. The current SQL contains MySQL-specific constructs such as `AUTO_INCREMENT`, MySQL `enum`, backtick identifiers, and `ON UPDATE CURRENT_TIMESTAMP` behavior [6] [10]. Create new PostgreSQL migrations under a dedicated `supabase/migrations/` directory.

Because the connected Supabase project is empty and the repository handover explicitly recommends a fresh project, use a clean PostgreSQL design rather than trying to replay MySQL migrations. Recommended changes include:

| Current MySQL-oriented design | PostgreSQL/Supabase target |
|---|---|
| Numeric `users.id` linked to `openId` | `profiles.id uuid references auth.users(id)`; keep external/display references separate. |
| MySQL enum columns | PostgreSQL enums only where state is stable, or checked text values where extensibility and migrations matter more. |
| CamelCase database columns | Snake_case database columns with explicit Dart mappers. |
| `text` containing JSON | `jsonb` for policy and audit metadata. |
| `timestamp` with MySQL update behavior | `timestamptz` plus explicit update triggers or function-controlled updates. |
| MySQL auto-increment IDs | UUID keys for new domain tables, with human-readable `order_reference` retained separately. |
| Application-side transaction in Drizzle | One Postgres RPC for checkout and other multi-row state transitions. |
| `openId` as authentication identity | Supabase `auth.uid()` as the non-editable identity boundary. |

Using UUIDs throughout the new schema will simplify RLS joins and align every user-owned row with `auth.uid()`. If preserving numeric IDs is essential for reporting or an external migration, use them as opaque `bigint` domain keys while retaining a UUID `user_id` foreign key to `auth.users`; do not retain `openId` as the authorization key.

### 4.2 Schema modules

Create migrations in dependency order: extensions and helper types; profiles and role memberships; markets, capabilities, and policy versions; merchants and shops; categories and products; fulfilment methods and payment methods; carts and cart items; checkout sessions and merchant orders; order items and immutable snapshots; payment claims and proofs; identity cases and evidence metadata; reports; audit events; Storage policies; and RLS tests.

The schema should add explicit fields for `created_by`, `updated_by` where needed, `version`, `effective_from`, and retention metadata. Historical order rows must not depend on current merchant settings. Consider a dedicated `merchant_order_payment_snapshots` table if the product expects multiple payment-method snapshots or future payment revisions; otherwise, immutable snapshot columns on `merchant_orders` are acceptable if update policies prevent changes.

### 4.3 RLS and grants

Enable RLS on every exposed application table and on relevant Storage objects. Revoke broad default grants from `anon` and `authenticated`, then grant only the operations required by the client. Write a separate policy for each operation rather than relying on a broad `for all` policy. Add indexes to columns used by RLS predicates, especially `user_id`, `merchant_id`, `shop_id`, `customer_user_id`, and `market_id` [2].

Recommended helper functions include `current_user_is_admin()`, `current_user_has_role(role, market_id)`, `current_user_merchant_ids()`, and `current_user_can_access_order(order_id)`. Any `SECURITY DEFINER` helper must set a fixed `search_path`, qualify object names, validate `auth.uid()`, and have `EXECUTE` revoked from `anon` unless it is intentionally public. Grant execution only to the roles that need the function.

Public catalogue reads should expose only approved shops and active products. It is safer to expose a deliberately shaped view or RPC that returns public columns than to make the full `shops` or `products` tables broadly readable. The same principle applies to payment information: customers may read their own order snapshot, merchants may read their own orders and claims, and administrators may read what policy permits.

### 4.4 Transactional RPC commands

Direct table CRUD is appropriate for simple, owner-scoped operations such as reading a public catalogue or updating a user-owned cart quantity. It is not sufficient for checkout, payment review, fulfilment transitions, identity review, or administrative approval. Those operations should be Postgres RPC commands that validate the caller, perform all related changes in one transaction, and return a typed result.

| RPC | Responsibility | Key checks |
|---|---|---|
| `checkout_create_orders` | Validate cart groups and create one order per merchant group. | Active market, approved shop, active product, current stock, selected fulfilment, selected manual payment method, price/totals, immutable snapshots, stock decrement, cart clear. |
| `submit_payment_claim` | Record reference/proof metadata and move order to under-review. | Customer owns order, awaiting-payment state, proof requirement, private storage path, no paid transition. |
| `review_payment_claim` | Accept or reject a claim. | Authenticated merchant owns the order, under-review state, rejection reason, history and audit record. |
| `transition_fulfilment` | Move fulfilment through permitted states. | Merchant owns order, payment is paid before readiness, allowed transition, history and audit record. |
| `submit_identity_case` | Create/update a merchant evidence case. | Merchant ownership, explicit consent, exactly one current passport/selfie record, retention policy. |
| `admin_review_identity_case` | Move evidence case to verified/rejected. | Administrator capability, valid state, mandatory decision note, audit event. |
| `admin_approve_shop` | Approve or suspend public shop visibility. | Administrator capability, merchant review requirements, audit event. |
| `set_market_capability` | Change feature availability for a market. | Administrator capability, explicit reason, policy/version audit. |

The client should call these functions with `supabase.rpc(...)`, display returned validation errors in Arabic, and then re-fetch the affected records. Postgres is the correct place to guarantee atomicity because a sequence of independent client requests cannot guarantee that all merchant orders, item rows, stock changes, and cart deletion succeed or fail together.

## 5. Storage and sensitive evidence

Create separate private buckets or tightly separated prefixes for `product-assets`, `payment-proofs`, and `identity-evidence`. Product images may be public only if the product’s public visibility policy explicitly allows it; payment proofs and identity evidence must remain private.

Storage policies must bind object paths to authenticated identities and business ownership. For example, customer payment-proof uploads should use a path that includes the authenticated customer UUID and order UUID, while a database policy or controlled finalize RPC confirms that the order belongs to that customer. Merchant passport/selfie files should use an identity-case path that cannot be chosen to impersonate another merchant.

Supabase Storage uses RLS on `storage.objects`; uploads are not automatically allowed without policies, and the service key bypasses Storage RLS and must not be shared publicly [3]. The Flutter client should never receive a service-role key. For administrator review, return a short-lived signed URL only after an administrator-scoped query confirms access. Do not put permanent document URLs into merchant responses, public catalogue records, order lists, logs, or analytics.

The current repository correctly states that identity verification is manual only and does not perform facial recognition, liveness, biometric matching, or automatic approval. Preserve that behavior. Before live document collection, obtain explicit approval for retention duration, deletion, access review, incident response, and any legal/privacy obligations.

## 6. Flutter migration workstreams

### 6.1 Foundation and configuration

Add `supabase_flutter` and initialize it once in `main.dart` using build-time configuration such as `--dart-define-from-file`. Maintain separate development, staging, and production project references. The publishable key may be included in client configuration when protected by correct RLS, but service-role and database credentials must stay in the project’s secret manager and migration/deployment environment.

Create typed configuration for API version, market ID, feature availability, and environment. Remove `API_BASE_URL` as the primary runtime dependency once direct Supabase access is active. Do not hard-code Ibb display names as authorization or market identifiers.

### 6.2 Data and domain layer

Retain the stable serialized status vocabulary where possible: `customer`, `merchant`, `admin`; `awaiting_payment`, `payment_under_review`, `paid`, `rejected`, `cancelled`; `collection`, `digital`, `seller_arranged`; and the identity-review states already documented in the repository. Map snake_case Postgres rows into immutable Dart entities and keep display labels in localization resources.

Replace the current `MarketplaceApiClient` with repositories such as `MarketRepository`, `CatalogRepository`, `CartRepository`, `CheckoutRepository`, `OrderRepository`, `PaymentRepository`, `MerchantRepository`, `IdentityRepository`, and `AdminRepository`. The repositories should expose domain results and typed failure categories rather than leaking `PostgrestException` into widgets.

### 6.3 Feature completion order

Refactor and implement in this order so the app always has a usable vertical slice:

1. Auth/session bootstrap, profile, role context, route guards, and sign-out.
2. Market configuration, capabilities, and public catalogue reads.
3. Customer shop/product details and cart persistence.
4. Merchant onboarding, shop settings, catalogue management, fulfilment settings, and manual payment settings.
5. Atomic grouped checkout and merchant-order creation.
6. Customer payment-information page, payment reference, proof upload, and independent payment progress.
7. Merchant claim review and fulfilment transitions.
8. Administrator approvals, identity review, reports, capabilities, and audit views.
9. Realtime refresh, notifications, public links, accessibility, and performance hardening.

The current large shell can be used as a visual and interaction reference, but each feature should receive its own state/controller, repository, DTOs, and tests. Every screen needs loading, empty, error, unavailable, success, and permission-denied states. Every authenticated screen must react correctly to sign-out and expired sessions.

## 7. Delivery phases and exit criteria

| Phase | Scope | Exit criteria |
|---|---|---|
| 0. Decisions | Confirm auth method, role model, identity-retention policy, market rules, provider labels, and “Dart-only” boundary. | Written decisions approved; no unresolved security ambiguity. |
| 1. Repository consolidation | Make `flutter_app` canonical; remove duplicate client ownership; preserve current UI and contracts in a migration branch. | One Flutter entrypoint for mobile and web; legacy UI is no longer a production dependency. |
| 2. Supabase baseline | Resolve `rls_auto_enable` warning; document project ref; create migration layout and environment templates without secrets. | Security advisor clean or accepted with documented justification; no application data changed. |
| 3. PostgreSQL schema | Translate the full Drizzle model to PostgreSQL with UUID/auth relationships, constraints, indexes, enums/checks, and seed configuration only. | Migrations apply to a fresh branch/project; table and constraint review passes. |
| 4. RLS and Storage | Add least-privilege grants, table policies, Storage buckets, object policies, helper functions, and policy tests. | Anonymous/public reads work only where intended; cross-customer, cross-merchant, and non-admin reads fail. |
| 5. Auth and profiles | Replace Manus OAuth with Supabase Auth; configure web redirects and native deep links; add profile/role context. | Sign-in, refresh, sign-out, route guards, and role loading work on Web and at least one mobile target. |
| 6. Transactional backend | Implement and test checkout, payment claims/review, fulfilment transitions, identity review, approvals, and audit functions as SQL RPCs/triggers. | Atomicity, status transitions, stock safety, snapshots, and audit attribution pass integration tests. |
| 7. Flutter data layer | Replace HTTP/tRPC client with Supabase repositories, typed mappers, errors, and state management. | Customer, merchant, and admin flows load from Supabase without Node/tRPC calls. |
| 8. Flutter feature completion | Finish all customer, merchant, payment, identity, admin, report, and public-link flows. | Feature acceptance checklist passes in Arabic RTL and English-ready layouts. |
| 9. Verification | Run SQL policy tests, Dart unit/widget tests, integration tests, web build, Android build, and concurrency checks. | No critical authorization, privacy, transaction, or runtime failures. |
| 10. Pilot cutover | Seed only approved configuration, onboard a small set of real merchants, monitor support and payment-review workflow. | Controlled Ibb pilot sign-off; rollback/export procedure documented. |

## 8. Validation strategy

The project should add a `supabase/tests/` suite using pgTAP or an equivalent database-test mechanism. Each table with RLS needs explicit allow and deny coverage for `anon`, the owning customer, another customer, the owning merchant, another merchant, and an administrator where relevant. Policy tests must assert that denied updates leave the target row unchanged, not merely that a query returns zero visible rows.

Dart tests should cover serialization, repositories, status-label localization, form validation, route guards, cart grouping, checkout confirmation, payment progress, proof-upload states, merchant workspace isolation, and admin-only views. Integration tests should run against the Supabase project’s local or isolated test environment and should include concurrent checkout attempts against limited stock.

The final release gate must include:

| Gate | Required evidence |
|---|---|
| Client/backend separation | No `api/trpc`, Manus OAuth, Forge storage, MySQL, or service-role key references in Flutter runtime code. |
| Public visibility | Only approved shops and active products are publicly readable. |
| Merchant isolation | A merchant cannot read or mutate another merchant’s shop, product, order, payment method, customer data, or evidence. |
| Payment privacy | Payment proofs are private; upload never marks an order paid. |
| Identity privacy | Passport/selfie metadata and objects are visible only to the merchant owner and authorized administrators. |
| Checkout atomicity | Exactly one order per merchant group; no partial stock/cart/order state after failure. |
| Snapshot immutability | Merchant payment changes do not alter historical order instructions or totals. |
| Fulfilment safety | Fulfilment cannot progress before payment confirmation. |
| Market expansion | A second city can be activated through records and policy configuration without a second checkout workflow. |
| Platform builds | Flutter Web release, Android build, and iOS build configuration succeed from the same Dart codebase. |

## 9. Risks and open decisions

The most important risk is interpreting “pure Flutter backend” as permission to put business rules in the client. That would weaken merchant isolation, stock safety, payment transitions, and private-document access. The safe interpretation is **Flutter/Dart-only application code with Supabase-managed backend services and SQL security/transaction logic**.

The second risk is authentication ambiguity. The repository’s preferred phone-number authentication is not the same as having a working OTP provider. Decide whether the pilot uses Supabase phone Auth, an approved alternative, or a temporary email-based development flow before building route guards and onboarding.

The third risk is direct-client transaction design. PostgREST CRUD calls from Flutter cannot by themselves guarantee a multi-step checkout transaction. The `checkout_create_orders` SQL RPC is a mandatory part of the architecture, not an optional optimization.

The fourth risk is identity evidence. The application must not collect live passport/selfie evidence until retention, deletion, access review, and incident-response policies are approved. A development environment should use synthetic files and test users.

The fifth risk is the existing project checklist. `todo.md` contains both older unchecked backlog items and later checked incremental implementation items. Treat the actual source, database policies, and end-to-end tests as the completion authority; do not infer production readiness from a checked box alone.

Before implementation begins, approve these decisions:

1. Whether all new domain primary keys will be UUIDs or whether numeric IDs must be retained for compatibility.
2. The launch authentication method while phone OTP remains disabled.
3. Whether product images are public or signed/private.
4. The exact merchant/admin scope for identity evidence and the retention schedule.
5. The cancellation and correction rules for payment claims and orders.
6. The first release’s supported provider labels and whether any provider API mode remains disabled.
7. The final canonical Flutter directory and whether `mobile_client/` is archived.
8. The isolated Supabase environment strategy for development, staging, and pilot production.

## 10. Immediate next actions

The next implementation step should be a **reviewed foundation increment**, not a UI rewrite. First, preserve this plan and the current Flutter Web baseline; then remove or restrict the flagged `rls_auto_enable` function, create the PostgreSQL migration skeleton, and translate only the identity/profile, market, role, shop, catalogue, and capability foundations. Do not apply the complete commerce schema in one unreviewed operation.

After the foundation migration passes RLS tests, implement the first vertical slice: Supabase Auth session bootstrap, public market/catalogue reads, a customer-owned cart, and a transaction-safe checkout RPC returning one order per merchant group. Only then reconnect the existing merchant, payment, identity, and administrator screens.

At the time of the original analysis, no Supabase application migrations or data changes had been applied. The first reviewed foundation migrations have since been applied as recorded in the implementation-status section below. The connected project must not be treated as production-ready until the Auth, RLS, Storage, transaction, and end-to-end gates above are complete.

## References

[1]: https://supabase.com/docs/guides/getting-started/quickstarts/flutter "Use Supabase with Flutter"
[2]: https://supabase.com/docs/guides/database/postgres/row-level-security "Row Level Security"
[3]: https://supabase.com/docs/guides/storage/security/access-control "Storage Access Control"
[4]: https://supabase.com/docs/reference/dart/rpc "Flutter: rpc"
[5]: https://github.com/Aiman003516/yemen-commerce/blob/main/README.md "Yemen Commerce repository README"
[6]: https://github.com/Aiman003516/yemen-commerce/blob/main/drizzle/schema.ts "Current Drizzle schema"
[7]: https://github.com/Aiman003516/yemen-commerce/blob/main/flutter_app/CONTRACTS.md "Flutter contract boundary"
[8]: https://github.com/Aiman003516/yemen-commerce/blob/main/todo.md "Repository implementation checklist"
[9]: https://github.com/Aiman003516/yemen-commerce/blob/main/master-plan-mobile-web.md "Yemen Commerce master plan"
[10]: https://github.com/Aiman003516/yemen-commerce/blob/main/server/routers/cart.ts "Current cart and checkout router"

## 11. Implementation status — first foundation increment

The first implementation increment has now been completed. The connected Supabase project contains the translated PostgreSQL foundation, 24 public application tables with RLS enabled, one active Ibb market seed, nine capability seeds, three private Storage buckets, and Supabase RPC wrappers for checkout, payment claims/review, fulfilment transitions, merchant onboarding, shop creation, manual payment settings, fulfilment settings, identity submission, and administrator identity review. The original exposed `public.rls_auto_enable()` helper was hardened, privileged RPC implementations were moved into the private schema, and the Supabase security advisor currently returns no lints.

The canonical Flutter app now initializes Supabase from build-time public configuration, pins `supabase_flutter` to the current 2.x release, adopts UUID-compatible Dart contracts, and routes market bootstrap, catalogue reads, authentication/profile context, cart persistence/grouping, checkout, customer orders, payment claims, merchant workspace operations, identity evidence uploads, and administrator identity-review operations through Supabase when configured. The legacy HTTP/tRPC adapter remains only as a temporary fallback during cutover and is no longer the intended production path.

Validation completed for this increment includes `flutter analyze` with no issues, three Flutter widget tests passing, a successful Flutter Web release build with the connected Supabase configuration, a public Data API market query returning HTTP 200, an anonymous protected-RPC attempt returning HTTP 401, and a structural Supabase smoke query confirming 24/24 public tables have RLS, one active market, nine capabilities, three private buckets, and four public RPC wrappers.

The remaining work is the production hardening and feature-completion increment: add full synthetic-user RLS allow/deny tests, complete merchant product/category management and admin/report workflows, implement Auth sign-in/deep-link configuration, add Realtime and notification decisions, remove the legacy Node/tRPC runtime after end-to-end parity, and validate Android/iOS builds. No real customer, merchant, identity, payment, or order data has been inserted.
