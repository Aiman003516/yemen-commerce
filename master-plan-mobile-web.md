# Master Plan: Ibb Commerce Platform for Mobile and Web

**Purpose:** Build a free-at-launch, two-sided commerce platform for **Ibb Governorate, Yemen**. The platform will serve customers, merchants, and administrators through Flutter mobile applications and a responsive web experience. It will support a multi-merchant cart, but every merchant receives a separate order and payment because merchants use their own local payment accounts.

## 1. Strategic Direction

The product is a local marketplace and storefront platform rather than a central wallet. It enables a merchant to create a branded shop, publish a catalogue, accept orders, share local-payment instructions, review payment proof, and fulfil orders through collection, digital delivery, or seller-arranged handoff. Customers discover Ibb shops, shop across merchants in one cart, and complete a guided payment step for each merchant order.

> **Core rule:** A single customer cart may contain products from several merchants. At checkout, it is split into separate merchant orders with separate totals, payment instructions, payment proofs, and fulfilment statuses.

The initial business model is **free for merchants and customers**. The platform will not charge subscriptions or commissions in the pilot, and it will not hold or settle merchant money. Tax and fee settings will be configurable by merchant and default to zero only as a product configuration, not as a legal determination.

## 2. Why a Dedicated Project Is the Right Decision

Yes, a dedicated project is the correct foundation. This product needs durable source control, a shared backend and database, separate development environments, role-based access control, security review, test coverage, and staged releases. It should not be built as a single landing page or a collection of disconnected prototypes.

The existing **Yemen Commerce** workspace can be used as the product’s initial project record and backend/web foundation. The fully functional solution should be organized as a product workspace with the following components.

| Component | Technology direction | Purpose |
|---|---|---|
| Mobile application | Flutter for Android first, with iOS support designed in | Customer and merchant operations on phones. |
| Web application | Flutter Web for shared customer/merchant functionality, or a responsive web frontend backed by the same APIs | Browser access, merchant administration, and future public shop links. |
| Backend API | Secure server and database with role-based APIs | Authentication, products, carts, orders, payment instructions, payment proofs, and audit logs. |
| Admin console | Responsive web console | Merchant verification, moderation, categories, reports, payment-provider approval, and support. |
| File storage | Secure object storage | Product images, shop logos, payment proofs, and administrative verification documents. |

**Recommended approach:** Use Flutter as the shared mobile-and-web client foundation where practical, while keeping a single backend API and database. This reduces duplicated business logic across Android, iOS, and browsers. The administrator console may use the web client with an administrator-specific layout.

## 3. Product Roles and Permissions

| Role | Who they are | What they can do |
|---|---|---|
| Customer | A person buying from Ibb shops. | Discover shops, browse products, maintain a cross-shop cart, place orders, view payment information, submit payment proof, and track each merchant order. |
| Merchant | A shop owner or owner-authorized manager. | Create and brand a shop, add products, set payment methods, manage stock, review payment proof, manage merchant orders, and define fulfilment instructions. |
| Administrator | Platform operations staff. | Verify merchants, approve shops, manage categories, review reports, moderate content, control provider activation, and inspect audit trails. |
| Support agent, later phase | Authorized operations staff. | Assist with account and order disputes under strictly limited permissions. |

A single person may be both a customer and a merchant, but those experiences must remain separate. A merchant can never view other merchants’ products, customers, payment details, or orders.

## 4. The Customer Experience

### 4.1 Discovery and shopping

The customer mobile home screen should focus on local Ibb discovery: featured verified shops, categories, search, curated collections, and shop profiles. Every shop profile displays its brand, area, available fulfilment options, payment methods, product catalogue, and operating details.

The web experience mirrors the same actions on a responsive layout. Customers should be able to open shared shop/product links in a browser even if they have not installed the app.

### 4.2 Multi-merchant cart

The cart groups items by merchant and always reveals that the customer will create multiple orders. The customer sees a merchant subtotal, the applicable merchant fee/tax configuration, and the total for every group before confirming checkout.

| Customer action | System behavior |
|---|---|
| Add products from different shops | Keep one cart but group items by merchant. |
| Change quantity/remove item | Update only the relevant merchant group and cart summary. |
| Tap checkout | Validate each merchant group independently for stock, availability, minimum order value, and fulfilment instructions. |
| Confirm checkout | Create one checkout session and one merchant-specific order per merchant group. |
| Pay | Guide the customer through payment one merchant at a time. |

### 4.3 Dedicated customer payment-information page

Every merchant-specific order receives a dedicated **Payment Information** page. This page is essential to make the manual local-wallet workflow understandable and safe.

