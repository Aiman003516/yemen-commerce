# Synthetic Debug Seed Guide

This guide prepares a **disposable Supabase test project** for Yemen Commerce Web debugging. It is not a production migration. The SQL creates only synthetic data, uses the reserved `example.invalid` email domain, does not send email, and does not represent real money or real payment accounts.

## 1. Create or choose the isolated project

Use a separate Supabase project. Do not run the seed in `mtaujfgkqvzwauqiegkl` or any other project containing real data. The project must first have the Yemen Commerce migrations applied through the current migration `20260827_0075_channels_logistics_idempotency.sql`, or the seed will fail because required tables will not exist.

In Supabase, open **SQL Editor** for the isolated project and run:

```text
supabase/debug/seed_synthetic_debug.sql
```

The script runs in one transaction. If any constraint fails, the transaction rolls back. Do not remove the `example.invalid` guards or replace `DEBUG-` values with real payment identifiers.

## 2. Synthetic accounts

The SQL creates six email-confirmed test users with the temporary password `DebugOnly-ChangeMe-2026!`. These credentials are for the isolated project only and should be changed or deleted after testing.

| Surface | Email | Intended coverage |
|---|---|---|
| Creator Console | `creator.debug@example.invalid` | Creator access, people, governance, AI readiness, audit summaries |
| Merchant | `merchant.debug@example.invalid` | Catalog, order workbench, shipment, exception, return, COD, inventory UI |
| Customer | `customer.debug@example.invalid` | Catalog, cart, order history, delivery timeline, return case, support |
| Customer 2 | `customer2.debug@example.invalid` | Unpaid/payment-under-review state and cross-customer isolation |
| Reviewer | `reviewer.debug@example.invalid` | Delegated review-agent visibility and restricted Creator operations |
| Support | `support.debug@example.invalid` | Delegated support-agent visibility and restricted Creator operations |

Because the Auth trigger creates a default customer role, the script adds the required additional roles and active access rows. The Creator is the only user seeded with the `creator` role. Reviewer and support roles are delegated through `creator_operator_assignments`; they are not treated as creators.

## 3. Fixtures included

The seed includes an active Ibb debug market, service area, pickup point, approved merchant and shop, Arabic catalog, manual payment method, delivery zone, customer address, cart, two checkout sessions, two merchant orders, claims, order history, one paid order, one payment-under-review order, an approved return case, a channel listing, an in-transit shipment, shipment events, an open delivery exception, return logistics, identity review state, a support report, and sanitized AI control-plane examples.

The paid order is `DEBUG-PAID-0001` and has a synthetic confirmed state only. It does not represent a real payment. The unpaid order is `DEBUG-UNPAID-0001` and must remain blocked from dispatch until the application’s authoritative payment workflow changes it through its existing RPCs. The test data deliberately preserves the rule that payment proof or a customer claim is not itself confirmation.

Useful fixed identifiers are:

| Record | UUID |
|---|---|
| Market | `20000000-0000-0000-0000-000000000001` |
| Shop | `50000000-0000-0000-0000-000000000001` |
| Product 1 | `60000000-0000-0000-0000-000000000002` |
| Product 2 | `60000000-0000-0000-0000-000000000003` |
| Paid order | `a0000000-0000-0000-0000-000000000001` |
| Unpaid order | `a0000000-0000-0000-0000-000000000002` |
| Shipment | `a7000000-0000-0000-0000-000000000001` |
| Return case | `a4000000-0000-0000-0000-000000000001` |

## 4. Configure the Web app locally

Copy the public example configuration to a local-only file and set values from the isolated Supabase project:

```bash
cp config/flutter_defines.example.json config/flutter_defines.json
```

Set `SUPABASE_URL` to the isolated project URL and set `SUPABASE_PUBLISHABLE_KEY` to the isolated project’s publishable/anon key. Do not put a service-role key, database password, provider key, or private key in this file. The repository’s Flutter helper rejects those values.

Then run the Web apps:

```bash
FLUTTER_BIN=/home/ubuntu/flutter/bin/flutter ./tools/flutter_yemen.sh setup all
FLUTTER_BIN=/home/ubuntu/flutter/bin/flutter ./tools/flutter_yemen.sh run customer web debug
FLUTTER_BIN=/home/ubuntu/flutter/bin/flutter ./tools/flutter_yemen.sh run creator web debug
```

