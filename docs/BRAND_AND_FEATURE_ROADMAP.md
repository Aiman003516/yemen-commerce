# Brand and Feature Roadmap for the Yemen Commerce OS

## Executive recommendation

Do not replace the current `yemen-commerce` working identity with another common Arabic noun. **SILA/صلة** and **BUNYAN/بنيان** were rejected because the words are already strongly associated with active commerce, technology, payments, or Yemeni organizations. The next master brand should be a **coined, pronounceable, legally screenable word** supported by descriptive product names such as `Market`, `Merchant`, and `Console`.

The product should compete on an operating model designed for Yemen rather than on a generic list of storefront features. Recent Yemen-focused research identifies weak connectivity, limited digital-payment adoption, cash dependence, disrupted transport, fraud risk, and incomplete regulation as central constraints. It also points to strategic partnerships, secure payment and delivery options, cybersecurity, digital literacy, and service to underserved markets as high-value responses [1] [2].

## Part I — Brand strategy

### 1. The recommended naming architecture

Use three layers:

| Layer | Recommendation | Example pattern |
|---|---|---|
| Master brand | A coined, distinctive, short word with an Arabic spelling that is easy to read in RTL | `NewWord` / `كلمة مبتكرة` |
| Product descriptors | Descriptive and stable, not trademark-dependent | `NewWord Market`, `NewWord Merchant`, `NewWord Console` |
| Positioning line | Explain the value without putting “Yemen” into the master brand | “Commerce infrastructure built for local trade” |

This keeps the master brand exportable while allowing the product to communicate its Yemen-first design. The master brand should not imply that the company is a bank, wallet, courier, marketplace-only business, or lender, because the system intentionally keeps merchant funds outside platform custody.

### 2. Naming rules

A candidate should pass all of the following before it enters the codebase:

| Test | Passing condition |
|---|---|
| Distinctiveness | Not an ordinary Arabic noun or a widely used business word. |
| Arabic/Latin parity | One obvious Arabic spelling and one obvious Latin spelling; no confusing Bunyan/Bonyan-style variants. |
| Pronunciation | Two or three syllables, easy to say in Yemen and in export markets. |
| Searchability | The first page of search results is not dominated by unrelated businesses, charities, banks, POS products, or marketplaces. |
| Category separation | No close conflict in ecommerce, POS, ERP, payments, logistics, SaaS, or merchant services. |
| Domain and handles | A practical `.com` or country-domain strategy, plus consistent app-store and social handles. |
| Linguistic safety | No unintended meaning, slang, political, sectarian, religious, or negative association in Yemeni dialects. |
| Legal screenability | WIPO, Yemeni records, target-market records, company names, app stores, and domains are checked by counsel before launch. |

### 3. Name-generation strategies

**Strategy A: coined Arabic-friendly word.** Combine a short commerce concept with a non-descriptive ending, then normalize the result into one Arabic spelling. This is the strongest strategy for distinctiveness. Avoid simply joining common nouns such as “market,” “connection,” “foundation,” or “growth.”

**Strategy B: Arabic root plus invented suffix.** Start with a value such as support, flow, trust, route, or growth, and add a deliberately invented suffix. The root gives emotional meaning while the suffix improves searchability. The resulting word must still be reviewed by a native Yemeni Arabic speaker because a small spelling change can create a different word or dialect meaning.

**Strategy C: neutral invented international word with an Arabic rendering.** Build a short Latin-first word that can be written naturally in Arabic. This gives the best export flexibility, but it needs stronger Arabic brand testing so it does not feel foreign or difficult for merchants.

**Strategy D: descriptive category plus a distinctive master brand.** Keep the master brand coined and use product descriptors for clarity: `X Market`, `X Merchant`, `X POS`, `X Console`, or `X Business`. Do not make the master brand itself a generic category term.

### 4. Unvetted seed concepts for a naming workshop

The following are **creative seeds only, not availability recommendations**. They have not been cleared for trademarks, domains, app stores, social handles, or local language associations.