| Page element | Customer purpose |
|---|---|
| Merchant identity | Confirms the exact shop the payment belongs to. |
| Order number and unique payment reference | Helps merchant and customer reconcile the transfer. |
| Exact amount and currency | Prevents payment ambiguity. |
| Wallet/provider option selector | Shows only methods enabled by the merchant, such as Jaib or Al Kuraimi. |
| Receiving account information | Displays merchant-controlled account name and identifier from the immutable order snapshot. |
| Step-by-step transfer instructions | Explains how to complete payment in the customer’s external wallet application. |
| Transaction reference field | Lets customer enter a wallet/bank confirmation number. |
| Payment-proof upload | Lets customer attach a screenshot or permitted proof image. |
| Payment timeline | Shows awaiting payment, under review, paid, rejected, or cancelled. |
| Help/report action | Lets the customer report incorrect payment information or an issue. |

The customer must confirm payment separately for each merchant order. The platform should present a clear progress view, such as **1 of 3 merchant payments completed**, so a multi-merchant order is never mistaken for one central payment.

### 4.4 Order tracking and fulfilment

After payment confirmation, the customer tracks every merchant order independently. The MVP supports three fulfilment methods: customer collection, digital delivery, and seller-arranged fulfilment. No platform-run shipping or delivery fleet is included in the first release.

## 5. The Merchant Experience

### 5.1 Merchant onboarding and shop verification

Merchants enter through a dedicated merchant onboarding flow. The first pilot should collect a phone number, shop name, owner/manager name, Ibb area, category, description, fulfilment methods, and basic supporting information. An administrator approves the shop before it becomes public.

The exact level of verification is a policy decision. For the pilot, a practical baseline is phone verification, Ibb location/area, shop information, administrator review, and a mechanism to request additional evidence for higher-risk categories.

### 5.2 Branded storefront management

Merchants control their shop’s display name, logo, cover image, colour accents, categories, operating hours, contact/support route, collection instructions, product images, stock state, prices, and product descriptions. The customer-facing web and mobile storefronts use the same merchant data.

### 5.3 Dedicated merchant payment-settings page

The merchant side needs a dedicated **Payment Methods & Information** area. This is the control centre for every local payment option and must be separate from general shop settings.

| Merchant payment setting | Purpose |
|---|---|
| Payment method name | Choose a provider label, such as Jaib, Al Kuraimi, Cash, Yemen Wallet, or a custom approved method. |
| Integration mode | Mark the method as manual or provider API. API mode remains disabled until formally approved and configured. |
| Receiving account holder name | Shows the name the customer should verify before sending funds. |
| Receiving account identifier | Stores a wallet number, account number, QR reference, or other provider-approved identifier. |
| Currency and accepted amount rules | Defines which currency the merchant accepts and whether amounts must match exactly. |
| Customer instructions | Gives plain-language steps for transferring money and identifying the order. |
| Proof requirement | Requires a transaction reference, screenshot, both, or neither according to the merchant/provider setup. |
| Activation state | Lets merchant enable/disable a method without changing historical orders. |
| Provider verification state | Shows manual-only, pending provider verification, or official API active. |

The merchant’s payment information is copied into an order snapshot at checkout. This prevents a merchant from changing the receiving account after the customer has placed an order and preserves a dispute record.

### 5.4 Payment review and order management

The merchant order screen shows only that shop’s part of a multi-merchant checkout. For a manual payment, the merchant compares the submitted reference/proof with their own wallet or bank account before confirming payment.

| Status | Meaning | Who moves it |
|---|---|---|
| Awaiting payment | Order exists; no customer payment claim yet. | Customer action begins the next step. |
| Payment under review | Customer submitted reference or proof. | Customer submits; merchant reviews. |
| Paid | Merchant confirmed receipt. | Merchant. |
| Ready for collection / fulfilment arranged | Goods/service are ready. | Merchant. |
| Completed | Customer received product/service or the merchant completed the fulfilment. | Merchant, with later customer confirmation option. |
| Rejected | Merchant could not verify payment. | Merchant, reason required. |
| Cancelled | Order was cancelled under platform rules. | Customer, merchant, or administrator depending on state. |

## 6. Payment-Provider Strategy

The first product release should use **merchant-owned payment accounts** and manual proof confirmation. The platform must not represent itself as an authorized payment provider, store customer funds, or automatically mark a transaction as paid based on a screenshot.

Al Kuraimi publicly describes an API-link service for connecting a website or application to its payment services, indicating a possible formal path to future integration. [1] Jaib publicly describes its wallet services, including transfers, payments, online shopping, and purchase payments, but a public merchant API specification was not identified during initial research. [2]

