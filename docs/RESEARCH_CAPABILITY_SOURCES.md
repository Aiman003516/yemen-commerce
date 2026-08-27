# Large Feature Expansion Research Notes

## Research scope

This working note records source-backed capability findings for the large ERP/composable-commerce expansion. It is not the final report; it preserves URLs and observations as research proceeds.

## Official platform findings

### Shopify Enterprise
Source: https://www.shopify.com/enterprise

The official enterprise page positions Shopify as an enterprise commerce platform with B2C, retail, and B2B solution areas; it links to Shopify APIs and developer documentation, Shop Pay, Shopify Plus, and Shopify Fulfillment Network. The page also references enterprise migration, conversion, total-cost, and AI-commerce positioning claims. For Yemen Commerce, the relevant transferable patterns are a modular commerce capability surface, a strong API/developer boundary, B2B and retail/POS variants, fulfillment as a separable capability, and AI as an assisted commerce layer rather than an unrestricted mutation engine. Any performance claims require primary study-level verification before inclusion in a quantitative report.

### Odoo application suite
Source: https://www.odoo.com/page/all-apps

Odoo’s official application catalog groups functionality into Website, Sales, Finance, Inventory & Manufacturing, Human Resources, Marketing, Services, Productivity, and Customization. It describes an integrated suite covering CRM, eCommerce, accounting, inventory, point of sale, and project management. For Yemen Commerce, the relevant transferable pattern is a broad integrated module catalog with a shared operational data model, while the safe implementation choice remains logical modules and narrow RPCs inside Supabase rather than exposing direct table access or importing an entire monolith.

## AI-for-ERP findings

### Microsoft Dynamics 365 Finance and Operations Copilot
Source: https://learn.microsoft.com/en-us/dynamics365/fin-ops-core/fin-ops/copilot/copilot-for-finance-operations

Microsoft documents three presentation patterns: sidecar conversational assistance, embedded AI inside a workflow, and outside agents that orchestrate across applications. The catalog includes generative help, workflow-history summaries, chat over authorized finance/operations data, ERP MCP access, customer/product/store insights, collections summaries, account reconciliation assistance, project/time-entry help, demand and warehouse insights, supplier communications, and agent management. The transferable design is to make AI capabilities contextual and role-scoped, with read/insight modes separated from mutation workflows. Yemen Commerce should use its existing fixed tool allowlist, creator governance, merchant confirmation, provenance, quotas, and no arbitrary SQL/RPC/URL rules as the stronger safety boundary.

### Oracle AI for ERP
Source: https://www.oracle.com/erp/ai-financials/

Oracle’s official catalog describes embedded predictive, generative, and agentic capabilities across transaction processing, accounting, planning, forecasting, reporting, payables, ledger, payments, expenses, cash processing, account reconciliation, profitability/cost management, and access-risk certification. Several patterns are especially relevant: invoice ingestion/extraction and PO/receipt matching as a draft-and-review process; ledger inquiry and adjustment-journal assistance; what-if planning; cash/remittance matching; continuous reconciliation; and access-certification recommendations with human rationale. Yemen Commerce should implement these as private evidence/extraction drafts, explainable proposals, approval queues, and immutable/reversal-based accounting—not as autonomous settlement, payment execution, or automatic ledger mutation.

## Supply-chain and logistics findings

### SAP Supply Chain Management
Source: https://www.sap.com/products/scm.html

SAP presents supply-chain orchestration across planning, procurement, product lifecycle, manufacturing, logistics, enterprise asset management, business network, and sustainability. Its current positioning emphasizes AI assistants, end-to-end visibility, disruption awareness, demand shifts, recommendations, and workflow automation. For Yemen Commerce, the practical near-term translation is a modular operations cockpit: inventory and demand projections, procurement suggestions, delivery exception queues, asset/maintenance records, and human-approved operational actions. Autonomous adjustments remain out of scope until there are measured data quality, approval, and worker controls.

### Oracle Supply Chain and Manufacturing
Source: https://www.oracle.com/scm/

Oracle’s official SCM catalog covers product lifecycle, supply-chain planning, procurement, supply-chain execution, order management, logistics, warehouse management, transportation management, and global trade management. The page emphasizes perfect-order fulfillment, freight-cost/service optimization, shipment risk, logistics execution, and AI-assisted planning. For Yemen Commerce, useful additions include bounded warehouse tasking, shipment and delivery exception states, carrier-neutral rate/ETA projections, route-planning drafts, and auditable handoff events. External carrier/routing calls should remain provider-gated and should never alter payment state or custody funds.

