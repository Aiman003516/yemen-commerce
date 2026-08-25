# New Manus Account Setup

## Purpose

Use these steps after creating the new Manus account. They preserve source control and produce a clean, separate application environment. They do **not** transfer hidden task memory or credentials.

## 1. Transfer repository access

The existing private repository is the source of truth. Add the new GitHub identity as a collaborator, or transfer repository ownership to a GitHub organization controlled by the new identity. Confirm the new identity can view the repository before creating the new Manus project.

Then, in the new Manus environment, clone the repository:

```bash
gh repo clone Aiman003516/yemen-commerce
cd yemen-commerce
git log --oneline -5
```

If ownership is transferred, use the new owner/repository path instead. Keep the repository private.

## 2. Create a new Manus project

Create a new full-stack web project in the new Manus account, then place the cloned source in that project. Copy this repository’s following durable files into the new project context if the new project does not already contain them:

| File or directory | Why it matters |
|---|---|
| `master-plan-mobile-web.md` | Governing product, payment, Ibb-launch, and merchant-isolation rules. |
| `todo.md` | Implementation history and unfinished work. |
| `handover/` | Account migration and Supabase setup record. |
| `flutter_app/CONTRACTS.md` | Implemented API contract subset mirrored by Flutter. |
| `drizzle/` | Existing schema and migration reference. |

## 3. Restore development tooling

Install project dependencies and run the existing verification commands:

```bash
pnpm install
pnpm check
pnpm test

cd flutter_app
flutter pub get
flutter analyze
flutter test
```

Flutter Web is staged after a verified build:

```bash
flutter build web --release --base-href / --no-wasm-dry-run
cd ..
rm -rf client/public/*
cp -a flutter_app/build/web/. client/public/
printf '{}\n' > client/public/assets/AssetManifest.json
```

The last JSON compatibility file prevents legacy Flutter asset requests from receiving the HTML fallback in the current hosting arrangement.

## 4. Create a fresh Supabase project

Create a **new Supabase account** and an empty project specifically for Yemen Commerce. Do not reuse the project, API keys, auth users, Storage buckets, or data of another application. Create project secrets only in the new Manus project’s secret manager; never commit them.

Follow [SUPABASE_MIGRATION_PLAN.md](SUPABASE_MIGRATION_PLAN.md) before changing database, Auth, or Storage code.

## 5. Confirm separation

Before importing any real merchant/customer data, verify all of the following:

- The new Manus project owns its own secrets and does not have access to this task’s connector configuration.
- The new Supabase project is empty and belongs to the new account or organization.
- The new project has its own Auth redirect URLs, service configuration, and Storage buckets.
- The GitHub repository is accessible to the intended new owner only.
- Passport/selfie evidence is **not** copied during setup. Its collection needs the production retention and incident-response policy identified in `todo.md`.
