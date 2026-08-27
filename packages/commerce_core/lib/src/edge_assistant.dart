import 'dart:convert';

import 'package:crypto/crypto.dart';

/// The application surface in which an edge-assistant proposal was created.
enum EdgeAppSurface {
  customer('customer'),
  merchant('merchant'),
  creator('creator');

  const EdgeAppSurface(this.value);
  final String value;

  static EdgeAppSurface? fromValue(String? value) {
    for (final item in values) {
      if (item.value == value) return item;
    }
    return null;
  }
}

enum EdgeRiskClass {
  readOnly('read_only'),
  draftOnly('draft_only'),
  reviewableOperational('reviewable_operational'),
  highImpact('high_impact'),
  prohibited('prohibited');

  const EdgeRiskClass(this.value);
  final String value;

  static EdgeRiskClass? fromValue(String? value) {
    for (final item in values) {
      if (item.value == value) return item;
    }
    return null;
  }
}

enum EdgeProposalState {
  proposalReady('proposal_ready'),
  needsClarification('needs_clarification'),
  rejected('rejected');

  const EdgeProposalState(this.value);
  final String value;
}

/// The fixed intent catalog. It is deliberately smaller than the backend RPC
/// catalog: the edge model may propose only these safe, user-facing intents.
abstract final class EdgeIntentCatalog {
  static const clarify = 'assistant.clarify';

  static const customerIntents = <String>{
    clarify,
    'catalog.search',
    'order.explain',
    'delivery.explain',
    'return.prepare',
    'support.draft',
  };

  static const merchantIntents = <String>{
    clarify,
    'catalog.search',
    'catalog.draft_description',
    'order.explain',
    'merchant.summary',
    'channel.save',
    'shipment.create',
    'shipment.record_status',
    'delivery_exception.open',
    'delivery_exception.resolve',
    'return.start',
    'return.record_status',
    'inventory.validate',
  };

  static const creatorIntents = <String>{
    clarify,
    'erp.summary',
    'provider.readiness',
    'ai.evaluation_summary',
    'governance.draft',
    'policy.propose',
  };

  static const prohibitedIntents = <String>{
    'payment.mark_paid',
    'payment.refund',
    'payment.settle',
    'fund.transfer',
    'auth.change_role',
    'raw.sql',
    'raw.rpc',
    'raw.url',
  };

  static const operationalIntents = <String>{
    'channel.save',
    'shipment.create',
    'shipment.record_status',
    'delivery_exception.open',
    'delivery_exception.resolve',
    'return.start',
    'return.record_status',
    'inventory.validate',
  };

  static const highImpactIntents = <String>{'policy.propose'};

  static Set<String> forSurface(EdgeAppSurface surface) {
    switch (surface) {
      case EdgeAppSurface.customer:
        return customerIntents;
      case EdgeAppSurface.merchant:
        return merchantIntents;
      case EdgeAppSurface.creator:
        return creatorIntents;
    }
  }

  static EdgeRiskClass expectedRiskFor(String intent) {
    if (prohibitedIntents.contains(intent)) return EdgeRiskClass.prohibited;
    if (highImpactIntents.contains(intent)) return EdgeRiskClass.highImpact;
    if (operationalIntents.contains(intent)) {
      return EdgeRiskClass.reviewableOperational;
    }
    if (intent == 'catalog.draft_description' || intent == 'support.draft') {
      return EdgeRiskClass.draftOnly;
    }
    return EdgeRiskClass.readOnly;
  }
}

class EdgeAssistantRequest {
  const EdgeAssistantRequest({
    required this.requestId,
    required this.surface,
    required this.locale,
    required this.prompt,
    required this.createdAt,
    this.context = const <String, dynamic>{},
    this.modelVersion = 'rules-0',
  });

  final String requestId;
  final EdgeAppSurface surface;
  final String locale;
  final String prompt;
  final DateTime createdAt;
  final Map<String, dynamic> context;
  final String modelVersion;

  Map<String, dynamic> toJson() => {
    'request_id': requestId,
    'surface': surface.value,
    'locale': locale,
    'prompt': prompt,
    'created_at': createdAt.toUtc().toIso8601String(),
    'context': EdgeRedactor.redact(context),
    'model_version': modelVersion,
  };
}

