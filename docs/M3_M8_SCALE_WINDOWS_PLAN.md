# M-3–M-8 Implementation, Scale, and Windows Plan

**Status:** Shared contracts for M-3 through M-8 are implemented as a safe foundation. Native model inference, cloud providers, fine-tuning, and Windows desktop targets remain disabled unless their external gates pass.

## Architectural decision

Yemen Commerce uses a **rules-first, proposal-only edge assistant**. The device may interpret a request, explain a status, compose a draft, or propose an allowlisted route. It cannot authorize or commit a commerce operation. Supabase remains authoritative for authentication, tenant scope, RLS, state transitions, payment confirmation, idempotency, and audit.

LiteRT-LM remains the primary native runtime direction. Its official overview currently lists CPU and accelerator support across Android, iOS, macOS, Windows, Linux, and IoT, while its Flutter integration is described as community-supported rather than the primary native API path [1]. Therefore this repository keeps the typed Flutter bridge and native adapters as the boundary, rather than making a Dart package or an unbenchmarked model a production dependency.

## Delivered modular phases

| Phase | Delivered contract | Safety or release gate |
|---|---|---|
| M-3 | `EdgeLocalPilotSession`, bounded prompts/outputs, timeout, cancellation, verified local artifact requirement, proposal validation, fallback | No runtime activation without signed manifest, opt-in, capabilities, and verified artifact |
| M-4 | `EdgeAssistantOrchestrator`, rules/local/cloud route enum, explicit policy, per-session attempt quota, privacy boundary, sanitized decision metadata | Cloud disabled by default; operational proposals stay on rules/manual flows |
| M-5 | Signed knowledge-pack manifest, Ed25519 verification, raw-byte digest, expiry, Arabic-Yemen locale, bounded parser, fixed topic retrieval | No private tenant records or arbitrary topics in a pack |
| M-6 | `EdgeDraftComposer`, fixed field allowlists, proposal-hash binding, non-committed draft output | Form prefill is a draft only; no direct state mutation or RPC call |
| M-7 | Sanitized device evidence, latency/memory/battery/crash/cancellation/completion fields, conservative readiness gate | Empty evaluation, unsafe proposal, crash, or performance failure blocks readiness |
| M-8 | Specialization candidate and gate with privacy/license review, held-out evaluation, reproducibility IDs, zero unsafe proposals | Fine-tuning and promotion remain disabled until Creator approval and evidence |

The customer/merchant and Creator assistant cards now use the deterministic orchestrator with local and cloud routes disabled by default. This preserves existing behavior while making the future route policy explicit.

## Scale design for more than one million users and millions of records

No source code or local test can guarantee a production capacity number without representative hosted load tests, Supabase plan capacity, query plans, connection telemetry, and realistic workload distributions. The implementation therefore establishes **scale-safe contracts and measurable gates**, not an unsupported capacity claim.

The shared `scale_contracts.dart` module enforces deterministic page sizes, keyset-style `after_id` cursors, maximum rows, payload limits, latency budgets, and failure thresholds. New high-volume Supabase APIs should follow these rules:

1. Use indexed, tenant-scoped keyset pagination ordered by a stable `(created_at, id)` or equivalent cursor. Do not use unbounded client lists or large offset scans for operational screens.
2. Return only the columns required by the screen or assistant context. Never send whole tenant rows, payment evidence, identity documents, provider secrets, or raw audit payloads to the device model.
3. Keep RPCs narrow and atomic. Authorization, state transitions, payment semantics, idempotency, and audit remain server-side. A client-side AI proposal is never a database authority.
4. Separate transactional tables from read-optimized projections and rollups when analytics or dashboards grow. Refresh rollups asynchronously and expose freshness timestamps.
5. Use connection pooling and observe peak concurrent connections. Supabase documents that pool sizing depends on actual usage and recommends reserving capacity for Auth and other platform services rather than allocating every database connection to PostgREST [2].
6. Validate representative query plans at staged row counts, including at least 100,000, 1,000,000, and 10,000,000-row synthetic datasets in an isolated project or database branch. These fixtures must never be inserted into the shared production Supabase project.
7. Measure p50, p95, and p99 latency, payload size, error rate, pool saturation, lock waits, cache hit rate, and background job lag. A “short time” target must be written per operation; one global number is not meaningful.

The next database-scale increment should be applied only after inspecting the deployed schema and query plans. It should add or adjust indexes and projections based on actual slow-query evidence, not create speculative indexes everywhere. Supabase’s connection-management guidance specifically calls for monitoring live connections and investigating `idle in transaction` sessions and blocked queries [2].

## Windows decision and build plan

The repository currently contains `flutter_app/` and `creator_app/` Flutter Web/mobile projects but no `windows/` runner directories. Windows is therefore **not an active supported target**, and no Windows runner or Windows-only package should be added merely to address a hypothetical build issue.

If Windows becomes an approved product target, the work should begin on a Windows machine or CI runner with Flutter, Visual Studio, and the **Desktop development with C++** workload installed. Flutter’s current setup guide identifies Visual Studio—not Visual Studio Code—as the required Windows compilation toolchain and recommends validating it with `flutter doctor -v` and `flutter devices` [3]. The build pipeline should then perform:

| Windows gate | Required check |
|---|---|
| Runner | Generate and commit the Windows runner only after product approval |
| Toolchain | `flutter doctor -v`; Visual Studio C++ workload; Windows SDK; CMake/Ninja as required by the Flutter version |
| Plugins | Verify every package supports Windows or provide a conditional implementation |
| Storage | Confirm `path_provider` private application-support paths and atomic artifact file operations |
| Runtime | Keep Edge Web/Windows model inference disabled until a Windows LiteRT-LM adapter is benchmarked and reviewed |
| Network | Verify HTTPS, proxy/TLS, redirects, cancellation, resume, and offline fallback on Windows |
| UX | Test Arabic RTL, keyboard navigation, high DPI, resizable windows, and long-running desktop sessions |
| Release | Build `flutter build windows --release`, smoke test the generated runner, and package with a signed MSIX or controlled ZIP |

Flutter’s Windows build documentation describes the generated C++ runner, Visual Studio compilation path, MSIX distribution, and the requirement to ship the executable, DLLs, data directory, and Visual C++ redistributables for a ZIP distribution [4]. The repository should not claim Windows readiness until these gates run on Windows; Linux cannot produce a meaningful native Windows build for this project’s runner and plugins.

## Remaining external gates

The following are intentionally not claimed as complete: an actual LiteRT-LM SDK dependency, production model artifact, signed production manifest, native Android/iOS inference, cloud provider, fine-tuning job, million-scale hosted load test, or Windows runner build. The safe next implementation increment is to connect a non-production fake/benchmark harness to the existing M-7 evidence schema, then run the first real-device CPU pilot only after an approved artifact and isolated test key exist.

## References

[1]: https://developers.google.com/edge/litert-lm/overview "Google AI Edge — LiteRT-LM Overview"
[2]: https://supabase.com/docs/guides/database/connection-management "Supabase Documentation — Connection management"
[3]: https://docs.flutter.dev/platform-integration/windows/setup "Flutter Documentation — Set up Windows development"
[4]: https://docs.flutter.dev/platform-integration/windows/building "Flutter Documentation — Building Windows apps with Flutter"
