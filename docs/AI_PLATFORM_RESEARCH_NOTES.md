# Official AI Commerce Research Notes

## Shopify

Source: https://www.shopify.com/sidekick

Shopify presents Sidekick as an AI commerce expert with role-like capabilities for store design, product-photo editing, product writing, technical support, and marketing. The page shows use cases for product descriptions, pricing strategy, social posts, weekly summaries, discounts, email campaigns, low-stock alerts, collections, marketing mix, and shipping audits. It also lists updates for creating customers and companies, and for writing payments, web-performance, fulfillments, and payouts queries.

Source: https://help.shopify.com/en/manual/ai-powered-tools/sidekick

Shopify’s help documentation states that Sidekick can provide guidance, generate content, build apps, complete tasks, analyze data, manage orders, edit products, work with third-party apps, and continue longer tasks in the background. It supports chat, voice, and screen sharing in the admin. It describes Sidekick Pulse recommendations on the admin home, saved skills for repeatable prompts, personalization from past conversations and recent admin activity, and multi-language interaction. It also states that Sidekick follows each staff member’s existing admin permissions and presents changes for review before applying them.

## Adobe Commerce

Source: https://business.adobe.com/products/commerce/ai-commerce.html

Adobe describes AI-driven commerce capabilities across LLM-optimized product discovery, conversational shopping, semantic product discovery, and custom agentic experiences. Its product-discovery material includes product-content optimization, structured metadata for AI-readable product detail pages, channel-ready feed generation, and detection of incomplete product data. Conversational shopping is described as using catalog content plus real-time pricing and inventory, product cards, comparisons, contextual recommendations, and planned in-conversation checkout. Adobe also describes enterprise AI governance and privacy controls.

Adobe’s page describes a Storefront MCP server that gives developers access to live Commerce data and services for branded shopping assistants, support agents, voice experiences, third-party MCP-compatible assistants, and real-time product, price, and inventory information.

Source: https://business.adobe.com/blog/adobe-commerce-commits-to-agentic-commerce-standards

Adobe states a commitment to Universal Commerce Protocol (UCP), Agentic Commerce Protocol (ACP), and earlier support for Agent Payments Protocol (AP2). The stated objective is to support AI-led product discovery and secure agent-powered checkout while preserving merchant control over customer relationships, branding, and commerce data. The source describes three layers: AI discoverability, agent-to-agent commerce, and brand-owned human experiences. These are vendor statements about current direction and planned capabilities; they should not be treated as proof that every capability is available in every Adobe plan or region.

## Zid

Source: https://zid.sa/ar/blog/zid-ai-tools/

Zid’s official Arabic materials describe “Zid AI” tools for product-description writing, image improvement, and sales analysis. The material also positions the broader Zid platform around storefronts, POS, payments, shipping, inventory, marketing, channels, WhatsApp, and financing.

Source: https://help.zid.sa/zidai/

Zid’s help documentation describes product copywriting and SEO, background removal and replacement, AI product photography, a store audit with a score and improvement opportunities, logo creation, banner/card/icon/theme-content design, and migration/data-transfer support. The page is Arabic-first and shows explicit operational dimensions for some generated banner and card assets.

Source: https://help.zid.sa/mcp-integration/

Zid documents an MCP connection app that lets a merchant connect a store to assistants such as ChatGPT, Claude, Cursor, Codex, and n8n. The document warns that the MCP URL must be treated like a password because it grants access to store data and tools. It describes tool-selection controls, revocation, product/order/offer/analytics/customer/loyalty/review/SEO operations, and claims more than 145 tools while noting that approximately 60% of store data and functions were covered at the time of the document. The document describes direct conversational execution, but its exact confirmation behavior should be verified per tool before copying the model.

## BigCommerce

Source: https://www.bigcommerce.com/

BigCommerce’s official site describes an AI-shopper direction: enriching catalog context for AI agents, enabling buying inside AI search/chat, building brand agents, and a Companion assistant for questions, insights, and operations. The same page describes B2B account-specific pricing, products, terms and payment options, self-service quotes/reorders/invoice payments/account management, buyer roles and approvals, multiple storefronts, multilingual and multicurrency support, and more than 600 integrations. These are official product-positioning claims and should be validated against plan/region availability before implementation decisions.

## Implications for Yemen Commerce

The strongest common pattern is not a free-form chatbot. It is a permission-aware commerce action layer: typed tools, live scoped data, previews, explicit approvals for high-impact actions, audit trails, background task status, and reusable connectors. Yemen Commerce already has useful prerequisites: Supabase RPC boundaries, RLS, creator capabilities, merchant ownership checks, immutable order/payment snapshots, append-only operational records, audit events, Arabic-first UI, provider readiness gates, and a three-app separation. The principal missing layer is an AI orchestration service that can call these boundaries through allowlisted typed tools and expose plan/preview/approval/result states consistently across the apps.

## Agent runtime and security references

Source: https://developers.openai.com/api/docs/guides/agents

OpenAI’s current documentation distinguishes the Responses API, where the application owns the model loop and branching, from the Agents SDK, where the SDK manages agent runs, tool calls, handoffs, sessions, guardrails, traces, and resumable approval state. It recommends a code-first server-owned agent when the server owns deployment, tool implementations, state, and approval decisions. It describes agents as applications that plan, call tools, collaborate across specialists, and keep enough state for multi-step work.

Source: https://developers.openai.com/api/docs/guides/agents/guardrails-approvals

The official guardrail guidance separates automatic guardrails from human review. Input guardrails can block requests, output guardrails can validate or redact final output, and tool guardrails can validate arguments/results. Human review pauses before side effects such as cancellations, edits, shell commands, or sensitive MCP actions; the run returns an interruption and resumable state that can be approved or rejected later. The document warns that agent-level guardrails do not automatically cover every tool in nested workflows, so controls must be placed next to the side-effecting tool.

Source: https://developers.openai.com/api/docs/guides/tools

OpenAI’s tool documentation covers function calling, hosted tools, file search, web search, deferred tool loading/tool search, and remote MCP. Strict JSON schemas with `additionalProperties: false`, bounded tool parameters, and explicit approval requirements are appropriate patterns for the Yemen Commerce tool registry. The current documentation also demonstrates disabling parallel tool calls for workflows where sequential validation matters.

Source: https://modelcontextprotocol.io/docs/2026-07-28/tutorials/security/security_best_practices

MCP security guidance highlights confused-deputy risk, per-client consent, exact redirect URI validation, CSRF/state checks, token audience validation, prohibition of token passthrough, SSRF protection, HTTPS and private-IP blocking, secure non-deterministic state handles, and binding handles to the authenticated principal. Yemen Commerce should therefore expose a first-party typed tool gateway rather than handing an unrestricted MCP URL to third parties. If external MCP is added later, it must use explicit per-client consent, scopes, short-lived tokens, revocation, and strict egress controls.
