# Yemen Commerce AI Agentic Workflow and Authority Plan

**Author:** Manus AI  
**Scope:** Customer App, Merchant App, and Developer/Owner Console  
**Product posture:** Arabic-first, Yemen-first, multi-merchant, non-custodial, server-authoritative

## Executive recommendation

Yemen Commerce should add AI as a **permission-aware commerce operating layer**, not as an unrestricted chatbot embedded in Flutter. The supplied files demonstrate a useful prototype pattern—chat input, a tool registry, a ReAct loop, model fallback, and a local retrieval index—but they do not yet contain tenant isolation, role checks, approval interrupts, audit records, tool-result redaction, or production secret handling.

The recommended target is a server-side AI gateway connected to Supabase through typed, allowlisted RPC tools. Flutter remains the client technology for all three apps. The gateway receives an authenticated app request, derives the acting user and scope from the verified session, selects an appropriate specialist workflow, retrieves only permitted context, proposes typed tool calls, runs policy checks, pauses for approval where required, executes through existing server-authorized RPCs, records an audit event, and returns Arabic-first progress and results. No model receives a service-role key, payment credential, refresh token, identity evidence, or unrestricted SQL capability.

> **Full authority for the Developer/Owner Console should mean full authority over all owner-eligible product and operational controls, while database invariants, auditability, secret isolation, approval records, and non-custodial payment rules remain absolute.** The owner AI must not become a hidden bypass around RLS or immutable financial history.

## 1. Extracted workflow from the supplied files

### 1.1 Current workflow

The supplied `app.py` is a thin Streamlit conversation shell. It stores `messages` in `st.session_state`, renders prior messages, accepts a prompt, calls `agent.run_chat(prompt)`, displays the returned text, and appends the assistant response. This is a useful presentation pattern but has no authenticated principal, merchant/customer scope, approval state, audit event, or safe tool-result preview.

The supplied `agent.py` contains the main orchestration pattern:

| Stage | Current behavior | Yemen Commerce interpretation |
|---|---|---|
| Input | A single free-form user query | Add authenticated user, app, market, merchant/shop scope, locale, and consent context. |
| Tool registry | Many Python functions decorated with `@tool` | Replace with typed commerce tools whose schemas, scopes, side-effect classes, and approval rules are server-defined. |
| System instruction | A prompt tells the agent to use tools and warn about insecure cryptography | Use layered policy: system instructions, deterministic tool guardrails, capability checks, approval state, and database enforcement. |
| Agent loop | `create_react_agent(llm, tools)` selects tools and returns the final message | Use a bounded orchestration loop with maximum turns, maximum tool calls, sequential execution for mutations, and resumable approval. |
| Provider fallback | Hard-coded OpenRouter model IDs are tried in sequence | Use a server-side provider adapter with an allowlisted model catalog, health checks, budgets, and no raw provider errors in the app. |
| Output | Final assistant message text | Return structured run state: plan, tool calls, approvals, results, citations, Arabic summary, and safe error code. |

The current fallback implementation also prints raw model exceptions and returns the last error. That is appropriate for a local prototype but would disclose infrastructure details in a commerce product. The production gateway should log a redacted correlation ID and return a stable Arabic-safe message.

### 1.2 Current knowledge-base workflow

The supplied `knowledge_base.py` is separate from the chat agent. It loads every PDF in the current directory, splits pages into 1,000-character chunks with 200-character overlap, creates local Hugging Face embeddings from a Windows `D:` path, builds a local FAISS index, and saves it to `faiss_index`. The useful pattern is **document loading → chunking → embeddings → retrieval index**.

For Yemen Commerce, this should become a managed ingestion pipeline with document ownership, market/shop scope, language, source URL or file ID, version, publication status, checksum, effective dates, and citation metadata. Product descriptions, reviews, support messages, and external provider payloads must be treated as untrusted data, never as instructions to the model. Private identity/payment evidence must be excluded from general retrieval and accessible only through a separate explicit capability path, if ever needed.

### 1.3 Current deterministic tools and security lessons

The supplied `crypto_tools.py` confirms the desirable separation between deterministic business functions and orchestration, but it also demonstrates why the commerce agent must have a strict tool catalog. The module exposes insecure DES, 3DES, and ECB operations, returns private RSA keys as strings, and includes decryption/signing operations that would require a much stronger trust model in production. The agent prompt warns about some insecure choices, but the tool registry itself does not prevent them.

