# AI-1/AI-2 Execution Engine and Typed Tool Dispatcher

**Status:** AI-2 is implemented on the deployed Supabase Edge Function version 2. Provider execution remains disabled by default until approved secrets and creator-published policy gates are configured.

AI-1 adds the request-triggered server-side gateway for the AI-0 control plane. Flutter and the Creator Console send a short-lived Supabase Auth bearer token to `POST /functions/v1/ai-run`; they never receive a model key, service-role key, database connection string, provider credential, or private Storage credential. The Edge Function verifies the JWT, derives the actor and scope through the authenticated AI-0 RPCs, and uses the same bearer token for operational RPCs so PostgreSQL/RLS remains authoritative.

> The engine is an orchestration boundary, not a second commerce backend. It can read approved projections, but it cannot bypass RPC/RLS, write operational tables, move funds, verify payment evidence, retrieve identity documents, or activate an external provider.

## Request contract

The pilot accepts a bounded JSON request. The client may send `app_surface` as `customer`, `merchant`, or `developer`; `input` up to 4,000 characters; an optional `messages` array of at most eight user/assistant messages; `intent_key` up to 120 characters; an optional `mode` of `read` or `draft`; an optional merchant `scope_id`; and a required `idempotency_key` up to 200 characters. AI-2 draft mode is merchant-only and limited to an explicit intent allowlist. The function forces Arabic response metadata (`locale: ar`) and does not accept an actor ID, role override, arbitrary scope type, RPC name, SQL statement, URL, or model-supplied authorization decision.

For the merchant surface, a shop UUID is required and AI-0 must confirm ownership. Customer requests do not accept a customer override. Developer requests require the `global` scope and creator authorization from the database. A repeated idempotency key returns a bounded existing-run response and never re-executes the provider or a tool.

## Execution sequence

1. The Supabase Edge gateway verifies the bearer JWT and creates a Supabase client whose Authorization header is that same token.
2. `ai_start_run` persists only the bounded intent, request hash, locale, idempotency key, and non-secret engine metadata. Identity and scope are resolved inside the database.
3. `ai_get_effective_policy` is called before provider execution and again for every selected tool. An implicit deny, missing `read`/`draft` permission, `provider_calls_enabled` not explicitly true, disabled provider configuration, malformed policy, or zero tool budget fails closed.
4. The fixed registry is presented to the model using strict function schemas. The dispatcher accepts only registered names, parses only JSON objects, validates every argument, executes one tool at a time, and caps the pilot at four tool calls and six provider rounds.
5. Each proposal is recorded through `ai_propose_tool_call`, transitioned to `running`, executed through an existing public read-only RPC, and transitioned to `succeeded` or `failed`. Tool result summaries store only a row count; prompt and result plaintext are not stored in AI-0.
6. Sensitive result keys are recursively removed before the model sees them. Successful output is returned to the caller and represented in the control plane only by a SHA-256 hash. Provider errors, RPC errors, and internal exceptions are mapped to stable Arabic-safe messages without raw response bodies, stack traces, tokens, SQL, or secret names.

## AI-2 pilot tool allowlist

| Tool | Surface | Authority and output boundary |
|---|---|---|
| `customer.list_own_quotes` | Customer | Authenticated customer-owned quote projection only. |
| `merchant.order_workbench` | Merchant | Owned shop workbench projection with bounded filters and pagination. |
| `merchant.daily_rollups` | Merchant | Owned shop daily analytics with bounded dates and pagination. |
| `merchant.price_lists` | Merchant | Owned shop price-list projection. |
| `merchant.b2b_analytics` | Merchant | Owned shop B2B summary without raw buyer records. |
| `merchant.cod_reconciliation` | Merchant | Bounded COD reconciliation summary; no collection or payment mutation. |
| `merchant.pos_analytics` | Merchant | Bounded POS analytics summary. |
| `merchant.quality_summary` | Merchant | Explainable owned-shop quality summary. |
| `merchant.ai_catalog` | Merchant | New 0045 projection with product copy fields and no private customer/payment/storage data. |
| `developer.provider_readiness` | Developer | Read-only provider adapter metadata; cannot activate or call a provider. |
| `developer.effective_policies` | Developer | Read-only effective AI policy projection for the creator owner. |

