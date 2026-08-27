# Debug findings — 2026-08-28

## Browser startup smoke test

The customer/merchant Flutter Web debug server was started on `http://localhost:4173` with the mock Supabase public configuration. The page title was `يمن كومرس`, but the viewport rendered a blank white screen with no visible interactive elements after the initial navigation and one wait/view operation. Flutter server logs showed compilation/startup was still in progress at the first check. This needs follow-up by checking browser console errors and the server log before declaring it a UI defect.

After both servers reported ready, the customer page still rendered a blank white viewport with no interactive elements. Browser console showed only DDC script-loading information and no visible exception. This is now a confirmed startup/rendering defect requiring diagnosis, likely in app initialization or the web debug runtime rather than server availability.

## Flutter bootstrap diagnosis

The customer Web document reached `readyState: complete`, but its body text was empty, there were no canvases, and no `flt-glass-pane` element. The page loaded the Flutter DDC scripts and `flutter_bootstrap.js`; the browser console reported only that DDC was loading scripts. The server was listening and reported the app as served. This narrows the blank screen to Flutter Web debug bootstrap/startup initialization rather than HTTP availability or Supabase query rendering.

## Release Web smoke test

The customer/merchant release bundle built with the seeded mock Supabase configuration and mounted successfully at `http://localhost:4183`. The apparent boxed Arabic glyphs in the first screenshot were a transient loading/rendering artifact; after the page settled, Arabic text, RTL layout, sidebar, hero, assistant card, and feature cards rendered legibly. The earlier blank screen is therefore associated with the Flutter `web-server` DDC debug bootstrap in this sandbox, not the release bundle startup.

## Creator Console release smoke test

The Creator Console release bundle mounted successfully at `http://localhost:4184` and rendered an Arabic RTL login card with the email field and magic-link button. No authenticated browser action was taken because submitting a magic-link request is an external side effect; authenticated testing can use the synthetic account through a controlled login flow or the existing token-based harness.

## Supabase Auth provisioning

The user-controlled Supabase dashboard session is authenticated for project `mtaujfgkqvzwauqiegkl`. The Auth UI initially showed no users. Direct SQL-created users were present in `auth.users` but could not authenticate through GoTrue; the supported Auth UI successfully created `creator.auth.debug@mock.yemencommerce.dev` with auto-confirm enabled and no confirmation email. The remaining synthetic accounts should be created through the same supported UI path.

The supported Supabase Auth UI successfully created:

- `creator.auth.debug@mock.yemencommerce.dev` — UID `7dc3cf8f-0a6b-41a59-9b8d-6ed926ebadd2` (dashboard displayed the full UID during creation)
- `merchant.auth.debug@mock.yemencommerce.dev` — UID `9d582e41-f2ab-41bf-a920-5604c6f089cb`

Auto-confirm was enabled for both and no email was sent.

While continuing supported Auth provisioning, the dashboard’s Add-user menu shortcut did not open the form on one attempt; a coordinate fallback opened the column selector instead. No unintended data mutation occurred. The next step is to close the selector and use the visible Add user control with a fresh page state.

The dashboard’s Add-user control is functional, but the menu is rendered outside the normalized screenshot viewport and indexed clicks can target adjacent controls. DOM inspection confirmed the menu item geometry, and controlled DOM activation successfully opened the new-user form. This is a dashboard automation quirk, not an application defect.

The supported Auth UI successfully created `customer.auth.debug@mock.yemencommerce.dev` with auto-confirm enabled. Dashboard UID: `6d57617e-24c3-4653-93e6-fe046e74c749`.

The supported Auth UI successfully created `customer2.auth.debug@mock.yemencommerce.dev` with auto-confirm enabled. Dashboard UID: `6b2a1dab-d292-4ffa-8057-a920a69e1291`.

The supported Auth UI successfully created `reviewer.auth.debug@mock.yemencommerce.dev` with auto-confirm enabled. The dashboard reported a total of 11 users after creation, including unrelated existing project users.

The supported Auth UI successfully created `reviewer.auth.debug@mock.yemencommerce.dev` with auto-confirm enabled. Dashboard UID: `8e22f903-e427-4211-aa3d-1b7583ab11b0`.

