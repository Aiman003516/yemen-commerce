# On-Device AI Assistant Design for Yemen Commerce

**Author:** Manus AI
**Reference date:** 27 August 2026
**Status:** Edge-0 rules-only foundation implemented; no on-device model or new execution authority is enabled by this document.

## Executive recommendation

Yemen Commerce should add an **edge assistant**, not an autonomous edge agent. The assistant should understand Arabic and English requests, explain screens and records, validate forms, summarize already-authorized local data, and prepare a precise execution proposal. It must never become the authority that changes orders, payments, inventory, accounting, identities, or permissions.

The correct control flow is:

```text
User speech/text/tap
        |
        v
On-device assistant: intent + missing fields + explanation
        |
        v
Deterministic Dart validator: schema, types, ranges, state, risk
        |
        v
Human review card: exact records, values, warnings, and consequences
        |
        v
Explicit user confirmation
        |
        v
Supabase RPC: Auth + RLS + state machine + payment gate + idempotency + audit
        |
        v
Fresh server result rendered by Flutter
```

The model may suggest **what the user appears to mean**. It may not decide **whether the user is authorized**, **whether a payment is confirmed**, **whether an order may transition**, or **whether a financial action should be posted**. Those decisions remain in Supabase and the existing narrow RPC boundaries.

## Why on-device is valuable in Yemen

On-device inference is especially suitable for private form assistance, low-connectivity operation, Arabic terminology help, barcode and product-entry assistance, and local explanations. It can continue to interpret requests and validate drafts when the network is unavailable. It also avoids sending every prompt and local context to a third-party AI provider. Apple describes local inference as a way to avoid sending data to third-party servers and emphasizes the need to optimize memory and computation [1]. Google’s current AI Edge material documents cross-platform local execution, hardware acceleration, multimodality, and constrained tool use [2].

The limitation is equally important: local inference does not make the device trusted. A modified app, rooted device, prompt injection, stale local cache, or hallucinated tool argument must all be treated as untrusted input. The server must re-check every sensitive operation.

> **Core rule:** The device can propose; the server authorizes and commits; the user confirms the exact proposal.

## Runtime strategy

Google’s current documentation marks the older MediaPipe LLM Inference API as maintenance-only and recommends LiteRT-LM for Android and iOS [3] [4]. LiteRT-LM currently presents stable Kotlin and C++ paths, early-preview Swift and JavaScript paths, and a community Flutter path through `flutter_gemma` [2]. Flutter’s supported integration pattern is a type-safe native bridge, preferably Pigeon, with Kotlin on Android and Swift on iOS; Web should use JavaScript interop rather than mobile platform channels [5].

I would therefore use a **Dart-first orchestration layer with native inference adapters**:

| Layer | Android | iOS | Web | Responsibility |
|---|---|---|---|---|
| Flutter/Dart contract | Shared | Shared | Shared | Prompt envelope, proposal schema, deterministic validation, confirmation UI, risk policy, audit metadata |
| Native runtime adapter | LiteRT-LM Kotlin initially | LiteRT-LM Swift when stable enough for the supported deployment target | LiteRT-LM JavaScript only as an opt-in experiment | Tokenization, model loading, inference, streaming, cancellation |
| Fallback | Rule-based assistant | Rule-based assistant | Rule-based assistant | Works without a model, network, GPU, or supported device |
| Server authority | Supabase Auth/RLS/RPC | Supabase Auth/RLS/RPC | Supabase Auth/RLS/RPC | Authorization, state, payment authority, idempotency, audit, final result |

The bridge should expose only a small typed interface such as `loadModel`, `modelStatus`, `generateProposal`, `cancelGeneration`, and `unloadModel`. It must not expose an arbitrary native method invocation or a generic “execute tool” method. The Flutter side should pass serialized, bounded envelopes; the native side should return text or a strictly bounded structured candidate. Model files should be downloaded or updated through an integrity-checked manifest rather than silently bundled into every APK/IPA. Google notes that on-device models can be too large for normal APK bundling and may need runtime download [3].

## Model tiers

A single model should not be forced to handle every device. The assistant should have a capability profile selected from measured device memory, thermal state, platform, language evaluation, and available storage.