class EdgeProposal {
  const EdgeProposal({
    required this.schemaVersion,
    required this.surface,
    required this.intent,
    required this.confidence,
    required this.locale,
    required this.entities,
    required this.missingFields,
    required this.riskClass,
    required this.explanationAr,
    required this.requiresConfirmation,
    required this.createdAt,
    this.modelVersion = 'rules-0',
    this.state = EdgeProposalState.proposalReady,
  });

  final String schemaVersion;
  final EdgeAppSurface surface;
  final String intent;
  final double confidence;
  final String locale;
  final Map<String, dynamic> entities;
  final List<String> missingFields;
  final EdgeRiskClass riskClass;
  final String explanationAr;
  final bool requiresConfirmation;
  final DateTime createdAt;
  final String modelVersion;
  final EdgeProposalState state;

  bool get isExecutableCandidate =>
      state == EdgeProposalState.proposalReady &&
      missingFields.isEmpty &&
      riskClass != EdgeRiskClass.prohibited;

  Map<String, dynamic> get canonicalPayload => <String, dynamic>{
    'schema_version': schemaVersion,
    'surface': surface.value,
    'intent': intent,
    'confidence': confidence,
    'locale': locale,
    'entities': EdgeCanonicalJson.normalize(entities),
    'missing_fields': [...missingFields]..sort(),
    'risk_class': riskClass.value,
    'requires_confirmation': requiresConfirmation,
    'model_version': modelVersion,
    'state': state.value,
  };

  String get proposalHash =>
      edgeSha256(EdgeCanonicalJson.encode(canonicalPayload));

  Map<String, dynamic> toJson() => {
    ...canonicalPayload,
    'explanation_ar': explanationAr,
    'created_at': createdAt.toUtc().toIso8601String(),
    'proposal_hash': proposalHash,
  };

  factory EdgeProposal.fromJson(Map<String, dynamic> json) => EdgeProposal(
    schemaVersion: json['schema_version']?.toString() ?? '',
    surface:
        EdgeAppSurface.fromValue(json['surface']?.toString()) ??
        EdgeAppSurface.customer,
    intent: json['intent']?.toString() ?? EdgeIntentCatalog.clarify,
    confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
    locale: json['locale']?.toString() ?? 'ar-YE',
    entities: _mapValue(json['entities']),
    missingFields: (json['missing_fields'] as List<dynamic>? ?? const [])
        .map((value) => value.toString())
        .toList(growable: false),
    riskClass:
        EdgeRiskClass.fromValue(json['risk_class']?.toString()) ??
        EdgeRiskClass.prohibited,
    explanationAr: json['explanation_ar']?.toString() ?? '',
    requiresConfirmation: json['requires_confirmation'] == true,
    createdAt:
        DateTime.tryParse(json['created_at']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    modelVersion: json['model_version']?.toString() ?? 'unknown',
    state: EdgeProposalState.values.firstWhere(
      (item) => item.value == json['state']?.toString(),
      orElse: () => EdgeProposalState.proposalReady,
    ),
  );
}

class EdgeValidationIssue {
  const EdgeValidationIssue(this.code, this.messageAr);

  final String code;
  final String messageAr;

  @override
  String toString() => '$code: $messageAr';
}

class EdgeValidationResult {
  const EdgeValidationResult._(this.issues, this.requiresClarification);

  factory EdgeValidationResult.valid({bool requiresClarification = false}) =>
      EdgeValidationResult._(const [], requiresClarification);

  factory EdgeValidationResult.invalid(
    List<EdgeValidationIssue> issues, {
    bool requiresClarification = false,
  }) =>
      EdgeValidationResult._(List.unmodifiable(issues), requiresClarification);

  final List<EdgeValidationIssue> issues;
  final bool requiresClarification;
  bool get isValid => issues.isEmpty;
}

abstract final class EdgeProposalValidator {
  static const _maxPromptOrExplanationLength = 2000;
  static const _maxEntityDepth = 6;

