# Domain Data Model Outline

## Scope

This document describes the planned domain entities and relationships for later implementation. It is a design artifact only; it does not create migrations, ORM models, database tables, or seed data.

## Entity catalogue

| Entity | Purpose | Key ownership or scope |
|---|---|---|
| Market | A configured governorate, city, district, or service area. | Owns activation, eligibility, and market-specific configuration references; Ibb is the first enabled market. |
| MarketPolicyVersion | Versioned rules for pricing, fees, taxes, verification, fulfilment, visibility, and rollout. | Effective scope and dates are explicit; applied versions are snapshotted where they affect orders. |
| ModuleConfiguration | Availability and settings for optional modules and capabilities. | Scoped to platform, market, merchant, or role as appropriate. |
| User | Customer, merchant operator, or administrator account. | Identity is user-owned; role assignments are explicit. |
| RoleAssignment | Grants customer, merchant, administrator, or future support-agent context. | Must be enforced server-side and expressed through capabilities rather than screen assumptions. |
| Merchant | Merchant business identity and verification record. | Owned by the merchant account; admin approval state is separate. |
| Shop | Customer-facing storefront identity and operating details. | Belongs to one merchant, one or more configured market areas, and is public only after approval. |
| Category | Marketplace and shop classification. | Administrator-managed. |
| Product | Catalogue item with price, description, image, and stock state. | Belongs to one shop and therefore one merchant. |
| FulfilmentSetting | Collection, digital delivery, or seller-arranged handoff configuration. | Belongs to one shop or merchant order context and is enabled according to market and merchant policy. |
| PaymentMethod | Merchant-owned receiving method and customer instructions. | Belongs to one merchant; activation affects new orders only. |
| Cart | Customer's current cross-merchant basket. | Belongs to one customer; items retain merchant grouping. |
| CartItem | Product reference, quantity, and cart-time information. | Belongs to one cart and references one product. |
| CheckoutSession | Snapshot of a checkout attempt containing one or more merchant groups. | Belongs to one customer; may generate multiple merchant orders. |
| MerchantOrder | One merchant's portion of a checkout session. | Belongs to exactly one merchant and one checkout session. |
| PaymentInstructionSnapshot | Immutable receiving information and amount rules used for an order. | Belongs to exactly one merchant order. |
| PaymentClaim | Customer's transaction reference and payment submission. | Belongs to one merchant order and one customer. |
| PaymentProof | Uploaded evidence associated with a payment claim. | Accessible only to permitted actors. |
| OrderStatusHistory | Append-only state transition record. | Records actor, timestamp, prior state, new state, reason, and context. |
| Report | Customer, merchant, or administrator issue report. | Must be scoped to permitted reporters and operators. |
| AuditEvent | Security and administrative activity record. | Append-only and attributable. |
| FeatureCapability | Stable identifier for an enabled module, feature, payment method, fulfilment method, role capability, or integration. | Availability is resolved from configuration and must have a safe fallback when disabled. |

## Relationship invariants

The future schema must enforce the following rules:

| Invariant | Required meaning |
|---|---|
| Market independence | Core entities are not hard-coded to Ibb; market association is represented by stable geography identifiers and configuration. |
| Merchant ownership | A product, payment method, and shop belong to one merchant boundary. |
| Cart grouping | A cart may contain products from many merchants, but every item resolves to exactly one merchant through its product and shop. |
| Order splitting | A checkout session may generate multiple merchant orders; each merchant order has exactly one merchant. |
| Snapshot immutability | Payment instructions, taxes, fees, and order totals used for a placed order cannot be rewritten by later settings changes. |
| Proof privacy | A payment proof is visible only to the customer, relevant merchant, and authorized administrators. |
| Auditable state | Payment and order changes create status-history and audit records. |
| Public visibility | A shop and its products are publicly discoverable only when the shop is approved and active. |
| Historical activation | Disabling a payment method or optional module does not rewrite historical orders or their payment snapshots. |
| Policy versioning | Any market or merchant policy that affects an order is identified and snapshotted for historical reconstruction. |
| Extension safety | Adding or disabling a market, category, fulfilment method, provider, role, language, or optional feature does not create invalid core transaction states. |

## State vocabularies

The implementation phase should define versioned, localized enums for merchant approval, shop visibility, product availability, payment mode, provider verification, payment status, fulfilment method, fulfilment status, and order cancellation reason. User-facing Arabic labels must not be stored as the authoritative enum values.

## Data-retention questions for sign-off

Before implementation, the project owner must decide retention periods for payment proofs, verification documents, audit events, cancelled orders, and customer reports. The project must also define deletion and export behavior for customer accounts while preserving legally or operationally required historical records.

## References

[1]: ../master-plan-mobile-web.md "Master Plan: Ibb Commerce Platform for Mobile and Web"
