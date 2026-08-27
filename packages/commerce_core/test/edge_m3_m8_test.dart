import 'dart:convert';

import 'package:commerce_core/commerce_core.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 8, 27, 10);

  test('M-3 pilot session bounds and validates a local proposal', () async {
    final bytes = <int>[1, 2, 3];
    final proposal = {
      'schema_version': 'edge_proposal.v1',
      'surface': 'customer',
      'intent': 'order.explain',
      'confidence': 0.9,
      'locale': 'ar-YE',
      'entities': {'order_id': 'order-1'},
      'missing_fields': <String>[],
      'risk_class': 'read_only',
      'explanation_ar': 'سأشرح آخر بيانات الطلب المسموح بعرضها.',
      'requires_confirmation': false,
      'created_at': now.toIso8601String(),
      'model_version': 'pilot-1',
      'state': 'proposal_ready',
    };
    final runtime = FakeEdgeRuntime(
      response: EdgeRuntimeInferenceResult(
        requestId: 'request-1',
        proposal: proposal,
      ),
    );
    final controller = EdgePilotController(
      runtime: runtime,
      verifier: const _AlwaysValidManifestVerifier(),
      preferences: InMemoryEdgePilotPreferences(
        state: EdgePilotOptInState.enabled,
      ),
      artifactStore: EdgeArtifactStore(cache: InMemoryEdgeArtifactCache()),
    );
    final manifest = EdgeModelManifest(
      manifestId: 'm3-manifest',
      modelId: 'm3-model',
      modelVersion: '1.0.0',
      platform: 'fake',
      artifactUri: 'asset://m3-model',
      artifactSha256: sha256.convert(bytes).toString(),
      artifactByteLength: bytes.length,
      signerKeyId: 'test',
      signatureBase64: 'test',
      requiresHardwareAcceleration: false,
    );
    final decision = await controller.evaluate(
      manifest: manifest,
      capabilities: const EdgeDeviceCapabilities(
        platform: 'fake',
        osVersion: '1.0.0',
        deviceModel: 'test',
        memoryMb: 4096,
        supportsNativeRuntime: true,
        supportsHardwareAcceleration: false,
      ),
    );
    final session = EdgeLocalPilotSession(
      controller: controller,
      downloader: MemoryEdgeArtifactDownloader(bytes),
    );

    await session.start(decision);
    final result = await session.infer(
      EdgeAssistantRequest(
        requestId: 'request-1',
        surface: EdgeAppSurface.customer,
        locale: 'ar-YE',
        prompt: 'أين حالة طلبي؟',
        createdAt: now,
      ),
    );

    expect(session.state, EdgePilotSessionState.ready);
    expect(result.usedFallback, isFalse);
    expect(result.proposal.intent, 'order.explain');
    await session.close();
    expect(session.state, EdgePilotSessionState.closed);
  });

  test(
    'M-4 keeps operational requests on rules-only and redacts cloud context',
    () async {
      final provider = _RecordingCloudProvider();
      final orchestrator = EdgeAssistantOrchestrator(
        cloudProvider: provider,
        policy: const EdgeOrchestratorPolicy(enableCloud: true),
      );
      final result = await orchestrator.propose(
        EdgeAssistantRequest(
          requestId: 'orchestrator-1',
          surface: EdgeAppSurface.merchant,
          locale: 'ar-YE',
          prompt: 'اجعل حالة التوصيل جاهز',
          createdAt: now,
          context: const {'payment_proof': 'private', 'order_id': 'order-1'},
        ),
      );

      expect(result.route, EdgeAssistantRoute.rulesOnly);
      expect(result.usedFallback, isTrue);
      expect(provider.calls, 0);
      expect(
        result.decision.sanitizedContext.containsKey('payment_proof'),
        isFalse,
      );
    },
  );

  test('M-5 parses only bounded fixed knowledge topics', () {
    final bytes = utf8.encode(
      jsonEncode({
        'documents': [
          {
            'document_id': 'delivery-1',
            'topic_key': 'delivery',
            'title_ar': 'التوصيل',
            'body_ar': 'تظهر حالة التوصيل من آخر حدث مسموح بعرضه.',
            'keywords': ['شحن', 'توصيل'],
          },
        ],
      }),
    );
    final pack = const EdgeKnowledgePackParser().parse(
      EdgeKnowledgePackManifest(
        packId: 'pack-1',
        version: '1.0.0',
        locale: 'ar-YE',
        sha256: 'a' * 64,
        byteLength: 1,
        signerKeyId: 'key',
        signatureBase64: 'signature',
        expiresAt: DateTime.utc(2027, 1, 1),
        topics: ['delivery'],
      ),
      bytes,
    );

    expect(pack.forTopic('delivery')?.titleAr, 'التوصيل');
    expect(pack.forTopic('private_customer_data'), isNull);
  });

  test('M-6 composes a non-committed safe draft only from allowed fields', () {
    final proposal = EdgeProposal(
      schemaVersion: 'edge_proposal.v1',
      surface: EdgeAppSurface.customer,
      intent: 'support.draft',
      confidence: 0.9,
      locale: 'ar-YE',
      entities: const {
        'subject': 'استفسار عن التوصيل',
        'body': 'أحتاج إلى معرفة آخر تحديث.',
        'raw_rpc': 'delete_all',
      },
      missingFields: const [],
      riskClass: EdgeRiskClass.draftOnly,
      explanationAr: 'سأجهز مسودة دعم للمراجعة.',
      requiresConfirmation: true,
      createdAt: now,
    );
    final draft = const EdgeDraftComposer().compose(proposal);

    expect(draft, isNotNull);
    expect(draft!.isCommitted, isFalse);
    expect(draft.formValues.keys, containsAll(['subject', 'body']));
    expect(draft.formValues.keys, isNot(contains('raw_rpc')));
  });

  test('M-7 readiness fails closed for empty or unsafe evidence', () {
    final evidence = EdgePilotEvidence(
      modelId: 'model',
      modelVersion: '1.0.0',
      deviceTier: EdgeDeviceTier.economy,
      platform: 'android',
      latencyMs: 100,
      peakMemoryMb: 1000,
      batteryDeltaPercent: 1,
      crashCount: 0,
      cancelledCount: 0,
      completedCount: 0,
      unsafeProposalCount: 0,
      evaluationCaseCount: 0,
      evaluationPassed: false,
      recordedAt: now,
    );

    final decision = const EdgePilotReadinessGate().evaluate(evidence);

    expect(decision.ready, isFalse);
    expect(
      decision.failedGates,
      containsAll(['EMPTY_EVALUATION', 'NO_COMPLETIONS']),
    );
  });

  test(
    'M-8 requires all privacy, licensing, held-out, and reproducibility gates',
    () {
      final candidate = const EdgeSpecializationCandidate(
        candidateId: 'candidate-1',
        baseModelId: 'model-1',
        baseModelVersion: '1.0.0',
        datasetVersion: 'dataset-1',
        trainingCodeVersion: 'code-1',
        licenseReviewed: true,
        privacyReviewed: true,
        heldOutCaseCount: 20,
        heldOutPassed: true,
        unsafeProposalCount: 0,
        state: EdgeSpecializationState.candidate,
      );

      expect(
        const EdgeSpecializationGate().evaluate(candidate).allowed,
        isTrue,
      );
    },
  );

  test(
    'scale contracts clamp page size and reject slow or oversized samples',
    () {
      expect(const CommercePageRequest(limit: 10000).safeLimit, 100);
      final decision = const ScaleGate().evaluate([
        const ScalePerformanceSample(
          operation: 'orders.keyset',
          pageSize: 100,
          durationMs: 1700,
          payloadBytes: 600000,
          resultCount: 100,
          failed: false,
        ),
      ]);

      expect(decision.passed, isFalse);
      expect(
        decision.failedGates,
        containsAll(['QUERY_LATENCY_LIMIT', 'PAYLOAD_LIMIT']),
      );
    },
  );
}

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

class _RecordingCloudProvider implements EdgeGovernedCloudProvider {
  int calls = 0;

  @override
  Future<EdgeProposal?> propose(
    EdgeAssistantRequest request, {
    required Map<String, dynamic> sanitizedContext,
    required Duration timeout,
  }) async {
    calls++;
    return null;
  }
}
