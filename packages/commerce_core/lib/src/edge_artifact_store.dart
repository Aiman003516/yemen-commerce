import 'dart:async';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'edge_pilot.dart';

/// Shared hard limits for model and knowledge-pack artifacts.
abstract final class EdgeArtifactPolicy {
  static const maxBytes = 2 * 1024 * 1024 * 1024;
  static const maxArtifactIdLength = 120;
  static const allowedDownloadSchemes = {'https', 'asset', 'file'};

  static String? validateManifest(EdgeModelManifest manifest) {
    final idPattern = RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9._-]{1,119}$');
    final hashPattern = RegExp(r'^[a-fA-F0-9]{64}$');
    final uri = Uri.tryParse(manifest.artifactUri);
    if (!idPattern.hasMatch(manifest.manifestId) ||
        !idPattern.hasMatch(manifest.modelId) ||
        !idPattern.hasMatch(manifest.modelVersion)) {
      return 'INVALID_ARTIFACT_ID';
    }
    if (uri == null ||
        manifest.artifactUri.length > 2000 ||
        !allowedDownloadSchemes.contains(uri.scheme)) {
      return 'INVALID_ARTIFACT_URI';
    }
    if (!hashPattern.hasMatch(manifest.artifactSha256.toLowerCase())) {
      return 'INVALID_ARTIFACT_HASH';
    }
    final expectedBytes = manifest.artifactByteLength;
    if (expectedBytes != null &&
        (expectedBytes <= 0 || expectedBytes > maxBytes)) {
      return 'ARTIFACT_SIZE_LIMIT';
    }
    return null;
  }
}

class EdgeArtifactCancellationToken {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() => _cancelled = true;

  void throwIfCancelled() {
    if (_cancelled) {
      throw const EdgeArtifactException(
        code: 'ARTIFACT_DOWNLOAD_CANCELLED',
        messageAr: 'تم إلغاء تنزيل الملف المحلي.',
      );
    }
  }
}

class EdgeArtifactProgress {
  const EdgeArtifactProgress({
    required this.artifactId,
    required this.bytesReceived,
    required this.expectedBytes,
  });

  final String artifactId;
  final int bytesReceived;
  final int? expectedBytes;

  double? get fraction => expectedBytes == null || expectedBytes == 0
      ? null
      : (bytesReceived / expectedBytes!).clamp(0, 1).toDouble();
}

class EdgeArtifactCacheEntry {
  const EdgeArtifactCacheEntry({
    required this.artifactId,
    required this.manifestId,
    required this.modelVersion,
    required this.localPath,
    required this.sha256,
    required this.byteLength,
    required this.committedAt,
  });

  final String artifactId;
  final String manifestId;
  final String modelVersion;
  final String localPath;
  final String sha256;
  final int byteLength;
  final DateTime committedAt;

  Map<String, dynamic> toJson() => {
    'artifact_id': artifactId,
    'manifest_id': manifestId,
    'model_version': modelVersion,
    'local_path': localPath,
    'sha256': sha256,
    'byte_length': byteLength,
    'committed_at': committedAt.toUtc().toIso8601String(),
  };

  factory EdgeArtifactCacheEntry.fromJson(Map<String, dynamic> json) =>
      EdgeArtifactCacheEntry(
        artifactId: json['artifact_id']?.toString() ?? '',
        manifestId: json['manifest_id']?.toString() ?? '',
        modelVersion: json['model_version']?.toString() ?? '',
        localPath: json['local_path']?.toString() ?? '',
        sha256: json['sha256']?.toString() ?? '',
        byteLength: (json['byte_length'] as num?)?.toInt() ?? 0,
        committedAt:
            DateTime.tryParse(json['committed_at']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );
}

class EdgeArtifactException implements Exception {
  const EdgeArtifactException({
    required this.code,
    required this.messageAr,
    this.retryable = false,
  });

  final String code;
  final String messageAr;
  final bool retryable;