The commerce equivalent is: **do not rely on prompt wording to protect a side effect**. A merchant price change, inventory adjustment, role grant, provider activation, order cancellation, or export must be rejected by deterministic policy and Supabase RPC checks even if the model requests it.

## 2. Target agentic workflow

The first production workflow should be a bounded **plan → retrieve → propose → approve → execute → verify → explain** loop.

```text
Flutter app
  → authenticated AI request
  → AI gateway derives auth.uid(), app, role, market/shop scope
  → intent router selects customer, merchant, or developer workflow
  → scoped retrieval returns only permitted context and citations
  → model proposes structured response and typed tool calls
  → input/tool guardrails validate schema, scope, sensitivity, and limits
  → policy engine classifies read-only, reversible, or high-impact action
  → approval interruption when required
  → existing Supabase RPC executes with auth/RLS/audit enforcement
  → result verifier checks expected state transition and idempotency
  → run/audit record stores hashes, decision, approval, outcome, and latency
  → Arabic-first response shows what was read, proposed, executed, or blocked
```

The gateway should start as **one orchestrator with specialist instructions**, not a large autonomous swarm. Specialist modes can include Customer Concierge, Merchant Operations Copilot, B2B and Pricing Copilot, Catalog and Content Copilot, Analytics Advisor, Support Triage, and Developer/Owner Operations. Each mode receives a different tool namespace and policy profile. Handoffs can be added later after evaluation proves that routing is reliable.

Every tool must have a machine-readable contract containing `tool_name`, `description`, strict JSON schema, read/write classification, required capability, allowed scopes, approval requirement, idempotency behavior, maximum result size, data sensitivity, and Arabic-safe error mapping. Parallel tool calls should be disabled for mutations and for any workflow where one action depends on the verified result of another.

## 3. Authority model across the three apps

### 3.1 Common hard boundaries

All apps share the following non-negotiable boundaries:

| Boundary | Rule |
|---|---|
| Identity | The server derives the principal from the verified Supabase session. The model cannot choose `user_id`, `merchant_id`, or `shop_id` to impersonate another actor. |
| Data scope | Every read and write is scoped to the authenticated customer, owned merchant/shop, delegated market, or creator capability. |
| Database writes | The AI never writes tables directly. It calls narrow RPCs that retain ownership checks, RLS, idempotency, immutable snapshots, and audit events. |
| Secrets | Provider keys, service-role keys, refresh tokens, payment credentials, private storage signing keys, and identity/payment evidence never enter model context. |
| Financial custody | AI cannot move funds, settle payments, mark an order paid from proof alone, or convert manual Jaib/QR/POS evidence into automatic verification. |
| Destructive history | AI cannot rewrite or delete immutable order, payment, collection, audit, or evidence history. Reversal must be a new audited record. |
| Prompt injection | Product text, reviews, uploaded PDFs, customer notes, and provider responses are data only. They cannot change system policy or tool permissions. |
| Approval binding | An approval is bound to the authenticated principal, exact tool name, normalized arguments hash, scope, expiry, and one-time approval ID. |
| Observability | Every run and tool attempt has a correlation ID, policy decision, approval state, result status, model/provider metadata, and redacted input/output hashes. |

### 3.2 Developer/Owner Console

The Developer/Owner AI receives the broadest capability set. It may inspect and manage platform configuration, markets, feature rollouts, creator capabilities, provider readiness metadata, merchant governance, support/risk queues, operational analytics, AI prompts, model allowlists, retrieval sources, evaluations, and staged releases—through existing creator-authorized RPCs and new AI-governance RPCs.

“Full authority” should be implemented as **owner-eligible authority**, not a bearer token with unrestricted database access. The owner AI may prepare or execute a role grant, suspension, policy change, provider activation, bulk export, or global rollout only when the creator capability and policy permit it. High-impact actions require an explicit owner confirmation in the Developer Console; destructive or security-sensitive actions should support dual approval and a cooling-off period. The AI must never reveal secrets, erase audit records, disable RLS, bypass immutable snapshots, or activate a provider without credentials, terms, webhook verification, settlement behavior, refund policy, consent, and compliance approval.

The Developer Console should expose a run timeline with the model’s plan, selected tools, exact bounded arguments, policy decision, approval request, execution result, and rollback or follow-up options. This is the place for advanced autonomy, background jobs, scheduled analyses, and controlled multi-step workflows.

