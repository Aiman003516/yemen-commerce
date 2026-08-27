# Edge-5 Device Benchmark Protocol

**Status:** Release-gated protocol. No real-device measurements are claimed in the repository until they are collected on approved Android and iOS devices.

The benchmark evaluates an approved `.litertlm` artifact through the native LiteRT-LM adapter. It must be run with the exact manifest ID, model version, artifact SHA-256, app build, runtime version, platform, OS version, device model, backend, and locale recorded for every run.

## Evidence record

The benchmark collector must emit JSON like this:

```json
{
  "manifest_id": "edge-model-2026-01",
  "model_version": "1.0.0",
  "artifact_sha256": "...",
  "records": [
    {
      "platform": "android",
      "os_version": "14",
      "device_model": "approved-device",
      "backend": "cpu",
      "locale": "ar-YE",
      "completed": true,
      "first_token_ms": 1400,
      "total_ms": 7800,
      "peak_memory_mb": 620,
      "battery_pct_per_10_requests": 3.2,
      "crashed": false
    }
  ]
}
```

The collector must run at least twenty completed read-only requests per device/backend combination, including Arabic/Yemeni evaluation prompts and clarification prompts. It must include cold start, warm start, cancellation, app background/foreground, low-power mode, and metered-network cases. Missing metrics fail the gate; they are never imputed.

## Release thresholds

| Metric | Gate |
|---|---:|
| Completed requests | At least 20 per device/backend combination |
| P95 first-token latency | At most 4,000 ms |
| P95 total response latency | At most 20,000 ms |
| Peak memory | At most 1,024 MB |
| Battery use | At most 8% per 10 requests |
| Crash rate | At most 1% |
| Safety | Zero prohibited or mutation-capable proposals |
| Quality | Edge-2 Arabic/Yemeni evaluation gate remains passed |

The evaluator is `tools/evaluate_edge_device_benchmark.py`. It consumes measured records and returns a non-zero exit code if any gate fails.

## Device tiers

The deterministic Edge-5 policy currently classifies native devices as follows:

| Tier | Capability | Backend recommendation | Status |
|---|---|---|---|
| Unavailable | No native runtime or less than 2 GB memory | Rules-only | Always safe fallback |
| Economy | At least 2 GB and less than 4 GB memory | CPU, 256 output tokens | Eligible only after signed manifest and benchmark |
| Standard | At least 4 GB and less than 8 GB, or no hardware acceleration | CPU, 384 output tokens | Eligible only after signed manifest and benchmark |
| Performance | At least 8 GB and hardware acceleration | GPU optional, 512 output tokens | GPU requires separate benchmark approval |
| Web fallback | Any browser | Rules-only | WebGPU/JavaScript disabled |

The tier is a recommendation, not authorization. The signed manifest, opt-in, runtime readiness, device policy, evaluation gate, and release kill switch remain authoritative.

## Model manifest release procedure

Use the offline signing helper:

```bash
python3 tools/sign_edge_model_manifest.py \
  --input unsigned_manifest.json \
  --output signed_manifest.json \
  --private-key-file /secure/release/edge-model-ed25519.pem \
  --key-id edge-release-2026-01 \
  --public-key-output /secure/release/edge-release-2026-01.pub.b64
```

The private key path must be outside the repository and release logs. The helper writes only the signed manifest and optional public key output. The app receives the signed manifest and public key through ignored build defines; it never receives the private key.

## WebGPU/JavaScript policy

The Web path remains rules-only. The code contains an explicit experimental flag and status seam, but `EdgeWebRuntimePolicy.isSafeToAttempt` remains false. A future WebGPU/JavaScript pilot needs browser compatibility checks, cross-origin isolation review, model-memory measurements, secure artifact delivery, cancellation behavior, and a separate privacy review. It must not silently become the default Web runtime.

## Platform gate

Android APK/AAB compilation and iOS archive/device benchmarking require external native toolchains. Linux validation can prove Dart contracts, Web fallback, manifest verification, and benchmark-report logic, but it cannot claim Android/iOS compiler or real-device results. Those results must be attached to a release record before enabling a production manifest.
