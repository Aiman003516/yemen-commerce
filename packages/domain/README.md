# Shared Domain Placeholder

This directory reserves the future shared domain-contract boundary for market-neutral entity names, role and capability vocabularies, status contracts, validation contracts, event vocabulary, policy versions, and cross-client serialization rules.

The shared domain must express the Ibb pilot invariants while remaining extensible beyond Ibb: a configurable geography model, cross-merchant cart, one merchant-specific order per merchant group, immutable payment-instruction snapshots, merchant-scoped access, private payment proofs, auditable state changes, saved historical totals, versioned policies, and safely disableable optional capabilities. Adding a city, provider, fulfilment method, role, language, or feature must extend the shared contracts rather than create a parallel domain model.

No package manifest, generated types, executable validators, or business logic is created in the preparation stage.

See [`../../docs/data-model.md`](../../docs/data-model.md), [`../../docs/modular-expansion.md`](../../docs/modular-expansion.md), [`../../docs/api-contracts.md`](../../docs/api-contracts.md), and [`../../docs/architecture.md`](../../docs/architecture.md) before implementation.