| Tier | Candidate direction | Approximate role | Allowed initial scope |
|---|---|---|---|
| `rules_only` | No generative model | Deterministic templates, Arabic labels, field validation, barcode normalization, command replay explanations | All devices; mandatory fallback |
| `edge_action_small` | FunctionGemma-class or another compact function-oriented model | Convert short natural-language requests into a fixed action schema | Merchant forms and simple customer actions after Arabic evaluation |
| `edge_chat_small` | Quantized 0.5B–1.5B multilingual model, selected by Arabic benchmark | Explanations, search refinement, summaries, missing-field questions | Read-only summaries and draft preparation |
| `edge_chat_medium` | Quantized 2B–4B model for capable devices | Richer Arabic assistance and multimodal drafts | Opt-in on supported devices; never required for core operation |

LiteRT-LM’s current model catalog includes compact models such as Qwen2.5-0.5B, Qwen3-0.6B, Qwen2.5-1.5B, Gemma3-1B, and FunctionGemma, as well as larger models [2]. These names are **candidates, not a production decision**. The final choice must be based on an Arabic/Yemeni evaluation set, peak memory, first-token latency, sustained decode speed, battery impact, package/model download size, and behavior on low-end Android devices. ONNX Runtime’s mobile guidance makes the same point: the model must fit device storage and memory, and teams should measure binary size, model size, latency, and power [6].

I would begin with a rules-only implementation and benchmark two local candidates: a compact action-oriented model for structured proposals and a compact multilingual model for explanations. If the action model cannot reliably produce Arabic-safe structured output, the system should use deterministic intent templates instead of pretending that the model is trustworthy. A small model should assist with language, not replace business rules.

## The proposal protocol

The model should never return executable code, SQL, a URL to fetch, a function name selected from arbitrary text, or unrestricted JSON. It should produce a **proposal envelope** whose fields are validated again by Dart.

```json
{
  "schema_version": "edge_proposal.v1",
  "surface": "merchant",
  "intent": "shipment.record_status",
  "confidence": 0.91,
  "locale": "ar-YE",
  "entities": {
    "shipment_plan_id": "selected-record-id",
    "status": "ready",
    "reason": "تم تجهيز الطلب للاستلام"
  },
  "missing_fields": [],
  "risk_class": "reviewable_operational",
  "explanation_ar": "سيتم تحديث حالة خطة التوصيل إلى جاهز. لن يتم تغيير حالة الدفع.",
  "requires_confirmation": true
}
```

The Dart validator should reject unknown schema versions, unknown intents, unknown fields, missing required fields, malformed identifiers, unsupported status values, overlong text, unsafe characters where relevant, model-produced claims about authorization, and any proposal that attempts to include a secret or private evidence payload. The model’s `confidence` should guide whether the UI asks a clarifying question; it must never bypass confirmation or server authorization.

The proposal should be bound to a deterministic hash over the normalized intent, entity values, visible record identifiers, app surface, policy version, and model/runtime version. The confirmation screen should display that exact normalized content. The client sends the proposal hash and an idempotency key with the existing RPC request. Supabase recomputes or verifies the relevant command shape and still performs all authoritative checks.

### Risk classes

| Risk class | Examples | User confirmation | Server behavior |
|---|---|---|---|
| `read_only` | Explain an order, search products, summarize stock warnings | Optional for navigation; required before sharing or exporting | Bounded read RPC only |
| `draft_only` | Draft product description, support reply, promotion text, delivery note | Confirm before copying/saving draft | No mutation unless a separate existing RPC is invoked |
| `reviewable_operational` | Create shipment plan, record shipment status, open delivery exception, start return logistics | Mandatory; show exact fields and reason | Existing keyed RPC, RLS, state machine, payment gate where applicable, audit reason |
| `high_impact` | Price changes, inventory adjustments, quote pricing, journal actions, role/policy changes | Mandatory plus an additional deliberate confirmation; Creator-only where applicable | Existing high-impact RPC and policy/approval path; never direct model execution |
| `prohibited` | Mark paid, settle, refund, transfer funds, change permissions without policy, expose private evidence, arbitrary SQL/RPC/URL | Cannot be confirmed from the assistant | Reject locally and server-side; log sanitized diagnostic only |

## What each app receives

### Customer app

The customer assistant should help with product discovery, Arabic search refinement, order explanations, payment-instruction comprehension, delivery timeline explanations, pickup/service-area guidance, support-ticket drafting, and return-case preparation. It may use the customer’s currently selected order or a server-returned sanitized projection. It should not expose merchant operational notes, other customers, payment evidence, internal risk signals, or raw provider data. It must explain that a payment reference or uploaded proof is a **claim awaiting merchant confirmation**, not a settled payment.

The customer can ask, for example, “أين وصل طلبي؟” or “ما المطلوب لإرجاع هذا المنتج؟”. The assistant should answer from the latest authorized timeline and clearly show its freshness. If offline, it should label the answer as “آخر بيانات محفوظة” and never present stale data as current.

