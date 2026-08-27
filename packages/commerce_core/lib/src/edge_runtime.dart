import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'edge_assistant.dart';

enum EdgeRuntimeState {
  unavailable('unavailable'),
  idle('idle'),
  loading('loading'),
  ready('ready'),
  running('running'),
  cancelling('cancelling'),
  failed('failed');

  const EdgeRuntimeState(this.value);
  final String value;

  static EdgeRuntimeState fromValue(String? value) => values.firstWhere(
    (item) => item.value == value,
    orElse: () => EdgeRuntimeState.unavailable,
  );
}

class EdgeRuntimeStatus {
  const EdgeRuntimeStatus({
    required this.platform,
    required this.state,
    required this.backend,
    required this.supportsCancellation,
    this.modelId,
    this.modelVersion,
    this.messageAr = '',
    this.errorCode,
  });

  final String platform;
  final EdgeRuntimeState state;
  final String backend;
  final bool supportsCancellation;
  final String? modelId;
  final String? modelVersion;
  final String messageAr;
  final String? errorCode;

  bool get isAvailable =>
      state == EdgeRuntimeState.ready || state == EdgeRuntimeState.running;

  bool get isInstalled =>
      state != EdgeRuntimeState.unavailable && state != EdgeRuntimeState.failed;

  Map<String, dynamic> toJson() => {
    'platform': platform,
    'state': state.value,
    'backend': backend,
    'supports_cancellation': supportsCancellation,
    if (modelId != null) 'model_id': modelId,
    if (modelVersion != null) 'model_version': modelVersion,
    'message_ar': messageAr,
    if (errorCode != null) 'error_code': errorCode,
  };

  factory EdgeRuntimeStatus.fromJson(Map<String, dynamic> json) =>
      EdgeRuntimeStatus(
        platform: json['platform']?.toString() ?? 'unknown',
        state: EdgeRuntimeState.fromValue(json['state']?.toString()),
        backend: json['backend']?.toString() ?? 'unknown',
        supportsCancellation: json['supports_cancellation'] == true,
        modelId: json['model_id']?.toString(),
        modelVersion: json['model_version']?.toString(),
        messageAr: json['message_ar']?.toString() ?? '',
        errorCode: json['error_code']?.toString(),
      );

  factory EdgeRuntimeStatus.unavailable({
    String? platform,
    String backend = 'rules_only_fallback',
    String errorCode = 'MODEL_RUNTIME_UNAVAILABLE',
    String messageAr =
        'محرك الذكاء المحلي غير متاح حالياً؛ سيتم استخدام التحقق الآمن.',
  }) => EdgeRuntimeStatus(
    platform: platform ?? _currentPlatform,
    state: EdgeRuntimeState.unavailable,
    backend: backend,
    supportsCancellation: false,
    messageAr: messageAr,
    errorCode: errorCode,
  );
}

class EdgeRuntimeModelSpec {
  const EdgeRuntimeModelSpec({
    required this.modelId,
    required this.modelVersion,
    this.artifactUri,
    this.sha256,
  });

  final String modelId;
  final String modelVersion;
  final String? artifactUri;
  final String? sha256;

  Map<String, dynamic> toJson() => {
    'model_id': modelId,
    'model_version': modelVersion,
    if (artifactUri != null) 'artifact_uri': artifactUri,
    if (sha256 != null) 'sha256': sha256,
  };
}

class EdgeRuntimeRequest {
  const EdgeRuntimeRequest({
    required this.requestId,
    required this.prompt,
    this.context = const <String, dynamic>{},
    this.maxOutputTokens = 256,
    this.locale = 'ar-YE',
  });

  final String requestId;
  final String prompt;
  final Map<String, dynamic> context;
  final int maxOutputTokens;
  final String locale;

  Map<String, dynamic> toJson() => {
    'request_id': requestId,
    'prompt': prompt,
    'context': EdgeRedactor.redact(context),
    'max_output_tokens': maxOutputTokens.clamp(1, 1024),
    'locale': locale,
  };
}

class EdgeRuntimeInferenceResult {
  const EdgeRuntimeInferenceResult({
    required this.requestId,
    required this.proposal,
    this.modelVersion,
  });

  final String requestId;
  final Map<String, dynamic>? proposal;
  final String? modelVersion;

  factory EdgeRuntimeInferenceResult.fromJson(Map<String, dynamic> json) =>
      EdgeRuntimeInferenceResult(
        requestId: json['request_id']?.toString() ?? '',
        proposal: json['proposal'] is Map
            ? Map<String, dynamic>.from(json['proposal'] as Map)
            : null,
        modelVersion: json['model_version']?.toString(),
      );
}

