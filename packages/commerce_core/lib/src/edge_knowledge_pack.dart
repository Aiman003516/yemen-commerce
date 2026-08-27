import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';

import 'edge_assistant.dart';

class EdgeKnowledgePackManifest {
  const EdgeKnowledgePackManifest({
    required this.packId,
    required this.version,
    required this.locale,
    required this.sha256,
    required this.byteLength,
    required this.signerKeyId,
    required this.signatureBase64,
    required this.expiresAt,
    required this.topics,
  });

  final String packId;
  final String version;
  final String locale;
  final String sha256;
  final int byteLength;
  final String signerKeyId;
  final String signatureBase64;
  final DateTime expiresAt;
  final List<String> topics;

  Map<String, dynamic> get canonicalPayload => EdgeCanonicalJson.normalize({
    'pack_id': packId,
    'version': version,
    'locale': locale,
    'sha256': sha256,
    'byte_length': byteLength,
    'expires_at': expiresAt.toUtc().toIso8601String(),
    'topics': [...topics]..sort(),
  }) as Map<String, dynamic>;

  String get canonicalJson => EdgeCanonicalJson.encode(canonicalPayload);

  Map<String, dynamic> toJson() => {
    ...canonicalPayload,
    'signer_key_id': signerKeyId,
    'signature_base64': signatureBase64,
  };
}

class EdgeKnowledgeDocument {
  const EdgeKnowledgeDocument({
    required this.documentId,
    required this.topicKey,
    required this.titleAr,
    required this.bodyAr,
    this.keywords = const [],
  });

  final String documentId;
  final String topicKey;
  final String titleAr;
  final String bodyAr;
  final List<String> keywords;

  Map<String, dynamic> toJson() => {
    'document_id': documentId,
    'topic_key': topicKey,
    'title_ar': titleAr,
    'body_ar': bodyAr,
    'keywords': keywords,
  };

  factory EdgeKnowledgeDocument.fromJson(Map<String, dynamic> json) =>
      EdgeKnowledgeDocument(
        documentId: json['document_id']?.toString() ?? '',
        topicKey: json['topic_key']?.toString() ?? '',
        titleAr: json['title_ar']?.toString() ?? '',
        bodyAr: json['body_ar']?.toString() ?? '',
        keywords: (json['keywords'] as List<dynamic>? ?? const [])
            .map((value) => value.toString())
            .toList(growable: false),
      );
}

class EdgeKnowledgePack {
  const EdgeKnowledgePack({required this.manifest, required this.documents});

  final EdgeKnowledgePackManifest manifest;
  final List<EdgeKnowledgeDocument> documents;

  EdgeKnowledgeDocument? forTopic(String topicKey) {
    if (!EdgeKnowledgeTopicCatalog.contains(topicKey)) return null;
    for (final document in documents) {
      if (document.topicKey == topicKey) return document;
    }
    return null;
  }
}

class EdgeKnowledgePackVerification {
  const EdgeKnowledgePackVerification({
    required this.isValid,
    required this.code,
    required this.messageAr,
  });

  final bool isValid;
  final String code;
  final String messageAr;
}

class EdgeKnowledgePackVerifier {
  EdgeKnowledgePackVerifier({required Map<String, String> trustedPublicKeys})
    : _trustedPublicKeys = Map.unmodifiable(trustedPublicKeys);

  final Map<String, String> _trustedPublicKeys;
  final _algorithm = Ed25519();

  Future<EdgeKnowledgePackVerification> verify(
    EdgeKnowledgePackManifest manifest,
    List<int> bytes,
  ) async {
    final idPattern = RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9._-]{1,119}$');
    final hashPattern = RegExp(r'^[a-fA-F0-9]{64}$');
    if (!idPattern.hasMatch(manifest.packId) ||
        !idPattern.hasMatch(manifest.version) ||
        manifest.locale != 'ar-YE' ||
        !hashPattern.hasMatch(manifest.sha256) ||
        manifest.byteLength <= 0 ||
        manifest.byteLength != bytes.length ||
        manifest.expiresAt.isBefore(DateTime.now().toUtc())) {
      return const EdgeKnowledgePackVerification(
        isValid: false,
        code: 'INVALID_KNOWLEDGE_PACK',
        messageAr: 'حزمة المعرفة المحلية غير صالحة أو منتهية.',
      );
    }
    if (sha256.convert(Uint8List.fromList(bytes)).toString() !=
        manifest.sha256.toLowerCase()) {
      return const EdgeKnowledgePackVerification(
        isValid: false,
        code: 'KNOWLEDGE_PACK_HASH_MISMATCH',
        messageAr: 'فشل التحقق من سلامة حزمة المعرفة المحلية.',
      );
    }
    final publicKeyText = _trustedPublicKeys[manifest.signerKeyId];
    if (publicKeyText == null) {
      return const EdgeKnowledgePackVerification(
        isValid: false,
        code: 'UNTRUSTED_KNOWLEDGE_SIGNER',
        messageAr: 'حزمة المعرفة ليست موقعة بمفتاح موثوق.',
      );
    }
    try {
      final publicKey = SimplePublicKey(
        base64Url.decode(base64Url.normalize(publicKeyText)),
        type: KeyPairType.ed25519,
      );
      final signature = Signature(
        base64Url.decode(base64Url.normalize(manifest.signatureBase64)),
        publicKey: publicKey,
      );
      final valid = await _algorithm.verify(
        utf8.encode(manifest.canonicalJson),
        signature: signature,
      );
      return valid
          ? const EdgeKnowledgePackVerification(
              isValid: true,
              code: 'VERIFIED',
              messageAr: 'تم التحقق من حزمة المعرفة المحلية.',
            )
          : const EdgeKnowledgePackVerification(
              isValid: false,
              code: 'INVALID_KNOWLEDGE_SIGNATURE',
              messageAr: 'توقيع حزمة المعرفة المحلية غير صالح.',
            );
    } catch (_) {
      return const EdgeKnowledgePackVerification(
        isValid: false,
        code: 'INVALID_KNOWLEDGE_SIGNATURE_FORMAT',
        messageAr: 'صيغة توقيع حزمة المعرفة المحلية غير صالحة.',
      );
    }
  }
}

class EdgeKnowledgePackParser {
  const EdgeKnowledgePackParser();

  EdgeKnowledgePack parse(EdgeKnowledgePackManifest manifest, List<int> bytes) {
    if (bytes.length > 2 * 1024 * 1024) {
      throw const FormatException('knowledge pack too large');
    }
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map || decoded['documents'] is! List) {
      throw const FormatException('invalid knowledge pack document');
    }
    final documents = (decoded['documents'] as List<dynamic>)
        .whereType<Map>()
        .map(
          (value) =>
              EdgeKnowledgeDocument.fromJson(Map<String, dynamic>.from(value)),
        )
        .toList(growable: false);
    if (documents.length > 500 ||
        documents.any(
          (document) =>
              !EdgeKnowledgeTopicCatalog.contains(document.topicKey) ||
              document.titleAr.length > 200 ||
              document.bodyAr.length > 4000 ||
              document.documentId.length > 120,
        )) {
      throw const FormatException('invalid knowledge pack limits');
    }
    return EdgeKnowledgePack(manifest: manifest, documents: documents);
  }
}
