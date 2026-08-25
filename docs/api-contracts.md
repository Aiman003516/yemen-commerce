# API and Domain Contract Outline

## Purpose

This file defines the future API surface at a planning level. It is intentionally not an OpenAPI document and contains no executable handlers. The implementation phase should convert these contracts into versioned schemas after product and policy sign-off.

## Resource groups

| Resource group | Planned capabilities |
|---|---|
| Geography and market configuration | Active governorates, cities, districts, service areas, rollout state, and market-specific settings. |
| Policy and capabilities | Versioned eligibility, fees, taxes, verification, fulfilment, localization, feature flags, and role capabilities. |
| Identity | Phone-number authentication, session management, role context, and account recovery. |
| Public marketplace | Approved shop discovery, categories, search, shop profiles, product catalogue, and public links. |
| Merchant operations | Onboarding, shop profile, branding, products, stock, fulfilment settings, and operating details. |
| Payment methods | Merchant-owned methods, receiving details, customer instructions, proof requirements, activation, and provider-verification state. |
| Cart and checkout | Cart items, merchant grouping, validation, checkout session creation, and merchant-order generation. |
| Merchant orders | Merchant-scoped order details, status transitions, fulfilment updates, and order history. |
| Customer payments | Payment-information page, transaction reference, proof submission, payment timeline, and report action. |
| Administration | Merchant verification, shop approval, moderation, categories, reports, provider controls, and audit inspection. |
| Audit | Append-only state-change events with actor, timestamp, reason, and affected resource. |

## Core contract rules

1. A cart response must identify the merchant for every item and expose grouping information suitable for a multi-merchant summary.
2. Checkout must validate each merchant group independently for stock, availability, minimum order value, fulfilment instructions, and merchant configuration.
3. A successful checkout creates one checkout session and one merchant-specific order per merchant group.
4. Each merchant order receives its own total, payment-instruction snapshot, payment status, proof collection, and fulfilment status.
5. Payment-instruction snapshots and order-calculation values are immutable historical records.
6. Merchant-facing queries must be scoped to the authenticated merchant and must not return another merchant's products, customers, orders, payment details, or proofs.
7. Payment proofs must be accessible only to the submitting customer, relevant merchant, and authorized administrators.
8. Status-changing commands must enforce allowed transitions and append a status-history event.
9. A proof upload must never directly transition an order to Paid.
10. Provider API modes must remain disabled unless the provider, credentials, security controls, sandbox tests, reconciliation, and operational approvals are complete.
11. Geography and market settings must be represented by stable identifiers and configuration references; clients must not hard-code Ibb or infer market rules from display names.
12. Optional modules must expose explicit capability and availability contracts, and an unavailable module must return a safe, documented fallback rather than corrupting core commerce state.
13. Adding a city, category, payment method, fulfilment method, language, or role must extend a contract or configuration set instead of creating a parallel core workflow.

## Planned command and query names

| Area | Planned command or query | Expected result |
|---|---|---|
| Cart | `getCart` | Cart with merchant groups and current validation context. |
| Cart | `addCartItem`, `updateCartItem`, `removeCartItem` | Updated cart; only the relevant merchant group changes. |
| Checkout | `validateCheckout` | Per-merchant validation results before order creation. |
| Checkout | `createCheckoutSession` | Session plus one merchant order per valid merchant group. |
| Payment | `getMerchantOrderPaymentInfo` | Immutable payment snapshot and current timeline. |
| Payment | `submitPaymentClaim` | Reference and proof metadata recorded; status becomes under review. |
| Merchant | `reviewPaymentClaim` | Accepted or rejected result with actor and reason. |
| Fulfilment | `updateFulfilmentStatus` | Merchant-scoped fulfilment transition with audit record. |
| Administration | `approveMerchantShop`, `moderateContent`, `setProviderState` | Audited administrative decision. |
| Geography | `listMarkets`, `getMarketConfiguration`, `setMarketActivation` | Market-aware discovery and audited rollout control. |
| Policy | `getEffectivePolicy`, `setPolicyVersion` | Versioned policy selection for a market or merchant scope. |
| Capabilities | `getAvailableCapabilities` | Enabled modules and supported options for the current role and market. |

## Error contract categories

Future API responses should distinguish authentication failure, authorization failure, invalid merchant scope, unavailable product, insufficient stock, invalid fulfilment selection, changed price or configuration, disabled payment method, proof-upload failure, invalid status transition, and policy-restricted action. Error messages shown to customers must be clear in Arabic and safe to expose.

## Versioning and compatibility

The API should use explicit versioning and stable resource identifiers. Client applications must not infer business rules from display strings. Status values, role values, payment modes, and fulfilment modes should be represented as documented contracts that can be localized independently. Geography identifiers, module identifiers, policy versions, feature states, and provider adapter identifiers must also remain stable across clients and releases.

## References

[1]: ../master-plan-mobile-web.md "Master Plan: Ibb Commerce Platform for Mobile and Web"
