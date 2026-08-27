import 'dart:convert';

import 'package:commerce_core/commerce_core.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'verifies a signed manifest with a trusted Ed25519 public key',
    () async {
      final algorithm = Ed25519();
      final keyPair = await algorithm.newKeyPair();
      final publicKey = await keyPair.extractPublicKey();
      final unsigned = EdgeModelManifest(
        manifestId: 'edge-test-manifest',
        modelId: 'edge-test-model',
        modelVersion: '0.1.0',
        platform: 'android',
        artifactUri: 'asset://edge-test-model.bin',
        artifactSha256: 'a' * 64,
        signerKeyId: 'test-key',
        signatureBase64: 'placeholder',
      );
      final signature = await algorithm.sign(
        utf8.encode(unsigned.canonicalJson),
        keyPair: keyPair,
      );
      final signed = EdgeModelManifest(
        manifestId: unsigned.manifestId,
        modelId: unsigned.modelId,
        modelVersion: unsigned.modelVersion,
        platform: unsigned.platform,
        artifactUri: unsigned.artifactUri,
        artifactSha256: unsigned.artifactSha256,
        signerKeyId: unsigned.signerKeyId,
        signatureBase64: base64UrlEncode(signature.bytes),
      );
      final verifier = EdgeEd25519ManifestVerifier(
        trustedPublicKeys: {'test-key': base64UrlEncode(publicKey.bytes)},
      );

      final result = await verifier.verify(signed);

      expect(result.isValid, isTrue);
      expect(result.code, 'VERIFIED');
    },
  );

  test('rejects an untrusted signer and a non-read-only manifest', () async {
    const manifest = EdgeModelManifest(
      manifestId: 'edge-test-manifest',
      modelId: 'edge-test-model',
      modelVersion: '0.1.0',
      platform: 'android',
      artifactUri: 'asset://edge-test-model.bin',
      artifactSha256:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      signerKeyId: 'unknown-key',
      signatureBase64: 'invalid',
      readOnlyOnly: false,
    );
    final result = await EdgeEd25519ManifestVerifier(
      trustedPublicKeys: const {},
    ).verify(manifest);

    expect(result.isValid, isFalse);
    expect(result.code, 'MODEL_NOT_READ_ONLY');
  });

  test('evaluates device capability requirements deterministically', () {
    const manifest = EdgeModelManifest(
      manifestId: 'edge-test-manifest',
      modelId: 'edge-test-model',
      modelVersion: '0.1.0',
      platform: 'android',
      artifactUri: 'asset://edge-test-model.bin',
      artifactSha256:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      signerKeyId: 'test-key',
      signatureBase64: 'signature',
      minOsVersion: '15.0.0',
      minMemoryMb: 2048,
    );
    const capable = EdgeDeviceCapabilities(
      platform: 'android',
      osVersion: '15.1.0',
      deviceModel: 'test-device',
      memoryMb: 4096,
      supportsNativeRuntime: true,
      supportsHardwareAcceleration: true,
    );
    const incapable = EdgeDeviceCapabilities(
      platform: 'android',
      osVersion: '14.0.0',
      deviceModel: 'low-memory-device',
      memoryMb: 1024,
      supportsNativeRuntime: false,
      supportsHardwareAcceleration: false,
    );

    expect(capable.evaluate(manifest).isEligible, isTrue);
    expect(incapable.evaluate(manifest).isEligible, isFalse);
    expect(
      incapable.evaluate(manifest).reasons,
      containsAll(<String>[
        'NATIVE_RUNTIME_UNAVAILABLE',
        'HARDWARE_ACCELERATION_REQUIRED',
        'INSUFFICIENT_MEMORY',
        'OS_VERSION_UNSUPPORTED',
      ]),
    );
  });

  test('requires opt-in before evaluating or loading a model', () async {
    final preferences = InMemoryEdgePilotPreferences();
    final runtime = FakeEdgeRuntime();
    final controller = EdgePilotController(
      runtime: runtime,
      verifier: const _AlwaysValidManifestVerifier(),
      preferences: preferences,
    );
    final manifest = _manifest();
    const capabilities = EdgeDeviceCapabilities(
      platform: 'fake',
      osVersion: '15.0.0',
      deviceModel: 'test',
      memoryMb: 4096,
      supportsNativeRuntime: true,
      supportsHardwareAcceleration: true,
    );

    final disabled = await controller.evaluate(
      manifest: manifest,
      capabilities: capabilities,
    );
    expect(disabled.isEligible, isFalse);
    expect(disabled.code, 'OPT_IN_REQUIRED');

    await preferences.writeOptIn(EdgePilotOptInState.enabled);
    final enabled = await controller.evaluate(
      manifest: manifest,
      capabilities: capabilities,
    );
    expect(enabled.isEligible, isTrue);
    final status = await controller.loadIfEligible(enabled);
    expect(status.state, EdgeRuntimeState.ready);
  });

  test('evaluation corpus has no unsafe rules-only proposals', () {
    final summary = EdgeEvaluationScorer.evaluateRulesOnly();

    expect(summary.totalCases, 10);
    expect(summary.unsafeProposalCount, 0);
    expect(summary.passed, isTrue);
    expect(summary.averageScore, greaterThanOrEqualTo(0.85));
  });
}

EdgeModelManifest _manifest() => const EdgeModelManifest(
  manifestId: 'edge-test-manifest',
  modelId: 'edge-test-model',
  modelVersion: '0.1.0',
  platform: 'fake',
  artifactUri: 'asset://edge-test-model.bin',
  artifactSha256:
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  signerKeyId: 'test-key',
  signatureBase64: 'signature',
);

class _AlwaysValidManifestVerifier implements EdgeManifestVerifier {
  const _AlwaysValidManifestVerifier();

  @override
  Future<EdgeManifestVerificationResult> verify(
    EdgeModelManifest manifest,
  ) async => const EdgeManifestVerificationResult(
    isValid: true,
    code: 'VERIFIED',
    messageAr: 'تم التحقق.',
  );
}
