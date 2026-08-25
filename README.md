# Yemen Commerce Project

## Status

This directory is the **documentation-first preparation package** for the Yemen Commerce Project. It translates the shared master plan into an implementation-ready structure without adding application logic, database migrations, API handlers, UI screens, infrastructure deployment, or provider integrations.

The governing source is [`Master Plan_ Ibb Commerce Platform for Mobile and Web.md`](master-plan-mobile-web.md). That document must be read before making product, design, payment, architecture, or implementation decisions.

## Non-negotiable pilot guardrails

| Area | Initial decision |
|---|---|
| Market | Ibb Governorate, Yemen for the initial pilot; geography must remain extensible. |
| Commercial model | Free for customers and merchants during the pilot; no subscription or commission. |
| Money custody | The platform does not hold, settle, or centrally custody merchant money. |
| Payment ownership | Merchants use their own local payment accounts and provide the receiving details. |
| Cart model | One customer cart may contain items from multiple merchants. |
| Checkout model | Checkout splits into one merchant-specific order per merchant group. |
| Payment model | Each merchant order has its own total, payment instructions, proof, review, and fulfilment status. |
| Fulfilment | Customer collection, digital delivery, or seller-arranged handoff only in the MVP. |
| Public visibility | Administrator approval is required before a shop becomes public. |
| Language direction | Arabic-first, with an English-ready architecture. |
| Modularity | Ibb is a configuration, not a hard-coded boundary; cities, regions, policies, providers, fulfilment methods, roles, and optional features must be addable through modular contracts. |

## Modularity requirement

The complete app and system must be organized as modular, configuration-driven components. Geography, city activation, service areas, categories, merchant eligibility, payment methods, fulfilment options, role capabilities, localization, pricing policies, notifications, and reporting must be extendable without copying the application or rewriting the core marketplace, cart, split-checkout, order, payment-review, or authorization foundations. The Ibb pilot is the first enabled market configuration; future Yemeni cities must be addable through approved configuration and isolated modules.

See [`docs/modular-expansion.md`](docs/modular-expansion.md) for the extension matrix, module boundaries, and acceptance criteria.

## Prepared structure

| Path | Purpose | Current state |
|---|---|---|
| `docs/` | Product, design, payment, architecture, policy, API, and delivery documentation. | Documentation and decision records only. |
| `apps/mobile/` | Future Flutter mobile client boundary. | Placeholder README only. |
| `apps/web/` | Future responsive web client and administrator console boundary. | Placeholder README only. |
| `services/api/` | Future authoritative backend API boundary. | Placeholder README only. |
| `packages/domain/` | Future shared domain contracts and business-rule boundary. | Placeholder README only. |
| `infra/` | Future storage, environments, deployment, and observability boundary. | Placeholder README only. |
| `tests/` | Future test-plan and test-suite boundary. | Placeholder README only. |

## Deliberately not implemented

The preparation package does not contain executable application code. It does not create authentication, role enforcement, product management, cart behavior, order splitting, payment-proof upload, payment-provider APIs, database schemas, storage buckets, notifications, deployment configuration, or production secrets.

## Planned delivery phases

The documentation follows the master plan's sequence: product and policy sign-off; secure foundations; merchant operations; customer marketplace; split checkout and payment proof; web and app polish; controlled Ibb pilot; and only later, formally approved provider integrations.

## References

[1]: master-plan-mobile-web.md "Master Plan: Ibb Commerce Platform for Mobile and Web"
