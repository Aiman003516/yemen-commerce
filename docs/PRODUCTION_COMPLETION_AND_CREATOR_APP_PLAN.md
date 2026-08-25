# Yemen Commerce: Production Completion and Creator Management Plan

**Prepared by:** Manus AI
**Date:** 25 August 2026
**Repository:** [Aiman003516/yemen-commerce](https://github.com/Aiman003516/yemen-commerce)

## Purpose

This plan extends the existing Flutter/Supabase migration by covering every remaining production-completion item and adding a separate third Flutter application for the system creator. The creator application will manage people, roles, markets, merchants, policies, capabilities, reports, and operational activity through the same Supabase project, but it will not share the customer/merchant UI shell or receive broad unrestricted database access.

The platform will contain three Flutter applications:

| Application | Primary users | Initial platforms | Backend boundary |
|---|---|---|---|
| **Yemen Commerce** | Customers and merchants. | Android, iOS, Web from the existing `flutter_app/` codebase. | Supabase Auth, Postgres/RLS, Storage, Realtime, and approved RPCs. |
| **Creator Console** | The system creator and explicitly delegated platform operators. | Web-first, with Android/iOS support if operational requirements justify it. | Same Supabase project, creator-scoped Auth role, creator-only RPCs, private audit and people-management data. |
| **Operations/Review surface** | Optional future support or review staff. | Initially represented as role-scoped areas of the Creator Console rather than a fourth app. | Same Supabase project with narrower capabilities than creator. |

The third application should be a separate Flutter target/package, not merely another hidden route in the customer app. It may share a private Dart package containing models, Supabase initialization, error mapping, localization primitives, and design tokens, but it must have an independent router, navigation shell, branding treatment, release configuration, and permission model.

> The creator application is an administrative control plane, not a back door. Every people-management and platform-management operation must be authorized by Supabase-side role checks, recorded in an append-only audit trail, and constrained by explicit capabilities.

## 1. Final decisions and assumptions

The following baseline is used for planning. Any item marked **owner decision required** must be confirmed before the relevant production gate, but it does not block creation of the code and test structure.

| Decision | Planned baseline | Owner decision required |
|---|---|---|
| Creator app location | New `creator_app/` Flutter application in the same repository, sharing selected Dart packages with `flutter_app/`. | Confirm application name and visual brand. |
| Creator app platforms | Flutter Web first; Android and iOS targets remain buildable from the same Dart source. | Confirm whether mobile creator builds are required at pilot launch. |
| Creator identity | A Supabase Auth user with a database-backed `creator` role. | Confirm the creator’s initial account/identity through a secure setup process. |
| Delegated operators | Separate `platform_operator`, `support_agent`, and `review_agent` capabilities; no role inheritance by client convention. | Approve which people may be delegated and whether delegation expires. |
| Role assignment | Only creator-scoped RPCs can grant or revoke privileged roles. Users cannot edit their own role or app metadata. | Confirm whether one creator or multiple creators are supported. |
| Authentication | Supabase Auth; start with the approved pilot method and add MFA for creator/operator accounts before production. | Confirm whether phone OTP, email, or an approved enterprise method is used. |
| People management | Search and manage profiles, merchant cases, roles, access status, and audit history. | Confirm whether personal phone/email values may be visible to each operator role. |
| Payments | Manual payment claims at launch; provider API integrations remain disabled until formally approved. | Confirm provider labels and reconciliation owner. |
| Identity evidence | Manual review only; private Storage; no facial matching, liveness, or automatic approval. | Approve retention, deletion, and incident response policy. |
| Multi-market model | Ibb is the first active market; additional cities are configuration records, not code forks. | Approve acceptance test for activating a second city. |
| Database project | Continue with Supabase project reference `mtaujfgkqvzwauqiegkl`. | Confirm this is the intended staging/pilot project before production data. |

## 2. Workstreams for remaining production completion

### 2.1 Full synthetic-user RLS and security tests

The current foundation has structural RLS tests, but production readiness requires user-aware allow/deny tests. Create synthetic Auth users for a customer, two merchants, an administrator, a creator, a review agent, and a support agent in an isolated Supabase test environment. Seed two markets, two shops, products, carts, orders, payment claims, identity cases, private Storage objects, reports, and audit records.

Each test must execute through the same Data API and RPC boundaries used by Flutter. Direct service-role SQL is permitted only for setup and teardown. The test suite must assert both positive and negative access and must verify that protected rows cannot be inferred through joins, counts, Storage metadata, signed URL generation, RPC error differences, or Realtime subscriptions.

| Test group | Required assertions |
|---|---|
| Customer isolation | Customer A can read/update only their own cart and orders; cannot read Customer B’s orders, claims, proofs, or reports. |
| Merchant isolation | Merchant A can manage only its own shops, products, payment methods, orders, and fulfilment; cannot access Merchant B’s records. |
| Creator authority | Creator can perform approved platform operations but cannot bypass immutable audit or historical order snapshots. |
| Delegated operator scope | Review/support operators can perform only capability-granted actions and cannot grant themselves roles or view unrelated private evidence. |
| Anonymous boundary | Anonymous users see only active markets, enabled public capabilities/policies, approved shops, active products, and active fulfilment options. |
| Storage privacy | Payment proofs and identity evidence cannot be listed, downloaded, or signed by unauthorized users. |
| RPC boundary | Anonymous calls fail; authenticated callers with the wrong role fail; malformed and cross-scope IDs fail without leaking protected data. |
| Realtime boundary | Subscribers receive only records allowed by RLS; private order/evidence changes do not appear in unrelated channels. |
| Audit immutability | Client roles cannot update or delete audit events and cannot choose the recorded actor. |
| Role escalation | No client-accessible table or function allows a user to insert/update creator, admin, operator, or review roles. |

### 2.2 Database and Storage hardening

Review all public grants, RLS policies, SECURITY DEFINER functions, function `search_path` values, Storage policies, indexes used by policies, and exposed views. Keep privileged implementations under `private`; expose only narrow invoker wrappers or carefully reviewed RPCs. Every new function must have a named owner, purpose, caller role, input validation, failure behavior, and audit behavior.

Add an immutable order snapshot policy. Once a merchant order is created, payment instructions, receiving identifier, account holder, currency, subtotal, total, fulfilment method, and item snapshot fields must not be editable by customer, merchant, operator, or creator workflows. Corrections should be represented as explicit events or a controlled adjustment record, never as silent mutation of history.

Create separate environments for development, staging, and pilot production. The staging project must contain synthetic evidence only. Production secrets, Auth provider credentials, Storage service credentials, and any provider API keys must be held outside Flutter and outside Git. Run security and performance advisors before each release candidate.

### 2.3 Authentication and creator-account setup

Replace the remaining legacy OAuth interaction entirely. The customer/merchant app and Creator Console should use a shared Auth package with session restoration, token refresh, sign-out, expired-session handling, redirect/deep-link configuration, and consistent Arabic error mapping.

Creator and delegated operator accounts require stronger controls than ordinary customers. Add an MFA requirement where the selected Supabase Auth configuration supports it, add a creator-account recovery process, prevent long-lived shared credentials, and record sign-in, role changes, evidence access, and sensitive exports in audit events. The initial creator bootstrap must be a one-time controlled procedure; no public sign-up path may create a creator role.

### 2.4 Product, merchant, and customer feature completion

Complete the current `flutter_app/` feature surface against Supabase. The existing public catalogue, grouped cart, checkout, payment reference, merchant onboarding, shop settings, payment settings, fulfilment settings, identity submission, and administrator identity review paths are partially wired. The next implementation must finish typed repositories and screens for product/category management, public shop links, order details, payment proof upload, merchant claim review, order cancellation rules, reports, and empty/error/permission states.

The customer app must remain Arabic-first and responsive. The merchant workspace must not expose customer or evidence data beyond the order and review permissions. All customer and merchant commands should call Supabase RPCs for multi-row or state-transition behavior; direct table writes should be limited to safe owner-scoped records such as cart quantities where the policy has been tested.

### 2.5 Realtime, notifications, and observability

Use Realtime selectively. Recommended first channels are customer order/payment status changes, merchant order/payment-review changes, and creator dashboard operational counters. Realtime events are hints to re-fetch authoritative rows; they are not authorization or state-transition mechanisms.

Notifications should be modeled as a database-backed `notifications` table with user ownership, type, localized title/body keys or safe rendered content, read state, and optional resource reference. Notification creation should occur from trusted database functions or a later approved server-side job. Avoid exposing private payment or identity content in notification payloads. Push delivery can be added after the in-app notification center is correct.

Add structured client error logging without secrets, Supabase dashboard monitoring, database health checks, migration history checks, Storage failure metrics, RPC failure counts, and support-oriented audit queries. Never log access tokens, service keys, identity document paths, payment proof URLs, or full phone/email values.

## 3. Creator Console product scope

### 3.1 Creator dashboard

The Creator Console opens with a controlled operational summary: active markets, pending merchant applications, pending identity cases, shops awaiting approval, payment claims under review, open reports, recent audit events, and system health indicators. Counts must be generated from creator-authorized views or RPCs; the client must not query unrestricted tables and calculate administrative statistics locally.

The dashboard should show stale-data timestamps, empty states, error states, and a clear distinction between operational data and configuration. No dashboard card should link to records the signed-in creator cannot inspect.

### 3.2 People management

The central creator capability is **managing people**, with privacy-aware workflows:

| People workflow | Creator Console behavior | Required control |
|---|---|---|
| Search users | Search by safe internal reference, approved name, phone/email fragment, role, status, or market. | Minimize displayed PII; require creator/operator capability. |
| View profile | Show profile, roles, market scope, onboarding state, and safe activity summary. | Do not expose private evidence by default. |
| Assign role | Grant customer/merchant/review/support/operator roles through an RPC. | Creator-only; reason required; audit event required. |
| Revoke role | Revoke delegated role or suspend access. | Cannot revoke the final creator without an explicit break-glass process. |
| Suspend user | Prevent selected application actions while preserving audit history. | Reason, start time, optional expiry, and creator audit. |
| Restore user | Restore access after review. | Reason and audit. |
| Assign market scope | Associate merchant/operator/reviewer with one or more markets. | Scope changes are audited and tested against RLS. |
| Review sessions | Show last sign-in and active-session metadata where supported. | Never show tokens; session revocation must be controlled. |
| Export data | Generate only approved operational exports. | Explicit capability, minimized fields, logged export, retention limit. |

The database must add `account_status`, `suspended_at`, `suspension_reason`, and optional `suspension_until` to a controlled profile/access table or a separate `user_access_controls` table. These values should be checked by helper functions used in RLS and RPCs. Suspending a user must not erase orders, audit history, payment snapshots, or legal records.

### 3.3 Merchant and shop governance

The Creator Console manages merchant applications, identity review queues, shop approvals, category policy, capability flags, market activation, and merchant suspension. Creator actions must be separate from merchant self-service operations. A creator may approve a shop, but the merchant remains responsible for shop content and payment settings.

The creator should be able to inspect a merchant’s payment configuration without viewing private payment proofs unless the creator has an explicit review capability. Payment provider API mode remains disabled at launch and cannot be enabled by a UI toggle without an approved provider and an audit-backed configuration change.

### 3.4 Policy, market, and capability management

Create configuration screens for markets, capabilities, policy versions, fulfilment methods, category availability, pilot pricing, and provider labels. Every configuration change should create a new version or a timestamped audit record; avoid destructive edits that rewrite historical interpretation.

A second-market acceptance test must create a synthetic city, activate it, configure a category/policy/capability set, create a merchant and shop, and complete a checkout without a new code path. The test must then disable an optional capability and prove that both customer and merchant apps degrade safely.

### 3.5 Reports, support, and audit

Creators should see reports, support notes, order references, customer/merchant communication context permitted by policy, and operational history. The Console should not become an unrestricted message browser. Add explicit report categories, status transitions, assignment, internal notes, resolution reason, and retention rules.

The audit screen should support filtering by actor, action, resource type, resource ID, market, date range, and sensitive-action category. Audit records must be append-only. Sensitive evidence access must create a separate event with actor, case, purpose, and timestamp.

### 3.6 Creator settings and safety controls

Provide creator-only settings for operator delegation, session/security policy, market configuration, policy versions, supported payment labels, notification policy, and maintenance mode. High-impact actions should use a confirmation step containing the target, effect, and reason. For role changes, suspension, evidence decisions, market activation, and provider capability changes, require a reason and display the audit consequence before submission.

## 4. Proposed repository structure

```text
packages/
  commerce_core/
    lib/
      auth/
      contracts/
      errors/
      localization/
      supabase/
      design_tokens/
  commerce_data/
    lib/
      repositories/
      rpc/
      storage/
      mappers/

flutter_app/
  lib/
    features/
      customer/
      merchant/
      admin-review/

creator_app/
  pubspec.yaml
  lib/
    main.dart
    app/
      creator_app.dart
      creator_router.dart
      creator_theme.dart
    core/
      creator_permissions.dart
      creator_session.dart
    features/
      dashboard/
      people/
      merchant_governance/
      markets/
      policies/
      capabilities/
      reports/
      audit/
      settings/

supabase/
  migrations/
  tests/
  seed/
```

The shared packages must not contain creator-only screens or creator service-role behavior. `commerce_core` may contain stable entities and Auth/session primitives, while creator-specific repositories and RPC wrappers belong in creator-scoped code. This separation reduces accidental exposure of creator operations to the customer app.

## 5. Creator role and database contract

Add a controlled creator authorization model. A recommended minimum is:

| Table/function | Purpose |
|---|---|
| `user_roles` | Stable role assignment with optional market scope. |
| `user_capabilities` | Explicit capabilities such as `manage_people`, `review_identity`, `manage_markets`, `manage_policies`, `view_audit`, and `export_operational_data`. |
| `user_access_controls` | Suspension, expiry, and account-status controls. |
| `creator_operator_assignments` | Creator-granted delegation with scope, reason, timestamps, and optional expiry. |
| `private.current_user_has_capability()` | Fixed-search_path helper used by RLS and RPCs. |
| `private.current_user_is_creator()` | Creator-only check; never based solely on email or client metadata. |
| `grant_creator_role()` | One-time/bootstrap or creator-controlled role grant with audit. |
| `set_user_role()` | Creator-only role changes with scope and reason validation. |
| `set_user_access_control()` | Creator-only suspension/restore workflow. |
| `set_user_market_scope()` | Creator-only market assignment. |
| `creator_dashboard_summary()` | Safe aggregate counters, not unrestricted table access. |
| `creator_people_search()` | Filtered, paginated people search with minimized PII. |
| `creator_audit_query()` | Paginated audit access with sensitive-field minimization. |

All creator functions should be `SECURITY DEFINER` implementations in `private` with public invoker wrappers, fixed search paths, explicit role checks, and no caller-provided actor identity. The wrappers should accept stable UUIDs and bounded text inputs, return safe typed JSON, and avoid revealing whether an unauthorized resource exists beyond the required error contract.

## 6. Implementation sequence

| Phase | Deliverable | Exit gate |
|---|---|---|
| A. Decisions | Confirm creator identity, delegated roles, platform targets, MFA, privacy, retention, and branding. | Signed decision register. |
| B. Shared Dart packages | Extract common contracts, Supabase configuration, Auth/session, errors, and design tokens. | Both apps compile against shared packages with no circular dependency. |
| C. Security test environment | Create isolated project/branch, synthetic users, fixtures, pgTAP/RLS/API tests, and Storage fixtures. | All allow/deny tests pass; no critical advisor lint. |
| D. Production hardening | Add access controls, capabilities, suspension, immutable snapshots, migration checks, and audit safeguards. | Security review and migration replay pass. |
| E. Customer/merchant parity | Finish product/category, order/payment, identity, reports, public links, and state/error handling. | Feature matrix passes on Web and mobile test targets. |
| F. Creator backend | Add creator tables, helpers, RPCs, policies, aggregates, people search, and audit queries. | Creator negative-path and role-escalation tests pass. |
| G. Creator Flutter app | Build dashboard, people management, merchant governance, markets/policies/capabilities, reports, audit, and settings. | Web-first creator acceptance suite passes. |
| H. Realtime and notifications | Add authorized Realtime subscriptions, in-app notifications, refresh logic, and observability. | Event privacy and stale-data recovery tests pass. |
| I. Platform release | Build Android, iOS, Web for customer/merchant app and Web plus required mobile targets for creator app. | Release builds, deep links, Auth redirects, Storage uploads, and accessibility checks pass. |
| J. Legacy removal | Remove Node/Express/tRPC/Manus OAuth/MySQL/Forge runtime dependencies and old fallback paths. | Repository scan shows no production runtime dependency on the legacy backend. |
| K. Pilot | Seed approved Ibb configuration, onboard synthetic then approved real users, monitor support and rollback. | Pilot sign-off with incident and data-recovery procedures. |

## 7. Release and acceptance gates

The project is production-complete only when the following conditions are all met:

1. The customer/merchant application and Creator Console use the same reviewed Supabase project boundary but cannot cross their role scopes.
2. All public tables have explicit grants and RLS; all Storage buckets have explicit privacy policies; all privileged functions have fixed search paths and limited execution grants.
3. Synthetic-user RLS tests cover customer, merchant, admin/reviewer/operator, creator, and anonymous access across tables, RPCs, Storage, and Realtime.
4. Creator people management cannot grant self-access, rewrite audit history, bypass suspension, expose private evidence, or mutate historical order snapshots.
5. Customer checkout remains atomic and creates one merchant-specific order per merchant group with immutable payment and item snapshots.
6. Payment proof submission never marks an order paid, and fulfilment cannot advance before payment confirmation.
7. Identity evidence remains private and manually reviewed, with approved retention and deletion controls.
8. Realtime events only trigger authorized refreshes and never become a substitute for database authorization.
9. Notifications do not expose sensitive evidence, payment details, access tokens, or unnecessary personal data.
10. Flutter Web, Android, and iOS builds succeed for every required app target, with Auth redirects/deep links and Storage upload behavior verified.
11. The legacy Node/tRPC runtime, Manus OAuth callback, MySQL/Drizzle production path, and Forge storage path are removed after end-to-end parity is proven.
12. The Ibb pilot has support ownership, rollback, backup/export, retention, incident response, and second-market expansion evidence.

## 8. Immediate next implementation increment

The next coding increment should not start with dashboard cosmetics. It should establish the shared package boundary, creator authorization schema, synthetic-user fixtures, and creator RPC contract. Specifically:

1. Create `packages/commerce_core`, `packages/commerce_data`, and `creator_app` scaffolds without exposing creator operations to `flutter_app`.
2. Add the Supabase migration for capabilities, access controls, creator/operator assignments, and append-only role-change audit records.
3. Add creator-only RPC wrappers for people search, role assignment/revocation, suspension/restore, market scope, and dashboard aggregates.
4. Expand the database tests to cover creator, operator, reviewer, support, merchant, customer, and anonymous paths.
5. Build the Creator Console session guard and a minimal dashboard/people-management vertical slice.
6. Run Flutter analyze/test/build for both applications, then continue with creator governance and remaining customer/merchant parity.

No creator account should be created or granted elevated access by a client-side seed or public sign-up flow. The first creator account must be bootstrapped through a controlled Supabase administrative process and immediately verified through the negative-path test suite.

## References

[1]: https://github.com/Aiman003516/yemen-commerce/blob/main/docs/FLUTTER_SUPABASE_MIGRATION_PLAN.md "Current Flutter and Supabase migration plan"
[2]: https://github.com/Aiman003516/yemen-commerce/blob/main/master-plan-mobile-web.md "Yemen Commerce master plan"
[3]: https://github.com/Aiman003516/yemen-commerce/blob/main/handover/SUPABASE_MIGRATION_PLAN.md "Supabase migration handover"
[4]: https://supabase.com/docs/guides/database/postgres/row-level-security "Supabase Row Level Security"
[5]: https://supabase.com/docs/guides/storage/security/access-control "Supabase Storage access control"
[6]: https://supabase.com/docs/guides/getting-started/quickstarts/flutter "Supabase Flutter quickstart"
