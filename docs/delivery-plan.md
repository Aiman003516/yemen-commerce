# Delivery Plan and Decision Register

## Phased delivery sequence

| Phase | Outcome | Preparation artifact |
|---|---|---|
| 0. Product and policy sign-off | Agreed Ibb pilot scope. | Product requirements, payment policy, and decision register. |
| 1. Foundations | Secure shared backend, role system, and modular configuration foundation. | Architecture, data model, API contracts, security boundaries, geography model, capability model, and policy-versioning plan. |
| 2. Merchant operations | Merchants can create approved shops and products. | Merchant requirements and design brief. |
| 3. Customer marketplace | Customers discover products and use one grouped cart. | Customer requirements, cart invariants, and UX flows. |
| 4. Split checkout and payment proof | Multi-merchant purchases work safely. | Payment workflow, snapshots, proof privacy, and state contracts. |
| 5. Web and app polish | Coherent phone and browser experience. | Arabic-first design, responsive layout, public-link, accessibility, and performance plans. |
| 6. Ibb pilot | Controlled real-world validation. | Pilot metrics, support process, feedback loop, and rollout checklist. |
| 6A. Expansion readiness | Prove that the platform can add a second market safely. | Add-market dry run, configuration-only rollout test, module-disable test, historical-order regression test, and permission-isolation review. |
| 7. Provider integrations | Selected wallets may become automatic. | Formal provider approvals, adapter contracts, sandbox evidence, reconciliation, and callback security. |

## Initial backlog themes

The first implementation backlog should be organized around modular foundations—geography and market configuration, policy versions, capability flags, module contracts, and extension testing—followed by identity and role boundaries, merchant onboarding and approval, shop and product management, customer discovery, grouped cart behavior, checkout validation, merchant-order creation, payment-information snapshots, proof submission and review, fulfilment status, administrator controls, audit history, and pilot measurement.

Each backlog item should identify its role boundary, data ownership, Arabic-facing copy needs, audit requirements, failure states, and whether it is required for the free Ibb pilot or deferred.

## Decision register

| ID | Decision | Initial baseline | Status |
|---|---|---|---|
| D-001 | Initial market | Ibb Governorate, Yemen. | Accepted from master plan. |
| D-002 | Pilot pricing | Free for customers and merchants; no subscription or commission. | Accepted from master plan. |
| D-003 | Merchant money | Merchant-owned payment accounts; no central custody or settlement. | Accepted from master plan. |
| D-004 | Cart model | One cross-merchant cart. | Accepted from master plan. |
| D-005 | Order model | One merchant-specific order per merchant group at checkout. | Accepted from master plan. |
| D-006 | Payment launch mode | Manual proof and merchant confirmation. | Accepted from master plan. |
| D-007 | Public shop visibility | Administrator approval required. | Accepted from master plan. |
| D-008 | Primary language | Arabic-first; English-ready architecture. | Accepted from master plan. |
| D-009 | Customer authentication | Phone-number authentication. | Recommended baseline; implementation sign-off pending. |
| D-010 | Initial fulfilment | Collection, digital delivery, or seller-arranged handoff. | Accepted from master plan. |
| D-011 | Provider integrations | Deferred until formal approval and technical readiness. | Accepted from master plan. |
| D-012 | Architecture extensibility | Ibb is the first enabled market; cities, regions, policies, providers, fulfilment methods, roles, languages, and optional features must be addable through modular contracts and configuration. | Required from first implementation. |

## Open decisions before executable work

The project owner must confirm merchant verification policy, category exclusions, cancellation rules, support ownership, branding, language scope, authentication details, exact provider labels, data-retention periods, hosting and storage choices, technical implementation stack, module ownership, configuration governance, and the acceptance test for adding a second Yemeni market.

## References

[1]: ../master-plan-mobile-web.md "Master Plan: Ibb Commerce Platform for Mobile and Web"
