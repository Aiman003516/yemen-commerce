import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'edge_assistant.dart';
import 'edge_runtime.dart';

enum EdgePilotOptInState {
  disabled('disabled'),
  enabled('enabled'),
  suspended('suspended');

  const EdgePilotOptInState(this.value);
  final String value;
}

class EdgeDeviceCapabilities {
  const EdgeDeviceCapabilities({
    required this.platform,
    required this.osVersion,
    required this.deviceModel,
    required this.memoryMb,
    required this.supportsNativeRuntime,
    required this.supportsHardwareAcceleration,
    this.isLowPowerMode = false,
    this.isMeteredNetwork = false,
  });

  final String platform;
  final String osVersion;
  final String deviceModel;
  final int memoryMb;
  final bool supportsNativeRuntime;
  final bool supportsHardwareAcceleration;
  final bool isLowPowerMode;
  final bool isMeteredNetwork;

  Map<String, dynamic> toJson() => {
    'platform': platform,
    'os_version': osVersion,
    'device_model': deviceModel,
    'memory_mb': memoryMb,
    'supports_native_runtime': supportsNativeRuntime,
    'supports_hardware_acceleration': supportsHardwareAcceleration,
    'is_low_power_mode': isLowPowerMode,
    'is_metered_network': isMeteredNetwork,
  };

  factory EdgeDeviceCapabilities.fromJson(Map<String, dynamic> json) =>
      EdgeDeviceCapabilities(
        platform: json['platform']?.toString() ?? 'unknown',
        osVersion: json['os_version']?.toString() ?? '0.0.0',
        deviceModel: json['device_model']?.toString() ?? 'unknown',
        memoryMb: (json['memory_mb'] as num?)?.toInt() ?? 0,
        supportsNativeRuntime: json['supports_native_runtime'] == true,
        supportsHardwareAcceleration:
            json['supports_hardware_acceleration'] == true,
        isLowPowerMode: json['is_low_power_mode'] == true,
        isMeteredNetwork: json['is_metered_network'] == true,
      );

  EdgeCapabilityDecision evaluate(EdgeModelManifest manifest) {
    final reasons = <String>[];
    if (manifest.platform != 'any' && manifest.platform != platform) {
      reasons.add('PLATFORM_UNSUPPORTED');
    }
    if (!supportsNativeRuntime) reasons.add('NATIVE_RUNTIME_UNAVAILABLE');
    if (manifest.requiresHardwareAcceleration &&
        !supportsHardwareAcceleration) {
      reasons.add('HARDWARE_ACCELERATION_REQUIRED');
    }
    if (memoryMb < manifest.minMemoryMb) reasons.add('INSUFFICIENT_MEMORY');
    if (manifest.minOsVersion != null &&
        EdgeVersion.compare(osVersion, manifest.minOsVersion!) < 0) {
      reasons.add('OS_VERSION_UNSUPPORTED');
    }
    if (isLowPowerMode && manifest.disallowLowPowerMode) {
      reasons.add('LOW_POWER_MODE');
    }
    if (isMeteredNetwork && manifest.requiresNetworkDownload) {
      reasons.add('METERED_DOWNLOAD_BLOCKED');
    }
    return EdgeCapabilityDecision(
      isEligible: reasons.isEmpty,
      reasons: reasons,
      messageAr: reasons.isEmpty
          ? 'الجهاز مؤهل لتجربة النموذج المحلي.'
          : 'الجهاز غير مؤهل لتجربة النموذج المحلي حالياً.',
    );
  }

  factory EdgeDeviceCapabilities.fromRuntimeStatus(
    EdgeRuntimeStatus status, {
    String osVersion = '0.0.0',
    String deviceModel = 'unknown',
    int memoryMb = 0,
    bool supportsHardwareAcceleration = false,
    bool isLowPowerMode = false,
    bool isMeteredNetwork = false,
  }) => EdgeDeviceCapabilities(
    platform: status.platform,
    osVersion: osVersion,
    deviceModel: deviceModel,
    memoryMb: memoryMb,
    supportsNativeRuntime: status.isAvailable,
    supportsHardwareAcceleration: supportsHardwareAcceleration,
    isLowPowerMode: isLowPowerMode,
    isMeteredNetwork: isMeteredNetwork,
  );
}

class EdgeDeviceCapabilityProbe {
  EdgeDeviceCapabilityProbe({MethodChannel? channel})
    : _channel =
          channel ?? const MethodChannel('com.yemencommerce/edge_runtime.v1');

  final MethodChannel _channel;