### Merchant app

The merchant assistant is the first high-value surface. It should explain dashboards, locate orders and products, prepare catalog text, validate barcode/product fields, summarize delivery exceptions, draft shipment updates, and prepare reviewable commands. The merchant sees a confirmation card such as:

> **سيتم تنفيذ العملية التالية:** تحديث خطة التوصيل إلى «جاهز».
> **الطلب:** رقم مختصر ظاهر للتاجر فقط.
> **السبب:** تم تجهيز الطلب للاستلام.
> **لن يتغير:** حالة الدفع أو أي مبلغ مالي.
> **تأكيد التاجر:** [تأكيد] [تعديل]

Shipment, exception, return, inventory, pricing, promotion, and quote actions must use the already deployed idempotent RPC contracts. The assistant must not invent a courier, payment provider, stock quantity, customer identity, or delivery promise. If a shipment is not backed by confirmed payment, it should explain the block rather than suggest a workaround.

### Creator Console

The Creator assistant can explain platform health, module readiness, policy versions, provider gates, audit summaries, and evaluation failures. It may prepare governance drafts and policy proposals, but high-impact Creator operations still require the existing Creator authorization, explicit reason, policy checks, and deliberate confirmation. “Full authority” for the Creator should mean **full authorized access to Creator-approved tools**, not unrestricted model control. The owner should never be able to make the model bypass immutable history, RLS, payment safety, or audit requirements.

## Local data and privacy boundary

The assistant should receive the smallest useful context. Context should be assembled by a Dart `EdgeContextBuilder` from the current screen, selected record IDs, sanitized projections, localized labels, and user-entered text. It should not receive the whole local database. Private payment evidence, identity documents, contact details, access tokens, service-role material, provider secrets, and Creator cross-tenant raw rows must be excluded by default.

Local conversation history, if enabled, should be encrypted and scoped to the authenticated user and app surface. It should have a clear delete control, bounded retention, and no automatic upload. Diagnostics should record model version, schema version, intent key, validation outcome, latency, and sanitized error code, but not prompts, private evidence, or raw customer data by default. If a user explicitly asks for image assistance, the image should remain local unless a separate user-visible upload flow is confirmed.

The model package itself is not a secret. It can be extracted from an application, so it must contain no credentials, authorization logic, private training data, or trusted policy. Model integrity should be checked with a signed or pinned manifest when downloading updates. A compromised model is still constrained by the proposal validator and Supabase authority boundary.

## Confirmation UX

Confirmation must be a first-class state machine, not a button attached to a chat bubble:

```text
idle
  -> interpreting
  -> needs_clarification
  -> proposal_ready
  -> user_reviewing
  -> confirmed
  -> submitting
  -> server_succeeded | server_rejected | network_pending
```

A proposal expires when its selected record, policy version, server freshness window, or payment/status prerequisite becomes stale. On expiration, the app must fetch fresh data and render a new proposal. The user should not be able to confirm a proposal whose visible fields differ from the submitted normalized payload.

For high-impact operations, the UI should require a second deliberate action, such as selecting “أوافق على هذه القيم” and confirming. Biometric confirmation can be added later as an optional local step, but it must not be treated as proof of server authorization. Accessibility, RTL layout, large text, and low-bandwidth behavior are part of the contract.

## Offline behavior

The assistant can remain useful offline for cached explanations, form validation, barcode normalization, draft generation, and preparation of idempotent commands. It cannot claim that a server-side operation succeeded while offline. The UI must distinguish:

| State | Arabic presentation | Meaning |
|---|---|---|
| Local draft | `مسودة محلية` | Nothing has been sent to Supabase |
| Waiting | `بانتظار الاتصال` | A confirmed eligible command is queued for retry |
| Server success | `تم الحفظ من الخادم` | Supabase accepted the command |
| Server rejection | `رفض الخادم العملية` | The authoritative check failed; show localized reason |
| Stale proposal | `تحتاج إلى تحديث` | The user must review fresh server data again |

Only commands that already have safe idempotency, bounded replay policy, and explicit offline eligibility may enter the existing outbox. Financial finalization, payment proof submission, permission changes, refunds, settlement, and Creator governance changes should remain online-only until separately approved.

## Security model

The edge assistant adds another untrusted input source. The threat model must include prompt injection in product titles, support messages, delivery notes, imported CSV rows, OCR text, and provider payloads. These values must be treated as data, never as instructions. The model prompt should state that all record text is untrusted content, but the real protection is the fixed proposal schema and allowlist.

