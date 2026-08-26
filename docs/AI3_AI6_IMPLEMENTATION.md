# Yemen Commerce AI-3 through AI-6 Implementation Runbook

**Status:** AI-3 through AI-6 foundations are implemented on the migration branch and deployed to the connected Supabase project. AI-3 proposal/execution are active behind merchant ownership, approval, action-registry, and policy checks; provider calls, background jobs, managed knowledge retrieval, and external-agent access remain disabled by default until isolated authenticated tests, creator review, provider configuration, and operational controls are complete.

> AI is an audited orchestration layer. Supabase Auth, PostgreSQL RPCs, RLS, immutable order/payment history, private evidence boundaries, and manual merchant-owned payments remain authoritative.

## AI-3: Reviewable merchant actions

AI-3 adds `ai-propose-action` and `ai-execute-action`. The proposal endpoint accepts only a merchant-owned shop scope, one fixed action key, strict bounded JSON arguments, and a mandatory idempotency key. It verifies the live creator-controlled `ai_action_definitions.enabled` and `approval_required` values through `ai_get_action_definition`, resolves the effective merchant policy, records an `ai_tool_calls` row with a normalized argument hash and redacted preview, retains the exact validated payload behind a private owner-scoped RPC, creates a time-limited approval through `ai_request_approval`, and returns an Arabic review envelope. It does not execute a mutation.

The executor requires the same authenticated merchant to supply the run, tool-call, and approval identifiers. It re-reads the run and tool-call projection, confirms the approval is approved and unexpired, retrieves the exact server-retained payload, recomputes the argument hash, rechecks the live action registry and validator, and maps the fixed action key to one existing public RPC. Direct authenticated table reads of raw tool calls are revoked; the merchant review screen receives only the redacted projection. Arbitrary RPC names, SQL, URLs, payment commands, or model-provided authority are impossible at this boundary. Execution is serial and idempotent through the existing commerce RPC’s idempotency key.

| Action key | Existing RPC | Class | Confirmation |
|---|---|---|---|
| `merchant.catalog_bulk_save` | `bulk_save_products` | Reversible write | Required |
| `merchant.save_price_list` | `save_wholesale_price_list` | Reversible write | Required |
| `merchant.save_price_list_item` | `save_wholesale_price_list_item` | Reversible write | Required |
| `merchant.save_promotion` | `save_merchant_promotion` | Reversible write | Required |
| `merchant.inventory_adjustment` | `record_inventory_adjustment` | Reversible write | Required |
| `merchant.inventory_transfer` | `complete_inventory_transfer` | Reversible write | Required |
| `merchant.inventory_count` | `apply_inventory_count` | Reversible write | Required |
| `merchant.open_support_ticket` | `open_support_ticket` | Reversible write | Required |

The action registry is stored in `ai_action_definitions` by migration `0046`. The registry is creator-visible and its enabled state is changed only by the creator RPC `ai_set_action_enabled`, which requires an explanation and writes an audit event. Support drafts remain draft content until a merchant explicitly reviews and submits them through the normal support workflow.

## AI-4: Creator/Owner copilot and governance

Migration `0047` adds versioned `ai_platform_settings_versions`. The active version records non-secret model metadata, provider/background/knowledge/external-agent gates, and bounded budgets. The creator-only RPC `ai_publish_platform_settings` retires the prior active version, creates a new version, requires a reason, and audits the change. The platform flag does not itself enable provider calls: the effective `ai_policies` row must also explicitly allow the relevant action class and provider behavior.

The Creator Console includes an Arabic-first **حوكمة الذكاء** page. It reads settings, action definitions, workflow status, and evaluation summaries through `CreatorRepository`, provides reason-required controls for settings and action changes, offers metadata-first source and chunk ingestion plus evaluation-suite creation, and clearly states that provider secrets never appear in the app. The existing creator authorization checks remain in force; the page is not an alternate admin API.

The creator-owner read-only registry also exposes provider readiness, effective policies, platform settings, action definitions, and workflow status through the authenticated `ai-run` developer surface. Creator mutations continue to use dedicated RPCs and are not generated dynamically by the model.

## AI-5: Managed knowledge and provenance

Migration `0048` adds `ai_knowledge_sources` and `ai_knowledge_chunks`; migration `0053` adds evaluation suites, cases, runs, results, hashes, and creator-only summary/upsert RPCs; migration `0058` adds creator-managed Arabic terminology entries with aliases, canonical terms, hashes, provenance links, and scope-aware retrieval. Sources are versioned, scope-labelled (`global`, `market`, or `shop`), content-hashed, trust-labelled, and status-controlled. Chunks have deterministic ordinals, content hashes, provenance metadata, and a PostgreSQL full-text search document with a GIN index.

Only the creator can upsert sources or chunks through `ai_upsert_knowledge_source` and `ai_add_knowledge_chunk`. Retrieval uses `ai_search_knowledge`, requires an authenticated session, validates the requested scope, checks merchant ownership for shop scope, returns only `ready` sources, and includes source key, title, version, trust class, content hash, chunk ID, and bounded snippet. Retrieval is disabled unless the active creator-published platform setting enables knowledge. The AI gateway exposes this as the bounded `merchant.knowledge_search` read-only tool and `merchant.terminology_search` read-only tool for Arabic terminology memory; no global FAISS index or unscoped private-document retrieval was introduced.

