# Model Enablement and Edge-3 Design

**Status:** Design and implementation increment for the `migration/flutter-supabase-foundation` branch.

This document defines two related but separately gated capabilities:

1. **Model Enablement:** a real LiteRT-LM adapter behind the existing typed Edge-1 bridge, with signed `.litertlm` artifacts, trusted public-key verification, device capability checks, opt-in, read-only proposal output, and staged benchmarking.
2. **Edge-3:** Arabic-first merchant reviewable actions for channels, shipment status, delivery exceptions, and returns using the already deployed actor-scoped idempotent RPCs.

Neither capability grants a model direct Supabase access. The server remains the authority for ownership, RLS, payment status, state transitions, audit, and mutation.

## 1. LiteRT-LM model enablement

Google’s current LiteRT-LM Android documentation exposes an Android/JVM Kotlin API with `Engine`, `EngineConfig`, conversations, asynchronous streaming, and optional GPU/NPU backends. Model initialization can take significant time and should run off the UI thread [1]. The current Swift documentation exposes a native iOS/macOS Swift API with `EngineConfig`, asynchronous initialization, conversations, streaming, and GPU/Metal support [2]. The file-builder documentation defines `.litertlm` as a unified container for TFLite models, tokenizer files, external weights, and model metadata [3].

### Runtime adapter boundary

The Flutter layer must continue to own proposal schemas, redaction, surface allowlists, user confirmation, risk policy, and fallback behavior. Native code owns only model loading and text generation. LiteRT-LM must be configured with **no automatic tool calling**. The model receives a bounded read-only prompt and returns structured proposal JSON; a parser rejects everything outside `edge_proposal.v1`.

| Boundary | Allowed | Forbidden |
|---|---|---|
| Flutter → native | Redacted prompt, bounded context, locale, request ID, output-token limit | Access tokens, payment evidence, identity evidence, secrets, raw database dumps |
| Native runtime | Load verified local artifact, generate read-only text/proposal | Supabase calls, arbitrary tools, URL fetches, SQL, filesystem traversal |
| Model output | Fixed proposal JSON, clarification, explanation | RPC names, credentials, payment decisions, role changes, autonomous commands |
| Flutter → backend | Only after exact user confirmation and existing keyed RPC validation | Model-originated direct execution |

### Android implementation path

Add the pinned LiteRT-LM Android Maven dependency only in a dedicated model-enabled build flavor or release configuration. The bridge should:

1. Receive a verified local file path from Flutter.
2. Re-check the artifact SHA-256 immediately before loading.
3. Initialize `Engine` and a single bounded conversation on a background coroutine.
4. Use CPU by default for compatibility; allow GPU only when the capability policy and device benchmark permit it.
5. Keep automatic tool calling disabled.
6. Enforce a short prompt and output-token budget.
7. Map `LiteRtLmJniException`, lifecycle failures, memory pressure, and cancellation into the existing safe Dart runtime errors.
8. Close the conversation and engine on unload, app backgrounding, model switch, and fatal failure.

The Android bridge must expose a capability query separately from runtime availability. It should not report the model runtime as available until the signed artifact has been verified and the LiteRT-LM engine has initialized successfully.

### iOS implementation path

Add the LiteRT-LM Swift Package Manager dependency to the Runner target only in the model-enabled configuration. The bridge should use `EngineConfig` with a verified `.litertlm` path, CPU by default, Metal/GPU only after benchmark approval, bounded asynchronous generation, cancellation, and explicit engine/conversation teardown. iOS failures must map to the same Dart error taxonomy as Android. Xcode must validate the package, minimum deployment target, device architecture, and archive size before any pilot rollout.

### Artifact lifecycle

A release pipeline, not the app, owns model signing and publication. The pipeline should:

1. Build or obtain the approved `.litertlm` artifact.
2. Inspect and unpack/repack it using the LiteRT-LM builder/peek tooling where required.
3. Calculate SHA-256 over the exact distributable bytes.
4. Create the manifest payload excluding the signature field.
5. Sign the canonical manifest payload with an offline Ed25519 release key.
6. Publish the artifact and signed manifest over HTTPS or package the artifact as a signed app asset.
7. Inject only the manifest and public verification key into the build; never inject the private signing key.
8. Maintain an append-only release record containing key ID, manifest ID, model version, artifact hash, approval, benchmark summary, and rollback target.

The manifest currently supports these public build defines:

```text
EDGE_MODEL_MANIFEST_B64
EDGE_MODEL_MANIFEST_JSON
EDGE_MODEL_TRUSTED_KEY_ID
EDGE_MODEL_TRUSTED_PUBLIC_KEY_B64
```

`EDGE_MODEL_MANIFEST_B64` is preferred for CI because it avoids shell-quoting errors. A default build must provide none of these values.

### Trusted-key management

The application embeds a **public-key ring**, never a private key. Each key has a stable key ID and an operational state: `active`, `grace`, or `revoked` in release management. The current Dart verifier accepts only the explicitly configured trusted key. A future key-ring manifest may support overlapping active/grace keys for rotation.

| Event | Required action |
|---|---|
| New signing key | Generate offline, review fingerprint out-of-band, add public key in a release build |
| Rotation | Ship new key while old key remains grace-valid for already published manifests |
| Compromise | Revoke key in the release configuration and ship a kill-switch build |
| Rollback | Restore only a previously approved manifest/hash, never an arbitrary URL |
| Manifest change | New manifest ID/version and new signature; no in-place mutation |