  @override
  String toString() => '$code: $messageAr';
}

abstract interface class EdgeArtifactDownloader {
  Stream<List<int>> open(
    Uri uri, {
    required int startAt,
    EdgeArtifactCancellationToken? cancellation,
  });
}

abstract interface class EdgeArtifactCache {
  Future<int> partialLength(String artifactId);

  Future<List<int>> readPartial(String artifactId);

  Future<void> appendPartial(String artifactId, List<int> bytes);

  Future<void> discardPartial(String artifactId);

  Future<void> commit(EdgeArtifactCacheEntry entry, List<int> verifiedBytes);

  Future<EdgeArtifactCacheEntry?> readEntry(String artifactId);

  Future<List<int>?> readCommitted(EdgeArtifactCacheEntry entry);

  Future<void> delete(String artifactId);
}

/// A bounded artifact manager. It never exposes bytes to the runtime until the
/// complete artifact has passed expected-size and SHA-256 verification.
class EdgeArtifactStore {
  EdgeArtifactStore({required this.cache});

  final EdgeArtifactCache cache;

  Future<EdgeArtifactCacheEntry?> findVerified(
    EdgeModelManifest manifest,
  ) async {
    final structuralError = EdgeArtifactPolicy.validateManifest(manifest);
    if (structuralError != null) return null;
    final entry = await cache.readEntry(manifest.modelId);
    if (entry == null ||
        entry.manifestId != manifest.manifestId ||
        entry.modelVersion != manifest.modelVersion ||
        entry.sha256.toLowerCase() != manifest.artifactSha256.toLowerCase()) {
      return null;
    }
    final bytes = await cache.readCommitted(entry);
    if (bytes == null || !_matches(manifest, bytes)) {
      await cache.delete(manifest.modelId);
      return null;
    }
    return entry;
  }

  Future<EdgeArtifactCacheEntry> download(
    EdgeModelManifest manifest, {
    required EdgeArtifactDownloader downloader,
    EdgeArtifactCancellationToken? cancellation,
    void Function(EdgeArtifactProgress progress)? onProgress,
    bool resume = true,
  }) async {
    final structuralError = EdgeArtifactPolicy.validateManifest(manifest);
    if (structuralError != null) {
      throw EdgeArtifactException(
        code: structuralError,
        messageAr: 'بيانات ملف النموذج غير صالحة أو تتجاوز الحد المسموح.',
      );
    }
    final token = cancellation ?? EdgeArtifactCancellationToken();
    token.throwIfCancelled();
    final artifactId = manifest.modelId;
    final expectedBytes = manifest.artifactByteLength;
    var partial = resume ? await cache.readPartial(artifactId) : <int>[];
    if (expectedBytes != null && partial.length > expectedBytes) {
      await cache.discardPartial(artifactId);
      partial = <int>[];
    }
    if (partial.isNotEmpty) {
      onProgress?.call(
        EdgeArtifactProgress(
          artifactId: artifactId,
          bytesReceived: partial.length,
          expectedBytes: expectedBytes,
        ),
      );
    }

    try {
      await for (final chunk in downloader.open(
        Uri.parse(manifest.artifactUri),
        startAt: partial.length,
        cancellation: token,
      )) {
        token.throwIfCancelled();
        if (chunk.isEmpty) continue;
        final nextLength = partial.length + chunk.length;
        if (nextLength > EdgeArtifactPolicy.maxBytes ||
            expectedBytes != null && nextLength > expectedBytes) {
          throw const EdgeArtifactException(
            code: 'ARTIFACT_SIZE_LIMIT',
            messageAr: 'تم رفض الملف لأنه يتجاوز الحجم المسموح.',
          );
        }
        await cache.appendPartial(artifactId, chunk);
        partial = <int>[...partial, ...chunk];
        onProgress?.call(
          EdgeArtifactProgress(
            artifactId: artifactId,
            bytesReceived: partial.length,
            expectedBytes: expectedBytes,
          ),
        );
      }
      token.throwIfCancelled();
      if (expectedBytes != null && partial.length != expectedBytes) {
        throw const EdgeArtifactException(
          code: 'ARTIFACT_LENGTH_MISMATCH',
          messageAr: 'اكتمل التنزيل بحجم لا يطابق manifest الموثوق.',
          retryable: true,
        );
      }
      if (!_matches(manifest, partial)) {
        throw const EdgeArtifactException(
          code: 'ARTIFACT_HASH_MISMATCH',
          messageAr: 'فشل التحقق من سلامة الملف المحلي.',
        );
      }
      final entry = EdgeArtifactCacheEntry(
        artifactId: artifactId,
        manifestId: manifest.manifestId,
        modelVersion: manifest.modelVersion,
        localPath: 'edge-artifact://$artifactId',
        sha256: manifest.artifactSha256.toLowerCase(),
        byteLength: partial.length,
        committedAt: DateTime.now().toUtc(),
      );
      await cache.commit(entry, partial);
      await cache.discardPartial(artifactId);
      return entry;
    } on EdgeArtifactException {
      rethrow;
    } catch (_) {
      throw const EdgeArtifactException(
        code: 'ARTIFACT_DOWNLOAD_FAILED',
        messageAr: 'تعذر تنزيل الملف المحلي. يمكن إعادة المحاولة لاحقاً.',
        retryable: true,
      );
    }
  }

