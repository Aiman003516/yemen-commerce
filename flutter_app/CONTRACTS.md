# Shared Contract Subset

The Flutter application mirrors the serialized `v1` values defined in `shared/domain.ts`. The server remains authoritative for all pricing, authorization, merchant ownership, stock validation, checkout splitting, payment transitions, fulfilment transitions, and audit history.

| Contract area | Shared status | Flutter use in this increment |
|---|---|---|
| Market configuration | Implemented | Reads `market.active` to identify the active market; Ibb is the first configured pilot. |
| Product discovery | Implemented | Reads approved products through `catalog.products`; the UI renders a real empty state until approved catalogue data exists. |
| Roles and states | Mirrored | Customer, merchant, administrator; manual-payment and fulfilment state vocabularies are declared for future UI flows. |
| Cart, merchant orders, proofs | Server contract defined | Flutter models will be expanded when authenticated customer flows are connected. |
| Policies and capabilities | Server contract defined | Flutter can surface safe availability states in later role-specific screens. |

Native Android and iOS builds must provide `API_BASE_URL` through `--dart-define`. Flutter Web uses the browser origin by default and therefore consumes the same versioned server endpoints as the responsive web application.
