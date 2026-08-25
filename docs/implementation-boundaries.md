# Implementation Boundaries

## Preparation-only scope

The current project package is limited to project organization, product requirements, design guidance, payment policy, architecture boundaries, modular-expansion contracts, domain contracts, delivery planning, and decision records. It may include placeholder README files that explain future ownership, but it must not contain executable business logic.

## Explicitly deferred until implementation approval

| Area | Deferred work |
|---|---|
| Client applications | Flutter project initialization, routing, screens, widgets, state management, localization files, market-aware configuration handling, and platform configuration. |
| Web experience | Responsive layouts, public links, merchant browser views, and administrator console implementation. |
| Backend | API server, authentication, role middleware, merchant scoping, checkout service, order service, payment review service, and report handling. |
| Database | Migrations, ORM schema, indexes, constraints, seed data, and transaction code. |
| Storage | Buckets, access policies, signed URLs, upload processing, and retention jobs. |
| Payments | Provider credentials, live integrations, callbacks, reconciliation, or automatic payment status updates. |
| Security | Production secrets, deployment credentials, infrastructure policies, and penetration testing configuration. |
| Testing | Executable unit, integration, end-to-end, device, accessibility, and performance tests. |

## Modularity gate

The first implementation must establish geography and market configuration, policy versioning, capability and feature configuration, stable module contracts, safe optional-module fallbacks, and extension tests as foundational concerns. Ibb may be the only enabled market at launch, but the code and data model must not assume that Ibb is the only possible market.

## Required approval gates

Implementation should begin only after product and policy sign-off confirms merchant verification rules, category exclusions, cancellation policy, support process, branding, language requirements, and the free-pilot payment posture. The technical design must then confirm the shared client approach, backend and database choices, storage access model, authentication provider, environments, audit requirements, module ownership, configuration governance, and the acceptance test for adding a second Yemeni city without a parallel code path.

## Definition of ready for implementation

The project is ready to implement when the owner has approved the product requirements, design brief, payment policy, architecture boundaries, modular-expansion document, data model, API contracts, and initial delivery backlog; has named decision owners; and has accepted the explicit pilot guardrails and expansion requirement in the project README.

## References

[1]: ../master-plan-mobile-web.md "Master Plan: Ibb Commerce Platform for Mobile and Web"