| Seed | Arabic rendering | Intended signal | Risk to investigate |
|---|---|---|---|
| **Yamora** | يامورا | Yemen-rooted warmth with international pronunciation | May be confused with personal names or unrelated international brands. |
| **Mawjra** | موجرا | Movement and flow through commerce | Arabic spelling and pronunciation need native-speaker testing. |
| **Sooqara** | سوقارا | A market concept with an invented ending | Retains the generic “souq” root and may be crowded. |
| **Rafda** | رفدا | Enabling and supporting merchants | May overlap with existing Arabic organizations or names. |
| **Tajora** | تاجورا | Merchant/trade association with a modern ending | The “tijara/tajir” root may still be commercially crowded. |
| **Marnova** | مارنوفا | Merchant infrastructure and new growth | Less naturally Arabic; requires stronger brand localization. |

The recommended next step is not to choose one of these immediately. Generate 50–100 candidates across the four strategies, reduce them to 10 through linguistic and semantic screening, then perform exact-name, spelling-variant, category, domain, app-store, and trademark checks. Only after that should one candidate be tested with merchants and customers.

## Part II — Additional features to implement

### Product principle

The next features should make the system **more reliable under weak connectivity, more useful to merchants who still use cash and manual operations, and more defensible through trust and governance**. They should not turn the platform into a wallet or payment custodian.

### Priority 0 — Close the existing foundations

| Feature | User value | Implementation boundary |
|---|---|---|
| Offline-first catalog, cart, POS, and order drafts | Merchants can keep working through intermittent connectivity and sync later. | Encrypted, user-scoped outbox; conflict states; server-side idempotency; never replay payment finalization automatically. |
| Full multi-location inventory workflows | Prevents overselling and gives merchants usable stock transfers, counts, reservations, and adjustments. | Atomic RPCs, append-only movement records, reason-required adjustments, audit events, and conflict-resolution UI. |
| Courier provisioning and richer dispatch | Turns the existing courier foundation into an operational workflow. | Courier onboarding, service-area eligibility, batch dispatch, status transitions, handoff evidence, proof of delivery, and returns. |
| Storefront/theme rendering | Converts stored storefront settings into a real merchant-facing storefront system. | Approved theme schema, safe customizations, preview/publish states, responsive RTL layouts, and no arbitrary client code injection. |
| B2B quote and negotiated-pricing flow | Makes wholesale features useful beyond request review. | RFQ, quote versions, expiration, approved price-list items, quantity breaks, tax/shipping snapshots, and idempotent checkout. |
| Review-moderation queue | Protects customers and merchants from abuse while preserving explainable governance. | Creator/reviewer capability checks, reason-required decisions, append-only audit, and private evidence where applicable. |
| Authenticated RLS test harness | Closes the most important remaining authorization gap. | Isolated synthetic users only; customer, merchant, reviewer, support, and creator roles; Data API, RPC, Storage, and Realtime cases. |

### Priority 1 — Yemen-first differentiation

| Feature | Why it matters in Yemen | Safe design |
|---|---|---|
| Cash-on-delivery operations suite | Cash remains important and delivery collection creates reconciliation risk. | Collection sessions, partial collection, variance reasons, merchant-owned cash records, return handling, and no platform custody. |
| Local payment instruction builder | Merchants need clear, channel-specific instructions even when direct APIs are unavailable. | Merchant-controlled account/reference/QR instructions, proof upload to private storage, reviewer workflow, and explicit manual status. |
| Resumable media and low-bandwidth mode | Poor connectivity makes image-heavy commerce unreliable. | Client-side image compression, resumable uploads, thumbnail variants, retry queues, and reduced-data mode. |
| Arabic commerce search | Customers use spelling variants, dialect terms, transliteration, and mixed Arabic/Latin SKUs. | Normalized Arabic search fields, synonym aliases, typo tolerance, SKU/barcode search, and explainable ranking. |
| Pickup and neighborhood delivery tools | Addresses can be ambiguous and transport networks may be disrupted. | Pickup-point aliases, landmark notes, service-zone pricing, delivery windows, customer confirmation, and private address handling. |
| Merchant bulk tools | Many merchants will migrate from spreadsheets or social-media catalogs. | CSV/Excel import with preview, duplicate detection, validation, rollback, image mapping, and export boundaries. |
| Barcode and receipt workflows | Supports small shops moving from manual sales to structured operations. | Camera barcode scanning, offline POS, printable/shareable receipts, local tax fields as configuration, and no financial custody. |
| Customer trust center | Online fraud and payment uncertainty reduce conversion. | Merchant verification tier, return policy, delivery SLA, dispute status, safe contact channels, and visible proof-versus-paid distinctions. |

