# Web Client Placeholder

This directory reserves the future responsive web client boundary. It will eventually support public shop and product links, customer browsing and checkout, merchant browser access, and an administrator-specific console for market operations beginning in Ibb.

The web client must use the same authoritative backend and domain contracts as the mobile client. It must render active markets, enabled modules, policies, roles, payment options, fulfilment options, and localization from those contracts. Adding a city, feature, role, or integration must not require copied web routes or Ibb-specific business logic. It must preserve the grouped cross-merchant cart, merchant-specific orders, separate payment-information pages, manual payment-proof review, administrator approval, and Arabic-first direction.

No web framework, executable code, deployment configuration, public routes, or business logic is created in the preparation stage.

See [`../../docs/design-brief.md`](../../docs/design-brief.md), [`../../docs/modular-expansion.md`](../../docs/modular-expansion.md), [`../../docs/api-contracts.md`](../../docs/api-contracts.md), and [`../../docs/architecture.md`](../../docs/architecture.md) before implementation.
