# Modular Expansion Architecture

## Strategic requirement

Yemen Commerce must be designed as a **modular, configuration-driven commerce platform**. Ibb is the initial pilot market and launch configuration, not a hard-coded system boundary. The same core product must be able to expand to additional cities and regions in Yemen, and later to new capabilities, without rewriting the marketplace, cart, order, payment, authorization, or administration foundations.

This requirement extends the shared master plan. The initial Ibb scope, free pilot, merchant-owned payment accounts, and merchant-specific order splitting remain unchanged. [1]

## Modularity principles

| Principle | Required design consequence |
|---|---|
| Geography is configuration | City, governorate, service area, availability, and local operating rules are data or configuration, not scattered constants in client and server code. |
| Core commerce is location-agnostic | Catalogue, cart, checkout session, merchant order, payment snapshot, proof review, and fulfilment states work regardless of the selected city. |
| Features are bounded modules | Discovery, merchant onboarding, catalogues, cart, split checkout, manual payment, fulfilment, reports, and administration have explicit interfaces and can evolve independently. |
| Providers are adapters | Jaib, Al Kuraimi, future wallets, banks, and approved APIs are isolated behind a payment-provider contract. Provider-specific code must not leak into core order logic. |
| Policies are configurable | Fees, taxes, categories, merchant verification requirements, fulfilment options, payment proof rules, and visibility rules are policy data with versioned effective dates where needed. |
| Roles are capability-based | Customer, merchant, administrator, future support agent, and future operational roles receive capabilities through authorization policy rather than hard-coded screen assumptions. |
| Clients share contracts | Mobile, web, and administrator interfaces consume the same versioned API and domain contracts. |
| Historical records are immutable | Orders, payment snapshots, totals, status history, and audit records preserve the configuration and policy used at the time of the transaction. |
| New modules fail safely | A disabled or unavailable optional module must not corrupt existing cart, order, payment, or fulfilment workflows. |

## Expansion dimensions

| Expansion target | Ibb launch configuration | Future extension path |
|---|---|---|
| Geography | Ibb Governorate and selected Ibb areas. | Add Yemen governorates, cities, districts, and service areas as managed records with activation and eligibility rules. |
| Shops | Approved Ibb merchants. | Add merchants in new areas without changing merchant-order ownership or permissions. |
| Categories | Administrator-managed pilot categories. | Add or retire categories through configuration and moderation policy. |
| Payment methods | Manual merchant-owned Jaib and Al Kuraimi labels, subject to verification. | Add other manual methods or approved provider adapters without changing checkout splitting. |
| Fulfilment | Collection, digital delivery, and seller-arranged handoff. | Add regional or merchant-specific fulfilment modules with explicit order-state contracts. |
| Languages | Arabic-first with English-ready architecture. | Add additional translations without changing domain values or business rules. |
| Roles | Customer, merchant, administrator. | Add support and operations roles through capability policies and audited scopes. |
| Commercial model | Free pilot, no commission or subscription. | Add versioned commercial policies later without rewriting order calculations. |
| Notifications | Later-phase capability. | Add SMS, push, email, or in-app notification adapters behind event contracts. |
| Reporting | Pilot success measures and administrative reports. | Add city, category, merchant, provider, and fulfilment analytics without altering transaction records. |

## Recommended module boundaries

The future implementation should separate the following modules behind stable contracts:

1. **Geography and market configuration.** Owns governorates, cities, districts, service areas, activation state, and market-specific settings.
2. **Identity and access.** Owns authentication, role context, capabilities, merchant scope, and administrator scope.
3. **Merchant and shop operations.** Owns onboarding, verification, shop approval, branding, operating details, and shop visibility.
4. **Catalogue and discovery.** Owns categories, products, search, collections, and public shop or product links.
5. **Cart and checkout.** Owns cross-merchant grouping, independent validation, checkout sessions, and order creation. It must not own provider-specific transfer logic.
6. **Orders and fulfilment.** Owns merchant-order lifecycle, fulfilment methods, status transitions, and completion records.
7. **Payments.** Owns payment methods, immutable instruction snapshots, payment claims, proof metadata, and review state. Provider adapters implement external behavior behind this module.
8. **Administration and moderation.** Owns approvals, category management, reports, provider activation, moderation, and audit inspection.
9. **Files and media.** Owns secure storage references, access control, upload policy, and retention metadata.
10. **Notifications and events.** Future module for user-facing notifications and operational events; it must be optional and asynchronous where practical.
11. **Analytics and reporting.** Reads authorized events and historical records without becoming the source of truth for transactions.

## Extension contracts

The implementation phase should define versioned contracts for geography eligibility, merchant verification policy, payment-provider adapters, fulfilment adapters, notification adapters, role capabilities, fee and tax policies, and marketplace discovery filters. A module should expose its inputs, outputs, state transitions, error categories, authorization requirements, and audit events.

A new city should require adding geography records, enabling relevant categories and policies, selecting available fulfilment and payment methods, and onboarding approved merchants. It should not require copying a city-specific codebase, changing the core cart algorithm, or introducing a city-specific order type.

## Configuration and feature flags

Configuration must distinguish between platform defaults, market or city settings, merchant settings, and order-time snapshots. Feature flags may control rollout of optional modules, but must not be used to hide data-integrity rules. All flags that affect customer-visible pricing, payment methods, fulfilment, or eligibility must be auditable and have an explicit owner.

## Modularity acceptance criteria

The future implementation is not ready for expansion unless it can demonstrate that:

| Test | Expected result |
|---|---|
| Add a second city | New city becomes selectable and can onboard merchants without changing core commerce code. |
| Disable a city | New discovery and onboarding stop for that city while historical orders remain readable. |
| Add a payment method | Method appears only where enabled and does not alter merchant-order splitting or existing snapshots. |
| Add a fulfilment method | The new method has explicit validation and status behavior without changing existing methods. |
| Add a role | New role receives scoped capabilities without broadening merchant data access. |
| Add a language | UI labels change through localization resources while domain states remain stable. |
| Disable an optional module | Core browsing, cart, order, and manual-payment workflows remain consistent and safe. |

## References

[1]: ../master-plan-mobile-web.md "Master Plan: Ibb Commerce Platform for Mobile and Web"
