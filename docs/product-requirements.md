# Product Requirements

## 1. Product definition

Yemen Commerce is a modular local marketplace and storefront platform, beginning with Ibb Governorate, Yemen. Ibb is the initial market configuration rather than a permanent product boundary. The system must be able to add other Yemeni cities and regions through approved geography, policy, merchant, and availability configuration while preserving the same core customer, merchant, administrator, cart, order, and payment contracts. It serves customers, merchants, and administrators through mobile and responsive web experiences. The pilot is intentionally free and does not operate as a central wallet or payment settlement service. [1]

The platform allows a merchant to create a branded shop, publish a catalogue, accept orders, communicate local-payment instructions, review payment proof, and fulfil orders through collection, digital delivery, or seller-arranged handoff. Customers can discover multiple Ibb shops and add products from several merchants to one cart.

> **Core invariant:** One customer cart can contain several merchants, but checkout creates one merchant-specific order per merchant group. Each resulting order owns its own amount, payment instructions, payment proof, payment status, and fulfilment status. [1]

## 2. Modular product requirements

The product shall be decomposed into independently evolvable modules for geography and market configuration, identity and capabilities, merchant and shop operations, catalogue and discovery, cart and checkout, merchant orders and fulfilment, payments and provider adapters, administration and moderation, files and media, notifications, and analytics. Each module shall have clear ownership, versioned contracts, authorization rules, state transitions, error categories, and audit events.

A new city shall be introduced by adding approved geography records, service-area rules, enabled categories, merchant eligibility policy, available fulfilment methods, payment-method availability, localization content, and rollout controls. Adding a city must not require a city-specific codebase, a duplicate checkout path, or a new order type. Optional features and integrations must be independently enableable and must fail safely when disabled.

## 3. Roles and permissions

| Role | Primary responsibility | Initial access boundary |
|---|---|---|
| Customer | Discover, buy, pay, and track. | May see public approved shops and their own carts, orders, payment pages, proofs, and reports. |
| Merchant | Operate one or more approved shops. | May manage only the shop data, products, payment settings, proofs, and orders assigned to that merchant. |
| Administrator | Operate and govern the platform. | May verify merchants, approve shops, moderate content, manage categories, inspect reports, control provider activation, and inspect audit history. |
| Support agent | Future support operations. | Deferred; must use strictly limited permissions and is not part of the initial pilot role set. |

A person may hold both customer and merchant experiences, but the contexts must remain separate. A merchant must never gain access to another merchant's products, customers, payment details, or orders. [1]

## 4. Customer requirements

The customer experience shall provide Ibb-focused discovery, featured verified shops, categories, search, curated collections, shop profiles, product browsing, a cross-shop cart, checkout validation, merchant-specific payment-information pages, payment-proof submission, and independent order tracking.

The cart shall group items by merchant and show that checkout will create multiple orders. Before confirmation, each group shall expose its merchant subtotal, applicable merchant-configured fee or tax, fulfilment information, and group total. Checkout validation shall run independently for stock, availability, minimum order value, and fulfilment instructions.

Each merchant-specific order shall have a dedicated payment-information page containing merchant identity, order number, unique payment reference, exact amount and currency, enabled wallet or provider option, immutable receiving-account snapshot, transfer instructions, transaction-reference field, proof upload where required, payment timeline, and a help/report action. The customer shall confirm payment separately for every merchant order and see progress such as “1 of 3 merchant payments completed.” [1]

## 5. Merchant requirements

Merchant onboarding shall collect phone number, shop name, owner or manager name, Ibb area, category, description, fulfilment methods, and basic supporting information. An administrator must approve the shop before public listing. The pilot baseline is phone verification, Ibb location or area, shop information, administrator review, and additional evidence for higher-risk categories when required by policy. [1]

Approved merchants shall be able to manage storefront identity, logo, cover image, colour accents, categories, operating hours, contact route, collection instructions, product images, stock state, prices, descriptions, payment methods, and fulfilment settings.

The merchant payment area shall remain distinct from general shop settings. It shall support payment method name, manual or future API mode, account-holder name, account identifier, currency and amount rules, customer instructions, proof requirements, activation state, and provider-verification state. Payment settings shall be copied to an immutable order snapshot at checkout.

## 6. Administrator requirements

The administrator experience shall support merchant verification, shop approval, category management, content moderation, report review, provider activation controls, support operations, and audit-trail inspection. Administrative actions that affect merchant visibility, payment-provider state, order status, or moderation shall be attributable to an administrator identity and timestamp.

## 7. MVP fulfilment and status model

The MVP shall support customer collection, digital delivery, and seller-arranged fulfilment. It shall not include a platform-operated delivery fleet or platform-run shipping workflow in the first release. [1]

| Status | Meaning | Primary transition actor |
|---|---|---|
| Awaiting payment | Order exists and no payment claim has been submitted. | Customer begins payment step. |
| Payment under review | Customer submitted a reference or proof. | Customer submits; merchant reviews. |
| Paid | Merchant confirmed receipt in the merchant's own account. | Merchant. |
| Ready for collection / fulfilment arranged | Goods or service are ready. | Merchant. |
| Completed | Fulfilment was completed. | Merchant, with later customer confirmation option. |
| Rejected | Submitted payment could not be verified. | Merchant; reason required. |
| Cancelled | Order was cancelled under policy. | Customer, merchant, or administrator according to state. |

## 8. Pilot success measures

The pilot shall measure whether the workflows are understandable and operationally practical rather than optimize for scale immediately. The initial measures are verified shops activated, shops with published products, customer-to-order conversion, payment-proof approval time, rejected-proof rate, completed orders by fulfilment type, and support or dispute rate. [1]

## 9. Deferred scope

Non-Ibb expansion is not a permanent exclusion. It is deferred only as a rollout activity until the Ibb pilot, policy approvals, operational capacity, and expansion-readiness tests are complete. The modular architecture itself is required from the first implementation.

Automatic payment-provider integrations, platform custody of funds, commissions, subscriptions, platform-run delivery, and advanced support-agent permissions are deferred until the relevant policy, commercial, operational, and technical decisions are approved.

## References

[1]: ../master-plan-mobile-web.md "Master Plan: Ibb Commerce Platform for Mobile and Web"