  static EdgeValidationResult validate(EdgeProposal proposal, {DateTime? now}) {
    final issues = <EdgeValidationIssue>[];
    if (proposal.schemaVersion != 'edge_proposal.v1') {
      issues.add(
        const EdgeValidationIssue(
          'UNSUPPORTED_SCHEMA',
          'إصدار اقتراح المساعد غير مدعوم.',
        ),
      );
    }
    if (proposal.locale.trim().isEmpty || proposal.locale.length > 20) {
      issues.add(
        const EdgeValidationIssue('INVALID_LOCALE', 'لغة المساعد غير صالحة.'),
      );
    }
    if (proposal.intent.trim().isEmpty) {
      issues.add(
        const EdgeValidationIssue(
          'MISSING_INTENT',
          'لم يتم تحديد العملية المطلوبة.',
        ),
      );
    } else if (!EdgeIntentCatalog.forSurface(proposal.surface)
        .contains(proposal.intent)) {
      issues.add(
        const EdgeValidationIssue(
          'UNKNOWN_INTENT',
          'هذه العملية غير متاحة لهذا التطبيق أو الدور.',
        ),
      );
    }
    if (proposal.confidence.isNaN ||
        proposal.confidence < 0 ||
        proposal.confidence > 1) {
      issues.add(
        const EdgeValidationIssue(
          'INVALID_CONFIDENCE',
          'درجة ثقة المساعد غير صالحة.',
        ),
      );
    }
    if (proposal.explanationAr.trim().isEmpty ||
        proposal.explanationAr.length > _maxPromptOrExplanationLength) {
      issues.add(
        const EdgeValidationIssue(
          'INVALID_EXPLANATION',
          'شرح العملية غير صالح أو طويل جداً.',
        ),
      );
    }
    if (proposal.missingFields.any(
      (field) =>
          field.trim().isEmpty ||
          field.length > 80 ||
          !_safeFieldName.hasMatch(field),
    )) {
      issues.add(
        const EdgeValidationIssue(
          'INVALID_MISSING_FIELD',
          'بيانات الحقول الناقصة غير صالحة.',
        ),
      );
    }
    if (proposal.missingFields.isNotEmpty &&
        proposal.state != EdgeProposalState.needsClarification) {
      issues.add(
        const EdgeValidationIssue(
          'MISSING_FIELDS',
          'تحتاج العملية إلى معلومات إضافية قبل المتابعة.',
        ),
      );
    }
    final expectedRisk = EdgeIntentCatalog.expectedRiskFor(proposal.intent);
    if (proposal.riskClass != expectedRisk) {
      issues.add(
        const EdgeValidationIssue(
          'RISK_MISMATCH',
          'تصنيف خطورة العملية غير متوافق مع نوعها.',
        ),
      );
    }
    if (proposal.riskClass == EdgeRiskClass.prohibited) {
      issues.add(
        const EdgeValidationIssue(
          'PROHIBITED_INTENT',
          'لا يمكن للمساعد تنفيذ هذه العملية.',
        ),
      );
    }
    if (proposal.riskClass != EdgeRiskClass.readOnly &&
        !proposal.requiresConfirmation) {
      issues.add(
        const EdgeValidationIssue(
          'CONFIRMATION_REQUIRED',
          'تتطلب هذه العملية مراجعة وتأكيداً صريحاً.',
        ),
      );
    }
    if (proposal.explanationAr.contains('تم الدفع') &&
        proposal.intent.startsWith('payment.')) {
      issues.add(
        const EdgeValidationIssue(
          'PAYMENT_AUTHORITY_CLAIM',
          'لا يسمح للمساعد بإثبات حالة الدفع.',
        ),
      );
    }
    if (!_validEntityTree(proposal.entities, 0)) {
      issues.add(
        const EdgeValidationIssue(
          'INVALID_ENTITIES',
          'بيانات العملية تحتوي على بنية أو قيمة غير صالحة.',
        ),
      );
    }
    final current = now ?? DateTime.now().toUtc();
    if (proposal.createdAt.toUtc().isAfter(
      current.add(const Duration(minutes: 2)),
    )) {
      issues.add(
        const EdgeValidationIssue(
          'FUTURE_PROPOSAL',
          'اقتراح المساعد يحمل وقتاً غير صالح.',
        ),
      );
    }
    final requiresClarification =
        proposal.state == EdgeProposalState.needsClarification ||
        proposal.missingFields.isNotEmpty ||
        proposal.intent == EdgeIntentCatalog.clarify;
    return issues.isEmpty
        ? EdgeValidationResult.valid(
            requiresClarification: requiresClarification,
          )
        : EdgeValidationResult.invalid(
            issues,
            requiresClarification: requiresClarification,
          );
  }

  static final _safeFieldName = RegExp(r'^[a-zA-Z][a-zA-Z0-9_]{0,79}$');