### 3.3 Merchant App

The Merchant AI is limited to the authenticated merchant’s owned shops and delegated capabilities. It can answer questions about inventory, orders, COD batches, B2B requests, quotes, price lists, POS, rollups, product quality, and provider readiness. It can draft product descriptions, SEO text, catalog classifications, promotions, quote versions, reorder suggestions, support replies, and image-edit instructions.

Low-risk read-only tools can run immediately. Draft generation can run immediately but must be clearly labeled as a draft. Changes to product content, price-list lines, negotiated quotes, promotions, inventory, order status, exports, or customer communications require a visible review step and a server-authorized mutation. Bulk changes require a preview with counts, affected IDs, before/after values, and a second confirmation. The merchant AI cannot inspect another merchant, access customer identity evidence, decide payment claims, grant roles, activate providers, or move money.

### 3.4 Customer App

The Customer AI is a personal shopping and support assistant. It can search active products, compare catalog facts, explain delivery and payment options, summarize the customer’s own orders, show COD status, draft a support request, and provide recommendations using the customer’s current cart and permitted history. It should be able to operate in Arabic, recognize Yemen-relevant wording and local place names, and state uncertainty when inventory, delivery, or payment information is not current.

The Customer AI cannot access another person’s orders, expose merchant operational data, submit payment evidence without an explicit user flow, mark an order paid, silently cancel or return an order, alter a delivery address after the server cutoff, or issue refunds. Cancellation, return, dispute, address change, or support submission should become a reviewable action card and require the customer’s explicit confirmation before the existing RPC is called.

### 3.5 Provider and external-agent boundary

Provider adapters and any future external MCP surface remain disabled by default. A provider operation must pass a readiness state that includes credentials, terms, data processing consent, webhook authenticity, allowed scopes, settlement/reconciliation rules, refund behavior, rate limits, and compliance review. The AI may explain readiness or prepare a configuration draft, but it cannot activate or call the provider until the server-side gate is open.

If Yemen Commerce later exposes MCP, it should expose a first-party scoped gateway with per-client consent, exact redirect URI validation, short-lived audience-bound tokens, revocation, state-handle binding, HTTPS-only production endpoints, SSRF defenses, and tool-level scopes. A shared secret URL that acts like a password is not an acceptable default for a multi-tenant commerce platform.

## 4. AI data and retrieval architecture

### 4.1 Context classes

| Context class | Examples | AI policy |
|---|---|---|
| Public catalog | Active product name, description, price, availability, shop policy | Searchable by customer and merchant according to publication scope. |
| Merchant-private operations | Inventory, rollups, price lists, quotes, COD batches, POS summaries | Only the owning merchant/delegated operator and permitted merchant tools. |
| Customer-private data | Own orders, addresses, support cases, preferences | Only the authenticated customer and customer tools. |
| Governance data | Roles, capabilities, reports, provider readiness, audit summaries | Developer/Owner Console only, with capability checks. |
| Sensitive evidence | Identity documents, payment proofs, private storage objects | Excluded from general retrieval; never sent to the model by default. |
| Untrusted instructions | Product copy, reviews, PDFs, messages, provider responses | Retrieved as quoted data with provenance; never treated as policy. |

### 4.2 Knowledge base replacement

The local FAISS prototype should be replaced or complemented by a server-managed retrieval index. A practical first version is a Supabase-backed document table with vector embeddings, full-text search, row-level scope columns, and citation metadata. Ingestion should be asynchronous and deterministic: validate file type and size, compute a checksum, extract text, detect language, split into bounded chunks, generate embeddings, store source/version metadata, and publish only after a review or policy gate.

Every retrieval result returned to a model should include a source ID, title, language, effective date, scope, and short citation span. The final app response should cite the source title or say when an answer is based on live RPC data rather than a document. Retrieval should be bounded by top-k, token budget, freshness policy, and scope; it should never use unrestricted “all documents” search.

## 5. Tool roadmap

### Phase A: Read-only copilot

Start with tools that query existing projections and return bounded, non-sensitive results: product search, shop policy lookup, customer order status, merchant order workbench, inventory summary, COD summary, daily rollup, B2B request list, quote list, provider readiness, and support knowledge search. This phase proves Arabic answer quality, citations, latency, and tenant isolation without creating side effects.

