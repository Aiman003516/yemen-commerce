# Synthetic Debug Fixture Guide

This guide prepares the explicitly authorized Yemen Commerce mock/debug Supabase project for disposable Web and RPC testing. It is **not** a production migration and must never be copied into a production project. Every account, identifier, payment reference, order, and provider value described here is synthetic; no email delivery, real payment, fund custody, external provider call, or real evidence upload is involved.

## 1. Project and migration prerequisites

The current debug target is the mock Supabase project `mtaujfgkqvzwauqiegkl`. The project must already contain the Yemen Commerce migrations through the current repository head. Run the seed and cleanup only through the project’s SQL Editor or the authorized migration path; do not place a service-role key or database password in the repository or in Flutter configuration.

The seed is now **supported-Auth-first**. It no longer writes to `auth.users`, does not hash a password, and does not manufacture GoTrue identities. Before running `supabase/debug/seed_synthetic_debug.sql`, create six auto-confirmed email/password accounts through the supported Supabase Auth UI/API with the exact synthetic addresses below. Keep the debug-only password outside the repository and rotate or delete the accounts after testing.

| Surface | Exact synthetic email | Intended coverage |
|---|---|---|
| Creator Console | `creator.auth.debug@mock.yemencommerce.dev` | Creator access, governance, people, AI readiness, and audit summaries |
| Merchant | `merchant.auth.debug@mock.yemencommerce.dev` | Catalog, workbench, shipment, return, COD, inventory, and provider gates |
| Customer | `customer.auth.debug@mock.yemencommerce.dev` | Catalog, cart, own orders, delivery timeline, returns, and support |
| Customer 2 | `customer2.auth.debug@mock.yemencommerce.dev` | Cross-customer isolation and B2B buyer-scoped workflows |
| Reviewer | `reviewer.auth.debug@mock.yemencommerce.dev` | Delegated review-agent visibility and denial of Creator-only operations |
| Support | `support.auth.debug@mock.yemencommerce.dev` | Delegated support-agent visibility and denial of Creator-only operations |

After the Auth UI has created the accounts, run `supabase/debug/seed_synthetic_debug.sql`. If the fixed business graph was seeded before the supported accounts were available, run `supabase/debug/bind_supported_auth_debug.sql` afterward. The binding script verifies all six exact addresses, assigns only the intended roles and market scope, populates Arabic profile metadata, and rewires the fixed graph without modifying immutable event, AI-core, or audit rows.

## 2. Baseline fixture graph

The seed creates an active Ibb market, service area, pickup point, approved merchant and shop, Arabic catalog, manual payment method, delivery zone, customer address, cart, checkout sessions, two customer orders, claims, an approved return case, channel listing, shipment and exception records, return logistics, identity-review state, a support report, and sanitized AI control-plane examples. The paid state is synthetic only and never represents money received by the platform.

| Record | Fixed identifier | Expected state |
|---|---|---|
| Market | `20000000-0000-0000-0000-000000000001` | Active Ibb pilot market |
| Shop | `50000000-0000-0000-0000-000000000001` | Approved synthetic shop |
| Product 1 | `60000000-0000-0000-0000-000000000002` | Active, YER 12,500 |
| Product 2 | `60000000-0000-0000-0000-000000000003` | Active, YER 18,000 |
| Paid order | `a0000000-0000-0000-0000-000000000001` | `paid` / `arranged` |
| Payment-under-review order | `a0000000-0000-0000-0000-000000000002` | `payment_under_review` / `pending` |
| Shipment | `a7000000-0000-0000-0000-000000000001` | In transit, synthetic tracking only |
| Return case | `a4000000-0000-0000-0000-000000000001` | Approved, synthetic return |

The payment-under-review order must remain blocked from dispatch until an authoritative payment workflow changes it. A payment proof or customer claim is never itself proof of confirmed payment. The system remains merchant-owned and manual-payment-first.

## 3. Local Flutter Web configuration

