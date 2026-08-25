# Payment Policy and Workflow

## Pilot position

The pilot uses **merchant-owned payment accounts** and manual proof confirmation. Yemen Commerce must not hold customer funds, settle merchant funds, present itself as an authorized payment provider, or mark a transaction paid solely because a screenshot was uploaded. [1]

Jaib and Al Kuraimi may be configured as manual payment-method labels for the pilot, subject to merchant and administrator verification. The master plan identifies a publicly described Al Kuraimi API-link service as a possible future formal integration path and notes that a public Jaib merchant API specification was not identified during initial research. [1] [2] [3]

## Payment method record

A merchant payment method should conceptually contain the following fields. This is a contract specification for later implementation, not a database migration.

| Field | Meaning | Pilot requirement |
|---|---|---|
| Method name | Provider or method label, such as Jaib, Al Kuraimi, Cash, Yemen Wallet, or an approved custom method. | Required. |
| Integration mode | Manual or formally approved provider API. | Manual only at launch. |
| Account-holder name | Name the customer should verify before sending money. | Required for electronic methods. |
| Account identifier | Wallet number, account number, QR reference, or approved identifier. | Required for electronic methods. |
| Currency and amount rules | Accepted currency and whether exact amounts are required. | Explicitly configured; default zero tax or fee is a product setting, not a legal determination. |
| Customer instructions | Plain-language transfer and reference instructions. | Required before activation. |
| Proof requirement | Transaction reference, screenshot, both, or neither. | Must be explicit. |
| Activation state | Enabled or disabled for new orders. | Historical orders remain unchanged. |
| Provider verification state | Manual-only, pending verification, or official API active. | Manual-only or pending at launch. |

## Checkout snapshot rule

When checkout creates a merchant-specific order, the platform must copy the selected payment method's customer-facing receiving information and applicable amount rules into an immutable payment-instruction snapshot. Later merchant edits must not change the information shown for that historical order. The order must also retain saved tax and fee values so later configuration changes cannot rewrite historical totals. [1]

## Payment workflow

| Step | Customer action | Merchant or platform result |
|---|---|---|
| 1 | Open the merchant-specific payment-information page. | The page shows the merchant identity, order, total, and snapshot. |
| 2 | Select an enabled payment method. | Only methods active for that merchant order are available. |
| 3 | Transfer funds in the external wallet or bank application. | The platform does not execute or custody the transfer. |
| 4 | Enter the transaction reference and upload proof when required. | The merchant order changes to Payment under review. |
| 5 | Merchant checks the merchant-owned account and compares reference or proof. | Merchant accepts or rejects with a reason. |
| 6 | If accepted, merchant marks the order paid. | Fulfilment may proceed according to merchant settings. |
| 7 | If rejected, merchant records a reason. | Customer can review the rejection and follow support or correction guidance. |

## Payment status controls

Payment state transitions must be explicit, attributable, and recorded in history. A proof file is evidence submitted for review, not a payment confirmation. A merchant must not be able to inspect another merchant's payment proofs. Authorized administrators may inspect proofs for support, moderation, or dispute handling.

## Future provider-integration gate

A provider adapter may be activated only after formal commercial and technical approval. The gate requires merchant credentials, official API documentation, settlement requirements, callback security, sandbox testing, reconciliation procedures, operational ownership, and contract requirements. Until all conditions are complete, the user interface must continue to label the method as manual. [1]

## References

[1]: ../master-plan-mobile-web.md "Master Plan: Ibb Commerce Platform for Mobile and Web"
[2]: https://kuraimibank.com/en/services/50 "Al Kuraimi Islamic Microfinance Bank — API Link Service"
[3]: https://e-jaib.com/ar "Jaib Digital Wallet — Official Website"


## Implemented provider boundary

Migration `20260825_0008_payment_provider_boundary.sql` now persists `provider_code` and customer-safe `provider_metadata` on payment methods and copies them into immutable merchant-order snapshots as `payment_provider_code` and `payment_provider_metadata`. The supported launch labels are `manual`, `jaib`, `kuraimi`, `cash`, and `other`. All remain `mode = 'manual'` and `provider_verification = 'manual_only'` until a provider integration passes the formal gate below.

The customer/merchant Flutter app shares a provider catalog through `packages/commerce_core/lib/src/payment_providers.dart`. Jaib is presented as a manual QR/POS-capable method: the customer completes payment in Jaib, submits the transaction reference, and waits for merchant review. This is not an automatic Jaib API integration. No credentials, provider secrets, or assumptions about a public Jaib API are embedded in the clients.
