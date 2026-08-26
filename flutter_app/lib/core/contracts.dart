const marketplaceApiVersion = 'v1';

String _stringValue(dynamic value) => value.toString();
int _intValue(dynamic value) => (value as num).toInt();

class AiDraft {
  const AiDraft({
    required this.kind,
    required this.title,
    required this.content,
    required this.language,
    this.sourceProductId,
  });

  final String kind;
  final String title;
  final String content;
  final String language;
  final String? sourceProductId;

  factory AiDraft.fromJson(Map<String, dynamic> json) => AiDraft(
    kind: json['kind']?.toString() ?? 'unknown',
    title: json['title']?.toString() ?? '',
    content: json['content']?.toString() ?? '',
    language: json['language']?.toString() ?? 'ar',
    sourceProductId: json['source_product_id']?.toString(),
  );
}

class AiRunResponse {
  const AiRunResponse({
    required this.runId,
    required this.status,
    required this.mode,
    required this.answer,
    required this.locale,
    required this.toolCalls,
    required this.idempotent,
    this.drafts = const [],
  });

  final String runId;
  final String status;
  final String mode;
  final String answer;
  final String locale;
  final int toolCalls;
  final bool idempotent;
  final List<AiDraft> drafts;

  bool get isSuccessful => status == 'succeeded';
  bool get hasDrafts => drafts.isNotEmpty;

  factory AiRunResponse.fromJson(Map<String, dynamic> json) => AiRunResponse(
    runId: json['run_id']?.toString() ?? '',
    status: json['status']?.toString() ?? 'failed',
    mode: json['mode']?.toString() ?? 'read',
    answer: json['answer']?.toString() ?? '',
    locale: json['locale']?.toString() ?? 'ar',
    toolCalls: (json['tool_calls'] as num?)?.toInt() ?? 0,
    idempotent: json['idempotent'] == true,
    drafts: (json['drafts'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) => AiDraft.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false),
  );
}

class AiActionProposal {
  const AiActionProposal({
    required this.runId,
    required this.toolCallId,
    required this.approvalId,
    required this.actionKey,
    required this.status,
    required this.argumentsRedacted,
    required this.expiresAt,
    required this.locale,
  });

  final String runId;
  final String toolCallId;
  final String approvalId;
  final String actionKey;
  final String status;
  final Map<String, dynamic> argumentsRedacted;
  final String? expiresAt;
  final String locale;

  factory AiActionProposal.fromJson(Map<String, dynamic> json) =>
      AiActionProposal(
        runId: json['run_id']?.toString() ?? '',
        toolCallId: json['tool_call_id']?.toString() ?? '',
        approvalId: json['approval_id']?.toString() ?? '',
        actionKey: json['action_key']?.toString() ?? '',
        status: json['status']?.toString() ?? 'unknown',
        argumentsRedacted: _mapValue(json['arguments']),
        expiresAt: json['expires_at']?.toString(),
        locale: json['locale']?.toString() ?? 'ar',
      );
}

class AiApprovalSummary {
  const AiApprovalSummary({
    required this.approvalId,
    required this.runId,
    required this.toolCallId,
    required this.toolName,
    required this.argumentsHash,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    this.decisionReason,
    this.decidedAt,
  });

  final String approvalId;
  final String runId;
  final String toolCallId;
  final String toolName;
  final String argumentsHash;
  final String status;
  final String? decisionReason;
  final String? createdAt;
  final String? expiresAt;
  final String? decidedAt;

  factory AiApprovalSummary.fromJson(Map<String, dynamic> json) =>
      AiApprovalSummary(
        approvalId: json['approval_id']?.toString() ?? '',
        runId: json['run_id']?.toString() ?? '',
        toolCallId: json['tool_call_id']?.toString() ?? '',
        toolName: json['tool_name']?.toString() ?? '',
        argumentsHash: json['arguments_hash']?.toString() ?? '',
        status: json['status']?.toString() ?? 'unknown',
        decisionReason: json['decision_reason']?.toString(),
        createdAt: json['created_at']?.toString(),
        expiresAt: json['expires_at']?.toString(),
        decidedAt: json['decided_at']?.toString(),
      );
}

class AiToolCallSummary {
  const AiToolCallSummary({
    required this.toolCallId,
    required this.runId,
    required this.toolName,
    required this.actionClass,
    required this.status,
    required this.argumentsHash,
    required this.argumentsRedacted,
    required this.approvalRequired,
    this.errorCode,
  });

  final String toolCallId;
  final String runId;
  final String toolName;
  final String actionClass;
  final String status;
  final String argumentsHash;
  final Map<String, dynamic> argumentsRedacted;
  final bool approvalRequired;
  final String? errorCode;

  factory AiToolCallSummary.fromJson(Map<String, dynamic> json) =>
      AiToolCallSummary(
        toolCallId: json['tool_call_id']?.toString() ?? '',
        runId: json['run_id']?.toString() ?? '',
        toolName: json['tool_name']?.toString() ?? '',
        actionClass: json['action_class']?.toString() ?? 'unknown',
        status: json['status']?.toString() ?? 'unknown',
        argumentsHash: json['arguments_hash']?.toString() ?? '',
        argumentsRedacted: _mapValue(json['arguments_redacted']),
        approvalRequired: json['approval_required'] == true,
        errorCode: json['error_code']?.toString(),
      );
}

class AiApprovalDecisionResult {
  const AiApprovalDecisionResult({
    required this.approvalId,
    required this.toolCallId,
    required this.status,
    required this.toolStatus,
  });

  final String approvalId;
  final String toolCallId;
  final String status;
  final String toolStatus;

  factory AiApprovalDecisionResult.fromJson(Map<String, dynamic> json) =>
      AiApprovalDecisionResult(
        approvalId: json['approval_id']?.toString() ?? '',
        toolCallId: json['tool_call_id']?.toString() ?? '',
        status: json['status']?.toString() ?? 'unknown',
        toolStatus: json['tool_status']?.toString() ?? 'unknown',
      );
}

class AiActionExecutionResult {
  const AiActionExecutionResult({
    required this.runId,
    required this.toolCallId,
    required this.actionKey,
    required this.status,
    required this.idempotent,
    required this.result,
    required this.locale,
  });

  final String runId;
  final String toolCallId;
  final String actionKey;
  final String status;
  final bool idempotent;
  final Map<String, dynamic> result;
  final String locale;

  factory AiActionExecutionResult.fromJson(Map<String, dynamic> json) =>
      AiActionExecutionResult(
        runId: json['run_id']?.toString() ?? '',
        toolCallId: json['tool_call_id']?.toString() ?? '',
        actionKey: json['action_key']?.toString() ?? '',
        status: json['status']?.toString() ?? 'unknown',
        idempotent: json['idempotent'] == true,
        result: _mapValue(json['result']),
        locale: json['locale']?.toString() ?? 'ar',
      );
}