### Phase B: Drafting and previews

Add product-description and SEO drafting, Arabic translation, product categorization, promotion drafts, quote drafts, support-response drafts, image-edit prompts, low-stock explanations, and analytics narratives. The model creates a draft artifact; the user reviews it in Flutter; no production state changes occur until a separate mutation call.

### Phase C: Approved merchant actions

Add reviewable tools for product updates, price-list line editing, quote version creation, promotion publication, inventory commands, COD batch notes, and customer-message preparation. Each tool returns a preview and a normalized arguments hash. The user confirms in the app, then the server executes the existing RPC with idempotency and audit.

### Phase D: Developer/Owner operations

Add creator-only tools for market and policy configuration, capability grants, merchant governance, provider readiness, AI model/prompt configuration, retrieval-source publication, evaluation runs, and staged feature rollouts. Require explicit owner confirmation for high-impact operations, and dual approval for role escalation, account suspension, provider activation, global policy changes, or destructive exports.

### Phase E: Background and multi-step workflows

After successful evaluation, add scheduled daily rollup explanations, low-stock alerts, quote follow-up drafts, catalog-quality batches, support triage, and provider-event classification. Background jobs should create resumable run records, enforce quotas, expire approvals, and avoid acting on financial or external-provider side effects without a live approval gate.

## 6. Required backend additions before production AI

The existing Supabase foundations are strong enough to host this layer, but the following new primitives should be added before enabling mutations:

| Primitive | Purpose |
|---|---|
| `ai_runs` | Run identity, app, principal, scope, model/provider, status, locale, timestamps, and correlation ID. |
| `ai_messages` | Redacted conversation turns or hashes with retention policy; never store raw sensitive evidence. |
| `ai_tool_calls` | Strict tool name, normalized arguments hash, scope, policy decision, approval requirement, result status, and bounded result metadata. |
| `ai_approvals` | One-time approval token, exact call hash, approver, reason, expiry, decision, and timestamp. |
| `ai_policies` | App/role/tool policy versions, budgets, limits, and rollout status. |
| `ai_provider_configs` | Secret references only, provider/model allowlist, readiness state, rate limits, and compliance metadata. |
| `ai_knowledge_sources` / `ai_knowledge_chunks` | Versioned document provenance, scope, language, publication state, checksum, and embeddings. |
| `ai_evaluations` | Prompt/tool test cases, expected policy outcomes, Arabic quality checks, and regression results. |
| `ai_audit_events` | Immutable audit projection for model, tool, approval, execution, and policy decisions. |

All writes should be private `SECURITY DEFINER` implementations behind narrow public invoker wrappers, with fixed search paths, explicit grants, RLS where appropriate, actor-derived identity, and audit records. The gateway should call these RPCs; Flutter should never call a model provider directly.

## 7. Comparison with Shopify, Zid, Adobe Commerce, and BigCommerce

The comparison below is an analytical maturity estimate based on publicly documented capabilities, not a claim that every feature is available in every plan or region.

