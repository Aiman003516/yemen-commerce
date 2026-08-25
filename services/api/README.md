# Backend API Placeholder

This directory reserves the future authoritative backend API boundary. It will eventually own modular authentication and capability enforcement, geography and market configuration, merchant scoping, product and shop data, cart validation, checkout-session creation, merchant-order splitting, payment-instruction snapshots, payment-proof workflows, fulfilment states, reports, and audit events.

The service must treat Ibb as the first market configuration, not as a hard-coded branch. City, region, policy, capability, fulfilment, payment-method, notification, and reporting extensions must be represented through stable contracts and configuration. The service must not custody or settle merchant funds. Payment-provider adapters must remain isolated from core order logic and must be disabled until formally approved. All merchant, payment-proof, status-transition, market, and administrator boundaries must be enforced server-side.

No runtime, handlers, migrations, environment files, secrets, provider callbacks, or executable business logic is created in the preparation stage.

See [`../../docs/architecture.md`](../../docs/architecture.md), [`../../docs/modular-expansion.md`](../../docs/modular-expansion.md), [`../../docs/data-model.md`](../../docs/data-model.md), [`../../docs/api-contracts.md`](../../docs/api-contracts.md), and [`../../docs/payment-policy.md`](../../docs/payment-policy.md) before implementation.