Copy the example configuration into the ignored local file and set only the project URL and public publishable key:

```bash
cp config/flutter_defines.example.json config/flutter_defines.json
```

The file must not contain a service-role key, database password, private storage credential, provider credential, or model signing key. The local Flutter commands are:

```bash
FLUTTER_BIN=/home/ubuntu/flutter/bin/flutter ./tools/flutter_yemen.sh setup all
FLUTTER_BIN=/home/ubuntu/flutter/bin/flutter ./tools/flutter_yemen.sh build customer web release
FLUTTER_BIN=/home/ubuntu/flutter/bin/flutter ./tools/flutter_yemen.sh build creator web release
```

For this sandbox, release Web bundles are the reliable UI smoke-test target. The Flutter `web-server` debug/Dart Dev Compiler path previously produced a blank unmounted page without `flt-glass-pane`, while the release bundles mounted and rendered the Arabic RTL shells. This is recorded as an environment/toolchain finding, not as evidence that the release app is broken.

## 4. Secure authenticated harness setup

The existing scripts use `SUPABASE_KEY`, not `SUPABASE_PUBLISHABLE_KEY`, and the role variable names are `SUPABASE_TEST_REVIEW_AGENT_ACCESS_TOKEN` and `SUPABASE_TEST_SUPPORT_AGENT_ACCESS_TOKEN`. Obtain access tokens through the normal password flow or supported Auth UI session, store them only in a chmod-600 temporary file, and never print them. The repository does not include a password or token file.

The Creator authorization runner first checks anonymous denial for the protected RPC/table boundary and then checks all five supported authenticated roles. It expects these variables:

```bash
export SUPABASE_URL='https://YOUR-MOCK-PROJECT.supabase.co'
export SUPABASE_KEY='YOUR-PUBLISHABLE-KEY'
export SUPABASE_TEST_CUSTOMER_ACCESS_TOKEN='customer-token'
export SUPABASE_TEST_MERCHANT_ACCESS_TOKEN='merchant-token'
export SUPABASE_TEST_REVIEW_AGENT_ACCESS_TOKEN='review-agent-token'
export SUPABASE_TEST_SUPPORT_AGENT_ACCESS_TOKEN='support-agent-token'
export SUPABASE_TEST_CREATOR_ACCESS_TOKEN='creator-token'
```

Run the authorization boundary suite from the repository root:

```bash
bash supabase/tests/run_creator_authorization.sh
```

A successful run must show anonymous protected RPC/table denial, customer/merchant/reviewer/support dashboard denial, Creator dashboard allowance, and `skipped=0`. The test intentionally validates the server boundary; UI visibility alone is not an authorization control.

## 5. Workflow fixture setup and integration tests

The inventory harness needs two active locations and stock at the supported merchant’s shop. Use the existing authenticated RPCs `save_inventory_location` and `record_inventory_adjustment`; capture the returned location IDs locally and set the following variables:

```bash
export SUPABASE_TEST_ISOLATED=1
export SUPABASE_TEST_SHOP_ID='50000000-0000-0000-0000-000000000001'
export SUPABASE_TEST_FROM_LOCATION_ID='from-rpc-result'
export SUPABASE_TEST_TO_LOCATION_ID='to-rpc-result'
export SUPABASE_TEST_PRODUCT_ID='60000000-0000-0000-0000-000000000002'
export SUPABASE_TEST_SECOND_PRODUCT_ID='60000000-0000-0000-0000-000000000003'
bash supabase/tests/run_inventory_integration.sh
```

The inventory RPC returns `idempotent: false` on the first successful command and `idempotent: true` on a replay. The corrected harness therefore asserts stable record identity and state plus the replay flag rather than incorrectly requiring byte-for-byte equality of those intentionally different metadata values.

For B2B testing, create a business profile for Customer 2, open a wholesale request as Customer 2, approve it as the supported Merchant, and create a clean awaiting-payment B2B order whose items match the quote. Set the returned request ID and the dedicated order ID in the harness variables:

```bash
export SUPABASE_TEST_B2B_SHOP_ID='50000000-0000-0000-0000-000000000001'
export SUPABASE_TEST_B2B_REQUEST_ID='approved-request-id'
export SUPABASE_TEST_B2B_BUYER_USER_ID='6b2a1dab-d292-4ffa-8057-a920a69e1291'
export SUPABASE_TEST_B2B_ORDER_ID='awaiting-payment-b2b-order-id'
export SUPABASE_TEST_B2B_PRODUCT_ID='60000000-0000-0000-0000-000000000003'
export SUPABASE_TEST_B2B_QUOTE_QUANTITY=1
export SUPABASE_TEST_B2B_QUOTE_UNIT_PRICE_MINOR=15000
bash supabase/tests/run_b2b_scale_integration.sh
```

For COD testing, use a dedicated current-date cash order with `payment_provider_code = 'cash'`, positive `cod_expected_minor`, `cod_status = 'expected'`, and `awaiting_payment` state. Then set:

```bash
export SUPABASE_TEST_COD_ORDER_ID='current-date-cod-order-id'
export SUPABASE_TEST_COD_BUSINESS_DATE="$(date -u +%F)"
export SUPABASE_TEST_COD_EXPECTED_MINOR=26500
bash supabase/tests/run_order_workbench_cod_integration.sh
```

The expected COD workflow is merchant-scoped workbench visibility, idempotent batch opening, rejection of a date-mismatched collection, exact collection changing the order to `collected`/`paid`, successful close to `reconciled`, and safe rejection of a second close. No provider call or fund transfer occurs.

## 6. Manual Web smoke matrix

Use a separate browser session for each role and sign out or clear the session between journeys. Anonymous visitors should see only approved public catalog data. Customers should see only their own order, address, claims, and delivery state. Merchants should see their shop’s operational data and must not be able to claim payment confirmation through a UI-only path. Reviewers and support agents must remain market-scoped and denied Creator-only changes. Creators may see bounded governance/readiness summaries but not raw private evidence or secrets. Narrow Arabic/RTL viewports must not overflow, and offline or stale state must never be presented as a successful server mutation.

## 7. Static and release validation

After any repository repair, run the seed validator, formatting checks, Dart analysis/tests, Web release builds, and the available legacy test suite. The Linux sandbox cannot produce authoritative Android/iOS/Windows builds without the corresponding external toolchains; those remain explicit gates.

```bash
python3 tools/validate_debug_seed.py
./tools/flutter_yemen.sh analyze all
./tools/flutter_yemen.sh test all
./tools/flutter_yemen.sh build customer web release
./tools/flutter_yemen.sh build creator web release
git diff --check
```

Do not claim native LiteRT-LM inference, cloud AI, fine-tuning, device benchmarking, Android signing, iOS/Xcode builds, or Windows runner validation unless those prerequisites have actually been completed.

## 8. Cleanup and zero-fixture verification

After all testing is complete, run `supabase/debug/cleanup_synthetic_debug.sql` in the same authorized mock project. The script removes dynamic inventory, quote, rollup, COD, and dedicated order fixtures; the fixed graph; synthetic audit rows; legacy direct-SQL `example.invalid` users; and only the six exact `*.auth.debug@mock.yemencommerce.dev` users. It temporarily drops only the immutable cleanup guards inside the transaction and recreates them verbatim before commit. It does not target unrelated project users.

Verify the cleanup with bounded checks such as:

```sql
select count(*) as remaining_debug_orders
from public.merchant_orders
where order_reference like 'DEBUG-%'
limit 1;

select count(*) as remaining_supported_debug_profiles
from public.profiles
where email like '%.auth.debug@mock.yemencommerce.dev'
limit 1;
```

Both counts must be zero. If cleanup fails, do not manually weaken triggers or delete unrelated rows; inspect the transaction error, repair the disposable script, and rerun it only after verifying the target IDs and email predicates.