Map<String, dynamic> _mapValue(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

class IdentityVerificationSummary {
  const IdentityVerificationSummary({
    this.status,
    this.decisionNote,
    this.evidenceKinds = const [],
  });
  final String? status;
  final String? decisionNote;
  final List<String> evidenceKinds;

  factory IdentityVerificationSummary.fromJson(Map<String, dynamic> json) {
    final identityCase = json['identityCase'] as Map<String, dynamic>?;
    return IdentityVerificationSummary(
      status: identityCase?['status'] as String?,
      decisionNote:
          identityCase?['decisionNote'] as String? ??
          identityCase?['decision_note'] as String?,
      evidenceKinds: (json['evidenceKinds'] as List<dynamic>? ?? const [])
          .map(_stringValue)
          .toList(),
    );
  }
}

class AdminIdentityCase {
  const AdminIdentityCase({
    required this.id,
    required this.merchantId,
    required this.status,
  });
  final String id;
  final String merchantId;
  final String status;
  factory AdminIdentityCase.fromJson(Map<String, dynamic> json) =>
      AdminIdentityCase(
        id: _stringValue(json['id']),
        merchantId: _stringValue(json['merchantId'] ?? json['merchant_id']),
        status: json['status'] as String,
      );
}

class AdminIdentityEvidence {
  const AdminIdentityEvidence({required this.kind, required this.signedUrl});
  final String kind;
  final String signedUrl;
  factory AdminIdentityEvidence.fromJson(Map<String, dynamic> json) =>
      AdminIdentityEvidence(
        kind: json['kind'] as String,
        signedUrl: json['signedUrl'] as String? ?? json['signed_url'] as String,
      );
}

class MerchantShopSummary {
  const MerchantShopSummary({
    required this.id,
    required this.name,
    required this.status,
    this.areaLabel,
  });
  final String id;
  final String name;
  final String status;
  final String? areaLabel;
  factory MerchantShopSummary.fromJson(Map<String, dynamic> json) =>
      MerchantShopSummary(
        id: _stringValue(json['id']),
        name: json['name'] as String,
        status: json['status'] as String,
        areaLabel:
            json['areaLabel'] as String? ?? json['area_label'] as String?,
      );
}

class MerchantPaymentMethodSummary {
  const MerchantPaymentMethodSummary({
    required this.id,
    required this.name,
    required this.accountHolderName,
    required this.receivingIdentifier,
    required this.instructions,
    required this.proofRequirement,
    required this.isActive,
    required this.providerCode,
    this.providerMetadata = const {},
  });
  final String id;
  final String name;
  final String accountHolderName;
  final String receivingIdentifier;
  final String instructions;
  final String proofRequirement;
  final bool isActive;
  final String providerCode;
  final Map<String, dynamic> providerMetadata;
  factory MerchantPaymentMethodSummary.fromJson(Map<String, dynamic> json) =>
      MerchantPaymentMethodSummary(
        id: _stringValue(json['id']),
        name: json['name'] as String,
        accountHolderName:
            json['accountHolderName'] as String? ??
            json['account_holder_name'] as String,
        receivingIdentifier:
            json['receivingIdentifier'] as String? ??
            json['receiving_identifier'] as String,
        instructions:
            json['customerInstructions'] as String? ??
            json['customer_instructions'] as String,
        proofRequirement:
            json['proofRequirement'] as String? ??
            json['proof_requirement'] as String,
        isActive: json['isActive'] as bool? ?? json['is_active'] as bool,
        providerCode:
            json['providerCode'] as String? ??
            json['provider_code'] as String? ??
            'manual',
        providerMetadata: Map<String, dynamic>.from(
          (json['providerMetadata'] ?? json['provider_metadata'] ?? const {})
              as Map,
        ),
      );
}

class MerchantManagedOrder {
  const MerchantManagedOrder({
    required this.id,
    required this.totalMinor,
    required this.paymentStatus,
    required this.fulfilmentStatus,
    this.providerCode = 'manual',
    this.deliveryFeeMinor = 0,
    this.codExpectedMinor = 0,
    this.codCollectedMinor = 0,
    this.codStatus = 'not_applicable',
  });
  final String id;
  final int totalMinor;
  final String paymentStatus;
  final String fulfilmentStatus;
  final String providerCode;
  final int deliveryFeeMinor;
  final int codExpectedMinor;
  final int codCollectedMinor;
  final String codStatus;
  factory MerchantManagedOrder.fromJson(Map<String, dynamic> json) =>
      MerchantManagedOrder(
        id: _stringValue(json['id']),
        totalMinor: _intValue(json['totalMinor'] ?? json['total_minor']),
        paymentStatus:
            json['paymentStatus'] as String? ??
            json['payment_status'] as String,
        fulfilmentStatus:
            json['fulfilmentStatus'] as String? ??
            json['fulfilment_status'] as String,
        providerCode:
            json['providerCode'] as String? ??
            json['payment_provider_code'] as String? ??
            'manual',
        deliveryFeeMinor: _intValue(
          json['deliveryFeeMinor'] ?? json['delivery_fee_minor'],
        ),
        codExpectedMinor: _intValue(
          json['codExpectedMinor'] ?? json['cod_expected_minor'],
        ),
        codCollectedMinor: _intValue(
          json['codCollectedMinor'] ?? json['cod_collected_minor'],
        ),
        codStatus:
            json['codStatus'] as String? ??
            json['cod_status'] as String? ??
            'not_applicable',
      );
}

class MerchantWorkspace {
  const MerchantWorkspace({
    this.merchantId,
    this.verificationStatus,
    this.shops = const [],
    this.paymentMethods = const [],
    this.orders = const [],
  });
  final String? merchantId;
  final String? verificationStatus;
  final List<MerchantShopSummary> shops;
  final List<MerchantPaymentMethodSummary> paymentMethods;
  final List<MerchantManagedOrder> orders;
  bool get exists => merchantId != null;
  factory MerchantWorkspace.fromJson(Map<String, dynamic> json) {
    final merchant = json['merchant'] as Map<String, dynamic>?;
    return MerchantWorkspace(
      merchantId: merchant == null ? null : _stringValue(merchant['id']),
      verificationStatus:
          merchant?['verificationStatus'] as String? ??
          merchant?['verification_status'] as String?,
      shops: (json['shops'] as List<dynamic>? ?? const [])
          .map(
            (item) => MerchantShopSummary.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      paymentMethods: (json['paymentMethods'] as List<dynamic>? ?? const [])
          .map(
            (item) => MerchantPaymentMethodSummary.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      orders: (json['orders'] as List<dynamic>? ?? const [])
          .map(
            (item) => MerchantManagedOrder.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
    );
  }
}

class MarketConfig {
  const MarketConfig({
    required this.id,
    required this.governorate,
    required this.city,
    required this.currency,
    required this.isPilot,
  });
  final String id;
  final String governorate;
  final String city;
  final String currency;
  final bool isPilot;

  factory MarketConfig.fromJson(Map<String, dynamic> json) => MarketConfig(
    id: _stringValue(json['id']),
    governorate: json['governorate'] as String,
    city: json['city'] as String,
    currency: json['currency'] as String,
    isPilot: json['isPilot'] as bool? ?? json['is_pilot'] as bool,
  );
}

class MarketServiceArea {
  const MarketServiceArea({
    required this.id,
    required this.marketId,
    required this.nameAr,
    required this.areaCode,
    required this.status,
    required this.deliveryEnabled,
    required this.pickupEnabled,
  });

  final String id;
  final String marketId;
  final String nameAr;
  final String areaCode;
  final String status;
  final bool deliveryEnabled;
  final bool pickupEnabled;

  factory MarketServiceArea.fromJson(Map<String, dynamic> json) =>
      MarketServiceArea(
        id: _stringValue(json['id']),
        marketId: _stringValue(json['marketId'] ?? json['market_id']),
        nameAr: json['nameAr'] as String? ?? json['name_ar'] as String,
        areaCode: json['areaCode'] as String? ?? json['area_code'] as String,
        status: json['status'] as String? ?? 'draft',
        deliveryEnabled:
            json['deliveryEnabled'] as bool? ??
            json['delivery_enabled'] as bool? ??
            true,
        pickupEnabled:
            json['pickupEnabled'] as bool? ??
            json['pickup_enabled'] as bool? ??
            true,
      );
}

class PickupPoint {
  const PickupPoint({
    required this.id,
    required this.marketId,
    required this.nameAr,
    required this.addressDetails,
    this.serviceAreaId,
    this.contactPhone,
    this.operatingHours,
  });

  final String id;
  final String marketId;
  final String nameAr;
  final String addressDetails;
  final String? serviceAreaId;
  final String? contactPhone;
  final String? operatingHours;

  factory PickupPoint.fromJson(Map<String, dynamic> json) => PickupPoint(
    id: _stringValue(json['id']),
    marketId: _stringValue(json['marketId'] ?? json['market_id']),
    nameAr: json['nameAr'] as String? ?? json['name_ar'] as String,
    addressDetails:
        json['addressDetails'] as String? ?? json['address_details'] as String,
    serviceAreaId:
        json['serviceAreaId'] as String? ?? json['service_area_id'] as String?,
    contactPhone:
        json['contactPhone'] as String? ?? json['contact_phone'] as String?,
    operatingHours:
        json['operatingHours'] as String? ?? json['operating_hours'] as String?,
  );
}

class CustomerAddress {
  const CustomerAddress({
    required this.id,
    required this.marketId,
    required this.label,
    required this.recipientName,
    required this.phone,
    required this.addressLine,
    required this.city,
    required this.isDefault,
    this.serviceAreaId,
    this.landmark,
    this.district,
  });

  final String id;
  final String marketId;
  final String label;
  final String recipientName;
  final String phone;
  final String addressLine;
  final String city;
  final bool isDefault;
  final String? serviceAreaId;
  final String? landmark;
  final String? district;

  factory CustomerAddress.fromJson(
    Map<String, dynamic> json,
  ) => CustomerAddress(
    id: _stringValue(json['id']),
    marketId: _stringValue(json['marketId'] ?? json['market_id']),
    label: json['label'] as String,
    recipientName:
        json['recipientName'] as String? ?? json['recipient_name'] as String,
    phone: json['phone'] as String,
    addressLine:
        json['addressLine'] as String? ?? json['address_line'] as String,
    city: json['city'] as String,
    isDefault:
        json['isDefault'] as bool? ?? json['is_default'] as bool? ?? false,
    serviceAreaId:
        json['serviceAreaId'] as String? ?? json['service_area_id'] as String?,
    landmark: json['landmark'] as String?,
    district: json['district'] as String?,
  );
}

class MerchantDeliveryZone {
  const MerchantDeliveryZone({
    required this.id,
    required this.shopId,
    required this.name,
    required this.feeMinor,
    required this.isActive,
    this.serviceAreaId,
    this.etaMinMinutes,
    this.etaMaxMinutes,
    this.instructions,
  });

  final String id;
  final String shopId;
  final String name;
  final int feeMinor;
  final bool isActive;
  final String? serviceAreaId;
  final int? etaMinMinutes;
  final int? etaMaxMinutes;
  final String? instructions;

  factory MerchantDeliveryZone.fromJson(
    Map<String, dynamic> json,
  ) => MerchantDeliveryZone(
    id: _stringValue(json['id']),
    shopId: _stringValue(json['shopId'] ?? json['shop_id']),
    name: json['name'] as String,
    feeMinor: _intValue(json['feeMinor'] ?? json['fee_minor']),
    isActive: json['isActive'] as bool? ?? json['is_active'] as bool? ?? true,
    serviceAreaId:
        json['serviceAreaId'] as String? ?? json['service_area_id'] as String?,
    etaMinMinutes: (json['etaMinMinutes'] ?? json['eta_min_minutes']) as int?,
    etaMaxMinutes: (json['etaMaxMinutes'] ?? json['eta_max_minutes']) as int?,
    instructions: json['instructions'] as String?,
  );
}

class FeatureAvailability {
  const FeatureAvailability({
    required this.key,
    required this.enabled,
    this.reasonAr,
  });
  final String key;
  final bool enabled;
  final String? reasonAr;
}

class MerchantAnalytics {
  const MerchantAnalytics({
    required this.shopId,
    required this.ordersCount,
    required this.paidOrdersCount,
    required this.completedOrdersCount,
    required this.grossPaidMinor,
    required this.activeProductsCount,
    required this.lowStockProductsCount,
    required this.openCasesCount,
  });

  final String shopId;
  final int ordersCount;
  final int paidOrdersCount;
  final int completedOrdersCount;
  final int grossPaidMinor;
  final int activeProductsCount;
  final int lowStockProductsCount;
  final int openCasesCount;

  factory MerchantAnalytics.fromJson(Map<String, dynamic> json) =>
      MerchantAnalytics(
        shopId: _stringValue(json['shopId'] ?? json['shop_id']),
        ordersCount: _intValue(json['ordersCount'] ?? json['orders_count']),
        paidOrdersCount: _intValue(
          json['paidOrdersCount'] ?? json['paid_orders_count'],
        ),
        completedOrdersCount: _intValue(
          json['completedOrdersCount'] ?? json['completed_orders_count'],
        ),
        grossPaidMinor: _intValue(
          json['grossPaidMinor'] ?? json['gross_paid_minor'],
        ),
        activeProductsCount: _intValue(
          json['activeProductsCount'] ?? json['active_products_count'],
        ),
        lowStockProductsCount: _intValue(
          json['lowStockProductsCount'] ?? json['low_stock_products_count'],
        ),
        openCasesCount: _intValue(
          json['openCasesCount'] ?? json['open_cases_count'],
        ),
      );
}

class MerchantQualitySummary {
  const MerchantQualitySummary({
    required this.shopId,
    required this.ordersCount,
    required this.completedOrdersCount,
    required this.cancelledOrdersCount,
    required this.disputedOrdersCount,
    required this.openRiskSignalsCount,
    this.averageRating,
  });

  final String shopId;
  final int ordersCount;
  final int completedOrdersCount;
  final int cancelledOrdersCount;
  final int disputedOrdersCount;
  final int openRiskSignalsCount;
  final double? averageRating;

  factory MerchantQualitySummary.fromJson(Map<String, dynamic> json) =>
      MerchantQualitySummary(
        shopId: _stringValue(json['shopId'] ?? json['shop_id']),
        ordersCount: _intValue(json['ordersCount'] ?? json['orders_count']),
        completedOrdersCount: _intValue(
          json['completedOrdersCount'] ?? json['completed_orders_count'],
        ),
        cancelledOrdersCount: _intValue(
          json['cancelledOrdersCount'] ?? json['cancelled_orders_count'],
        ),
        disputedOrdersCount: _intValue(
          json['disputedOrdersCount'] ?? json['disputed_orders_count'],
        ),
        openRiskSignalsCount: _intValue(
          json['openRiskSignalsCount'] ?? json['open_risk_signals_count'],
        ),
        averageRating: (json['averageRating'] ?? json['average_rating']) is num
            ? ((json['averageRating'] ?? json['average_rating']) as num)
                  .toDouble()
            : null,
      );
}

class ProviderCatalogEntry {
  const ProviderCatalogEntry({
    required this.providerCode,
    required this.category,
    required this.displayNameAr,
    required this.integrationMode,
    required this.readinessState,
    required this.supportsWebhooks,
    this.notesAr,
  });

  final String providerCode;
  final String category;
  final String displayNameAr;
  final String integrationMode;
  final String readinessState;
  final bool supportsWebhooks;
  final String? notesAr;

  factory ProviderCatalogEntry.fromJson(
    Map<String, dynamic> json,
  ) => ProviderCatalogEntry(
    providerCode:
        json['providerCode'] as String? ?? json['provider_code'] as String,
    category: json['category'] as String,
    displayNameAr:
        json['displayNameAr'] as String? ?? json['display_name_ar'] as String,
    integrationMode:
        json['integrationMode'] as String? ??
        json['integration_mode'] as String,
    readinessState:
        json['readinessState'] as String? ?? json['readiness_state'] as String,
    supportsWebhooks:
        json['supportsWebhooks'] as bool? ??
        json['supports_webhooks'] as bool? ??
        false,
    notesAr: json['notesAr'] as String? ?? json['notes_ar'] as String?,
  );
}

class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.category,
    required this.subject,
    required this.status,
    required this.priority,
  });

  final String id;
  final String category;
  final String subject;
  final String status;
  final String priority;

  factory SupportTicket.fromJson(Map<String, dynamic> json) => SupportTicket(
    id: _stringValue(json['id']),
    category: json['category'] as String,
    subject: json['subject'] as String,
    status: json['status'] as String,
    priority: json['priority'] as String,
  );
}

class StorefrontSettings {
  const StorefrontSettings({
    required this.shopId,
    required this.themeKey,
    required this.primaryColor,
    required this.isPublished,
    this.displayName,
    this.tagline,
    this.logoStorageKey,
    this.customSlug,
    this.customDomain,
  });

  final String shopId;
  final String? displayName;
  final String? tagline;
  final String themeKey;
  final String primaryColor;
  final String? logoStorageKey;
  final String? customSlug;
  final String? customDomain;
  final bool isPublished;

  factory StorefrontSettings.fromJson(
    Map<String, dynamic> json,
  ) => StorefrontSettings(
    shopId: _stringValue(json['shopId'] ?? json['shop_id']),
    displayName:
        json['displayName'] as String? ?? json['display_name'] as String?,
    tagline: json['tagline'] as String?,
    themeKey:
        json['themeKey'] as String? ??
        json['theme_key'] as String? ??
        'yemen_teal',
    primaryColor:
        json['primaryColor'] as String? ??
        json['primary_color'] as String? ??
        '#006A63',
    logoStorageKey:
        json['logoStorageKey'] as String? ??
        json['logo_storage_key'] as String?,
    customSlug: json['customSlug'] as String? ?? json['custom_slug'] as String?,
    customDomain:
        json['customDomain'] as String? ?? json['custom_domain'] as String?,
    isPublished:
        json['isPublished'] as bool? ?? json['is_published'] as bool? ?? false,
  );
}

class InventoryLocation {
  const InventoryLocation({
    required this.id,
    required this.shopId,
    required this.name,
    required this.status,
    required this.isDefault,
    this.areaLabel,
  });

  final String id;
  final String shopId;
  final String name;
  final String? areaLabel;
  final String status;
  final bool isDefault;

  factory InventoryLocation.fromJson(Map<String, dynamic> json) =>
      InventoryLocation(
        id: _stringValue(json['id']),
        shopId: _stringValue(json['shopId'] ?? json['shop_id']),
        name: json['name'] as String,
        areaLabel:
            json['areaLabel'] as String? ?? json['area_label'] as String?,
        status: json['status'] as String? ?? 'active',
        isDefault:
            json['isDefault'] as bool? ?? json['is_default'] as bool? ?? false,
      );
}

class MerchantProductSummary {
  const MerchantProductSummary({
    required this.id,
    required this.shopId,
    required this.shopName,
    required this.name,
    required this.priceMinor,
    required this.stockQuantity,
    required this.status,
    this.description,
    this.currency = 'YER',
    this.barcode,
  });

  final String id;
  final String shopId;
  final String shopName;
  final String name;
  final String? description;
  final int priceMinor;
  final int stockQuantity;
  final String status;
  final String currency;
  final String? barcode;

  factory MerchantProductSummary.fromJson(Map<String, dynamic> json) {
    final shop = json['shops'] is Map
        ? Map<String, dynamic>.from(json['shops'] as Map)
        : const <String, dynamic>{};
    return MerchantProductSummary(
      id: _stringValue(json['id']),
      shopId: _stringValue(json['shopId'] ?? json['shop_id']),
      shopName:
          json['shopName'] as String? ??
          json['shop_name'] as String? ??
          shop['name'] as String? ??
          '',
      name: json['name'] as String,
      description: json['description'] as String?,
      priceMinor: _intValue(json['priceMinor'] ?? json['price_minor']),
      stockQuantity: _intValue(json['stockQuantity'] ?? json['stock_quantity']),
      status: json['status'] as String? ?? 'draft',
      currency: json['currency'] as String? ?? 'YER',
      barcode: json['barcode'] as String?,
    );
  }
}

class InventoryAdjustmentResult {
  const InventoryAdjustmentResult({
    required this.movementId,
    required this.productId,
    required this.locationId,
    required this.previousQuantity,
    required this.resultingQuantity,
    required this.totalProductQuantity,
    required this.idempotent,
  });

  final String movementId;
  final String productId;
  final String locationId;
  final int previousQuantity;
  final int resultingQuantity;
  final int totalProductQuantity;
  final bool idempotent;

  factory InventoryAdjustmentResult.fromJson(Map<String, dynamic> json) =>
      InventoryAdjustmentResult(
        movementId: _stringValue(json['movementId'] ?? json['movement_id']),
        productId: _stringValue(json['productId'] ?? json['product_id']),
        locationId: _stringValue(json['locationId'] ?? json['location_id']),
        previousQuantity: _intValue(
          json['previousQuantity'] ?? json['previous_quantity'],
        ),
        resultingQuantity: _intValue(
          json['resultingQuantity'] ?? json['resulting_quantity'],
        ),
        totalProductQuantity: _intValue(
          json['totalProductQuantity'] ?? json['total_product_quantity'],
        ),
        idempotent: json['idempotent'] as bool? ?? false,
      );
}

class InventoryCommandResult {
  const InventoryCommandResult({
    required this.id,
    required this.status,
    required this.idempotent,
    this.itemCount,
  });

  final String id;
  final String status;
  final bool idempotent;
  final int? itemCount;

  factory InventoryCommandResult.fromJson(Map<String, dynamic> json) =>
      InventoryCommandResult(
        id: _stringValue(
          json['transferId'] ??
              json['transfer_id'] ??
              json['countId'] ??
              json['count_id'],
        ),
        status: json['status'] as String? ?? 'completed',
        idempotent: json['idempotent'] as bool? ?? false,
        itemCount: json['itemCount'] == null && json['item_count'] == null
            ? null
            : _intValue(json['itemCount'] ?? json['item_count']),
      );
}

class MerchantOrderWorkbenchEntry {
  const MerchantOrderWorkbenchEntry({
    required this.id,
    required this.orderReference,
    required this.shopId,
    required this.paymentStatus,
    required this.fulfilmentStatus,
    required this.codStatus,
    required this.currency,
    required this.subtotalMinor,
    required this.feeMinor,
    required this.taxMinor,
    required this.totalMinor,
    required this.codExpectedMinor,
    required this.codCollectedMinor,
    required this.fulfilmentMethod,
    required this.createdAt,
    required this.updatedAt,
    required this.itemCount,
    required this.hasOpenCase,
    required this.hasActiveCourierAssignment,
  });

  final String id;
  final String orderReference;
  final String shopId;
  final String paymentStatus;
  final String fulfilmentStatus;
  final String codStatus;
  final String currency;
  final int subtotalMinor;
  final int feeMinor;
  final int taxMinor;
  final int totalMinor;
  final int codExpectedMinor;
  final int codCollectedMinor;
  final String fulfilmentMethod;
  final String createdAt;
  final String updatedAt;
  final int itemCount;
  final bool hasOpenCase;
  final bool hasActiveCourierAssignment;

  factory MerchantOrderWorkbenchEntry.fromJson(
    Map<String, dynamic> json,
  ) => MerchantOrderWorkbenchEntry(
    id: _stringValue(json['id']),
    orderReference: _stringValue(
      json['orderReference'] ?? json['order_reference'],
    ),
    shopId: _stringValue(json['shopId'] ?? json['shop_id']),
    paymentStatus:
        json['paymentStatus'] as String? ??
        json['payment_status'] as String? ??
        'awaiting_payment',
    fulfilmentStatus:
        json['fulfilmentStatus'] as String? ??
        json['fulfilment_status'] as String? ??
        'pending',
    codStatus:
        json['codStatus'] as String? ??
        json['cod_status'] as String? ??
        'not_applicable',
    currency: json['currency'] as String? ?? 'YER',
    subtotalMinor: _intValue(json['subtotalMinor'] ?? json['subtotal_minor']),
    feeMinor: _intValue(json['feeMinor'] ?? json['fee_minor']),
    taxMinor: _intValue(json['taxMinor'] ?? json['tax_minor']),
    totalMinor: _intValue(json['totalMinor'] ?? json['total_minor']),
    codExpectedMinor: _intValue(
      json['codExpectedMinor'] ?? json['cod_expected_minor'],
    ),
    codCollectedMinor: _intValue(
      json['codCollectedMinor'] ?? json['cod_collected_minor'],
    ),
    fulfilmentMethod:
        json['fulfilmentMethod'] as String? ??
        json['fulfilment_method'] as String? ??
        'collection',
    createdAt: _stringValue(json['createdAt'] ?? json['created_at']),
    updatedAt: _stringValue(json['updatedAt'] ?? json['updated_at']),
    itemCount: _intValue(json['itemCount'] ?? json['item_count']),
    hasOpenCase:
        json['hasOpenCase'] as bool? ?? json['has_open_case'] as bool? ?? false,
    hasActiveCourierAssignment:
        json['hasActiveCourierAssignment'] as bool? ??
        json['has_active_courier_assignment'] as bool? ??
        false,
  );
}

class CodReconciliationBatch {
  const CodReconciliationBatch({
    required this.id,
    required this.shopId,
    required this.businessDate,
    required this.status,
    required this.expectedTotalMinor,
    required this.collectedTotalMinor,
    required this.varianceMinor,
    this.note,
    this.closedAt,
  });

  final String id;
  final String shopId;
  final String businessDate;
  final String status;
  final int expectedTotalMinor;
  final int collectedTotalMinor;
  final int varianceMinor;
  final String? note;
  final String? closedAt;

  factory CodReconciliationBatch.fromJson(
    Map<String, dynamic> json,
  ) => CodReconciliationBatch(
    id: _stringValue(json['batchId'] ?? json['batch_id']),
    shopId: _stringValue(json['shopId'] ?? json['shop_id']),
    businessDate: _stringValue(json['businessDate'] ?? json['business_date']),
    status: json['status'] as String? ?? 'open',
    expectedTotalMinor: _intValue(
      json['expectedTotalMinor'] ?? json['expected_total_minor'],
    ),
    collectedTotalMinor: _intValue(
      json['collectedTotalMinor'] ?? json['collected_total_minor'],
    ),
    varianceMinor: _intValue(json['varianceMinor'] ?? json['variance_minor']),
    note: json['note'] as String?,
    closedAt: json['closedAt'] as String? ?? json['closed_at'] as String?,
  );
}

class CodReconciliationCloseResult {
  const CodReconciliationCloseResult({
    required this.batchId,
    required this.status,
    required this.expectedTotalMinor,
    required this.collectedTotalMinor,
    required this.varianceMinor,
  });

  final String batchId;
  final String status;
  final int expectedTotalMinor;
  final int collectedTotalMinor;
  final int varianceMinor;

  factory CodReconciliationCloseResult.fromJson(Map<String, dynamic> json) =>
      CodReconciliationCloseResult(
        batchId: _stringValue(json['batchId'] ?? json['batch_id']),
        status: json['status'] as String? ?? 'variance',
        expectedTotalMinor: _intValue(
          json['expectedTotalMinor'] ?? json['expected_total_minor'],
        ),
        collectedTotalMinor: _intValue(
          json['collectedTotalMinor'] ?? json['collected_total_minor'],
        ),
        varianceMinor: _intValue(
          json['varianceMinor'] ?? json['variance_minor'],
        ),
      );
}

class CodReconciliationEntry {
  const CodReconciliationEntry({
    required this.recordId,
    required this.merchantOrderId,
    required this.orderReference,
    required this.expectedMinor,
    required this.collectedMinor,
    required this.status,
    required this.createdAt,
    this.note,
  });

  final String? recordId;
  final String merchantOrderId;
  final String orderReference;
  final int expectedMinor;
  final int collectedMinor;
  final String status;
  final String createdAt;
  final String? note;

  factory CodReconciliationEntry.fromJson(Map<String, dynamic> json) =>
      CodReconciliationEntry(
        recordId: json['recordId'] as String? ?? json['record_id'] as String?,
        merchantOrderId: _stringValue(
          json['merchantOrderId'] ?? json['merchant_order_id'],
        ),
        orderReference: _stringValue(
          json['orderReference'] ?? json['order_reference'],
        ),
        expectedMinor: _intValue(
          json['expectedMinor'] ?? json['expected_minor'],
        ),
        collectedMinor: _intValue(
          json['collectedMinor'] ?? json['collected_minor'],
        ),
        status: json['status'] as String? ?? 'expected',
        createdAt: _stringValue(json['createdAt'] ?? json['created_at']),
        note: json['note'] as String?,
      );
}

class CodReconciliationSnapshot {
  const CodReconciliationSnapshot({
    this.batch,
    this.rows = const [],
    this.limit = 50,
    this.offset = 0,
  });

  final CodReconciliationBatch? batch;
  final List<CodReconciliationEntry> rows;
  final int limit;
  final int offset;

  factory CodReconciliationSnapshot.fromJson(Map<String, dynamic> json) {
    final batchJson = json['batch'];
    final rowsJson = json['rows'] as List<dynamic>? ?? const [];
    return CodReconciliationSnapshot(
      batch: batchJson is Map
          ? CodReconciliationBatch.fromJson(
              Map<String, dynamic>.from(batchJson),
            )
          : null,
      rows: rowsJson
          .whereType<Map>()
          .map(
            (row) =>
                CodReconciliationEntry.fromJson(Map<String, dynamic>.from(row)),
          )
          .toList(growable: false),
      limit: _intValue(json['limit'] ?? 50),
      offset: _intValue(json['offset'] ?? 0),
    );
  }
}

class CatalogImportResult {
  const CatalogImportResult({
    required this.batchId,
    required this.status,
    required this.rowCount,
    required this.appliedCount,
    required this.idempotent,
  });

  final String batchId;
  final String status;
  final int rowCount;
  final int appliedCount;
  final bool idempotent;

  factory CatalogImportResult.fromJson(Map<String, dynamic> json) =>
      CatalogImportResult(
        batchId: _stringValue(json['batchId'] ?? json['batch_id']),
        status: json['status'] as String? ?? 'applied',
        rowCount: _intValue(json['rowCount'] ?? json['row_count']),
        appliedCount: _intValue(json['appliedCount'] ?? json['applied_count']),
        idempotent: json['idempotent'] as bool? ?? false,
      );
}

class ProductVariant {
  const ProductVariant({
    required this.id,
    required this.productId,
    required this.name,
    required this.priceMinor,
    required this.stockQuantity,
    required this.status,
    this.sku,
  });

  final String id;
  final String productId;
  final String name;
  final String? sku;
  final int priceMinor;
  final int stockQuantity;
  final String status;

  factory ProductVariant.fromJson(Map<String, dynamic> json) => ProductVariant(
    id: _stringValue(json['id']),
    productId: _stringValue(json['productId'] ?? json['product_id']),
    name: json['name'] as String,
    sku: json['sku'] as String?,
    priceMinor: _intValue(json['priceMinor'] ?? json['price_minor']),
    stockQuantity: _intValue(json['stockQuantity'] ?? json['stock_quantity']),
    status: json['status'] as String? ?? 'draft',
  );
}

class MarketplaceProduct {
  const MarketplaceProduct({
    required this.id,
    required this.name,
    required this.priceMinor,
    required this.currency,
    required this.stockQuantity,
    required this.shopName,
    required this.shopSlug,
  });
  final String id;
  final String name;
  final int priceMinor;
  final String currency;
  final int stockQuantity;
  final String shopName;
  final String shopSlug;

  factory MarketplaceProduct.fromCatalogJson(Map<String, dynamic> json) {
    final product = Map<String, dynamic>.from((json['product'] ?? json) as Map);
    final shop = Map<String, dynamic>.from(
      (json['shops'] ?? const <String, dynamic>{}) as Map,
    );
    return MarketplaceProduct(
      id: _stringValue(product['id']),
      name: product['name'] as String,
      priceMinor: _intValue(product['priceMinor'] ?? product['price_minor']),
      currency: product['currency'] as String,
      stockQuantity: _intValue(
        product['stockQuantity'] ?? product['stock_quantity'],
      ),
      shopName:
          json['shopName'] as String? ??
          json['shop_name'] as String? ??
          shop['name'] as String? ??
          '',
      shopSlug:
          json['shopSlug'] as String? ??
          json['shop_slug'] as String? ??
          shop['slug'] as String? ??
          '',
    );
  }
}

class SessionUser {
  const SessionUser({required this.id, this.name, required this.role});
  final String id;
  final String? name;
  final String role;

  factory SessionUser.fromJson(Map<String, dynamic> json) => SessionUser(
    id: _stringValue(json['id']),
    name: json['name'] as String? ?? json['display_name'] as String?,
    role: json['role'] as String,
  );
}

class ProductReview {
  const ProductReview({
    required this.id,
    required this.productId,
    required this.rating,
    required this.status,
    this.comment,
  });

  final String id;
  final String productId;
  final int rating;
  final String status;
  final String? comment;

  factory ProductReview.fromJson(Map<String, dynamic> json) => ProductReview(
    id: _stringValue(json['id']),
    productId: _stringValue(json['productId'] ?? json['product_id']),
    rating: _intValue(json['rating']),
    status: json['status'] as String? ?? 'pending',
    comment: json['comment'] as String?,
  );
}

class MerchantPromotion {
  const MerchantPromotion({
    required this.id,
    required this.shopId,
    required this.code,
    required this.kind,
    required this.valueMinor,
    required this.status,
  });

  final String id;
  final String shopId;
  final String code;
  final String kind;
  final int valueMinor;
  final String status;

  factory MerchantPromotion.fromJson(Map<String, dynamic> json) =>
      MerchantPromotion(
        id: _stringValue(json['id']),
        shopId: _stringValue(json['shopId'] ?? json['shop_id']),
        code: json['code'] as String,
        kind: json['kind'] as String,
        valueMinor: _intValue(json['valueMinor'] ?? json['value_minor']),
        status: json['status'] as String? ?? 'draft',
      );
}

class NotificationEvent {
  const NotificationEvent({
    required this.id,
    required this.kind,
    required this.payload,
    required this.createdAt,
    this.readAt,
  });

  final String id;
  final String kind;
  final Map<String, dynamic> payload;
  final String createdAt;
  final String? readAt;

  bool get isRead => readAt != null;

  factory NotificationEvent.fromJson(Map<String, dynamic> json) =>
      NotificationEvent(
        id: _stringValue(json['id']),
        kind: json['kind'] as String,
        payload: Map<String, dynamic>.from(json['payload'] as Map? ?? const {}),
        createdAt: json['createdAt'] as String? ?? json['created_at'] as String,
        readAt: json['readAt'] as String? ?? json['read_at'] as String?,
      );
}

class OrderCaseSummary {
  const OrderCaseSummary({
    required this.id,
    required this.merchantOrderId,
    required this.caseType,
    required this.status,
    required this.reason,
    this.resolutionNote,
  });

  final String id;
  final String merchantOrderId;
  final String caseType;
  final String status;
  final String reason;
  final String? resolutionNote;

  factory OrderCaseSummary.fromJson(Map<String, dynamic> json) =>
      OrderCaseSummary(
        id: _stringValue(json['id']),
        merchantOrderId: _stringValue(
          json['merchantOrderId'] ?? json['merchant_order_id'],
        ),
        caseType: json['caseType'] as String? ?? json['case_type'] as String,
        status: json['status'] as String? ?? 'open',
        reason: json['reason'] as String,
        resolutionNote:
            json['resolutionNote'] as String? ??
            json['resolution_note'] as String?,
      );
}

class MerchantOrderSummary {
  const MerchantOrderSummary({
    required this.id,
    required this.totalMinor,
    required this.currency,
    required this.paymentStatus,
    required this.fulfilmentStatus,
    this.accountHolderName,
    this.receivingIdentifier,
    this.paymentInstructions,
    this.providerCode = 'manual',
    this.deliveryFeeMinor = 0,
    this.codExpectedMinor = 0,
    this.codCollectedMinor = 0,
    this.codStatus = 'not_applicable',
    this.shopId,
    this.orderReference,
  });
  final String id;
  final int totalMinor;
  final String currency;
  final String paymentStatus;
  final String fulfilmentStatus;
  final String? accountHolderName;
  final String? receivingIdentifier;
  final String? paymentInstructions;
  final String providerCode;
  final int deliveryFeeMinor;
  final int codExpectedMinor;
  final int codCollectedMinor;
  final String codStatus;
  final String? shopId;
  final String? orderReference;
  factory MerchantOrderSummary.fromJson(
    Map<String, dynamic> json,
  ) => MerchantOrderSummary(
    id: _stringValue(json['id']),
    totalMinor: _intValue(json['totalMinor'] ?? json['total_minor']),
    currency: json['currency'] as String,
    paymentStatus:
        json['paymentStatus'] as String? ?? json['payment_status'] as String,
    fulfilmentStatus:
        json['fulfilmentStatus'] as String? ??
        json['fulfilment_status'] as String,
    accountHolderName:
        json['accountHolderName'] as String? ??
        json['account_holder_name'] as String?,
    receivingIdentifier:
        json['receivingIdentifier'] as String? ??
        json['receiving_identifier'] as String?,
    paymentInstructions:
        json['paymentInstructions'] as String? ??
        json['payment_instructions'] as String?,
    providerCode:
        json['providerCode'] as String? ??
        json['payment_provider_code'] as String? ??
        'manual',
    deliveryFeeMinor: _intValue(
      json['deliveryFeeMinor'] ?? json['delivery_fee_minor'],
    ),
    codExpectedMinor: _intValue(
      json['codExpectedMinor'] ?? json['cod_expected_minor'],
    ),
    codCollectedMinor: _intValue(
      json['codCollectedMinor'] ?? json['cod_collected_minor'],
    ),
    codStatus:
        json['codStatus'] as String? ??
        json['cod_status'] as String? ??
        'not_applicable',
    shopId: json['shopId'] as String? ?? json['shop_id'] as String?,
    orderReference:
        json['orderReference'] as String? ?? json['order_reference'] as String?,
  );
}

class CartGroup {
  const CartGroup({
    required this.shopId,
    required this.shopName,
    required this.merchantId,
    required this.totalMinor,
    required this.items,
    required this.fulfilmentMethods,
    required this.paymentMethods,
  });
  final String shopId;
  final String shopName;
  final String merchantId;
  final int totalMinor;
  final List<MarketplaceProduct> items;
  final List<String> fulfilmentMethods;
  final List<MerchantPaymentChoice> paymentMethods;
  factory CartGroup.fromJson(Map<String, dynamic> json) {
    final shop = Map<String, dynamic>.from(json['shop'] as Map);
    final items = (json['items'] as List<dynamic>).map((item) {
      final map = Map<String, dynamic>.from(item as Map);
      return MarketplaceProduct(
        id: _stringValue(map['productId'] ?? map['product_id']),
        name: map['name'] as String,
        priceMinor: _intValue(map['unitPriceMinor'] ?? map['unit_price_minor']),
        currency: map['currency'] as String? ?? 'YER',
        stockQuantity: _intValue(map['stockQuantity'] ?? map['stock_quantity']),
        shopName: shop['name'] as String,
        shopSlug: shop['slug'] as String,
      );
    }).toList();
    return CartGroup(
      shopId: _stringValue(shop['id']),
      shopName: shop['name'] as String,
      merchantId: _stringValue(json['merchantId'] ?? json['merchant_id']),
      totalMinor: _intValue(json['totalMinor'] ?? json['total_minor']),
      items: items,
      fulfilmentMethods:
          ((json['fulfilmentMethods'] ??
                      json['fulfilment_methods'] as List<dynamic>? ??
                      const [])
                  .map(
                    (item) => item is String
                        ? item
                        : (item as Map<String, dynamic>)['method'] as String,
                  ))
              .toList(),
      paymentMethods: (json['paymentMethods'] as List<dynamic>? ?? const [])
          .map(
            (item) => MerchantPaymentChoice.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
    );
  }
}

class MerchantPaymentChoice {
  const MerchantPaymentChoice({
    required this.id,
    required this.name,
    this.providerCode = 'manual',
  });
  final String id;
  final String name;
  final String providerCode;
  factory MerchantPaymentChoice.fromJson(Map<String, dynamic> json) =>
      MerchantPaymentChoice(
        id: _stringValue(json['id']),
        name: json['name'] as String,
        providerCode:
            json['providerCode'] as String? ??
            json['provider_code'] as String? ??
            'manual',
      );
}

class WholesalePriceListItemSummary {
  const WholesalePriceListItemSummary({
    required this.id,
    required this.productId,
    required this.productName,
    required this.unitPriceMinor,
    required this.minQuantity,
    required this.status,
    this.variantId,
  });

  final String id;
  final String productId;
  final String productName;
  final String? variantId;
  final int unitPriceMinor;
  final int minQuantity;
  final String status;

  factory WholesalePriceListItemSummary.fromJson(Map<String, dynamic> json) =>
      WholesalePriceListItemSummary(
        id: _stringValue(json['price_list_item_id'] ?? json['id']),
        productId: _stringValue(json['product_id']),
        productName: json['product_name'] as String? ?? 'منتج',
        variantId: json['variant_id'] as String?,
        unitPriceMinor: _intValue(json['unit_price_minor']),
        minQuantity: json['min_quantity'] is num
            ? (json['min_quantity'] as num).toInt()
            : 1,
        status: json['status'] as String? ?? 'active',
      );
}

class WholesalePriceListSummary {
  const WholesalePriceListSummary({
    required this.id,
    required this.shopId,
    required this.nameAr,
    required this.currency,
    required this.status,
    required this.items,
  });

  final String id;
  final String shopId;
  final String nameAr;
  final String currency;
  final String status;
  final List<WholesalePriceListItemSummary> items;

  factory WholesalePriceListSummary.fromJson(Map<String, dynamic> json) =>
      WholesalePriceListSummary(
        id: _stringValue(json['price_list_id'] ?? json['id']),
        shopId: _stringValue(json['shop_id']),
        nameAr: json['name_ar'] as String? ?? 'قائمة أسعار',
        currency: json['currency'] as String? ?? 'YER',
        status: json['status'] as String? ?? 'draft',
        items: (json['items'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map(
              (item) => WholesalePriceListItemSummary.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList(growable: false),
      );
}

class WholesaleQuoteItemSummary {
  const WholesaleQuoteItemSummary({
    required this.id,
    required this.productId,
    required this.productNameSnapshot,
    required this.unitPriceMinor,
    required this.quantity,
    required this.lineTotalMinor,
    this.variantId,
  });

  final String id;
  final String productId;
  final String productNameSnapshot;
  final String? variantId;
  final int unitPriceMinor;
  final int quantity;
  final int lineTotalMinor;

  factory WholesaleQuoteItemSummary.fromJson(Map<String, dynamic> json) =>
      WholesaleQuoteItemSummary(
        id: _stringValue(json['id'] ?? json['quote_item_id']),
        productId: _stringValue(json['product_id']),
        productNameSnapshot: json['product_name_snapshot'] as String? ?? 'منتج',
        variantId: json['variant_id'] as String?,
        unitPriceMinor: _intValue(json['unit_price_minor']),
        quantity: json['quantity'] is num
            ? (json['quantity'] as num).toInt()
            : 1,
        lineTotalMinor: _intValue(json['line_total_minor']),
      );
}

class WholesaleQuoteVersionSummary {
  const WholesaleQuoteVersionSummary({
    required this.id,
    required this.quoteId,
    required this.versionNo,
    required this.status,
    required this.currency,
    required this.reason,
    required this.items,
    this.validUntil,
    this.note,
  });

  final String id;
  final String quoteId;
  final int versionNo;
  final String status;
  final String currency;
  final String reason;
  final DateTime? validUntil;
  final String? note;
  final List<WholesaleQuoteItemSummary> items;

  factory WholesaleQuoteVersionSummary.fromJson(Map<String, dynamic> json) =>
      WholesaleQuoteVersionSummary(
        id: _stringValue(json['quote_version_id'] ?? json['id']),
        quoteId: _stringValue(json['quote_id']),
        versionNo: json['version_no'] is num
            ? (json['version_no'] as num).toInt()
            : 0,
        status: json['status'] as String? ?? 'sent',
        currency: json['currency'] as String? ?? 'YER',
        reason: json['reason'] as String? ?? '',
        validUntil: DateTime.tryParse(json['valid_until']?.toString() ?? ''),
        note: json['note'] as String?,
        items: (json['items'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map(
              (item) => WholesaleQuoteItemSummary.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList(growable: false),
      );
}

class MerchantDailyRollup {
  const MerchantDailyRollup({
    required this.id,
    required this.shopId,
    required this.businessDate,
    required this.orderCount,
    required this.paidOrderCount,
    required this.grossTotalMinor,
    required this.codExpectedMinor,
    required this.codCollectedMinor,
    required this.wholesaleRequestCount,
    required this.wholesaleApprovedCount,
    required this.posSaleCount,
    required this.posGrossTotalMinor,
  });

  final String id;
  final String shopId;
  final DateTime businessDate;
  final int orderCount;
  final int paidOrderCount;
  final int grossTotalMinor;
  final int codExpectedMinor;
  final int codCollectedMinor;
  final int wholesaleRequestCount;
  final int wholesaleApprovedCount;
  final int posSaleCount;
  final int posGrossTotalMinor;

  factory MerchantDailyRollup.fromJson(Map<String, dynamic> json) =>
      MerchantDailyRollup(
        id: _stringValue(json['id'] ?? json['rollup_id']),
        shopId: _stringValue(json['shop_id']),
        businessDate:
            DateTime.tryParse(json['business_date']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        orderCount: _intValue(json['order_count']),
        paidOrderCount: _intValue(json['paid_order_count']),
        grossTotalMinor: _intValue(json['gross_total_minor']),
        codExpectedMinor: _intValue(json['cod_expected_minor']),
        codCollectedMinor: _intValue(json['cod_collected_minor']),
        wholesaleRequestCount: _intValue(json['wholesale_request_count']),
        wholesaleApprovedCount: _intValue(json['wholesale_approved_count']),
        posSaleCount: _intValue(json['pos_sale_count']),
        posGrossTotalMinor: _intValue(json['pos_gross_total_minor']),
      );
}

class ProductAssetVariantSummary {
  const ProductAssetVariantSummary({
    required this.id,
    required this.productId,
    required this.format,
    required this.status,
    required this.width,
    required this.height,
    required this.byteSize,
    this.sourceStorageKey,
    this.optimizedStorageKey,
  });

  final String id;
  final String productId;
  final String format;
  final String status;
  final int width;
  final int height;
  final int byteSize;
  final String? sourceStorageKey;
  final String? optimizedStorageKey;

  factory ProductAssetVariantSummary.fromJson(Map<String, dynamic> json) =>
      ProductAssetVariantSummary(
        id: _stringValue(json['id'] ?? json['asset_variant_id']),
        productId: _stringValue(json['product_id']),
        format: json['format'] as String? ?? 'webp',
        status: json['status'] as String? ?? 'pending',
        width: _intValue(json['width']),
        height: _intValue(json['height']),
        byteSize: _intValue(json['byte_size']),
        sourceStorageKey: json['source_storage_key'] as String?,
        optimizedStorageKey: json['optimized_storage_key'] as String?,
      );
}

class ProviderAdapterOperation {
  const ProviderAdapterOperation({
    required this.providerCode,
    required this.operationKey,
    required this.category,
    required this.enabled,
    required this.requiredReadinessState,
    required this.notesAr,
    this.requiredCapability,
  });

  final String providerCode;
  final String operationKey;
  final String category;
  final bool enabled;
  final String requiredReadinessState;
  final String? requiredCapability;
  final String notesAr;

  factory ProviderAdapterOperation.fromJson(Map<String, dynamic> json) =>
      ProviderAdapterOperation(
        providerCode: _stringValue(json['provider_code']),
        operationKey: _stringValue(json['operation_key']),
        category: json['category'] as String? ?? 'other',
        enabled: json['enabled'] as bool? ?? false,
        requiredReadinessState:
            json['required_readiness_state'] as String? ?? 'configured',
        requiredCapability: json['required_capability'] as String?,
        notesAr: json['notes_ar'] as String? ?? 'الميزة غير مفعلة حالياً.',
      );
}

class WholesaleQuoteSummary {
  const WholesaleQuoteSummary({
    required this.id,
    required this.shopId,
    required this.status,
    required this.currentVersionNo,
    this.buyerUserId,
    this.wholesaleRequestId,
    this.latestVersion,
  });

  final String id;
  final String shopId;
  final String status;
  final int currentVersionNo;
  final String? buyerUserId;
  final String? wholesaleRequestId;
  final WholesaleQuoteVersionSummary? latestVersion;

  factory WholesaleQuoteSummary.fromJson(Map<String, dynamic> json) {
    final latest = json['latest_version'];
    return WholesaleQuoteSummary(
      id: _stringValue(json['quote_id'] ?? json['id']),
      shopId: _stringValue(json['shop_id']),
      status: json['status'] as String? ?? 'draft',
      currentVersionNo: _intValue(json['current_version_no']),
      buyerUserId: json['buyer_user_id'] as String?,
      wholesaleRequestId: json['wholesale_request_id'] as String?,
      latestVersion: latest is Map
          ? WholesaleQuoteVersionSummary.fromJson(
              Map<String, dynamic>.from(latest),
            )
          : null,
    );
  }
}
