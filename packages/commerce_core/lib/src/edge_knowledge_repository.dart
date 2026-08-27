import 'edge_assistant.dart';
import 'edge_knowledge_pack.dart';

class EdgeKnowledgeQueryResult {
  const EdgeKnowledgeQueryResult({
    required this.document,
    required this.provenance,
  });

  final EdgeKnowledgeDocument document;
  final EdgeProposalProvenance provenance;
}

class EdgeKnowledgePackRepository {
  EdgeKnowledgePackRepository({required this.verifier});

  final EdgeKnowledgePackVerifier verifier;
  final EdgeKnowledgePackParser parser = const EdgeKnowledgePackParser();
  final Map<String, EdgeKnowledgePack> _packs = {};

  Future<EdgeKnowledgePackVerification> install(
    EdgeKnowledgePackManifest manifest,
    List<int> bytes,
  ) async {
    final verification = await verifier.verify(manifest, bytes);
    if (!verification.isValid) return verification;
    try {
      final pack = parser.parse(manifest, bytes);
      _packs[manifest.packId] = pack;
      return verification;
    } catch (_) {
      return const EdgeKnowledgePackVerification(
        isValid: false,
        code: 'INVALID_KNOWLEDGE_DOCUMENTS',
        messageAr: 'محتوى حزمة المعرفة المحلية غير صالح.',
      );
    }
  }

  EdgeKnowledgeQueryResult? query(String topicKey, {DateTime? now}) {
    if (!EdgeKnowledgeTopicCatalog.contains(topicKey)) return null;
    final current = now ?? DateTime.now().toUtc();
    for (final pack in _packs.values) {
      if (!pack.manifest.expiresAt.isAfter(current)) continue;
      final document = pack.forTopic(topicKey);
      if (document == null) continue;
      return EdgeKnowledgeQueryResult(
        document: document,
        provenance: EdgeProposalProvenance(
          source: 'local_knowledge_pack',
          retrievedAt: current,
          packId: pack.manifest.packId,
          packVersion: pack.manifest.version,
          expiresAt: pack.manifest.expiresAt,
        ),
      );
    }
    return null;
  }

  void clear() => _packs.clear();
}
