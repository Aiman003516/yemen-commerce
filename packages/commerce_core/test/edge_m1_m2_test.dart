import 'package:commerce_core/commerce_core.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 8, 27, 10);

  test(
    'rules-only assistant creates an allowlisted Arabic navigation proposal',
    () {
      final proposal = const EdgeRulesOnlyAssistant().interpret(
        EdgeAssistantRequest(
          requestId: 'navigation-1',
          surface: EdgeAppSurface.customer,
          locale: 'ar-YE',
          prompt: 'افتح شاشة الطلبات',
          createdAt: now,
        ),
      );

      expect(proposal.intent, EdgeIntentCatalog.navigationOpen);
      expect(proposal.entities['route_id'], EdgeRouteCatalog.customerOrders);
      expect(
        EdgeProposalValidator.validate(proposal, now: now).isValid,
        isTrue,
      );
    },
  );

  test('knowledge proposals carry local provenance and fixed topics', () {
    final proposal = const EdgeRulesOnlyAssistant().interpret(
      EdgeAssistantRequest(
        requestId: 'knowledge-1',
        surface: EdgeAppSurface.merchant,
        locale: 'ar-YE',
        prompt: 'اشرح سياسة الدفع عند الاستلام',
        createdAt: now,
      ),
    );

    expect(proposal.intent, EdgeIntentCatalog.knowledgeExplain);
    expect(proposal.entities['topic_key'], 'cod');
    expect(proposal.provenance?.source, 'rules');
    expect(EdgeProposalValidator.validate(proposal, now: now).isValid, isTrue);
  });

  test('status explanations remain read-only and do not assert payment', () {
    final proposal = const EdgeRulesOnlyAssistant().interpret(
      EdgeAssistantRequest(
        requestId: 'status-1',
        surface: EdgeAppSurface.customer,
        locale: 'ar-YE',
        prompt: 'اشرح حالة جاهز',
        createdAt: now,
      ),
    );

    expect(proposal.intent, EdgeIntentCatalog.statusExplain);
    expect(proposal.entities['status_key'], 'shipment.ready');
    expect(proposal.requiresConfirmation, isFalse);
    expect(EdgeProposalValidator.validate(proposal, now: now).isValid, isTrue);
  });

  test(
    'validator rejects arbitrary routes and unapproved knowledge topics',
    () {
      final route = EdgeProposal(
        schemaVersion: 'edge_proposal.v1',
        surface: EdgeAppSurface.customer,
        intent: EdgeIntentCatalog.navigationOpen,
        confidence: 0.9,
        locale: 'ar-YE',
        entities: const {'route_id': '/admin/raw'},
        missingFields: const [],
        riskClass: EdgeRiskClass.readOnly,
        explanationAr: 'سأفتح شاشة مسموحة فقط دون تغيير أي بيانات.',
        requiresConfirmation: false,
        createdAt: now,
      );
      final topic = EdgeProposal(
        schemaVersion: 'edge_proposal.v1',
        surface: EdgeAppSurface.customer,
        intent: EdgeIntentCatalog.knowledgeExplain,
        confidence: 0.9,
        locale: 'ar-YE',
        entities: const {'topic_key': 'private_customer_data'},
        missingFields: const [],
        riskClass: EdgeRiskClass.readOnly,
        explanationAr: 'سأعرض شرحاً من المعرفة المحلية الموثقة.',
        requiresConfirmation: false,
        createdAt: now,
        provenance: EdgeProposalProvenance(source: 'rules', retrievedAt: now),
      );

      expect(
        EdgeProposalValidator.validate(
          route,
          now: now,
        ).issues.map((issue) => issue.code),
        contains('INVALID_ROUTE'),
      );
      expect(
        EdgeProposalValidator.validate(
          topic,
          now: now,
        ).issues.map((issue) => issue.code),
        contains('INVALID_KNOWLEDGE_TOPIC'),
      );
    },
  );

  test(
    'artifact store resumes, verifies raw bytes, and atomically exposes cache',
    () async {
      final bytes = <int>[0, 255, 1, 128, 10, 42, 99];
      final cache = InMemoryEdgeArtifactCache();
      final store = EdgeArtifactStore(cache: cache);
      final manifest = EdgeModelManifest(
        manifestId: 'm1-artifact-manifest',
        modelId: 'm1-artifact-model',
        modelVersion: '1.0.0',
        platform: 'android',
        artifactUri: 'https://models.example.invalid/m1.bin',
        artifactSha256: sha256.convert(bytes).toString(),
        artifactByteLength: bytes.length,
        signerKeyId: 'pilot-key',
        signatureBase64: 'signature',
        requiresHardwareAcceleration: false,
      );
      await cache.appendPartial(manifest.modelId, bytes.sublist(0, 3));
      final downloader = MemoryEdgeArtifactDownloader(bytes, chunkSize: 2);
      final progress = <EdgeArtifactProgress>[];

      final entry = await store.download(
        manifest,
        downloader: downloader,
        onProgress: progress.add,
      );

      expect(entry.byteLength, bytes.length);
      expect(downloader.requestedOffsets, [3]);
      expect(progress.last.bytesReceived, bytes.length);
      expect(await store.findVerified(manifest), isNotNull);
      expect(await cache.partialLength(manifest.modelId), 0);
    },
  );

  test(
    'artifact store rejects hash mismatch and preserves retryable partial data',
    () async {
      final bytes = <int>[1, 2, 3, 4];
      final manifest = EdgeModelManifest(
        manifestId: 'm1-bad-hash-manifest',
        modelId: 'm1-bad-hash-model',
        modelVersion: '1.0.0',
        platform: 'ios',
        artifactUri: 'https://models.example.invalid/bad.bin',
        artifactSha256: 'a' * 64,
        artifactByteLength: bytes.length,
        signerKeyId: 'pilot-key',
        signatureBase64: 'signature',
        requiresHardwareAcceleration: false,
      );
      final cache = InMemoryEdgeArtifactCache();
      final store = EdgeArtifactStore(cache: cache);

      await expectLater(
        store.download(
          manifest,
          downloader: MemoryEdgeArtifactDownloader(bytes),
        ),
        throwsA(
          isA<EdgeArtifactException>().having(
            (error) => error.code,
            'code',
            'ARTIFACT_HASH_MISMATCH',
          ),
        ),
      );
      expect(await cache.partialLength(manifest.modelId), bytes.length);
    },
  );

  test(
    'artifact store cancels before reading and enforces manifest size',
    () async {
      final token = EdgeArtifactCancellationToken()..cancel();
      final bytes = <int>[1, 2, 3];
      final manifest = EdgeModelManifest(
        manifestId: 'm1-cancel-manifest',
        modelId: 'm1-cancel-model',
        modelVersion: '1.0.0',
        platform: 'android',
        artifactUri: 'https://models.example.invalid/cancel.bin',
        artifactSha256: sha256.convert(bytes).toString(),
        artifactByteLength: 1,
        signerKeyId: 'pilot-key',
        signatureBase64: 'signature',
        requiresHardwareAcceleration: false,
      );
      final downloader = MemoryEdgeArtifactDownloader(bytes);
      final store = EdgeArtifactStore(cache: InMemoryEdgeArtifactCache());

      await expectLater(
        store.download(manifest, downloader: downloader, cancellation: token),
        throwsA(
          isA<EdgeArtifactException>().having(
            (error) => error.code,
            'code',
            'ARTIFACT_DOWNLOAD_CANCELLED',
          ),
        ),
      );
      expect(downloader.openCalls, 0);
    },
  );
}
