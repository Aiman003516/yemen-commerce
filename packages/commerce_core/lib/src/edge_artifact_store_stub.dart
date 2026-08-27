import 'edge_artifact_store.dart';

class FileEdgeArtifactCache implements EdgeArtifactCache {
  const FileEdgeArtifactCache();

  EdgeArtifactException _unsupported() => const EdgeArtifactException(
    code: 'ARTIFACT_STORAGE_UNAVAILABLE',
    messageAr: 'التخزين المحلي للنموذج غير متاح في هذا التطبيق.',
  );

  @override
  Future<int> partialLength(String artifactId) async => throw _unsupported();

  @override
  Future<List<int>> readPartial(String artifactId) async =>
      throw _unsupported();

  @override
  Future<void> appendPartial(String artifactId, List<int> bytes) async =>
      throw _unsupported();

  @override
  Future<void> discardPartial(String artifactId) async => throw _unsupported();

  @override
  Future<void> commit(
    EdgeArtifactCacheEntry entry,
    List<int> verifiedBytes,
  ) async => throw _unsupported();

  @override
  Future<EdgeArtifactCacheEntry?> readEntry(String artifactId) async =>
      throw _unsupported();

  @override
  Future<List<int>?> readCommitted(EdgeArtifactCacheEntry entry) async =>
      throw _unsupported();

  @override
  Future<void> delete(String artifactId) async => throw _unsupported();
}

class HttpEdgeArtifactDownloader implements EdgeArtifactDownloader {
  const HttpEdgeArtifactDownloader();

  @override
  Stream<List<int>> open(
    Uri uri, {
    required int startAt,
    EdgeArtifactCancellationToken? cancellation,
  }) async* {
    throw const EdgeArtifactException(
      code: 'ARTIFACT_DOWNLOAD_UNAVAILABLE',
      messageAr: 'تنزيل النماذج المحلية متوقف في تطبيق الويب.',
    );
  }
}
