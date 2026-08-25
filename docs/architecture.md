# Architecture Decision Record

## Decision summary

Yemen Commerce should use one authoritative backend API and database for the Flutter mobile client, responsive web client, and administrator console. Flutter is the preferred shared client foundation where practical, while the backend remains the single source of business rules. [1]

This document defines boundaries and invariants only. It does not select concrete packages, create services, generate migrations, configure environments, or implement endpoints.

## Modularity and expansion posture

Ibb is the initial market configuration, not a hard-coded architecture boundary. Geography, market activation, service areas, categories, fulfilment availability, payment-method availability, commercial policies, and localization must be represented through modular configuration with clear ownership and auditability. The core commerce modules must operate independently of the selected city or governorate so that additional Yemeni cities can be added without copying the application or rewriting cart, order, payment, or authorization logic.

Optional capabilities such as notifications, future provider APIs, additional fulfilment methods, support operations, and advanced reporting must be isolated behind explicit contracts. Disabling an optional module must not invalidate historical orders or compromise the core browsing, cart, merchant-order, manual-payment, or fulfilment workflows. See [`modular-expansion.md`](modular-expansion.md) for the extension matrix and acceptance criteria.

## Logical boundaries

| Boundary | Future responsibility | Explicit non-responsibility |
|---|---|---|
| `apps/mobile` | Flutter Android-first experience with iOS support designed in; customer and merchant flows; local state; secure session handling; image and proof selection. | Does not own authoritative cart, order, payment, or permission rules. |
| `apps/web` | Responsive customer marketplace, public shop/product links, merchant browser access, and administrator console. | Does not duplicate backend business rules. |
| `services/api` | Authentication, role enforcement, cart validation, checkout splitting, orders, payment states, product data, settings, reports, and audit events. | Does not custody merchant funds or act as a payment processor. |
| `packages/domain` | Shared names, states, validation contracts, and event vocabulary used by clients and API. | Does not contain UI or provider credentials. |
| `infra` | Future environment, database, object storage, deployment, monitoring, backup, and secret-management documentation. | No production infrastructure is created in this preparation step. |
| Object storage | Product images, shop logos, payment proofs, and administrative verification documents. | Files are not public by default; access must be authorized. |
| Payment adapters | Isolated future provider modules. | Provider-specific behavior must not alter core checkout or order-splitting logic. |
| Geography and market configuration | Governorates, cities, districts, service areas, activation state, and market-specific policy references. Ibb is the initial configuration. | No city-specific code paths or copied applications. |
| Policy and capability modules | Versioned fees, taxes, eligibility, verification, fulfilment, localization, feature flags, and role capabilities. | No hidden policy embedded only in a client screen. |
| Optional integrations | Notifications, future fulfilment services, analytics, and support tooling behind contracts. | Optional modules must fail safely when disabled. |

## Authoritative data model concepts

The future data model must represent users, roles, merchants, shops, products, carts, checkout sessions, merchant orders, payment methods, payment-instruction snapshots, payment proofs, status history, taxes and fees, and reports. [1]

The most important relationships are:

| Concept | Required relationship or invariant |
|---|---|
| Checkout session | May include multiple merchant groups. |
| Merchant order | Belongs to exactly one merchant and one checkout session. |
| Payment method | Belongs to one merchant. |
| Payment-instruction snapshot | Belongs to one merchant order and is immutable after placement. |
| Payment proof | Belongs to one merchant order and is visible only to the customer, relevant merchant, and authorized administrators. |
| Status-history event | Records who changed a state, when, and why. |
| Tax and fee values | Saved on the order so later settings changes do not alter historical totals. |

## Order-splitting invariant

The system must model a customer cart and the resulting merchant orders as distinct concepts. Adding products from several merchants does not create a single merchant-owned order. Checkout creates one checkout session, validates each merchant group independently, and emits one merchant order per group. Payment and fulfilment status then proceed independently for each merchant order.

## Security boundaries

Authentication, role enforcement, merchant scoping, object-storage access, payment-proof authorization, immutable snapshots, status-transition authorization, and audit logging must be enforced by the backend. Client-side visibility is not a security boundary.

A merchant request must be scoped to the authenticated merchant identity. Administrator access must be explicit and auditable. Payment proof URLs must not be guessable or permanently public. Provider credentials, storage credentials, signing keys, and environment secrets must not be committed to the project files.

## Integration posture

Payment providers are represented behind isolated adapters. Manual payment is the only launch mode. An automatic adapter requires formal provider approval, official API documentation, merchant credentials, settlement and reconciliation design, callback security, sandbox testing, and operational readiness before activation. [1]

## Architecture decisions still requiring sign-off

The implementation design must explicitly document geography configuration, module contracts, feature-flag ownership, policy versioning, and extension-test coverage before executable development begins.


| Decision | Baseline for later implementation | Owner or approval needed |
|---|---|---|
| Client framework | Flutter shared foundation where practical. | Technical owner. |
| Backend runtime and API style | To be selected during implementation planning. | Technical owner. |
| Database engine | To be selected with transaction and audit requirements in mind. | Technical owner. |
| Authentication provider | Phone-number authentication is the product baseline. | Product and security owner. |
| Storage provider | Secure object storage. | Technical and operations owner. |
| Notification strategy | Later phase; not required for this preparation package. | Product owner. |
| Production hosting | To be selected after environment and support requirements are approved. | Technical and operations owner. |

## References

[1]: ../master-plan-mobile-web.md "Master Plan: Ibb Commerce Platform for Mobile and Web"