## Yemen-market findings

### Sana’a Center policy research: Fostering Opportunities for E-Commerce Growth in Yemen
Source: https://sanaacenter.org/publications/policy-research/25516

The policy research identifies strong potential for e-commerce to support growth and financial inclusion, particularly for women and rural communities, while highlighting poor internet connectivity, limited digital payment systems, weak legal/regulatory frameworks, a cash-heavy economy, fraud exposure, and transportation-network damage. Its recommendations emphasize infrastructure, cohesive oversight, digital literacy, cybersecurity, and collaboration to incentivize safer digital payments. The product implications are offline-tolerant workflows, merchant-owned/manual payment rails, private evidence, fraud/trust tooling, rural/service-area support, low-bandwidth UI, and explicit education and status explanations.

### Academic study: Unlocking the Potential of E-Commerce in Yemen
Source: https://www.mdpi.com/2071-1050/15/18/13712

The study’s abstract identifies economic and political instability, logistical challenges, and lack of trust in online payments as the most significant factors affecting Yemen’s e-commerce ecosystem. It recommends strategic partnerships, secure payment and delivery options, and targeting underserved markets. These findings support prioritizing trust-and-proof workflows, merchant-controlled payment confirmation, delivery/returns visibility, service-area and pickup design, and partnerships/adapters rather than assuming a card-first or centralized-custody model.

## Yemen payment and local-service findings

### Jaib Digital Wallet
Source: https://apps.apple.com/us/app/jaib-digital-wallet/id6472856710

The public App Store description says Jaib supports wallet-based purchase payments, transfers between subscribers and between the user’s own currency accounts, bill payment, mobile-balance recharge, cash withdrawal through agents/service points, QR or point-of-sale-number purchase payment, and transaction statements. The listing identifies AHD Financial as the developer. It does not provide a public developer API, webhook, SDK, sandbox, settlement specification, or automated verification contract. The safe product implication is a provider-neutral manual/QR/POS payment method with merchant review of references; any future provider adapter must wait for documented credentials, callbacks, reconciliation, refunds, and compliance approval.

### Yemen Mobile
Source: https://yemenmobile.com.ye/en

Yemen Mobile’s official site presents consumer and company services, prepaid/postpaid offerings, 3G/4G connectivity, agent centers, and a “Riyal Mobile” service area. The site also links financial statements, agents, tenders, and service sections. This supports a future local-services marketplace and merchant recharge/bill-pay adapter concept, but it does not by itself establish an e-commerce API or payment settlement integration. Such capabilities should be modeled as catalog/service-order flows with provider-gated fulfillment, not as platform-held funds.

## Interoperability standards

### CloudEvents
Source: https://cloudevents.io/

CloudEvents is a specification for describing event data in a common way across services and platforms. The project emphasizes consistency, accessibility, and portability; the site also references HTTP/JSON bindings, SDKs, and adoption by eventing platforms. Yemen Commerce can align its existing versioned outbox envelope with the conceptual CloudEvents fields (stable event identity, type, source, subject, time, content type, schema/version, and correlation/idempotency metadata) without introducing a broker prematurely.

### OpenAPI Specification 3.2
Source: https://swagger.io/specification/v3.2/

OpenAPI defines a standard, language-agnostic interface for HTTP APIs so humans and computers can discover and understand service capabilities, and so documentation, client generation, and testing tools can consume the description. The expansion should maintain a machine-readable module contract catalog for future Edge Functions and integrations, while keeping public RPCs narrow and preventing arbitrary SQL/RPC passthrough from Flutter or AI tools.

## Composable commerce comparison

### commercetools Sphere
Source: https://commercetools.com/commerce-platform

commercetools describes an API-native architecture in which every commerce capability is exposed as an independent, versioned API. Its positioning also groups headless, autonomous, agentic, and unified commerce. The transferable lesson is that independent versioned contracts matter more than physical microservices at the start. Yemen Commerce should keep Supabase/RPC as the authority while making module contracts explicit, versioning event schemas, and using typed Flutter adapters and bounded Edge Functions.

### BigCommerce Multi-Storefront
Source: https://www.bigcommerce.com/solutions/multi-store/

BigCommerce documents a single dashboard for multiple storefronts, unique categories, product availability by storefront, customer/order management, and unified analytics. It also describes duplication from a base storefront while customizing brand, products, and pricing. The Yemen Commerce opportunity is a creator-governed multi-storefront/brand workspace with market-specific catalogs, pricing, delivery options, themes, and analytics, while retaining merchant ownership boundaries and avoiding cross-merchant data leakage.