| Capability | Yemen Commerce now | Zid | Shopify | Adobe Commerce | BigCommerce |
|---|---:|---:|---:|---:|---:|
| In-product AI assistant with live commerce context | **2/5** — AI-1 gateway deployed with fixed read-only tools; provider disabled by default | **4/5** — Zid AI and MCP connection are documented | **5/5** — Sidekick is embedded in admin and can guide and act | **4/5** — conversational and agentic commerce capabilities documented | **4/5** — Companion and brand-agent direction documented |
| Merchant product writing and SEO | **2/5** — AI not yet connected; deterministic catalog foundation exists | **5/5** — product writer and SEO capabilities documented | **5/5** — Writer persona and product-description workflows | **4/5** — content and product-data optimization | **4/5** — AI-ready catalog context and enrichment |
| AI image generation/editing | **2/5** — deterministic optimization only; no generative image workflow | **5/5** — background editor, product photographer, logos, banners, themes | **5/5** — Sidekick photo-editor and image-generation positioning | **3/5** — AI commerce and experience ecosystem, but not equivalent to Zid’s documented merchant tool set | **3/5** — less emphasized in the reviewed official material |
| Agentic admin mutations | **2/5** now; read-only gateway exists, mutations remain future work | **4/5** — MCP app claims 145+ tools and configurable tool access | **5/5** — Sidekick can complete admin tasks, with review and permission respect | **4/5** — Storefront MCP and agentic standards direction | **3/5** — Companion/brand-agent direction, details vary |
| Customer conversational shopping | **2/5** now; customer-scoped quote tool exists, catalog/order tools remain future work | **2–3/5** in reviewed sources; merchant AI is clearer than customer agent capability | **3/5** in reviewed sources; Sidekick is primarily admin-facing | **4/5** — conversational shopping guidance, recommendations, comparisons, real-time price/inventory | **4/5** — AI shopping and in-conversation buying positioning |
| B2B and negotiated pricing | **4/5** commerce foundation; AI copilot not yet connected | **4/5** broad commerce platform, AI B2B detail less clear in reviewed sources | **4/5** platform-dependent and app-extensible | **5/5** enterprise B2B depth plus agentic direction | **5/5** account-specific pricing, quotes, approvals, and self-service are documented |
| Governance, permissions, and audit foundation | **5/5** backend foundation; AI policy layer remains to be built | **3/5** tool controls and revocation documented; internal enforcement details are not public | **4/5** permission respect and review-before-apply documented | **5/5** enterprise governance/privacy and protocol direction documented | **4/5** enterprise permissions and integrations documented |
| Arabic/Yemen specialization | **5/5** Arabic-first, Yemen-first, local manual-payment/COD and multi-merchant rules | **4/5** Arabic-first regional platform | **3/5** multilingual and Arabic regional presence, but not Yemen-specific | **3/5** broad enterprise/global capability, not Yemen-specific | **3/5** broad global capability, not Yemen-specific |
| External agent connectivity | **0/5** today; should add scoped MCP/agent endpoints later | **4/5** documented MCP connection for external clients | **3/5** strong internal Sidekick; external protocol story less central in reviewed sources | **5/5** Storefront MCP plus UCP/ACP/AP2 commitment | **4/5** explicit AI-agent discovery and in-conversation commerce direction |

### How close are we?

Yemen Commerce is **still behind in visible AI feature breadth**, but it now has a deployed request gateway and an implemented merchant copilot slice. Customer copilot, semantic search, background AI runs, and agent protocol surfaces remain future work. On practical merchant-facing AI breadth, Shopify and Zid remain ahead, while Adobe and BigCommerce remain ahead in enterprise and agentic-commerce positioning.

Yemen Commerce is much closer in **commerce control foundations** than the AI feature count suggests. It already has typed Flutter boundaries, Supabase RPC enforcement, merchant ownership checks, creator capabilities, RLS, immutable snapshots, append-only operational records, audit events, private evidence boundaries, B2B quote/pricing primitives, daily rollups, and explicit provider limitations. Those foundations are exactly what a trustworthy agent needs to execute safely. The implementation gap is therefore concentrated in the AI gateway, knowledge/retrieval layer, tool registry, approval UX, evaluation system, and model/provider operations—not in replacing the commerce core.

A reasonable strategic objective is to reach **Shopify-like merchant copilot usefulness**, **Zid-like Arabic merchant AI accessibility**, and **Adobe/BigCommerce-like agent-ready catalog and checkout interfaces**, while keeping Yemen Commerce’s stronger Yemen-specific and non-custodial rules. The first competitive milestone should not be “give the AI every tool.” It should be “make the AI reliably useful, Arabic-first, scoped, reviewable, and auditable across the three apps.”

## 8. Recommended implementation sequence

| Increment | Outcome | Authority |
|---|---|---|
| AI-0 | Add AI run/tool/approval/audit schema, policy resolver, immutable lifecycle, and Arabic-safe control-plane errors. | No model calls or mutations. |
| AI-1 | Deploy the request-triggered server gateway with fixed customer/merchant/developer read-only tools, policy checks, result redaction, bounded provider adapter, and safe disabled state. | Verified JWT; caller bearer token; no mutations. |
| AI-1b | Add customer catalog/order projections, citations, customer typed invocation/status contracts, and isolated authenticated tests. | Customer scope only. |
| AI-2 | Implement merchant read-only and drafting copilot: workbench, merchant catalog, rollups, B2B/COD/POS/quality analytics, product copy, SEO, and review-only draft envelopes. | Merchant scope; read-only tools and in-memory drafts only. |
| AI-3 | Reviewable merchant mutations: catalog, price lists, quotes, promotions, inventory commands, support drafts. | Explicit merchant confirmation; existing RPCs only. |
| AI-4 | Developer/Owner Console copilot: governance, policies, provider readiness, AI configuration, evaluations, staged rollouts. | Creator capabilities; high-impact approval and optional dual control. |
| AI-5 | Knowledge ingestion, semantic search, Arabic terminology memory, personalized but bounded context, and evaluation dashboards. | Scope-aware retrieval. |
| AI-6 | Background workflows and external-agent/MCP surface after security review. | Resumable runs, quotas, approval gates, OAuth/SSRF protections. |