class EdgeRuntimeException implements Exception {
  const EdgeRuntimeException({
    required this.code,
    required this.messageAr,
    this.retryable = false,
  });

  final String code;
  final String messageAr;
  final bool retryable;

  @override
  String toString() => '$code: $messageAr';

  factory EdgeRuntimeException.fromPlatformException(PlatformException error) =>
      EdgeRuntimeException(
        code: error.code,
        messageAr: _safeRuntimeMessage(error.code, error.message),
        retryable: error.code == 'MODEL_BUSY' || error.code == 'MODEL_LOADING',
      );
}

abstract interface class EdgeRuntime {
  Future<EdgeRuntimeStatus> status();

  Future<EdgeRuntimeStatus> loadModel(EdgeRuntimeModelSpec model);

  Future<EdgeRuntimeInferenceResult> infer(EdgeRuntimeRequest request);

  Future<bool> cancel(String requestId);

  Future<void> unloadModel();
}

/// Typed adapter around the native platform channel. It deliberately maps a
/// missing or disabled native implementation to an unavailable status so the
/// caller can safely fall back to [EdgeRulesOnlyAssistant].
class EdgeRuntimeChannel implements EdgeRuntime {
  EdgeRuntimeChannel({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const _channelName = 'com.yemencommerce/edge_runtime.v1';
  final MethodChannel _channel;

  @override
  Future<EdgeRuntimeStatus> status() async {
    try {
      final value = await _channel.invokeMethod<Object?>('status');
      return EdgeRuntimeStatus.fromJson(_mapValue(value));
    } on MissingPluginException {
      return EdgeRuntimeStatus.unavailable();
    } on PlatformException catch (error) {
      return EdgeRuntimeStatus.unavailable(
        errorCode: error.code,
        messageAr: _safeRuntimeMessage(error.code, error.message),
      );
    }
  }

  @override
  Future<EdgeRuntimeStatus> loadModel(EdgeRuntimeModelSpec model) async {
    try {
      final value = await _channel.invokeMethod<Object?>(
        'loadModel',
        model.toJson(),
      );
      return EdgeRuntimeStatus.fromJson(_mapValue(value));
    } on MissingPluginException {
      throw const EdgeRuntimeException(
        code: 'MODEL_RUNTIME_UNAVAILABLE',
        messageAr: 'محرك الذكاء المحلي غير متاح على هذا الجهاز.',
      );
    } on PlatformException catch (error) {
      throw EdgeRuntimeException.fromPlatformException(error);
    }
  }

  @override
  Future<EdgeRuntimeInferenceResult> infer(EdgeRuntimeRequest request) async {
    _validateRequest(request);
    try {
      final value = await _channel.invokeMethod<Object?>(
        'infer',
        request.toJson(),
      );
      return EdgeRuntimeInferenceResult.fromJson(_mapValue(value));
    } on MissingPluginException {
      throw const EdgeRuntimeException(
        code: 'MODEL_RUNTIME_UNAVAILABLE',
        messageAr: 'محرك الذكاء المحلي غير متاح على هذا الجهاز.',
      );
    } on PlatformException catch (error) {
      throw EdgeRuntimeException.fromPlatformException(error);
    }
  }

  @override
  Future<bool> cancel(String requestId) async {
    if (requestId.trim().isEmpty || requestId.length > 120) return false;
    try {
      final value = await _channel.invokeMethod<Object?>('cancel', {
        'request_id': requestId,
      });
      final map = _mapValue(value);
      return map['cancelled'] == true;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (error) {
      throw EdgeRuntimeException.fromPlatformException(error);
    }
  }

  @override
  Future<void> unloadModel() async {
    try {
      await _channel.invokeMethod<Object?>('unloadModel');
    } on MissingPluginException {
      return;
    } on PlatformException catch (error) {
      throw EdgeRuntimeException.fromPlatformException(error);
    }
  }

  void _validateRequest(EdgeRuntimeRequest request) {
    if (request.requestId.trim().isEmpty || request.requestId.length > 120) {
      throw const EdgeRuntimeException(
        code: 'INVALID_REQUEST',
        messageAr: 'معرّف طلب الذكاء المحلي غير صالح.',
      );
    }
    if (request.prompt.trim().isEmpty || request.prompt.length > 2000) {
      throw const EdgeRuntimeException(
        code: 'INVALID_REQUEST',
        messageAr: 'نص طلب الذكاء المحلي غير صالح أو طويل جداً.',
      );
    }
    if (EdgeRedactor.containsSecretLikeKey(request.prompt)) {
      throw const EdgeRuntimeException(
        code: 'SENSITIVE_INPUT',
        messageAr: 'لا يمكن إرسال بيانات سرية إلى محرك الجهاز.',
      );
    }
  }
}

/// Deterministic runtime used by unit/widget tests and local development.
class FakeEdgeRuntime implements EdgeRuntime {
  FakeEdgeRuntime({
    this.available = true,
    this.response,
    this.platform = 'fake',
  });

  final bool available;
  final EdgeRuntimeInferenceResult? response;
  final String platform;
  EdgeRuntimeState _state = EdgeRuntimeState.idle;
  int inferCalls = 0;

  @override
  Future<EdgeRuntimeStatus> status() async => EdgeRuntimeStatus(
    platform: platform,
    state: available ? EdgeRuntimeState.ready : EdgeRuntimeState.unavailable,
    backend: 'fake',
    supportsCancellation: available,
    messageAr: available ? 'محرك اختبار محلي.' : 'محرك الاختبار غير متاح.',
  );

  @override
  Future<EdgeRuntimeStatus> loadModel(EdgeRuntimeModelSpec model) async {
    if (!available)
      throw const EdgeRuntimeException(
        code: 'MODEL_RUNTIME_UNAVAILABLE',
        messageAr: 'محرك الاختبار غير متاح.',
      );
    _state = EdgeRuntimeState.ready;
    return EdgeRuntimeStatus(
      platform: platform,
      state: _state,
      backend: 'fake',
      supportsCancellation: true,
      modelId: model.modelId,
      modelVersion: model.modelVersion,
      messageAr: 'تم تحميل نموذج الاختبار.',
    );
  }

  @override
  Future<EdgeRuntimeInferenceResult> infer(EdgeRuntimeRequest request) async {
    if (!available)
      throw const EdgeRuntimeException(
        code: 'MODEL_RUNTIME_UNAVAILABLE',
        messageAr: 'محرك الاختبار غير متاح.',
      );
    inferCalls++;
    _state = EdgeRuntimeState.running;
    final result =
        response ??
        EdgeRuntimeInferenceResult(
          requestId: request.requestId,
          proposal: null,
        );
    _state = EdgeRuntimeState.ready;
    return result;
  }

  @override
  Future<bool> cancel(String requestId) async {
    if (!available) return false;
    _state = EdgeRuntimeState.ready;
    return requestId.trim().isNotEmpty;
  }

  @override
  Future<void> unloadModel() async {
    _state = EdgeRuntimeState.idle;
  }
}

/// Chooses a validated native proposal when available and otherwise uses the
/// deterministic rules-only assistant. The returned proposal still has no
/// execution authority; a caller must apply the existing confirmation/RPC flow.
class EdgeAssistantCoordinator {
  const EdgeAssistantCoordinator({
    required this.runtime,
    this.fallback = const EdgeRulesOnlyAssistant(),
  });

  final EdgeRuntime runtime;
  final EdgeRulesOnlyAssistant fallback;

  Future<EdgeProposal> propose(EdgeAssistantRequest request) async {
    final fallbackProposal = fallback.interpret(request);
    try {
      final status = await runtime.status();
      if (!status.isAvailable) return fallbackProposal;
      final result = await runtime.infer(
        EdgeRuntimeRequest(
          requestId: request.requestId,
          prompt: request.prompt,
          context: request.context,
          locale: request.locale,
        ),
      );
      final proposalJson = result.proposal;
      if (proposalJson == null) return fallbackProposal;
      final proposal = EdgeProposal.fromJson(proposalJson);
      if (!EdgeProposalValidator.validate(proposal).isValid) {
        return fallbackProposal;
      }
      return proposal;
    } on EdgeRuntimeException {
      return fallbackProposal;
    }
  }
}

Map<String, dynamic> _mapValue(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

String get _currentPlatform {
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

String _safeRuntimeMessage(String? code, String? nativeMessage) {
  switch (code) {
    case 'MODEL_RUNTIME_UNAVAILABLE':
    case 'MODEL_RUNTIME_NOT_ENABLED':
      return 'محرك الذكاء المحلي غير متاح أو لم يتم تفعيله بعد.';
    case 'MODEL_BUSY':
      return 'محرك الذكاء المحلي مشغول حالياً. حاول مرة أخرى.';
    case 'MODEL_LOADING':
      return 'يتم تجهيز محرك الذكاء المحلي حالياً.';
    case 'INVALID_REQUEST':
      return 'طلب محرك الذكاء المحلي غير صالح.';
    case 'SENSITIVE_INPUT':
      return 'لا يمكن إرسال بيانات سرية إلى محرك الجهاز.';
    default:
      return nativeMessage == null || nativeMessage.trim().isEmpty
          ? 'تعذر استخدام محرك الذكاء المحلي.'
          : 'تعذر استخدام محرك الذكاء المحلي.';
  }
}