  static bool _validEntityTree(dynamic value, int depth) {
    if (depth > _maxEntityDepth) return false;
    if (value == null || value is num || value is bool) return true;
    if (value is String) {
      return value.length <= _maxPromptOrExplanationLength &&
          !EdgeRedactor.containsSecretLikeKey(value);
    }
    if (value is List) {
      return value.length <= 50 &&
          value.every((item) => _validEntityTree(item, depth + 1));
    }
    if (value is Map) {
      if (value.length > 50) return false;
      return value.entries.every(
        (entry) =>
            entry.key is String &&
            (entry.key as String).length <= 80 &&
            !EdgeRedactor.containsSecretLikeKey(entry.key as String) &&
            _validEntityTree(entry.value, depth + 1),
      );
    }
    return false;
  }
}

abstract final class EdgeRedactor {
  static const _sensitiveKeyFragments = <String>{
    'access_token',
    'authorization',
    'cookie',
    'credential',
    'identity_evidence',
    'password',
    'payment_proof',
    'private_key',
    'secret',
    'service_role',
    'signed_url',
    'token',
  };

  static dynamic redact(dynamic value, {int depth = 0}) {
    if (depth > 8) return '[TRUNCATED]';
    if (value == null || value is num || value is bool) return value;
    if (value is String) {
      return value.length <= 2000 ? value : '${value.substring(0, 2000)}…';
    }
    if (value is List) {
      return value
          .take(50)
          .map((item) => redact(item, depth: depth + 1))
          .toList(growable: false);
    }
    if (value is Map) {
      final output = <String, dynamic>{};
      for (final entry in value.entries.take(50)) {
        final key = entry.key.toString();
        output[key] = containsSecretLikeKey(key)
            ? '[REDACTED]'
            : redact(entry.value, depth: depth + 1);
      }
      return output;
    }
    return '[UNSUPPORTED]';
  }

  static bool containsSecretLikeKey(String value) {
    final normalized = value.toLowerCase().replaceAll('-', '_');
    return _sensitiveKeyFragments.any(normalized.contains);
  }
}

abstract final class EdgeCanonicalJson {
  static String encode(dynamic value) => jsonEncode(normalize(value));

  static dynamic normalize(dynamic value) {
    if (value == null || value is String || value is num || value is bool) {
      return value;
    }
    if (value is DateTime) return value.toUtc().toIso8601String();
    if (value is List) return value.map(normalize).toList(growable: false);
    if (value is Map) {
      final entries =
          value.entries
              .map(
                (entry) =>
                    MapEntry(entry.key.toString(), normalize(entry.value)),
              )
              .toList()
            ..sort((a, b) => a.key.compareTo(b.key));
      return <String, dynamic>{
        for (final entry in entries) entry.key: entry.value,
      };
    }
    return value.toString();
  }
}

String edgeSha256(String value) =>
    sha256.convert(utf8.encode(value)).toString();

/// A deterministic fallback that does not access a server or execute a tool.
/// It provides useful Arabic clarification/proposal states before Edge-1 adds
/// a local model runtime.
class EdgeRulesOnlyAssistant {
  const EdgeRulesOnlyAssistant();

  EdgeProposal interpret(EdgeAssistantRequest request) {
    final prompt = request.prompt.trim();
    final lower = prompt.toLowerCase();
    final context = EdgeRedactor.redact(request.context);
    final intentAndEntities = _route(request.surface, prompt, lower, context);
    final intent = intentAndEntities.$1;
    final entities = intentAndEntities.$2;
    final missingFields = <String>[];
    if (EdgeIntentCatalog.operationalIntents.contains(intent)) {
      if (intent.startsWith('shipment.') &&
          entities['shipment_plan_id'] == null) {
        missingFields.add('shipment_plan_id');
      }
      if (intent == 'channel.save' && entities['channel_key'] == null) {
        missingFields.add('channel_key');
      }
      if (entities['reason'] == null) missingFields.add('reason');
    }
    final needsClarification =
        intent == EdgeIntentCatalog.clarify || missingFields.isNotEmpty;
    final effectiveIntent =
        needsClarification && intent == EdgeIntentCatalog.clarify
        ? EdgeIntentCatalog.clarify
        : intent;
    return EdgeProposal(
      schemaVersion: 'edge_proposal.v1',
      surface: request.surface,
      intent: effectiveIntent,
      confidence: needsClarification ? 0.35 : 0.82,
      locale: request.locale,
      entities: entities,
      missingFields: missingFields,
      riskClass: EdgeIntentCatalog.expectedRiskFor(effectiveIntent),
      explanationAr: _explanation(effectiveIntent, needsClarification),
      requiresConfirmation:
          EdgeIntentCatalog.expectedRiskFor(effectiveIntent) !=
          EdgeRiskClass.readOnly,
      createdAt: request.createdAt,
      modelVersion: request.modelVersion,
      state: needsClarification
          ? EdgeProposalState.needsClarification
          : EdgeProposalState.proposalReady,
    );
  }