## 9. Success criteria

The AI rollout should not be considered production-ready until it passes the following gates. A customer cannot retrieve another customer’s data in adversarial tests. A merchant cannot cause a cross-shop read or write through prompt manipulation. The owner AI cannot bypass immutable history, RLS, or provider readiness. Every mutation has a visible preview or approval record. Every tool call has a bounded schema and Arabic-safe failure. Prompt-injection fixtures from product descriptions, reviews, PDFs, and provider messages remain inert. Model failure, timeout, quota exhaustion, and approval expiry fail closed. Arabic outputs preserve Yemeni product, location, currency, COD, and manual-payment terminology. Offline replay never includes AI mutations, payment finalization, evidence submission, or external-provider actions.

Evaluation should measure task success, authorization accuracy, refusal accuracy, citation correctness, Arabic comprehension, latency, cost per run, tool-call count, approval abandonment, and regression performance across customer, merchant, and owner scenarios. The strongest release signal is not a fluent answer; it is a correct, scoped, auditable outcome.

## References

[1]: https://www.shopify.com/sidekick "Shopify Sidekick"
[2]: https://help.shopify.com/en/manual/ai-powered-tools/sidekick "Shopify Sidekick help documentation"
[3]: https://business.adobe.com/products/commerce/ai-commerce.html "Adobe Commerce AI-driven commerce"
[4]: https://business.adobe.com/blog/adobe-commerce-commits-to-agentic-commerce-standards "Adobe Commerce commits to agentic commerce standards"
[5]: https://zid.sa/ar/blog/zid-ai-tools/ "Zid AI tools"
[6]: https://help.zid.sa/zidai/ "Zid AI help documentation"
[7]: https://help.zid.sa/mcp-integration/ "Zid MCP integration help documentation"
[8]: https://www.bigcommerce.com/ "BigCommerce official platform overview"
[9]: https://developers.openai.com/api/docs/guides/agents "OpenAI Agents SDK guide"
[10]: https://developers.openai.com/api/docs/guides/agents/guardrails-approvals "OpenAI guardrails and human review"
[11]: https://developers.openai.com/api/docs/guides/tools "OpenAI tools guide"
[12]: https://modelcontextprotocol.io/docs/2026-07-28/tutorials/security/security_best_practices "Model Context Protocol security best practices"


## AI-0 implementation status

AI-0 database foundations are now deployed through migrations `20260826_0041_ai0_control_plane.sql`, `20260826_0042_ai0_policy_read_guard.sql`, and `20260826_0043_ai0_fk_indexes.sql`. The control plane contains `ai_runs`, `ai_tool_calls`, `ai_approvals`, and `ai_policies` with UUID identities, strict status/action checks, scope consistency, bounded metadata, idempotency support, immutable core-field triggers, append-only policies, creator-only policy publication, and conservative system defaults.

The public surface consists of narrow authenticated wrappers for starting and inspecting runs, proposing and transitioning tool calls, requesting and deciding approvals, finishing runs, listing effective policies and approvals, and publishing creator policies. The private implementations derive identity from `auth.uid()`, validate customer/shop/global scope, enforce creator-only developer access, create audit events, and never expose direct client table writes. Customer defaults allow only read/draft actions, merchant defaults allow read/draft/reversible-write actions subject to confirmation, and developer defaults allow a wider owner-eligible set while still requiring approval for high-impact, external, and sensitive operations. Global defaults explicitly disable provider calls, payment custody, direct table writes, and raw evidence retrieval.

The connected Supabase project accepted AI migrations through `20260826_0045_ai2_merchant_projection.sql`. The Security Advisor recheck is clean (`lints: []`). The Performance Advisor reports no errors or warnings or new unindexed foreign-key findings; 174 remaining notices are informational unused-index records, including AI-0/AI-2 indexes that have not yet been exercised by live traffic. The bounded structural check confirms the effective-policy resolver exists in both `private` and `public`, with a `SECURITY DEFINER` implementation and a narrow public wrapper. The anonymous authorization suite includes the AI-1 resolver and AI-2 merchant catalog denial cases; authenticated AI-1/AI-2 cases remain gated behind isolated short-lived tokens and fixtures.

