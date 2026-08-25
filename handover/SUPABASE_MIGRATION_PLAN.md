# Dedicated Supabase Migration Plan

## Current boundary

The current server uses **Node.js, tRPC, Drizzle, and a MySQL/TiDB-oriented schema**. Flutter is the shared Android, iOS, and Web client. Moving to Supabase is a backend migration, not a key swap: Supabase provides PostgreSQL, Auth, Storage, and optional Edge Functions, while the current schema and Manus OAuth flow are not PostgreSQL/Supabase implementations.

## Required design decisions

| Area | Current state | Dedicated Supabase target | Required decision |
|---|---|---|---|
| Database | Drizzle MySQL/TiDB schema | Supabase PostgreSQL | Translate schema and migrations from MySQL dialect to PostgreSQL; do not apply MySQL SQL files directly. |
| Authentication | Manus OAuth callback/session | Supabase Auth or a compatible server-side migration layer | Decide whether to migrate existing users or launch with new accounts. Never expose service-role keys to Flutter. |
| File storage | Server-authorized object storage helper | Supabase Storage with private buckets | Use private buckets and server-side authorization for passport/selfie evidence, payment proofs, and restricted documents. |
| API layer | Node/Express/tRPC | Retain tRPC initially, backed by Supabase, or migrate selected server logic to Supabase Edge Functions | Retaining tRPC first lowers client-contract disruption. |
| Sensitive identity evidence | Staff-reviewed, no biometric automation | Private Supabase Storage plus database metadata | Maintain merchant/admin scope checks, audit events, retention dates, and no public document URL. |

## Recommended staged migration

### Stage 1 — Fresh project and schema translation

Create a brand-new Supabase project. Translate `drizzle/schema.ts` to PostgreSQL Drizzle tables and generate new **PostgreSQL** migrations. Apply them to the new empty database only. Validate foreign keys, unique constraints, indexes, enum values, timestamps, and JSON metadata before connecting the app.

### Stage 2 — Server database adapter

Replace current database connection configuration with a Supabase/PostgreSQL-compatible server implementation. Keep the tRPC route names and shared `v1` vocabulary stable where possible, so Android, iOS, and Flutter Web do not need needless UI rewrites. Run server tests after each domain migration.

### Stage 3 — Authentication

Configure Supabase Auth redirect URLs for Flutter Web and native deep links. Replace the Manus-specific OAuth start/callback implementation only after the new session strategy is tested. Existing user records should not be copied casually; choose either a controlled user migration or clean launch accounts.

### Stage 4 — Private Storage

Create separate private buckets or equivalent prefixes for product assets, payment proofs, and identity evidence. Passport and selfie objects must stay private. A server endpoint must re-check authorization before providing a short-lived signed URL to an authorized administrator; customers and unrelated merchants must receive neither file URLs nor metadata.

### Stage 5 — Verification and cutover

Use an empty pilot dataset first. Verify merchant isolation, multi-merchant checkout splitting, payment snapshots, staff identity review, disabled OTP behavior, and Flutter Web runtime. Only then configure the new project as the active environment.

## Required new-project secrets

Add these only in the **new Manus project’s secret manager** after creating the dedicated Supabase project. Values must never enter Git, documentation, or Flutter client code.

| Secret category | Server use | Client exposure |
|---|---|---|
| Supabase project URL | Server and controlled public client configuration | Public URL may be exposed as a public configuration value. |
| Supabase anonymous key | Browser/mobile Auth and permitted public access | May be used in the client only with strict Row Level Security. |
| Supabase service-role key | Server-side administration, restricted storage operations, controlled migrations | **Never expose to Flutter or browser code.** |
| Database connection string | Server-side Drizzle/PostgreSQL adapter and migrations | **Never expose to Flutter or browser code.** |

## Data handling and rollback

No production dataset needs to move by default. If data exists later, export only through a reviewed migration, validate row counts and relationships in a non-production environment, and retain a rollback window. Do not automatically transfer passports, selfies, payment proofs, auth tokens, or customer data. Those require a separate approved privacy/retention plan.