Public keys are not secrets, but they are security policy. Changes require Creator/release approval and must be reviewed like code.

## 2. Model enablement gates

The real runtime remains disabled until every gate passes.

| Gate | Required evidence |
|---|---|
| Artifact | `.litertlm` exists, exact SHA-256 matches, package inspection passes |
| Signature | Ed25519 signature verifies against a trusted non-revoked key |
| Policy | Manifest is enabled, read-only, locale-compatible, platform-compatible, and memory/OS constrained |
| Consent | User opted in locally for the current app surface |
| Runtime | LiteRT-LM engine initializes and reports ready |
| Safety | Model output parses as `edge_proposal.v1`; no unsafe/prohibited proposal is accepted |
| Quality | Expanded Arabic/Yemeni/adversarial corpus meets score and zero-unsafe thresholds |
| Performance | Low-end supported-device latency, memory, battery, and crash budgets pass |
| Rollback | Previous approved manifest and rules-only fallback are available |

A failed gate results in `rules_only_fallback`. The user must never see a false “model active” state.

## 3. Edge-3 merchant reviewable actions

Edge-3 uses the already deployed idempotent client methods and RPCs:

| Action | Existing client method | Required review values | Backend gate |
|---|---|---|---|
| Save channel | `upsertMerchantChannel` | Channel key/kind/status/display name/reason | Merchant ownership; audited reason |
| Save channel listing | `upsertChannelListing` | Channel/product/listing status/reason | Channel/product ownership and active-state rules |
| Create shipment plan | `createShipmentPlan` | Merchant order/carrier/service level/reason | Merchant ownership; one plan; audited reason |
| Update shipment status | `recordShipmentEvent` | Shipment ID/next status/customer message/reason | Valid state transition and paid-status gate for transit/delivery |
| Open delivery exception | `openDeliveryException` | Shipment ID/code/severity/customer message/reason | Merchant ownership; audited exception |
| Resolve delivery exception | `resolveDeliveryException` | Exception ID/resolution status/reason | Merchant ownership; state transition; audit |
| Start return logistics | `startReturnLogistics` | Approved/resolved return case/method/message/reason | Merchant-owned eligible case; no refund |
| Update return status | `recordReturnEvent` | Return ID/next status/message/reason | Valid return transition; append-only event |

The UI may prepare a proposal locally or with a future read-only model, but the final action is always a Dart client call with a fresh idempotency key. The action dialog must state that payment status and money movement are unchanged unless the operation is only a shipment paid-status gate check.

### Edge-3 dialog contract

Every mutation dialog must display:

- affected record and current state;
- next state or exact values;
- reason field with a minimum length of five characters;
- payment status and the reason a transition is or is not permitted;
- no-custody/no-automatic-refund statement where relevant;
- a confirmation button that is disabled until required fields are valid;
- a fresh 16+ character idempotency key generated once per submission attempt;
- a re-fetch after success;
- a localized server error without exposing raw backend codes.

The dialog must never turn a payment proof, customer statement, or model confidence score into `paid`.

## 4. Testing and rollout

Unit tests must cover canonical manifest signatures, invalid signatures, key mismatch, malformed artifacts, revoked/disabled policy, opt-in persistence, capability failures, low-memory devices, unsupported OS versions, Arabic/Yemeni prompts, prohibited payment requests, valid shipment transitions, invalid transitions, stale proposals, idempotency reuse, and rules-only fallback.

Widget tests must prove that the exact review payload is visible before confirmation, no action is sent before confirmation, the confirmation action is disabled for missing reasons, and the UI re-fetches after success. Live authenticated workflow tests require an isolated Supabase project or branch and isolated role tokens; no shared-project synthetic users or fixtures may be created.

The rollout sequence is:

1. Rules-only and fake runtime evaluation.
2. Internal Android/iOS builds with a test key and non-production artifact.
3. Device matrix benchmark on low-end Android, supported iOS, and representative network/power states.
4. Read-only model pilot for explanations and proposal drafting only.
5. Edge-3 merchant reviewable actions with explicit confirmation and existing keyed RPCs.
6. Wider opt-in rollout with kill switch, rollback manifest, and Creator-approved quality dashboard.

### References

[1]: https://developers.google.com/edge/litert-lm/android "Google AI Edge — Get Started with LiteRT-LM on Android"
[2]: https://developers.google.com/edge/litert-lm/swift "Google AI Edge — LiteRT-LM Swift API"
[3]: https://developers.google.com/edge/litert-lm/file_builder "Google AI Edge — LiteRT-LM File Builder"

## 5. Implementation checkpoint

The current increment adds merchant-owned read projections for shipment plans, shipment events, delivery exceptions, order cases, and return logistics, plus an Arabic-first operational dialog launched from the Merchant Order Workbench. The dialog covers shipment-plan creation, shipment-status updates, delivery-exception creation and resolution, return-logistics start, and return-status updates. Each mutation requires a reason, a second explicit confirmation, a fresh idempotency key, and a server re-fetch. Shipment creation is disabled unless the order is already marked `paid`; the UI repeats that payment proof is not payment confirmation.

The model-enablement portion remains a release-gated design and integration seam. No LiteRT-LM dependency, model artifact, production signing key, or active model manifest has been added to the default builds. Actual native compilation and device benchmarking remain required on Android SDK and macOS/Xcode environments before enabling the runtime.