The registry intentionally does not expose mutation commands, catalog writes, checkout, payment, COD collection, courier dispatch, promotion application, evidence lookup, private Storage reads, arbitrary SQL/RPC, web fetches, or MCP. AI-2 drafting returns a validated in-memory envelope for human review; it never saves, publishes, applies, or approves a draft. B2B and order tools remain bounded projections, and raw buyer identifiers or contact details are excluded. A recursive redactor is an additional defense, not a replacement for database projection design.

## Provider configuration

The deployed function is safe while unconfigured. With the default policy it returns `AI_PROVIDER_POLICY_DISABLED`; if an explicitly enabled policy lacks provider settings, it returns `AI_PROVIDER_NOT_CONFIGURED`. In both cases it marks the run failed and does not claim that an AI response was generated. If a provider is approved, configure these Supabase Function secrets by name only:

| Secret/configuration name | Purpose | Required handling |
|---|---|---|
| `AI_PROVIDER_URL` | OpenAI-compatible API base URL, normally ending in `/v1` | HTTPS endpoint only; do not accept a user-supplied URL. |
| `AI_PROVIDER_API_KEY` | Server-side provider credential | Store only in Supabase Function secrets; never commit or send to Flutter. |
| `AI_MODEL` | Approved model identifier | Default is `gpt-5-mini` in code, but the live provider catalog must be checked before enabling. |

The current release does not configure these values. Provider calls remain disabled unless the effective policy explicitly sets `provider_calls_enabled: true`; the default merchant policy does not do so. The adapter sends strict tool schemas, uses strict JSON Schema for draft envelopes, disables parallel tool calls, uses a bounded output budget, and aborts after 35 seconds. It does not log chain-of-thought or raw provider payloads.

## Deployment and rollback

The active function is deployed as version 2 with JWT verification enabled; an anonymous probe returned HTTP 401. A maintainer should upload `supabase/functions/ai-run/index.ts`, `contract.ts`, and `deno.json` as one version, then verify that the function is `ACTIVE` and `verify_jwt = true`. Provider secrets should be configured separately through the Supabase project’s secret-management path, never in the repository or deployment JSON. The function can be rolled back by deploying the last reviewed source version; database migrations remain ordered and are not rewritten.

The database prerequisites are migrations `20260826_0044_ai1_effective_policy.sql` and `20260826_0045_ai2_merchant_projection.sql`. Migration 0045 exposes the bounded authenticated `merchant_ai_catalog(uuid,text,integer,integer)` projection. Both migrations were applied successfully. Security Advisor remains clean. Performance Advisor reports only 174 informational unused-index notices; it reports no errors or warnings for AI-2.

## Test gates

The dependency-free contract suite is `supabase/functions/ai-run/tests/contract.test.ts`. It verifies the expanded allowlist and namespaces, dangerous-action exclusion, strict catalog/COD/POS argument bounds, JSON-object parsing, recursive redaction, fail-closed policy parsing, bounded draft-envelope parsing, and customer/merchant/developer namespace separation. The repository test runner can execute it with a temporary Vitest include configuration when the Deno CLI is unavailable. Supabase Edge Runtime compilation and JWT enforcement are verified by deployment and an anonymous endpoint probe; anonymous calls receive HTTP 401 before function execution.

The existing `supabase/tests/run_creator_authorization.sh` now includes anonymous denial for `ai_get_effective_policy`. Authenticated AI-1 tests remain intentionally gated behind an isolated project or branch and short-lived customer, merchant, and creator tokens. They must not create users or mutate fixtures in the connected shared project. Future authenticated vectors must prove that a customer cannot request merchant tools, a merchant cannot read another shop, and a developer path requires creator authorization.

## Explicit non-goals

AI-2 does not add a background worker, scheduler, MCP connector, provider webhook, automated payment verification, platform custody, order mutation, draft publication, or direct table write. The merchant UI is a thin review surface; it does not add an AI-specific mutation path. Those are separate increments requiring their own migrations, policy review, approval semantics, authenticated isolated tests, and provider/compliance gates. The system continues to treat Jaib as a manual QR/POS/reference payment flow until official API, callback, settlement, refund, and compliance documentation is approved.