The ingest path intentionally accepts pre-chunked, hashed content rather than fetching arbitrary URLs. A future ingestion adapter must add allowlisted HTTPS fetching, malware/content scanning, size limits, provenance capture, and a review state before setting a source to `ready`.

## AI-6: Resumable workflows and external agents

Migrations `0049` through `0052` add `ai_workflows`, external-client registration, explicit user consent, revocation, narrow public gates, workflow listing, and RLS performance remediation. Migrations `0056` and `0057` add an atomic per-user/per-client daily external-agent quota ledger with an explicit deny RLS policy; the quota is 120 requests per UTC day per consenting client/user pair. A workflow has a bounded redacted payload, input hash, idempotency key, retry budget, next-run time, lease token hash, and terminal status. `ai_claim_workflow` and `ai_complete_workflow` are service-role worker RPCs; lease tokens are stored only as hashes and completion requires the matching lease.

The deployed `ai-workflow-worker` function is an internal worker boundary. It requires the server-only `AI_WORKER_KEY`, uses `SUPABASE_SERVICE_ROLE_KEY` only inside the function runtime, accepts only `claim` and `complete`, and allows only the fixed workflow keys `evaluation.batch`, `knowledge.refresh`, and `merchant.alert_summary`. No service-role key is sent to Flutter. The database `background_enabled` policy gate is false by default, so queued work cannot be created until the creator enables both the platform and effective policy gates.

The deployed `ai-mcp` function implements a bounded JSON-RPC-compatible read-only tool surface. It requires a Supabase bearer token, `x-ai-client-id`, `x-ai-redirect-uri`, the database external-agent gate, an active consent with the exact registered redirect URI and `ai.read` scope, and a daily quota check in the database before dispatching any read. It exposes only merchant catalog, order-workbench, and daily-analytics reads. It does not dereference redirect URIs, fetch arbitrary URLs, accept bearer-token passthrough, execute actions, read evidence, or run SQL. Client registration accepts HTTPS redirect URIs and is creator-only; consent and revocation are user-audited. A full third-party OAuth authorization-code/token broker is intentionally not fabricated inside the Edge Function: until one is approved, the Supabase session bearer remains the authenticated resource token and the MCP surface is disabled by default.

## Deployment and required secrets

| Function | JWT verification | Required secret state |
|---|---:|---|
| `ai-run` | Enabled | `SUPABASE_URL`, `SUPABASE_ANON_KEY`; provider settings remain optional and disabled |
| `ai-propose-action` | Enabled | `SUPABASE_URL`, `SUPABASE_ANON_KEY` |
| `ai-execute-action` | Enabled | `SUPABASE_URL`, `SUPABASE_ANON_KEY` |
| `ai-mcp` | Enabled | `SUPABASE_URL`, `SUPABASE_ANON_KEY` |
| `ai-workflow-worker` | Disabled at platform JWT layer | `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `AI_WORKER_KEY` |

If provider execution is approved later, configure only server-side Function secrets named `AI_PROVIDER_URL`, `AI_PROVIDER_API_KEY`, and `AI_MODEL`. The provider URL must be an operator-configured HTTPS endpoint; no request may supply or override it. Enabling a platform setting is not evidence that a provider is reachable or compliant. Missing configuration must return a sanitized unavailable response and fail the run.

## Test and release gates

Local checks include the AI-2 dispatcher suite and AI-3 action-contract suite under `supabase/functions/**/*.test.ts`, strict TypeScript checking with temporary Deno declarations, Flutter analyzer/tests, Creator Console analyzer/tests, and web release builds. The anonymous Supabase authorization runner must cover each new public RPC and endpoint denial. Authenticated customer/merchant/creator authorization vectors must run only with isolated short-lived credentials and must not create users or mutate the connected shared project.

Before enabling provider calls, background workflows, knowledge retrieval, or external agents, require: isolated role/scope tests; exact approval replay and argument-hash mismatch tests; lease-expiry and duplicate-worker tests; knowledge provenance and prompt-injection tests; redacted logging review; rate and cost budgets; secret rotation; provider terms/compliance review; and rollback evidence. The connected project currently remains conservative: provider calls, background jobs, managed knowledge retrieval, and external-agent access are disabled by default. The worker endpoint returns a safe unavailable response until an operator supplies a server-only `AI_WORKER_KEY`; no recurring scheduler was configured.

## Yemen Commerce invariants preserved

No AI path owns platform funds or verifies a payment merely from a proof. Jaib remains manual QR/POS/reference based absent an approved official API and settlement/refund contract. Order/payment snapshots remain immutable, one merchant order remains the checkout split boundary, identity and payment evidence remain private, merchant ownership remains database-enforced, and all operational mutations go through existing audited RPCs.