AI-1 is implemented as `supabase/functions/ai-run` and deployed with JWT verification enabled. Migration `20260826_0044_ai1_effective_policy.sql` supplies the authenticated effective-policy resolver, and migration `20260826_0045_ai2_merchant_projection.sql` supplies the bounded merchant catalog projection. AI-2 adds merchant-only `read`/`draft` modes, a fixed merchant read-only registry for catalog, workbench, rollups, B2B, COD, POS, price-list, and quality summaries, strict structured draft envelopes, provider-policy enforcement, and a typed Flutter client plus Arabic-first merchant review card. The gateway still passes the verified bearer token to existing read-only RPCs, redacts sensitive keys, and returns Arabic-safe errors. Provider calls remain disabled until approved server-side Function secrets and an explicit effective policy enablement are present. Drafts are not saved, published, applied, or approved. No payment action, evidence retrieval path, direct table write, background agent, external MCP server, or mutation tool is enabled. The next increments are customer catalog/order projections, isolated authenticated tests, citations, and reviewable mutation workflows.

## AI-3 through AI-6 implementation status

The migration branch now includes and the connected Supabase project has accepted migrations `20260826_0046_ai3_action_registry.sql` through `20260826_0058_ai5_terminology.sql`. AI-3 exposes `ai-propose-action` v4 and `ai-execute-action` v3. Proposals are limited to fixed merchant action keys and existing audited commerce RPCs; they require a merchant-owned shop, a mandatory idempotency key, a live creator-enabled action definition, an effective policy allow, a redacted preview, and a separate approval. Exact validated arguments are retained behind owner-scoped RPC access so the execution screen never needs to resend raw payloads. The executor rechecks approval expiry, action enablement, the exact argument hash, and the fixed mapping before invoking one existing RPC.

AI-4 adds versioned creator-published platform settings and audited action toggles. The Creator Console now exposes Arabic-first settings, action registry, workflow status, knowledge source/chunk ingestion, and evaluation-suite summary controls. Every creator mutation requires a non-empty reason; provider credentials, service-role keys, and model secrets are not rendered or stored in Flutter.

AI-5 adds scope-aware managed knowledge sources and chunks with source/chunk hashes, trust labels, provenance fields, bounded PostgreSQL full-text retrieval, creator-managed Arabic terminology entries with aliases/canonical terms, and a creator-only evaluation model for suites, cases, runs, results, and summary metrics. Ingestion accepts pre-chunked content and references only; arbitrary URL fetching and unreviewed external content ingestion are intentionally absent. Retrieval remains disabled until the active creator setting enables it and still respects global/market/shop scope and merchant ownership.

AI-6 adds resumable workflow state with database leases, fixed worker operations, external client registration, exact HTTPS redirect matching, explicit `ai.read` consent, user and creator revocation, and a fixed read-only MCP gateway. Migrations `0056` and `0057` add an atomic quota ledger of 120 MCP requests per UTC day per consenting user/client pair; the ledger and raw tool-call payloads have no direct authenticated table-read grants. The worker remains safely unavailable until a server operator intentionally supplies `AI_WORKER_KEY` and a service-role runtime; no minute-level scheduler was configured. A full third-party OAuth authorization-code/token broker is not claimed: the current resource boundary uses the authenticated Supabase bearer only after explicit consent, and MCP is disabled by default.

The active deployment versions are `ai-run` v6, `ai-propose-action` v4, `ai-execute-action` v3, `ai-mcp` v2, and `ai-workflow-worker` v1. The connected anonymous authorization runner passed 117 checks; authenticated role/scope tests remain skipped because isolated customer, merchant, reviewer, support, and creator tokens were not supplied and no shared-project users or fixtures were created. Security Advisor is clean (`lints: []`), while Performance Advisor reports only informational unused-index notices and no errors or warnings for the completed AI roadmap. Before activating providers, background workers, managed retrieval, or external agents, run isolated authenticated tests, review prompt-injection/provenance behavior, configure server-only secrets, confirm provider/compliance terms, and capture rollback evidence.