The following controls are mandatory:

| Control | Required implementation |
|---|---|
| Tool allowlist | Per-app and per-role fixed intent catalog; no arbitrary function names |
| Deterministic validation | Dart validators for types, ranges, record ownership hints, status values, and required reasons |
| Server revalidation | Supabase Auth, RLS, state machines, payment authority, idempotency, and audit remain authoritative |
| Proposal binding | Canonical normalized payload plus hash shown in the confirmation view and sent with the command |
| Scope minimization | Current user, selected records, bounded projections; no unrestricted local database dump |
| Privacy | No tokens, secrets, evidence, or unnecessary identity data in model context or diagnostics |
| Failure safety | Unknown intent, low confidence, stale data, offline ambiguity, and model failure become clarification or manual form states |
| Revocation | Remote feature flag and local kill switch disable the model while leaving ordinary app flows usable |
| Monitoring | Sanitized aggregate metrics for latency, validation rejection, model crashes, and user correction rate |

## Implementation increments

### Edge-0 — Contract and policy, no model

Add shared Dart types in `packages/commerce_core` for `EdgeAssistantRequest`, `EdgeProposal`, `EdgeRiskClass`, `EdgeValidationResult`, and `EdgeConfirmationState`. Add deterministic intent catalogs per surface, local redaction, canonical hashing, feature flags, and a rules-only assistant. No new execution authority is introduced.

### Edge-1 — Native runtime shell

Add a shared Flutter plugin or package with Pigeon-generated Android Kotlin and iOS Swift contracts. Implement model lifecycle, streaming/cancellation, memory checks, runtime health, and a no-model fallback. Add a fake runtime for unit and widget tests. Keep Web on the rules-only path until the JavaScript runtime is stable and separately benchmarked.

### Edge-2 — Read-only assistant

Connect the assistant to bounded, already authorized projections. Add Arabic/Yemeni terminology tests, stale-data labels, prompt-injection fixtures, and golden confirmation/explanation widgets. The assistant can explain and search but cannot write.

### Edge-3 — Merchant reviewable actions

Start with channel save, shipment plan/status, delivery exception, and return logistics because their keyed RPC contracts and payment/state gates already exist. Each action must render the exact normalized payload, require an Arabic reason, send an idempotency key, and refresh from Supabase after success. Add offline eligibility only after replay tests.

### Edge-4 — Customer and Creator surfaces

Add customer order/delivery/return explanations and Creator governance/readiness summaries. Keep customer writes limited to existing customer-owned flows and keep Creator high-impact operations behind existing governance confirmations.

### Edge-5 — Model optimization and optional Web

After real-device benchmarks, select model tiers, download/update policy, and supported device matrix. Consider a WebGPU/JavaScript adapter only if the browser experience meets memory, privacy, and performance requirements; otherwise keep Web as rules-only plus optional server AI when separately enabled.

## Evaluation and release gates

A model should not ship because it produces attractive chat responses. The release gate should include a versioned Arabic/Yemeni evaluation set with paraphrases, dialect variation, misspellings, mixed Arabic/English product terms, low-confidence requests, adversarial record text, stale-data scenarios, and prohibited financial requests.

| Gate | Minimum expectation |
|---|---|
| Intent routing | Unknown and ambiguous requests route to clarification or manual form |
| Argument extraction | Required IDs, enums, quantities, currencies, and reasons validate deterministically |
| Safety | Zero accepted proposals for prohibited actions in the release corpus |
| Scope | No cross-customer, cross-merchant, or Creator-only context leakage in redacted outputs |
| Arabic UX | Human review by Arabic speakers familiar with Yemen terminology; no raw backend error codes |
| Offline honesty | No offline path claims server success |
| Performance | Device-tier latency, memory, thermal, battery, and download budgets pass on a representative device matrix |
| Recovery | Model crash, corrupted download, cancellation, and low-memory conditions fall back to ordinary UI |
| Server authority | Authenticated integration tests show that forged proposals still fail RLS/RPC/payment/state checks |

Google’s and Microsoft’s mobile runtime guidance both emphasize device-specific performance measurement and accelerator selection rather than assuming one runtime behaves uniformly across devices [2] [6]. The evaluation must therefore include lower-end Android devices common to the target market, not only flagship phones.

## What I would implement first

I would not begin by embedding a chat window everywhere. The first production slice should be **Edge-0 and Edge-1**, followed by a rules-only Merchant Assistant on the existing channel and logistics UI. This gives the system the important behavior—structured proposals, exact confirmation, localized explanations, stale-state handling, and server-authoritative execution—before introducing model variability.