### Priority 2 — Merchant operating-system expansion

| Feature | Scope |
|---|---|
| Purchase orders and supplier records | Let merchants track replenishment, supplier quotes, receiving, damaged stock, and landed cost without turning the platform into a lender. |
| Product bundles and kits | Support restaurant combos, gift sets, spare-part kits, and stock deduction across component items. |
| Advanced B2B workspace | Add customer-specific price lists, quote comparison, approval chains, minimum order quantities, payment terms as records, and delivery scheduling. Credit should remain a merchant-owned policy or licensed-provider feature, not platform financing. |
| Profit and cash analytics | Add merchant-entered cost basis, gross-margin snapshots, returns impact, COD variance, stock aging, and fulfillment SLA. Keep analytics aggregate and merchant-scoped. |
| Customer segmentation and campaigns | Segments based on consented, scoped events; campaigns can start as drafts and link out to approved channels rather than claiming unconfigured automation. |
| Loyalty and vouchers | Add expiry, merchant scope, abuse limits, offline-safe redemption, reversals, and clear liability ownership. |
| Local marketplace discovery | Add neighborhood/store filters, pickup availability, merchant response time, and category discovery without forcing every merchant into one fulfillment model. |
| Accessibility and assisted commerce | Improve font scaling, contrast, RTL semantics, voice-friendly labels, family-assisted ordering, and clear error recovery. |

### Priority 3 — Provider-enabled capabilities

These should be implemented as **provider-neutral adapters**, not hard-coded promises:

| Capability | First release | Later release after verification |
|---|---|---|
| Wallet and payment providers | Manual QR/reference/instruction mode | Server-side adapter only after official API, sandbox, webhook, settlement, refund, terms, and compliance evidence. |
| SMS and WhatsApp | Deep links, copyable templates, and manual share | Official API integration with consent, rate limits, delivery status, template approval, and provider-specific audit. |
| Courier networks | Handoff/dispatch records and manual status | Verified API/webhook adapters with retry, signature validation, cancellation, and reconciliation. |
| Accounting | CSV/export and merchant mapping | Connector with merchant-owned credentials, least privilege, retry safety, and explicit data-retention rules. |
| External channels | Product-feed export and draft publishing | Approved channel APIs with per-merchant consent, idempotent publishing, and rollback/audit. |

Jaib should remain **manual QR/POS/reference only** until official Alhazmi documentation confirms APIs, callbacks, settlement behavior, refunds, sandbox access, and commercial approval. Provider pages may exist in the UI, but they must be labelled preview/manual until those conditions are met.

## Part III — Recommended execution sequence

| Release increment | Main outcome | Exit criteria |
|---|---|---|
| Increment A | Reliable offline/online merchant operations | Outbox conflict tests, inventory movement tests, idempotency tests, low-bandwidth smoke test, and authenticated RLS suite. |
| Increment B | Complete fulfillment and cash operations | Courier lifecycle, proof of delivery, COD variance, returns, private evidence, and audit checks. |
| Increment C | Merchant growth and B2B | Storefront themes, bulk import, quote/pricing workflow, bundles, and merchant analytics. |
| Increment D | Trust and ecosystem | Moderation queue, verification tiers, fraud/risk signals, support SLAs, and creator policy tools. |
| Increment E | Verified provider adapters | One provider at a time, behind feature flags and server-side credentials, with contract tests and rollback. |

## Success metrics

The roadmap should be measured by operational outcomes rather than feature count: merchant activation rate, percentage of orders created or recovered through intermittent connectivity, stock adjustment and oversell rate, COD variance, delivery-on-time rate, return resolution time, payment-proof review time, B2B quote conversion, search no-result rate, support first-response time, and the number of privileged actions with complete audit reasons.

## Recommendation

The strongest next move is to **keep the current technical identity, run a disciplined coined-name workshop, and implement Priority 0 plus low-bandwidth/COD/trust features before adding more provider integrations**. This creates a defensible product for Yemen’s real operating conditions instead of a broad but fragile clone of a regional SaaS platform.

## References

[1]: https://sanaacenter.org/publications/policy-research/25516 "Sana'a Center, Fostering Opportunities for E-Commerce Growth in Yemen"

[2]: https://www.mdpi.com/2071-1050/15/18/13712 "Al Harazi et al., Unlocking the Potential of E-Commerce in Yemen"