  Future<EdgeDeviceCapabilities> read() async {
    try {
      final value = await _channel.invokeMethod<Object?>('capabilities');
      return EdgeDeviceCapabilities.fromJson(
        value is Map ? Map<String, dynamic>.from(value) : const {},
      );
    } on MissingPluginException {
      return _unknown();
    } on PlatformException {
      return _unknown();
    }
  }

  EdgeDeviceCapabilities _unknown() => const EdgeDeviceCapabilities(
    platform: 'unknown',
    osVersion: '0.0.0',
    deviceModel: 'unknown',
    memoryMb: 0,
    supportsNativeRuntime: false,
    supportsHardwareAcceleration: false,
  );
}

class EdgeCapabilityDecision {
  const EdgeCapabilityDecision({
    required this.isEligible,
    required this.reasons,
    required this.messageAr,
  });

  final bool isEligible;
  final List<String> reasons;
  final String messageAr;
}

class EdgeModelManifest {
  const EdgeModelManifest({
    required this.manifestId,
    required this.modelId,
    required this.modelVersion,
    required this.platform,
    required this.artifactUri,
    required this.artifactSha256,
    required this.signerKeyId,
    required this.signatureBase64,
    this.minOsVersion,
    this.minMemoryMb = 2048,
    this.requiredLocales = const ['ar-YE'],
    this.requiresHardwareAcceleration = true,
    this.requiresNetworkDownload = true,
    this.disallowLowPowerMode = true,
    this.enabled = true,
    this.readOnlyOnly = true,
  });

  final String manifestId;
  final String modelId;
  final String modelVersion;
  final String platform;
  final String artifactUri;
  final String artifactSha256;
  final String signerKeyId;
  final String signatureBase64;
  final String? minOsVersion;
  final int minMemoryMb;
  final List<String> requiredLocales;
  final bool requiresHardwareAcceleration;
  final bool requiresNetworkDownload;
  final bool disallowLowPowerMode;
  final bool enabled;
  final bool readOnlyOnly;

  Map<String, dynamic> get canonicalPayload => EdgeCanonicalJson.normalize({
    'manifest_id': manifestId,
    'model_id': modelId,
    'model_version': modelVersion,
    'platform': platform,
    'artifact_uri': artifactUri,
    'artifact_sha256': artifactSha256,
    'min_os_version': minOsVersion,
    'min_memory_mb': minMemoryMb,
    'required_locales': requiredLocales,
    'requires_hardware_acceleration': requiresHardwareAcceleration,
    'requires_network_download': requiresNetworkDownload,
    'disallow_low_power_mode': disallowLowPowerMode,
    'enabled': enabled,
    'read_only_only': readOnlyOnly,
  }) as Map<String, dynamic>;

  String get canonicalJson => EdgeCanonicalJson.encode(canonicalPayload);

  Map<String, dynamic> toJson() => {
    ...canonicalPayload,
    'signer_key_id': signerKeyId,
    'signature_base64': signatureBase64,
  };

  factory EdgeModelManifest.fromJson(Map<String, dynamic> json) =>
      EdgeModelManifest(
        manifestId: json['manifest_id']?.toString() ?? '',
        modelId: json['model_id']?.toString() ?? '',
        modelVersion: json['model_version']?.toString() ?? '',
        platform: json['platform']?.toString() ?? 'any',
        artifactUri: json['artifact_uri']?.toString() ?? '',
        artifactSha256: json['artifact_sha256']?.toString() ?? '',
        signerKeyId: json['signer_key_id']?.toString() ?? '',
        signatureBase64: json['signature_base64']?.toString() ?? '',
        minOsVersion: json['min_os_version']?.toString(),
        minMemoryMb: (json['min_memory_mb'] as num?)?.toInt() ?? 2048,
        requiredLocales:
            (json['required_locales'] as List<dynamic>? ?? const ['ar-YE'])
                .map((value) => value.toString())
                .toList(growable: false),
        requiresHardwareAcceleration:
            json['requires_hardware_acceleration'] != false,
        requiresNetworkDownload: json['requires_network_download'] != false,
        disallowLowPowerMode: json['disallow_low_power_mode'] != false,
        enabled: json['enabled'] != false,
        readOnlyOnly: json['read_only_only'] != false,
      );
}

class EdgeManifestVerificationResult {
  const EdgeManifestVerificationResult({
    required this.isValid,
    required this.code,
    required this.messageAr,
  });

  final bool isValid;
  final String code;
  final String messageAr;
}

abstract interface class EdgeManifestVerifier {
  Future<EdgeManifestVerificationResult> verify(EdgeModelManifest manifest);
}

class EdgeEd25519ManifestVerifier implements EdgeManifestVerifier {
  EdgeEd25519ManifestVerifier({required Map<String, String> trustedPublicKeys})
    : _trustedPublicKeys = Map.unmodifiable(trustedPublicKeys);