The first model-enabled pilot should be read-only and opt-in for merchant users. It should compare a compact function-oriented model with a compact multilingual model on the same evaluation set. If the model does not improve task completion without increasing unsafe proposals, the rules-only assistant remains the correct production default. The system should be able to remove or update the model without changing the commerce authority layer.

## Edge-0 implementation checkpoint

Edge-0 is implemented in `packages/commerce_core` and consumed by the customer/merchant and Creator Flutter surfaces. It provides shared proposal and risk types, fixed per-surface intent catalogs, deterministic validation, canonical SHA-256 proposal hashes, recursive redaction, an Arabic-aware rules-only assistant, local confirmation states, and unit/widget coverage. The customer/merchant app shows the card on customer home and the merchant hub; the Creator Console shows it on the Creator dashboard.

The current cards confirm only a local proposal and explicitly report that no server change was performed. They do not load a model, call an AI provider, invoke Supabase, enqueue an outbox command, or create a new execution authority.

## Edge-1 implementation checkpoint

Edge-1 is implemented as a typed native runtime shell. `EdgeRuntimeChannel` exposes status, model loading, inference, cancellation, and unload operations through the versioned `com.yemencommerce/edge_runtime.v1` channel. Android Kotlin and iOS Swift bridges are registered in both Flutter apps and currently return the explicit `MODEL_RUNTIME_NOT_ENABLED` response for model loading and inference. This is intentional: the bridge proves the lifecycle and fallback boundary without shipping an unbenchmarked model or adding model-controlled execution authority.

`FakeEdgeRuntime` and `EdgeAssistantCoordinator` provide deterministic tests and select the rules-only assistant whenever the native runtime is missing, unavailable, returns an invalid proposal, or raises a safe runtime error. The app cards now use this coordinator, so Web and unsupported devices remain functional without native inference. Android APK compilation is pending because this Linux environment has no Android SDK; iOS compilation is pending because Xcode is unavailable on Linux. Dart analysis, Flutter tests, and Web release builds remain runnable and are covered by the validation report.

## Edge-2 implementation checkpoint

Edge-2 is implemented as a **gated model-pilot foundation**, not an active model deployment. `EdgeModelManifest` defines the model identity, version, platform, artifact URI, artifact SHA-256, signer key ID, Ed25519 signature, minimum OS and memory, required locales, hardware requirements, low-power policy, and read-only-only policy. `EdgeEd25519ManifestVerifier` rejects malformed, disabled, unsigned, untrusted, non-read-only, or policy-invalid manifests before any model-loading call.

`EdgePilotController` requires device-local opt-in, a verified manifest, an installed native runtime, and passing device-capability checks before calling `loadModel`. `EdgePilotPreferences` scopes the opt-in locally by app surface. `EdgePilotBuildConfig` accepts only public build-time values: `EDGE_MODEL_MANIFEST_B64` or `EDGE_MODEL_MANIFEST_JSON`, `EDGE_MODEL_TRUSTED_KEY_ID`, and `EDGE_MODEL_TRUSTED_PUBLIC_KEY_B64`. Default builds contain none of these values and therefore cannot activate a model.

The Android and iOS bridge shells now expose a capability query with platform, OS version, model, memory, hardware-acceleration, low-power, and metered-network fields. The native runtime remains intentionally disabled in this increment, so the production decision is still rules-only. The baseline synthetic Arabic/Yemeni corpus and deterministic scorer are in `docs/EDGE2_ARABIC_YEMEN_EVALUATION.md` and `packages/commerce_core/lib/src/edge_evaluation.dart`; activation requires zero unsafe proposals, complete case passing, and an average score of at least `0.85`.

## References

[1]: https://machinelearning.apple.com/research/core-ml-on-device-llama "Apple Machine Learning Research — On Device Llama 3.1 with Core ML"
[2]: https://developers.google.com/edge/litert-lm/overview "Google AI Edge — LiteRT-LM Overview"
[3]: https://developers.google.com/edge/mediapipe/solutions/genai/llm_inference/android "Google AI Edge — LLM Inference guide for Android"
[4]: https://developers.google.com/edge/mediapipe/solutions/genai/llm_inference/ios "Google AI Edge — LLM Inference guide for iOS"
[5]: https://docs.flutter.dev/platform-integration/platform-channels "Flutter Documentation — Writing custom platform-specific code"
[6]: https://onnxruntime.ai/docs/tutorials/mobile/ "ONNX Runtime — How to develop a mobile application"
