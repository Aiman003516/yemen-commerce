import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'edge_artifact_store.dart';

class FileEdgeArtifactCache implements EdgeArtifactCache {
  FileEdgeArtifactCache({Directory? root}) : _root = root;

  final Directory? _root;
  Directory? _resolvedRoot;

  Future<Directory> _directory() async {
    final existing = _resolvedRoot;
    if (existing != null) return existing;
    final root =
        _root ??
        Directory(
          '${(await getApplicationSupportDirectory()).path}/edge_artifacts_v1',
        );
    await root.create(recursive: true);
    _resolvedRoot = root;
    return root;
  }

  String _safe(String artifactId) =>
      artifactId.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');

  Future<File> _file(String artifactId, String suffix) async =>
      File('${(await _directory()).path}/${_safe(artifactId)}$suffix');

  @override
  Future<int> partialLength(String artifactId) async =>
      (await readPartial(artifactId)).length;

  @override
  Future<List<int>> readPartial(String artifactId) async {
    final file = await _file(artifactId, '.part');
    if (!await file.exists()) return <int>[];
    return file.readAsBytes();
  }

  @override
  Future<void> appendPartial(String artifactId, List<int> bytes) async {
    final file = await _file(artifactId, '.part');
    final sink = file.openWrite(mode: FileMode.append);
    try {
      sink.add(bytes);
    } finally {
      await sink.close();
    }
  }

  @override
  Future<void> discardPartial(String artifactId) async {
    final file = await _file(artifactId, '.part');
    if (await file.exists()) await file.delete();
  }

  @override
  Future<void> commit(
    EdgeArtifactCacheEntry entry,
    List<int> verifiedBytes,
  ) async {
    final finalFile = await _file(entry.artifactId, '.artifact');
    final tempFile = await _file(entry.artifactId, '.artifact.tmp');
    final metadataFile = await _file(entry.artifactId, '.json');
    final metadataTemp = await _file(entry.artifactId, '.json.tmp');

    await tempFile.writeAsBytes(verifiedBytes, flush: true);
    if (await finalFile.exists()) await finalFile.delete();
    await tempFile.rename(finalFile.path);

    final storedEntry = EdgeArtifactCacheEntry(
      artifactId: entry.artifactId,
      manifestId: entry.manifestId,
      modelVersion: entry.modelVersion,
      localPath: finalFile.path,
      sha256: entry.sha256,
      byteLength: entry.byteLength,
      committedAt: entry.committedAt,
    );
    await metadataTemp.writeAsString(
      jsonEncode(storedEntry.toJson()),
      flush: true,
    );
    if (await metadataFile.exists()) await metadataFile.delete();
    await metadataTemp.rename(metadataFile.path);
  }

  @override
  Future<EdgeArtifactCacheEntry?> readEntry(String artifactId) async {
    final metadataFile = await _file(artifactId, '.json');
    if (!await metadataFile.exists()) return null;
    try {
      final decoded = jsonDecode(await metadataFile.readAsString());
      if (decoded is! Map) return null;
      final entry = EdgeArtifactCacheEntry.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      final root = (await _directory()).absolute;
      final artifactFile = File(entry.localPath).absolute;
      final rootPrefix = '${root.path}${Platform.pathSeparator}';
      if (!artifactFile.path.startsWith(rootPrefix) ||
          !await artifactFile.exists()) {
        return null;
      }
      return entry;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<int>?> readCommitted(EdgeArtifactCacheEntry entry) async {
    try {
      final file = File(entry.localPath);
      if (!await file.exists()) return null;
      return await file.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> delete(String artifactId) async {
    for (final suffix in const [
      '.part',
      '.artifact',
      '.json',
      '.artifact.tmp',
      '.json.tmp',
    ]) {
      final file = await _file(artifactId, suffix);
      if (await file.exists()) await file.delete();
    }
  }
}

class HttpEdgeArtifactDownloader implements EdgeArtifactDownloader {
  HttpEdgeArtifactDownloader({HttpClient? client})
    : _client = client ?? HttpClient();

  final HttpClient _client;

  @override
  Stream<List<int>> open(
    Uri uri, {
    required int startAt,
    EdgeArtifactCancellationToken? cancellation,
  }) async* {
    if (uri.scheme != 'https' || uri.userInfo.isNotEmpty || uri.host.isEmpty) {
      throw const EdgeArtifactException(
        code: 'INVALID_ARTIFACT_URI',
        messageAr: 'لا يسمح بتنزيل الملف إلا من عنوان HTTPS موثوق.',
      );
    }
    cancellation?.throwIfCancelled();
    final request = await _client.getUrl(uri);
    request.followRedirects = false;
    if (startAt > 0)
      request.headers.set(HttpHeaders.rangeHeader, 'bytes=$startAt-');
    final response = await request.close();
    if (response.isRedirect) {
      throw const EdgeArtifactException(
        code: 'ARTIFACT_REDIRECT_BLOCKED',
        messageAr: 'تم حظر إعادة توجيه تنزيل الملف المحلي.',
      );
    }
    if (response.statusCode != HttpStatus.ok &&
        !(startAt > 0 && response.statusCode == HttpStatus.partialContent)) {
      throw EdgeArtifactException(
        code: 'ARTIFACT_HTTP_${response.statusCode}',
        messageAr: 'تعذر تنزيل الملف المحلي من المصدر الموثوق.',
        retryable: response.statusCode >= 500,
      );
    }
    if (startAt > 0 && response.statusCode != HttpStatus.partialContent) {
      throw const EdgeArtifactException(
        code: 'RESUME_NOT_SUPPORTED',
        messageAr: 'لا يدعم المصدر استكمال التنزيل بأمان.',
        retryable: true,
      );
    }
    await for (final chunk in response) {
      cancellation?.throwIfCancelled();
      yield chunk;
    }
  }
}