The merchant experience is part of `flutter_app`; sign in with the merchant account after starting the customer/merchant app. Creator Console is a separate Flutter app.

## 5. Manual test matrix

First verify that anonymous visitors can read the approved public catalog and cannot read private profiles, payment claims, payment proofs, audit rows, or Creator data. Then sign in separately as customer, merchant, reviewer, support, and creator. Do not keep multiple roles in one browser session; use separate browser profiles or clear the session between roles.

| Test | Expected result |
|---|---|
| Customer reads `DEBUG-PAID-0001` | Sees only their own order, payment state, and customer delivery timeline |
| Customer reads `DEBUG-UNPAID-0001` | Sees payment-under-review language; no dispatch success is shown |
| Customer attempts another customer’s order | Empty/denied result; no private record leakage |
| Merchant opens the paid order | Sees operational details and can review shipment/exception/return actions |
| Merchant opens the unpaid order | Dispatch-related action is blocked with localized explanation |
| Merchant repeats an idempotent command key | Same result, no duplicate operational event |
| Reviewer opens Creator Console | Sees only delegated surfaces allowed by capability/assignment |
| Reviewer tries Creator-only capability change | Server rejects it |
| Support accesses private evidence | Server rejects it unless an explicit permitted workflow exists; the UI must not expose raw storage keys |
| Creator opens governance/readiness | Sees bounded summaries, not raw customer evidence or secrets |
| Offline or disconnected Web state | UI distinguishes local/stale data from server success and does not claim a mutation succeeded |
| Arabic/RTL and narrow viewport | Labels, cards, dialogs, tables, and errors remain readable without overflow |

## 6. Automated authenticated tests

After creating the isolated users, obtain their access tokens through normal Supabase Auth login for the isolated project. Do not paste service-role credentials into test variables. The existing harnesses accept publishable URL/key plus role access tokens:

```bash
export SUPABASE_TEST_ISOLATED=true
export SUPABASE_URL='https://YOUR-ISOLATED-PROJECT.supabase.co'
export SUPABASE_PUBLISHABLE_KEY='YOUR-PUBLISHABLE-KEY'
export SUPABASE_TEST_CREATOR_ACCESS_TOKEN='creator-user-token'
export SUPABASE_TEST_MERCHANT_ACCESS_TOKEN='merchant-user-token'
export SUPABASE_TEST_CUSTOMER_ACCESS_TOKEN='customer-user-token'
export SUPABASE_TEST_REVIEW_ACCESS_TOKEN='reviewer-user-token'
export SUPABASE_TEST_SUPPORT_ACCESS_TOKEN='support-user-token'
export SHOP_ID='50000000-0000-0000-0000-000000000001'
export COD_ORDER_ID='a0000000-0000-0000-0000-000000000001'
```

Run the applicable isolated harnesses from the repository:

```bash
bash supabase/tests/run_creator_authorization.sh
bash supabase/tests/run_order_workbench_cod_integration.sh
bash supabase/tests/run_inventory_integration.sh
bash supabase/tests/run_b2b_scale_integration.sh
```

Some harnesses require additional seeded inventory, B2B, or COD-specific IDs. If a harness reports a missing fixture rather than a product defect, record it separately; do not weaken the production schema or insert guessed rows into the shared project.

## 7. Cleanup

When testing is complete, run:

```text
supabase/debug/cleanup_synthetic_debug.sql
```

in the same isolated project. It deletes only the fixed synthetic fixture graph and `example.invalid` Auth users. As a final check, the following query should return zero rows:

```sql
select count(*) as remaining_debug_orders
from public.merchant_orders
where order_reference like 'DEBUG-%'
limit 1;
```

If the isolated project will not be used again, pause or delete it through Supabase’s project controls. Never run the cleanup script against the shared project unless you have independently verified that it contains only these exact synthetic IDs.

## 8. What to provide after seeding

Send back only the isolated project URL, the publishable key, and the fixed record IDs if they differ from the values above. Do not send the service-role key, database password, or any private storage credentials. For authenticated browser testing, the test accounts can be entered through the browser takeover flow rather than sent in chat.