  final Map<String, String> _trustedPublicKeys;
  final _algorithm = Ed25519();

  @override
  Future<EdgeManifestVerificationResult> verify(
    EdgeModelManifest manifest,
  ) async {
    final structuralError = _validateStructure(manifest);
    if (structuralError != null) return structuralError;
    final publicKeyText = _trustedPublicKeys[manifest.signerKeyId];
    if (publicKeyText == null) {
      return const EdgeManifestVerificationResult(
        isValid: false,
        code: 'UNTRUSTED_SIGNER',
        messageAr: 'توقيع النموذج غير صادر عن مفتاح موثوق.',
      );
    }
    try {
      final publicKey = SimplePublicKey(
        _decode(publicKeyText),
        type: KeyPairType.ed25519,
      );
      final signature = Signature(
        _decode(manifest.signatureBase64),
        publicKey: publicKey,
      );
      final valid = await _algorithm.verify(
        utf8.encode(manifest.canonicalJson),
        signature: signature,
      );
      return valid
          ? const EdgeManifestVerificationResult(
              isValid: true,
              code: 'VERIFIED',
              messageAr: 'تم التحقق من توقيع manifest النموذج.',
            )
          : const EdgeManifestVerificationResult(
              isValid: false,
              code: 'INVALID_SIGNATURE',
              messageAr: 'توقيع manifest النموذج غير صالح.',
            );
    } catch (_) {
      return const EdgeManifestVerificationResult(
        isValid: false,
        code: 'INVALID_SIGNATURE_FORMAT',
        messageAr: 'صيغة توقيع manifest النموذج غير صالحة.',
      );
    }
  }

  EdgeManifestVerificationResult? _validateStructure(
    EdgeModelManifest manifest,
  ) {
    final idPattern = RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9._-]{1,119}$');
    final hashPattern = RegExp(r'^[a-fA-F0-9]{64}$');
    if (!idPattern.hasMatch(manifest.manifestId) ||
        !idPattern.hasMatch(manifest.modelId) ||
        !idPattern.hasMatch(manifest.modelVersion)) {
      return const EdgeManifestVerificationResult(
        isValid: false,
        code: 'INVALID_MANIFEST_ID',
        messageAr: 'هوية manifest النموذج غير صالحة.',
      );
    }
    if (manifest.platform != 'any' &&
        !{'android', 'ios', 'web'}.contains(manifest.platform)) {
      return const EdgeManifestVerificationResult(
        isValid: false,
        code: 'INVALID_PLATFORM',
        messageAr: 'منصة manifest النموذج غير مدعومة.',
      );
    }
    final uri = Uri.tryParse(manifest.artifactUri);
    if (uri == null ||
        manifest.artifactUri.length > 2000 ||
        !{'https', 'asset', 'file'}.contains(uri.scheme)) {
      return const EdgeManifestVerificationResult(
        isValid: false,
        code: 'INVALID_ARTIFACT_URI',
        messageAr: 'مسار ملف النموذج غير صالح.',
      );
    }
    if (!hashPattern.hasMatch(manifest.artifactSha256) ||
        manifest.minMemoryMb < 512 ||
        manifest.minMemoryMb > 65536 ||
        manifest.requiredLocales.isEmpty ||
        manifest.requiredLocales.length > 10 ||
        manifest.requiredLocales.any((locale) => locale.length > 20)) {
      return const EdgeManifestVerificationResult(
        isValid: false,
        code: 'INVALID_MANIFEST_POLICY',
        messageAr: 'سياسة manifest النموذج غير صالحة.',
      );
    }
    if (!manifest.readOnlyOnly) {
      return const EdgeManifestVerificationResult(
        isValid: false,
        code: 'MODEL_NOT_READ_ONLY',
        messageAr: 'لا يسمح Edge-2 إلا بنموذج قراءة واقتراحات غير تنفيذية.',
      );
    }
    if (!manifest.enabled) {
      return const EdgeManifestVerificationResult(
        isValid: false,
        code: 'MANIFEST_DISABLED',
        messageAr: 'تم تعطيل manifest النموذج.',
      );
    }
    return null;
  }

  List<int> _decode(String value) =>
      base64Url.decode(base64Url.normalize(value));
}

class EdgePilotPreferences {
  const EdgePilotPreferences({this.keyPrefix = 'yemen_commerce.edge_pilot'});

  final String keyPrefix;

  Future<EdgePilotOptInState> readOptIn() async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getString('$keyPrefix.opt_in');
    return EdgePilotOptInState.values.firstWhere(
      (item) => item.value == value,
      orElse: () => EdgePilotOptInState.disabled,
    );
  }

  Future<void> writeOptIn(EdgePilotOptInState state) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('$keyPrefix.opt_in', state.value);
  }

  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove('$keyPrefix.opt_in');
  }
}

