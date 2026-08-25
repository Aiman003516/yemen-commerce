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

The checkout RPC is the transaction boundary for grouped carts. It must create exactly one merchant order per merchant group, preserve the payment snapshot, decrement stock safely, write history and audit records, and clear the cart only when the complete transaction succeeds.

## Creator Console migrations

The creator-control plane is deployed after the foundation migrations in this order:

```text
20260825_0005_creator_authorization.sql
20260825_0006_creator_control_rpc.sql
20260825_0007_creator_governance.sql
```

Migrations 0005 and 0006 add explicit access controls, capabilities, delegated operator assignments, creator-only access helpers, people search, dashboard summaries, role delegation/revocation, account suspension/restoration, and capability grants. Migration 0007 adds creator-only RPCs for merchant verification, shop status moderation, market status moderation, market/policy/capability listing, policy-version creation, and per-market capability toggles. These operations are audited and remain behind creator authorization checks; the Creator Console exposes them through the Merchant Governance and Global Policies screens. Privileged implementations remain in the `private` schema; Flutter sees only narrow public RPC wrappers. The migrations do not create a creator account and do not grant a creator role automatically.

The matching security test starter is `supabase/tests/creator_authorization.test.sql`. It must be expanded and run against an isolated project with synthetic Auth users before any production creator account is bootstrapped.

## Authorization boundary runner

Run the available boundary test from the repository root:

```bash
./supabase/tests/run_creator_authorization.sh
```

The runner verifies the public client boundary against the connected project and exercises anonymous denial for all creator-control and governance RPCs plus protected creator tables. The latest run produced `RESULT passed=20 skipped=5`. The five skipped cases are authenticated customer, merchant, review-agent, support-agent, and creator scenarios because isolated synthetic-user access tokens are not configured. To run those cases, provide the corresponding `SUPABASE_TEST_*_ACCESS_TOKEN` values from an isolated test project or branch; never use a production service-role key or commit tokens. The harness checks creator dashboard allowance and non-creator dashboard denial, while the SQL pgTAP starters document the remaining role-escalation and cross-role cases.
