# Mobile Client Placeholder

This directory reserves the future Flutter mobile client boundary for Android-first delivery with iOS support designed in. It will eventually contain customer and merchant experiences, market-aware navigation, secure session handling, local state, Arabic-first localization, image selection, payment-proof selection, and responsive mobile flows.

The client must render geography, enabled modules, policies, roles, payment options, fulfilment options, and localization from versioned backend contracts. A new city or feature must not require a copied mobile application or Ibb-specific screen branch. No Flutter project, executable code, platform configuration, credentials, or business logic is created in the preparation stage. The client must call the authoritative backend and must not independently decide cart grouping, order splitting, payment state, merchant scope, or authorization.

See [`../../docs/design-brief.md`](../../docs/design-brief.md), [`../../docs/modular-expansion.md`](../../docs/modular-expansion.md), [`../../docs/product-requirements.md`](../../docs/product-requirements.md), and [`../../docs/architecture.md`](../../docs/architecture.md) before implementation.