class InMemoryEdgePilotPreferences extends EdgePilotPreferences {
  InMemoryEdgePilotPreferences({
    EdgePilotOptInState state = EdgePilotOptInState.disabled,
  }) : _state = state;

  EdgePilotOptInState _state;

  @override
  Future<EdgePilotOptInState> readOptIn() async => _state;

  @override
  Future<void> writeOptIn(EdgePilotOptInState state) async => _state = state;

  @override
  Future<void> clear() async => _state = EdgePilotOptInState.disabled;
}

class EdgePilotDecision {
  const EdgePilotDecision({
    required this.isEligible,
    required this.code,
    required this.messageAr,
    this.manifest,
    this.capabilityDecision,
    this.verification,
  });

  final bool isEligible;
  final String code;
  final String messageAr;
  final EdgeModelManifest? manifest;
  final EdgeCapabilityDecision? capabilityDecision;
  final EdgeManifestVerificationResult? verification;
}

class EdgePilotController {
  const EdgePilotController({
    required this.runtime,
    required this.verifier,
    required this.preferences,
  });

  final EdgeRuntime runtime;
  final EdgeManifestVerifier verifier;
  final EdgePilotPreferences preferences;

  Future<EdgePilotDecision> evaluate({
    required EdgeModelManifest manifest,
    required EdgeDeviceCapabilities capabilities,
  }) async {
    final optIn = await preferences.readOptIn();
    if (optIn != EdgePilotOptInState.enabled) {
      return const EdgePilotDecision(
        isEligible: false,
        code: 'OPT_IN_REQUIRED',
        messageAr: 'تجربة النموذج المحلي متوقفة حتى يفعّلها المستخدم.',
      );
    }
    final verification = await verifier.verify(manifest);
    if (!verification.isValid) {
      return EdgePilotDecision(
        isEligible: false,
        code: verification.code,
        messageAr: verification.messageAr,
        verification: verification,
      );
    }
    final runtimeStatus = await runtime.status();
    if (!runtimeStatus.isInstalled) {
      return EdgePilotDecision(
        isEligible: false,
        code: 'RUNTIME_UNAVAILABLE',
        messageAr: 'محرك النموذج المحلي غير متاح على هذا الجهاز.',
        manifest: manifest,
        verification: verification,
      );
    }
    final capabilityDecision = capabilities.evaluate(manifest);
    if (!capabilityDecision.isEligible) {
      return EdgePilotDecision(
        isEligible: false,
        code: capabilityDecision.reasons.first,
        messageAr: capabilityDecision.messageAr,
        manifest: manifest,
        capabilityDecision: capabilityDecision,
        verification: verification,
      );
    }
    return EdgePilotDecision(
      isEligible: true,
      code: 'READY_FOR_READ_ONLY_PILOT',
      messageAr: 'تجربة القراءة والاقتراح المحلي جاهزة بعد تأكيد المستخدم.',
      manifest: manifest,
      capabilityDecision: capabilityDecision,
      verification: verification,
    );
  }

  Future<EdgeRuntimeStatus> loadIfEligible(EdgePilotDecision decision) async {
    if (!decision.isEligible || decision.manifest == null) {
      throw const EdgeRuntimeException(
        code: 'PILOT_NOT_ELIGIBLE',
        messageAr: 'لا يمكن تحميل النموذج قبل اجتياز opt-in والتحقق من manifest والجهاز.',
      );
    }
    return runtime.loadModel(
      EdgeRuntimeModelSpec(
        modelId: decision.manifest!.modelId,
        modelVersion: decision.manifest!.modelVersion,
        artifactUri: decision.manifest!.artifactUri,
        sha256: decision.manifest!.artifactSha256,
      ),
    );
  }
}

abstract final class EdgeVersion {
  static int compare(String left, String right) {
    final a = _parse(left);
    final b = _parse(right);
    for (var index = 0; index < 3; index++) {
      final result = a[index].compareTo(b[index]);
      if (result != 0) return result;
    }
    return 0;
  }

  static List<int> _parse(String value) {
    final parts = value.split('.');
    return List<int>.generate(
      3,
      (index) => int.tryParse(parts.elementAtOrNull(index) ?? '') ?? 0,
    );
  }
}

String get edgeDevicePlatform {
  if (kIsWeb) return 'web';
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return 'android';
    case TargetPlatform.iOS:
      return 'ios';
    case TargetPlatform.macOS:
      return 'macos';
    case TargetPlatform.windows:
      return 'windows';
    case TargetPlatform.linux:
      return 'linux';
    case TargetPlatform.fuchsia:
      return 'fuchsia';
  }
}