  (String, Map<String, dynamic>) _route(
    EdgeAppSurface surface,
    String prompt,
    String lower,
    dynamic context,
  ) {
    final contextMap = context is Map ? context : const <String, dynamic>{};
    const prohibitedAliases = <String, String>{
      'payment.mark_paid': 'payment.mark_paid',
      'mark_paid': 'payment.mark_paid',
      'mark paid': 'payment.mark_paid',
      'refund': 'payment.refund',
      'استرداد': 'payment.refund',
      'settle': 'payment.settle',
      'تسوية': 'payment.settle',
      'fund.transfer': 'fund.transfer',
      'transfer funds': 'fund.transfer',
      'تحويل الأموال': 'fund.transfer',
    };
    for (final entry in prohibitedAliases.entries) {
      if (lower.contains(entry.key)) {
        return (entry.value, const <String, dynamic>{});
      }
    }
    if (surface == EdgeAppSurface.merchant &&
        (lower.contains('shipment') || prompt.contains('توصيل')) &&
        (lower.contains('ready') || prompt.contains('جاهز'))) {
      return (
        'shipment.record_status',
        <String, dynamic>{
          'shipment_plan_id': contextMap['shipment_plan_id'],
          'status': 'ready',
          'reason': prompt.length >= 5 ? prompt : null,
        },
      );
    }
    if (surface == EdgeAppSurface.merchant &&
        (prompt.contains('قناة') || lower.contains('channel'))) {
      return (
        'channel.save',
        <String, dynamic>{'channel_key': contextMap['channel_key']},
      );
    }
    if (surface == EdgeAppSurface.customer &&
        (prompt.contains('طلب') || lower.contains('order')) &&
        (prompt.contains('أين') ||
            prompt.contains('حالة') ||
            lower.contains('status'))) {
      return (
        'order.explain',
        <String, dynamic>{'order_id': contextMap['order_id']},
      );
    }
    if (surface == EdgeAppSurface.customer &&
        (prompt.contains('مرتجع') || lower.contains('return'))) {
      return ('return.prepare', const <String, dynamic>{});
    }
    if (surface == EdgeAppSurface.creator &&
        (prompt.contains('مزود') || lower.contains('provider'))) {
      return ('provider.readiness', const <String, dynamic>{});
    }
    return (EdgeIntentCatalog.clarify, const <String, dynamic>{});
  }

  String _explanation(String intent, bool clarification) {
    if (clarification) {
      return 'أحتاج إلى معلومات إضافية أو اختياراً أوضح قبل إعداد الاقتراح.';
    }
    switch (intent) {
      case 'shipment.record_status':
        return 'سأجهز اقتراحاً لتحديث حالة التوصيل. لن تتغير حالة الدفع أو أي مبلغ مالي.';
      case 'channel.save':
        return 'سأجهز اقتراحاً لحفظ بيانات قناة البيع بعد مراجعة الحقول.';
      case 'order.explain':
        return 'سأشرح آخر بيانات الطلب المسموح بعرضها لهذه الجلسة.';
      case 'return.prepare':
        return 'سأجهز خطوات طلب المرتجع دون إنشاء استرداد أو تسوية مالية.';
      case 'provider.readiness':
        return 'سأعرض حالة جاهزية المزود من البيانات المسموح بها فقط.';
      case 'payment.mark_paid':
      case 'payment.refund':
      case 'payment.settle':
      case 'fund.transfer':
        return 'لا يمكن للمساعد تنفيذ أو إثبات عملية مالية.';
      default:
        return 'سأجهز اقتراحاً قابلاً للمراجعة قبل أي إجراء.';
    }
  }
}

Map<String, dynamic> _mapValue(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
