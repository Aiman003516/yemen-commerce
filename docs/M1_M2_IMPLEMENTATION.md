# M-1/M-2 Implementation: Read-Only Edge Vocabulary and Signed Artifact Store

**Status:** Implemented in the shared `commerce_core` package and surfaced in the customer/merchant and Creator assistant cards. No native model, remote artifact, cloud provider, or autonomous execution path is enabled.

## M-1: Expanded read-only proposal vocabulary

The Edge-0 assistant now exposes a fixed, surface-scoped vocabulary for safe read-only assistance:

| Intent | Purpose | Required entity | Confirmation |
|---|---|---|---|
| `navigation.open` | Propose opening a compiled application screen | `route_id` | No server mutation; local review only |
| `knowledge.explain` | Explain a fixed Yemen Commerce workflow topic | `topic_key` | No server mutation; provenance required |
| `status.explain` | Explain an operational or payment-display status | `status_key` | No server mutation; never proves payment |
| Existing `order.explain`, `delivery.explain`, `merchant.summary`, and similar intents | Preserve existing read-only behavior | Existing contracts | No mutation |

`EdgeRouteCatalog` contains only compiled route identifiers for customer, merchant, and Creator surfaces. An assistant proposal containing a Flutter path, URL, callback, or unknown route is rejected. `EdgeKnowledgeTopicCatalog` similarly restricts knowledge retrieval to a fixed set of topics such as catalog, orders, delivery, returns, inventory, POS, COD, B2B, channels, payment explanations, governance, and offline sync.

`EdgeProposalProvenance` records an allowed source (`rules`, `local_knowledge_pack`, or `server_read`), retrieval time, optional pack identity/version, and optional expiry. Knowledge proposals require provenance, and expired provenance is rejected. Provenance is included in the canonical proposal payload and shown in the Arabic assistant cards.

The rules-only router recognizes Arabic and English navigation, knowledge, and status phrases. It remains deterministic and precedes any future local model. Existing specific order, provider, shipment, and return routes retain priority over broad phrase matching. A missing route, topic, or status key becomes a clarification proposal rather than an arbitrary action.

## M-2: Signed-manifest artifact store

M-2 extends the existing Ed25519-signed `EdgeModelManifest` with optional `artifact_byte_length` and `artifact_content_type` fields. These fields are part of the canonical signed payload. The verifier and artifact manager enforce identifier syntax, allowed URI schemes, SHA-256 shape, content-type bounds, and a hard two-gigabyte artifact limit. The signed manifest is still verified by `EdgeEd25519ManifestVerifier` before preparation.

`EdgeArtifactStore` provides the following lifecycle:

```text
signed manifest verification
        -> capability and opt-in decision
        -> find and re-verify private cache entry
        -> resume from .part offset when available
        -> bounded chunk append with cancellation/progress
        -> expected-size check
        -> raw-byte SHA-256 check
        -> atomic artifact and metadata commit
        -> native runtime receives only verified localPath
```

The native cache uses the application-support directory through `path_provider`, stores partial data and metadata privately, writes through temporary files, and does not expose the artifact until integrity checks pass. Cached metadata is treated as untrusted: paths are confined to the private cache directory, and a cache entry is invalidated if its file is absent, its manifest identity differs, its version differs, its size differs, or its digest differs.

The HTTPS downloader rejects credentials in URLs, redirects, non-HTTPS sources, unexpected status codes, and unsafe resume responses. A source must return `206 Partial Content` for a resumed request. Flutter Web uses a fail-closed stub, preserving the existing rules-only Web policy. Tests use an in-memory cache and downloader; they do not create model files or contact external hosts.

## Runtime integration boundary

`EdgePilotController.prepareArtifactIfEligible` is the only preparation path. It requires the existing local opt-in, valid signed manifest, installed runtime, and device capability decision. `loadIfEligible` now requires a matching `EdgeArtifactCacheEntry` and passes its private local path to the native bridge. Passing a remote manifest URI directly to native loading is rejected.

The artifact store does **not** download or activate anything by itself. A future M-3 screen or release workflow must explicitly provide a signed manifest, trusted public key, user opt-in, eligible device decision, and a governed downloader. The native runtime remains disabled until the LiteRT-LM pilot is separately implemented and benchmarked.

## Verification performed

The shared package analyzer passed, all `commerce_core` tests passed, all existing customer-app tests passed, and all Creator-app tests passed. The new tests cover:

- Arabic read-only navigation proposals and route allowlisting.
- Fixed knowledge topics and required provenance.
- Read-only status explanations.
- Rejection of arbitrary routes and private knowledge topics.
- Resumable chunk download and progress reporting.
- Raw binary SHA-256 verification.
- Expected-size and hard-limit rejection.
- Cancellation before network access.
- Verified-artifact requirement before native loading.

Android/iOS native model inference remains disabled. No Supabase migration is required for this client-only increment, and no tenant or financial data is introduced into the artifact or local-knowledge contracts.