  bool _matches(EdgeModelManifest manifest, List<int> bytes) {
    if (manifest.artifactByteLength != null &&
        manifest.artifactByteLength != bytes.length) {
      return false;
    }
    return sha256.convert(Uint8List.fromList(bytes)).toString() ==
        manifest.artifactSha256.toLowerCase();
  }
}

class InMemoryEdgeArtifactCache implements EdgeArtifactCache {
  final Map<String, List<int>> _partials = {};
  final Map<String, EdgeArtifactCacheEntry> _entries = {};
  final Map<String, List<int>> _committed = {};

  @override
  Future<int> partialLength(String artifactId) async =>
      _partials[artifactId]?.length ?? 0;

  @override
  Future<List<int>> readPartial(String artifactId) async =>
      List<int>.from(_partials[artifactId] ?? const []);

  @override
  Future<void> appendPartial(String artifactId, List<int> bytes) async =>
      (_partials[artifactId] ??= <int>[]).addAll(bytes);

  @override
  Future<void> discardPartial(String artifactId) async =>
      _partials.remove(artifactId);

  @override
  Future<void> commit(
    EdgeArtifactCacheEntry entry,
    List<int> verifiedBytes,
  ) async {
    _committed[entry.artifactId] = List<int>.from(verifiedBytes);
    _entries[entry.artifactId] = entry;
  }

  @override
  Future<EdgeArtifactCacheEntry?> readEntry(String artifactId) async =>
      _entries[artifactId];

  @override
  Future<List<int>?> readCommitted(EdgeArtifactCacheEntry entry) async =>
      _committed[entry.artifactId] == null
      ? null
      : List<int>.from(_committed[entry.artifactId]!);

  @override
  Future<void> delete(String artifactId) async {
    _entries.remove(artifactId);
    _committed.remove(artifactId);
  }
}

class MemoryEdgeArtifactDownloader implements EdgeArtifactDownloader {
  MemoryEdgeArtifactDownloader(this.bytes, {this.chunkSize = 4});

  final List<int> bytes;
  final int chunkSize;
  int openCalls = 0;
  final List<int> requestedOffsets = [];

  @override
  Stream<List<int>> open(
    Uri uri, {
    required int startAt,
    EdgeArtifactCancellationToken? cancellation,
  }) async* {
    openCalls++;
    requestedOffsets.add(startAt);
    if (startAt > bytes.length) return;
    for (var offset = startAt; offset < bytes.length; offset += chunkSize) {
      cancellation?.throwIfCancelled();
      await Future<void>.delayed(Duration.zero);
      yield bytes.sublist(offset, (offset + chunkSize).clamp(0, bytes.length));
    }
  }
}
