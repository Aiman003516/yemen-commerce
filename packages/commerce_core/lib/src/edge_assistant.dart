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
  static const navigationOpen = 'navigation.open';
  static const knowledgeExplain = 'knowledge.explain';
  static const statusExplain = 'status.explain';

  static const readOnlyIntents = <String>{
    navigationOpen,
    knowledgeExplain,
    statusExplain,
    'catalog.search',
    'order.explain',
    'delivery.explain',
    'merchant.summary',
    'erp.summary',
    'provider.readiness',
    'ai.evaluation_summary',
  };

  static const customerIntents = <String>{
    clarify,
    navigationOpen,
    knowledgeExplain,
    statusExplain,
    'catalog.search',
    'order.explain',
    'delivery.explain',
    'return.prepare',
    'support.draft',
  };

  static const merchantIntents = <String>{
    clarify,
    navigationOpen,
    knowledgeExplain,
    statusExplain,
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
    navigationOpen,
    knowledgeExplain,
    statusExplain,
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

  static bool isReadOnly(String intent) =>
      readOnlyIntents.contains(intent) || intent == clarify;

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

/// A fixed route identifier, never an arbitrary Flutter path, URL, callback,
/// or deep link. Consumers map it to locally compiled screens.
abstract final class EdgeRouteCatalog {
  static const customerOrders = 'customer.orders';
  static const customerDelivery = 'customer.delivery';
  static const customerReturns = 'customer.returns';
  static const customerSupport = 'customer.support';
  static const merchantOrders = 'merchant.orders';
  static const merchantCatalog = 'merchant.catalog';
  static const merchantInventory = 'merchant.inventory';
  static const merchantShipments = 'merchant.shipments';
  static const merchantReturns = 'merchant.returns';
  static const merchantSync = 'merchant.sync';
  static const creatorGovernance = 'creator.governance';
  static const creatorProviders = 'creator.providers';
  static const creatorEvaluations = 'creator.evaluations';

  static const _routesBySurface = <EdgeAppSurface, Set<String>>{
    EdgeAppSurface.customer: {
      customerOrders,
      customerDelivery,
      customerReturns,
      customerSupport,
    },
    EdgeAppSurface.merchant: {
      merchantOrders,
      merchantCatalog,
      merchantInventory,
      merchantShipments,
      merchantReturns,
      merchantSync,
    },
    EdgeAppSurface.creator: {
      creatorGovernance,
      creatorProviders,
      creatorEvaluations,
    },
  };

  static bool isAllowed(EdgeAppSurface surface, String? routeId) =>
      routeId != null && _routesBySurface[surface]!.contains(routeId);

  static Set<String> forSurface(EdgeAppSurface surface) =>
      Set.unmodifiable(_routesBySurface[surface]!);
}

abstract final class EdgeKnowledgeTopicCatalog {
  static const topics = <String>{
    'catalog',
    'orders',
    'delivery',
    'returns',
    'inventory',
    'pos',
    'cod',
    'b2b',
    'channels',
    'payments_explanation',
    'creator_governance',
    'offline_sync',
  };

  static bool contains(String? topic) =>
      topic != null && topics.contains(topic);
}

class EdgeProposalProvenance {
  const EdgeProposalProvenance({
    required this.source,
    required this.retrievedAt,
    this.packId,
    this.packVersion,
    this.expiresAt,
  });

  final String source;
  final DateTime retrievedAt;
  final String? packId;
  final String? packVersion;
  final DateTime? expiresAt;

  Map<String, dynamic> toJson() => {
    'source': source,
    'retrieved_at': retrievedAt.toUtc().toIso8601String(),
    if (packId != null) 'pack_id': packId,
    if (packVersion != null) 'pack_version': packVersion,
    if (expiresAt != null) 'expires_at': expiresAt!.toUtc().toIso8601String(),
  };

  factory EdgeProposalProvenance.fromJson(Map<String, dynamic> json) =>
      EdgeProposalProvenance(
        source: json['source']?.toString() ?? '',
        retrievedAt:
            DateTime.tryParse(json['retrieved_at']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        packId: json['pack_id']?.toString(),
        packVersion: json['pack_version']?.toString(),
        expiresAt: DateTime.tryParse(json['expires_at']?.toString() ?? ''),
      );
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
    this.provenance,
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
  final EdgeProposalProvenance? provenance;

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
    if (provenance != null) 'provenance': provenance!.toJson(),
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
    provenance: json['provenance'] is Map
        ? EdgeProposalProvenance.fromJson(
            Map<String, dynamic>.from(json['provenance'] as Map),
          )
        : null,
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
    final current = now ?? DateTime.now().toUtc();
    if (proposal.intent == EdgeIntentCatalog.navigationOpen &&
        !EdgeRouteCatalog.isAllowed(
          proposal.surface,
          proposal.entities['route_id']?.toString(),
        )) {
      issues.add(
        const EdgeValidationIssue(
          'INVALID_ROUTE',
          'مسار الشاشة غير مسموح لهذا التطبيق أو الدور.',
        ),
      );
    }
    if (proposal.intent == EdgeIntentCatalog.knowledgeExplain &&
        !EdgeKnowledgeTopicCatalog.contains(
          proposal.entities['topic_key']?.toString(),
        )) {
      issues.add(
        const EdgeValidationIssue(
          'INVALID_KNOWLEDGE_TOPIC',
          'موضوع المعرفة غير موجود في الحزمة الموثوقة.',
        ),
      );
    }
    if (proposal.intent == EdgeIntentCatalog.statusExplain &&
        !_safeStatusKey.hasMatch(
          proposal.entities['status_key']?.toString() ?? '',
        )) {
      issues.add(
        const EdgeValidationIssue(
          'INVALID_STATUS_KEY',
          'مفتاح الحالة المطلوب شرحه غير صالح.',
        ),
      );
    }
    final provenance = proposal.provenance;
    if (proposal.intent == EdgeIntentCatalog.knowledgeExplain &&
        provenance == null) {
      issues.add(
        const EdgeValidationIssue(
          'PROVENANCE_REQUIRED',
          'لا يمكن عرض المعرفة المحلية دون مصدر موثق.',
        ),
      );
    }
    if (provenance != null) {
      if (!_allowedProvenanceSources.contains(provenance.source) ||
          provenance.source.length > 80 ||
          provenance.packId != null &&
              !_safeIdentifier.hasMatch(provenance.packId!) ||
          provenance.packVersion != null &&
              !_safeIdentifier.hasMatch(provenance.packVersion!)) {
        issues.add(
          const EdgeValidationIssue(
            'INVALID_PROVENANCE',
            'مصدر الاقتراح غير موثق أو غير صالح.',
          ),
        );
      }
      if (provenance.expiresAt != null &&
          !provenance.expiresAt!.toUtc().isAfter(current)) {
        issues.add(
          const EdgeValidationIssue(
            'STALE_PROVENANCE',
            'مصدر المعرفة المحلي منتهي الصلاحية.',
          ),
        );
      }
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
  static final _safeStatusKey = RegExp(r'^[a-zA-Z][a-zA-Z0-9_.-]{0,79}$');
  static final _safeIdentifier = RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9._-]{0,119}$');
  static const _allowedProvenanceSources = {
    'rules',
    'local_knowledge_pack',
    'server_read',
  };

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
    if (intent == EdgeIntentCatalog.navigationOpen &&
        entities['route_id'] == null) {
      missingFields.add('route_id');
    }
    if (intent == EdgeIntentCatalog.knowledgeExplain &&
        entities['topic_key'] == null) {
      missingFields.add('topic_key');
    }
    if (intent == EdgeIntentCatalog.statusExplain &&
        entities['status_key'] == null) {
      missingFields.add('status_key');
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
      provenance: intent == EdgeIntentCatalog.knowledgeExplain
          ? EdgeProposalProvenance(
              source: 'rules',
              retrievedAt: request.createdAt,
            )
          : null,
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
    if (lower.contains('افتح') ||
        lower.contains('open') ||
        lower.contains('navigate') ||
        prompt.contains('اذهب')) {
      final route = _routeFromPrompt(surface, prompt, lower);
      return (
        EdgeIntentCatalog.navigationOpen,
        <String, dynamic>{'route_id': route},
      );
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
    if (prompt.contains('اشرح') ||
        prompt.contains('ما معنى') ||
        lower.contains('explain') ||
        lower.contains('how does')) {
      final topic = _topicFromPrompt(prompt, lower);
      if (topic != null) {
        return (
          EdgeIntentCatalog.knowledgeExplain,
          <String, dynamic>{'topic_key': topic},
        );
      }
      final statusKey = _statusKeyFromPrompt(prompt, lower);
      if (statusKey != null) {
        return (
          EdgeIntentCatalog.statusExplain,
          <String, dynamic>{'status_key': statusKey},
        );
      }
    }
    return (EdgeIntentCatalog.clarify, const <String, dynamic>{});
  }

  String? _routeFromPrompt(
    EdgeAppSurface surface,
    String prompt,
    String lower,
  ) {
    if (surface == EdgeAppSurface.customer) {
      if (prompt.contains('طلب') || lower.contains('order')) {
        return EdgeRouteCatalog.customerOrders;
      }
      if (prompt.contains('توصيل') || lower.contains('delivery')) {
        return EdgeRouteCatalog.customerDelivery;
      }
      if (prompt.contains('مرتجع') || lower.contains('return')) {
        return EdgeRouteCatalog.customerReturns;
      }
      if (prompt.contains('دعم') || lower.contains('support')) {
        return EdgeRouteCatalog.customerSupport;
      }
    }
    if (surface == EdgeAppSurface.merchant) {
      if (prompt.contains('طلب') || lower.contains('order')) {
        return EdgeRouteCatalog.merchantOrders;
      }
      if (prompt.contains('منتج') || lower.contains('catalog')) {
        return EdgeRouteCatalog.merchantCatalog;
      }
      if (prompt.contains('مخزون') || lower.contains('inventory')) {
        return EdgeRouteCatalog.merchantInventory;
      }
      if (prompt.contains('شحن') || lower.contains('shipment')) {
        return EdgeRouteCatalog.merchantShipments;
      }
      if (prompt.contains('مرتجع') || lower.contains('return')) {
        return EdgeRouteCatalog.merchantReturns;
      }
      if (prompt.contains('مزامنة') || lower.contains('sync')) {
        return EdgeRouteCatalog.merchantSync;
      }
    }
    if (surface == EdgeAppSurface.creator) {
      if (prompt.contains('حوكمة') || lower.contains('governance')) {
        return EdgeRouteCatalog.creatorGovernance;
      }
      if (prompt.contains('مزود') || lower.contains('provider')) {
        return EdgeRouteCatalog.creatorProviders;
      }
      if (prompt.contains('تقييم') || lower.contains('evaluation')) {
        return EdgeRouteCatalog.creatorEvaluations;
      }
    }
    return null;
  }

  String? _topicFromPrompt(String prompt, String lower) {
    final aliases = <String, String>{
      'منتج': 'catalog',
      'كتالوج': 'catalog',
      'طلب': 'orders',
      'توصيل': 'delivery',
      'شحن': 'delivery',
      'مرتجع': 'returns',
      'مخزون': 'inventory',
      'نقطة البيع': 'pos',
      'دفع عند الاستلام': 'cod',
      'جملة': 'b2b',
      'قناة': 'channels',
      'دفع': 'payments_explanation',
      'مزامنة': 'offline_sync',
      'catalog': 'catalog',
      'order': 'orders',
      'delivery': 'delivery',
      'return': 'returns',
      'inventory': 'inventory',
      'pos': 'pos',
      'cod': 'cod',
      'b2b': 'b2b',
      'channel': 'channels',
      'payment': 'payments_explanation',
      'sync': 'offline_sync',
    };
    for (final entry in aliases.entries) {
      if (prompt.contains(entry.key) || lower.contains(entry.key)) {
        return entry.value;
      }
    }
    return null;
  }

  String? _statusKeyFromPrompt(String prompt, String lower) {
    final aliases = <String, String>{
      'قيد المراجعة': 'payment.pending_review',
      'بانتظار الدفع': 'payment.awaiting_payment',
      'جاهز': 'shipment.ready',
      'في الطريق': 'shipment.in_transit',
      'تم التسليم': 'shipment.delivered',
      'استثناء': 'delivery_exception.open',
      'pending': 'payment.pending_review',
      'ready': 'shipment.ready',
      'in transit': 'shipment.in_transit',
      'delivered': 'shipment.delivered',
      'exception': 'delivery_exception.open',
    };
    for (final entry in aliases.entries) {
      if (prompt.contains(entry.key) || lower.contains(entry.key)) {
        return entry.value;
      }
    }
    return null;
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
      case EdgeIntentCatalog.navigationOpen:
        return 'سأفتح شاشة مسموحة فقط دون تغيير أي بيانات.';
      case EdgeIntentCatalog.knowledgeExplain:
        return 'سأعرض شرحاً من المعرفة المحلية الموثقة دون الوصول إلى بيانات خاصة.';
      case EdgeIntentCatalog.statusExplain:
        return 'سأشرح معنى الحالة كما هي، دون تغييرها أو إثبات حالة الدفع.';
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
