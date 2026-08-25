# UX and Design Brief

## Design direction

The interface is **Arabic-first** and designed for the realities of local commerce in Ibb. Ibb is the first enabled market, while the design system must remain location-independent so additional Yemeni cities can be enabled through market configuration rather than copied screens. English-ready architecture is required, but the pilot experience should prioritize clear Arabic labels, readable numbers, explicit merchant identity, and low-ambiguity payment instructions. [1]

The product should feel like a trustworthy collection of local storefronts rather than a central financial institution. Every payment-related surface must make clear which merchant owns the receiving account, which order is being paid, and whether the platform is waiting for a merchant review.

## Modular design requirements

The design system must support market-aware configuration without embedding Ibb-specific assumptions into reusable components. City, governorate, district, service area, shop availability, category visibility, fulfilment options, payment methods, role capabilities, and optional features must be rendered from versioned contracts and configuration. A new city should be able to use the same discovery, shop, cart, checkout, payment, and order components with different approved content and policies.

Reusable components should expose stable states for enabled, disabled, unavailable, pending approval, and not-yet-launched modules. Optional modules such as notifications, additional fulfilment methods, and automatic payment providers must have clear fallbacks that preserve the core experience when they are disabled.

## Experience surfaces

| Surface | Primary user | Design objective |
|---|---|---|
| Customer mobile home | Customer | Make local Ibb discovery immediate through verified shops, categories, search, and curated collections. |
| Shop profile | Customer | Establish shop identity, area, fulfilment options, payment methods, operating details, and catalogue context. |
| Cross-merchant cart | Customer | Keep one cart understandable while visibly grouping products by merchant. |
| Merchant payment-information page | Customer | Provide safe, merchant-specific transfer instructions and payment-proof submission. |
| Order tracking | Customer | Show every merchant order independently, with payment and fulfilment progress. |
| Merchant onboarding | Merchant | Collect the minimum pilot information and explain approval expectations. |
| Shop management | Merchant | Make branding, catalogue, stock, fulfilment, and operating details easy to maintain. |
| Payment methods and information | Merchant | Keep receiving-account settings separate, reviewable, and explicit about manual mode. |
| Order and payment review | Merchant | Support account reconciliation and reasoned payment acceptance or rejection. |
| Administrator console | Administrator | Support verification, approval, moderation, reports, provider controls, and audit review. |

## Core customer flow

1. The customer opens the active marketplace for the selected market area, initially Ibb, and discovers an approved shop or product.
2. The customer reviews shop identity, location or area, fulfilment choices, payment methods, and product details.
3. The customer adds products from one or more shops to a single cart.
4. The cart groups products by merchant and explains that checkout creates multiple merchant orders.
5. The customer reviews each merchant subtotal, applicable configured fee or tax, fulfilment information, and total.
6. The system validates each merchant group independently for availability, stock, minimum order value, and fulfilment requirements.
7. The system creates one checkout session and one merchant-specific order per merchant group.
8. The customer completes a separate payment-information step for each merchant order.
9. The customer sees payment progress across the merchant orders and can return to any incomplete payment step.
10. The customer tracks each merchant order through payment review and fulfilment independently.

## Payment-information page layout

The page should present the following information in a deliberate order:

| Order | Content | Usability reason |
|---|---|---|
| 1 | Merchant identity and shop mark | Prevents payment to the wrong shop. |
| 2 | Order number and unique payment reference | Gives the customer and merchant a reconciliation key. |
| 3 | Exact amount and currency | Reduces ambiguity. |
| 4 | Enabled provider or wallet selector | Avoids displaying disabled methods. |
| 5 | Receiving-account holder and identifier | Lets the customer verify the destination. |
| 6 | Plain-language transfer instructions | Explains the external-wallet step. |
| 7 | Transaction-reference field | Captures the customer's confirmation number. |
| 8 | Proof upload control, when required | Supports merchant review without implying automatic verification. |
| 9 | Payment timeline | Communicates awaiting payment, review, paid, rejected, or cancelled. |
| 10 | Help/report action | Provides a path for incorrect information or disputes. |

The interface must not suggest that uploading a screenshot automatically confirms payment. A proof submission changes the order to **Payment under review**; the merchant must verify receipt in the merchant-owned account before marking the order paid. [1]

## Multi-merchant cart communication

The cart must use merchant grouping consistently in the item list, subtotal summary, checkout review, payment progress, order history, and notifications. A persistent summary should state how many merchant payments remain. Example copy: “You have 3 merchant orders. Complete payment for each shop separately.”

## Design states to prepare later

The implementation phase should provide explicit loading, empty, unavailable, validation-error, upload-failure, rejected-proof, cancelled-order, merchant-not-approved, and provider-disabled states. These states are design requirements, not optional polish, because the pilot relies on manual review and locally variable fulfilment.

## Accessibility and localization requirements

Arabic text must remain legible at supported mobile sizes, controls must have clear labels, status colours must not be the only signal, and numbers, currency, dates, and directionality must be tested in Arabic layouts. The architecture must permit English translations without embedding language-specific strings in business rules.

## References

[1]: ../master-plan-mobile-web.md "Master Plan: Ibb Commerce Platform for Mobile and Web"
