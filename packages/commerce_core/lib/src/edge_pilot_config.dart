import 'dart:convert';

import 'edge_pilot.dart';

/// Reads only public pilot configuration from build-time defines. It contains
/// no secret material: the trusted key is a public verification key and the
/// manifest is still rejected unless its signature and device policy pass.
abstract final class EdgePilotBuildConfig {
  static const _manifestJson = String.fromEnvironment(
    'EDGE_MODEL_MANIFEST_JSON',
    defaultValue: '',
  );
  static const _manifestBase64 = String.fromEnvironment(
    'EDGE_MODEL_MANIFEST_B64',
    defaultValue: '',
  );
  static const trustedKeyId = String.fromEnvironment(
    'EDGE_MODEL_TRUSTED_KEY_ID',
    defaultValue: '',
  );
  static const trustedPublicKeyBase64 = String.fromEnvironment(
    'EDGE_MODEL_TRUSTED_PUBLIC_KEY_B64',
    defaultValue: '',
  );

  static EdgeModelManifest? get manifest {
    final source = _manifestBase64.trim().isNotEmpty
        ? _decodeManifestBase64()
        : _manifestJson;
    if (source.trim().isEmpty) return null;
    try {
      final value = jsonDecode(source);
      if (value is! Map) return null;
      return EdgeModelManifest.fromJson(Map<String, dynamic>.from(value));
    } catch (_) {
      return null;
    }
  }

  static String _decodeManifestBase64() {
    try {
      return utf8.decode(
        base64Url.decode(base64Url.normalize(_manifestBase64.trim())),
      );
    } catch (_) {
      return '';
    }
  }

  static Map<String, String> get trustedPublicKeys {
    if (trustedKeyId.trim().isEmpty || trustedPublicKeyBase64.trim().isEmpty) {
      return const <String, String>{};
    }
    return <String, String>{trustedKeyId: trustedPublicKeyBase64};
  }
}