| Provider state | What the product does |
|---|---|
| Manual payment available | Merchant adds their verified receiving details and customers submit reference/proof. |
| Provider business/API path under review | The app labels the method as manual until commercial and technical requirements are signed off. |
| Formally verified provider API | Activate a provider adapter only after merchant credentials, API documentation, settlement requirements, callback security, sandbox tests, and contract requirements are complete. |

## 7. Shared Technical Architecture

The platform should use one authoritative backend. Both Flutter mobile and responsive web call the same API and receive the same business rules.

| Layer | Responsibilities |
|---|---|
| Flutter client | Customer and merchant interfaces on Android, iOS, and web; local state; secure session handling; image/proof selection; push notifications in a later phase. |
| Responsive web | Public product/shop links, browser shopping, merchant browser access, and administration. |
| API service | Authentication, role enforcement, cart logic, order splitting, payment-state transitions, product data, settings, and audit events. |
| Database | Users, roles, merchants, shops, products, carts, checkout sessions, merchant orders, payment methods, payment proofs, status history, taxes/fees, and reports. |
| Object storage | Product images, shop brand assets, payment proof files, and administrator verification documents. |
| Payment adapters | Isolated modules for each provider so future provider APIs do not alter checkout or order logic. |

### Key data rules

1. A **checkout session** can include multiple merchant groups.
2. A **merchant order** belongs to exactly one merchant and one checkout session.
3. A **payment method** belongs to one merchant.
4. A **payment instruction snapshot** belongs to one merchant order and is immutable after order placement.
5. A **payment proof** belongs to one merchant order and is accessible only to the customer, relevant merchant, and authorized administrators.
6. A **status-history event** records who changed an order/payment state, when, and why.
7. Tax and fee calculations are saved on the order so later settings changes do not alter historical totals.

## 8. Phased Delivery Plan

| Phase | Outcome | Main work |
|---|---|---|
| **0. Product and policy sign-off** | Agreed pilot scope for Ibb. | Merchant verification rules, category exclusions, cancellation policy, support process, branding, and language requirements. |
| **1. Foundations** | Secure shared backend and role system. | Authentication, roles, merchant profiles, shop approval, database schema, file storage, and audit logging. |
| **2. Merchant operations** | Merchants can create shops and products. | Onboarding, storefront branding, catalogue/stock, fulfilment settings, and payment-settings page. |
| **3. Customer marketplace** | Customers can discover and add products to one cart. | Ibb discovery, shop/product pages, search, cart grouping, and checkout validation. |
| **4. Split checkout and payment proof** | Multi-merchant purchases work safely. | Checkout session, merchant-order generation, customer payment-information pages, proof upload, merchant payment review, and status tracking. |
| **5. Web and app polish** | Product is coherent across phone and browser. | Flutter responsive layouts, public shop links, accessibility, Arabic-first UI, and performance tuning. |
| **6. Ibb pilot** | Controlled real-world validation. | Invite a small group of verified shops, monitor support issues, collect genuine feedback, improve onboarding, and expand carefully. |
| **7. Provider integrations** | Selected wallets can become automatic. | Only after formal agreements, verified APIs, sandbox testing, reconciliation, callback security, and operational readiness. |

## 9. Pilot Success Measures

The pilot should measure product behaviour rather than pursue large scale immediately.

| Metric | What it tells us |
|---|---|
| Verified shops activated | Whether merchant onboarding is practical. |
| Shops with published products | Whether merchants can complete setup. |
| Customer-to-order conversion | Whether discovery and checkout are understandable. |
| Payment-proof approval time | Whether the manual payment process is usable. |
| Rejected payment-proof rate | Whether instructions and references are clear. |
| Orders completed by fulfilment type | Which handoff model is most realistic in Ibb. |
| Support/dispute rate | Where trust and workflow need improvement. |

## 10. Decisions Needed Before Implementation

The master plan is now clear enough to start a full functional project after the following decisions are confirmed:

| Decision | Recommended initial choice |
|---|---|
| Primary language | Arabic-first interface, with English-ready architecture. |
| Merchant visibility | Administrator approval required before public listing. |
| Minimum merchant details | Phone, shop name, Ibb area, category, owner/manager name, fulfilment instructions, and review. |
| Customer account | Phone-number authentication. |
| Payment method launch set | Jaib and Al Kuraimi as configurable manual methods, with additional methods added after verification. |
| Cart and payment model | Multi-merchant cart, merchant-specific orders, separate merchant payments. |
| Pricing | Free during pilot; no commission and no central money custody. |
| Fulfilment | Collection, digital delivery, or merchant-arranged handoff only. |

## References

[1] [Al Kuraimi Islamic Microfinance Bank — API Link Service](https://kuraimibank.com/en/services/50)

[2] [Jaib Digital Wallet — Official Website](https://e-jaib.com/ar)
