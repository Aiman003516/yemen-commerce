# Yemen Commerce: Clone and Local Run Guide

This guide runs the Yemen Commerce Flutter customer/merchant application and the separate Creator Console against a **development or staging Supabase project**. The repository preserves an Arabic-first, Yemen-first product boundary: Supabase owns authentication, authorization, RLS, Storage, RPC state transitions, checkout splitting, immutable snapshots, audit history, and merchant-owned manual payment records. The platform does not custody merchant money or claim automatic Jaib verification.

## 1. Install prerequisites

Install Git and a compatible Flutter SDK. The repository was validated with Flutter 3.47.1 and Dart 3.13.1; if the checkout declares a different compatible version, prefer the version recorded by the project toolchain. Install Chrome for Flutter Web. Android development additionally requires the Android SDK, platform tools, and an emulator or physical device. iOS development requires macOS and Xcode; Linux cannot produce an iOS archive.

A Supabase project is also required. Use a disposable development/staging project for local work and integration tests. Do not use a production database for fixture creation or mutation tests.

## 2. Clone the repository and select the migration branch

```bash
git clone https://github.com/Aiman003516/yemen-commerce.git
cd yemen-commerce
git fetch origin
git checkout migration/flutter-supabase-foundation
git pull --ff-only origin migration/flutter-supabase-foundation
```

Confirm the branch before editing or testing:

```bash
git status --short --branch
git log -1 --oneline
```

Do not merge this branch into `main` unless that review and release decision is explicitly approved.

## 3. Configure Supabase safely

Create or select a development/staging Supabase project and configure its Auth redirect URLs for the local Web origin used by your Flutter run. Apply the repository SQL migrations in filename order using the Supabase CLI or the Supabase SQL Editor after reviewing each migration. This checkout contains the migration SQL under `supabase/migrations/`; it does not commit project credentials or a service-role key.

If your team has a Supabase CLI project configuration, use the team-approved CLI workflow from the repository root, for example:

```bash
supabase login
supabase link --project-ref YOUR_DEVELOPMENT_PROJECT_REF
supabase db push
```

If the checkout is not linked to a CLI project, use the Supabase Dashboard SQL Editor or the connected project-management workflow to apply every migration in lexical filename order. Verify the migration history and run the Security Advisor after migrations that add functions, policies, Storage behavior, or triggers. The current branch includes migrations through `20260826_0035_cod_batch_date_guard.sql`.

The Flutter client must receive only the public project URL and publishable key. Never put a service-role key, database connection string, refresh token, private Storage signing secret, or provider credential in Flutter, browser JavaScript, `--dart-define`, or a committed file.

## 4. Run the customer and merchant Flutter application

From the repository root:

```bash
cd flutter_app
flutter pub get
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

The same two defines are used for native builds. For repeatable local work, place public values in an ignored configuration file and use Flutter’s `--dart-define-from-file` support where appropriate. Confirm that the file is ignored before adding it.

The merchant workspace requires an authenticated merchant profile, an approved shop, and the relevant RLS/RPC data. The **Order Workbench** displays a bounded merchant-owned projection only; it does not display customer identity or payment evidence. Fulfilment actions call the server transition RPC and remain subject to payment-before-fulfilment. The **COD Reconciliation** screen records append-only merchant collection evidence and compares expected versus collected totals; it does not move funds or verify non-cash payments automatically.

Build the Web release with:

```bash
flutter build web --release \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

## 5. Run the Creator Console

Open a second terminal from the repository root:

```bash
cd creator_app
flutter pub get
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

Build its Web release with:

```bash
flutter build web --release \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

Creator access is controlled by Supabase roles, capabilities, market scope, RLS, narrow RPC wrappers, required reasons, and audit events. The first creator account must be provisioned through an approved administrative process; the Flutter client does not self-grant creator privileges.

## 6. Run analysis and tests

From the repository root, run the shared package checks and both applications:

```bash
export PATH=/path/to/flutter/bin:$PATH
(cd packages/commerce_core && dart analyze)
(cd packages/commerce_data && dart analyze)
(cd flutter_app && flutter analyze && flutter test)
(cd creator_app && flutter analyze && flutter test)
git diff --check
```

If Android SDK tooling is absent, Android APK/AAB output is skipped rather than claimed. iOS archive/signing remains a macOS/Xcode gate.

## 7. Run Supabase boundary and isolated E2E tests

The anonymous boundary runner is safe to run against the configured project because it checks that protected public RPCs and tables are denied to anonymous clients:

```bash
./supabase/tests/run_creator_authorization.sh
```

The authenticated inventory and order-workbench/COD runners are intentionally guarded. They refuse to mutate data unless an isolated disposable project is explicitly marked with `SUPABASE_TEST_ISOLATED=1` and all fixture IDs and short-lived access tokens are present.

For the new order-workbench/COD suite, set these variables only from an isolated test project:

```bash
export SUPABASE_TEST_ISOLATED=1
export SUPABASE_TEST_MERCHANT_ACCESS_TOKEN='SHORT_LIVED_ISOLATED_TOKEN'
export SUPABASE_TEST_SHOP_ID='MERCHANT_OWNED_SHOP_UUID'
export SUPABASE_TEST_COD_ORDER_ID='CASH_COD_ORDER_UUID'
export SUPABASE_TEST_COD_BUSINESS_DATE='YYYY-MM-DD'
export SUPABASE_TEST_COD_EXPECTED_MINOR='5000'
# Optional when the fixture intentionally produces a variance:
# export SUPABASE_TEST_EXPECTED_BATCH_STATUS='variance'
./supabase/tests/run_order_workbench_cod_integration.sh
```

The runner verifies workbench ownership visibility, COD projection visibility, idempotent batch opening, cross-date attachment rejection, exact collection status, latest-record summary, batch close, and closed-batch re-close rejection. It does not create users, discover credentials, use a service-role key, or touch shared/production data. With no isolated token and fixture values, the correct result is an explicit `SKIP`, not a fabricated pass.

## 8. Native platform setup

For Android, install the Android SDK and accept licenses, then verify:

```bash
flutter doctor
flutter devices
flutter build apk --release \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

A Play Store AAB must be signed with a release keystore kept outside Git. Configure signing through local or CI secrets, never through a committed keystore or secret property file. For iOS, use macOS/Xcode, configure the bundle identifier, signing team, Auth deep links, and privacy declarations, then validate on a simulator and physical device before archiving.

## 9. Operational limitations to preserve

Manual merchant-owned payments remain the supported pilot path. Jaib may be represented as a manual QR/POS/reference method, but automatic verification, webhooks, SDK settlement, refunds, and provider custody must not be claimed until official AHD/Alhazmi documentation, sandbox credentials, callback security, settlement rules, and compliance approval exist. Payment proof is not payment finalization. COD collection records are append-only, private evidence remains private, and fulfilment cannot bypass server-enforced payment rules.

When reporting a local validation result, separate successful analysis, tests, Web builds, Supabase anonymous boundary checks, authenticated isolated E2E checks, Android builds, and iOS archives. A missing platform toolchain or isolated token is a documented limitation, not a successful run.