The supported Auth UI successfully created `support.auth.debug@mock.yemencommerce.dev` with auto-confirm enabled. Dashboard UID: `cdf22d9f-595d-4292-9370-84b51ed91e23`. The Auth dashboard now shows 12 total users, including the six synthetic auth.debug accounts and six unrelated existing project users.

## Supported Auth binding and authorization results

The six dashboard-created synthetic accounts were found to have auto-created `customer` role rows but null display names. A targeted migration populated Arabic profile metadata, activated the accounts, assigned `creator`, `merchant`, `review_agent`, and `support_agent` roles with the Ibb market scope, and rewired the fixed merchant/customer/order graph to the supported Auth UIDs. The migration deliberately skipped immutable event, AI-core, and audit actor updates; those records remain synthetic but retain their original fixture actors by design.

A temporary password-flow harness successfully authenticated all six supported accounts. Access tokens were stored only in `/tmp/yemen_commerce_auth_tokens.env` with mode `600` and were never printed. The full Creator authorization runner completed with `passed=160 skipped=0`: all protected anonymous RPC/table checks were denied, customer/merchant/reviewer/support Creator dashboard access was denied, and Creator dashboard access was allowed.

## Workflow integration results

The authenticated inventory harness initially reported a transfer idempotency mismatch. The RPC intentionally returns `idempotent: false` for the first call and `idempotent: true` for a replay while preserving the same transfer identity and completed status. The harness was corrected to assert the stable identity/state contract plus the replay flag rather than byte-for-byte JSON equality. The corrected inventory transfer and count suite passed.

The B2B harness initially used Customer 1’s token with Customer 2’s buyer UUID and correctly rejected the request with `WHOLESALE_REQUEST_NOT_FOUND`. The fixture helper was corrected to create the business profile and wholesale request as Customer 2, and a dedicated awaiting-payment B2B order was added rather than mutating the payment-under-review fixture. The complete B2B quote, acceptance, negotiated pricing, daily rollup, and disabled-provider suite passed.

A dedicated current-date cash-on-delivery order was added for the merchant workbench. The complete order-workbench/COD suite passed: merchant projection, batch idempotency, date-mismatch rejection, exact collection to `collected`/`paid`, reconciliation visibility, close to `reconciled`, and safe re-close rejection.

## Seed and cleanup hardening

The seed was redesigned as supported-Auth-first. It no longer writes to `auth.users`, inserts encrypted passwords, or claims that direct SQL-created users can authenticate. The reusable `bind_supported_auth_debug.sql` script verifies the six exact dashboard-created identities and binds the fixed graph. The cleanup script now removes dynamic inventory, B2B, COD, and dedicated-order fixtures, the fixed graph, synthetic audit rows, legacy direct-SQL users, and only the six exact supported debug emails. It temporarily removes immutable cleanup guards inside one transaction and restores their exact trigger definitions before commit.

## Post-change advisor findings

The Supabase Security Advisor reported one external configuration warning: leaked-password protection is disabled for Auth. This is a project-level setting and was not changed during the disposable debug cycle because the task did not authorize changing Auth policy; it should be enabled before any real deployment. The Performance Advisor reported informational unused-index notices, not query failures or security lints. No additional application migration was needed for the bounded client caps, so the existing index set was retained rather than dropping indexes based only on limited debug traffic.

## Release-Web smoke observations after hardening

The customer release bundle at `http://127.0.0.1:4183/` mounted successfully and displayed the Arabic Yemen Commerce shell, RTL sidebar, local-market hero, rules-only assistant card, and feature cards. The Creator release bundle at `http://127.0.0.1:4184/` mounted successfully and displayed the Arabic RTL Creator login card with email input and magic-link action. No authenticated browser mutation was submitted, and no raw token or private evidence was exposed. The browser adapter did not enumerate Flutter canvas controls, so authenticated UI journeys remain covered by RPC harnesses rather than claimed as completed browser interactions.

## Cleanup verification

After all authenticated and release-Web testing, the revised cleanup transaction succeeded. Bounded verification returned `remaining_debug_orders = 0`, `remaining_debug_merchant = 0`, `remaining_supported_profiles = 0`, and `remaining_legacy_profiles = 0`. All seven immutable protections were present again: shipment events, return-logistics events, COD collection records, AI runs, AI tool calls, AI approvals, and AI policies.
