import 'package:commerce_core/commerce_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreatorRepository {
  CreatorRepository({SupabaseClient? client})
    : _client = client ?? SupabaseRuntime.client;

  final SupabaseClient _client;

  Future<CreatorAccess> loadAccess() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const CreatorRepositoryException('AUTH_REQUIRED');
    }
    final result = await _client.rpc('creator_current_access');
    final json = Map<String, dynamic>.from(result as Map);
    return CreatorAccess(
      userId: user.id,
      isCreator: json['is_creator'] as bool? ?? false,
      capabilities: ((json['capabilities'] ?? const []) as List<dynamic>)
          .map((item) => item.toString())
          .toSet(),
      accountStatus: (json['account_status'] ?? 'active').toString(),
    );
  }

  Future<CreatorDashboardSummary> dashboardSummary() async {
    final result = await _client.rpc('creator_dashboard_summary');
    return CreatorDashboardSummary.fromJson(
      Map<String, dynamic>.from(result as Map),
    );
  }

  Future<List<CreatorPerson>> searchPeople({
    String? query,
    String? role,
    String? marketId,
    int limit = 50,
    int offset = 0,
  }) async {
    final result = await _client.rpc(
      'creator_people_search',
      params: {
        'p_query': query?.trim().isEmpty == true ? null : query?.trim(),
        'p_role': role,
        'p_market_id': marketId,
        'p_limit': limit.clamp(1, 100),
        'p_offset': offset < 0 ? 0 : offset,
      },
    );
    return (result as List<dynamic>)
        .map(
          (row) =>
              CreatorPerson.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList(growable: false);
  }

  Future<CreatorMutationResult> setRole({
    required String userId,
    required CreatorRole role,
    String? marketId,
    DateTime? expiresAt,
    required String reason,
  }) async {
    final result = await _client.rpc(
      'creator_set_user_role',
      params: {
        'p_user_id': userId,
        'p_role': role.value,
        'p_market_id': marketId,
        'p_expires_at': expiresAt?.toUtc().toIso8601String(),
        'p_reason': reason.trim(),
      },
    );
    return CreatorMutationResult.fromJson(
      Map<String, dynamic>.from(result as Map),
    );
  }

  Future<CreatorMutationResult> revokeRole({
    required String userId,
    required CreatorRole role,
    String? marketId,
    required String reason,
  }) async {
    final result = await _client.rpc(
      'creator_revoke_user_role',
      params: {
        'p_user_id': userId,
        'p_role': role.value,
        'p_market_id': marketId,
        'p_reason': reason.trim(),
      },
    );
    return CreatorMutationResult.fromJson(
      Map<String, dynamic>.from(result as Map),
    );
  }

  Future<CreatorMutationResult> setAccountStatus({
    required String userId,
    required String status,
    DateTime? until,
    required String reason,
  }) async {
    final result = await _client.rpc(
      'creator_set_account_status',
      params: {
        'p_user_id': userId,
        'p_status': status,
        'p_until': until?.toUtc().toIso8601String(),
        'p_reason': reason.trim(),
      },
    );
    return CreatorMutationResult.fromJson(
      Map<String, dynamic>.from(result as Map),
    );
  }

  Future<CreatorMutationResult> setCapability({
    required String userId,
    required CreatorCapability capability,
    String? marketId,
    DateTime? expiresAt,
    required String reason,
  }) async {
    final result = await _client.rpc(
      'creator_set_capability',
      params: {
        'p_user_id': userId,
        'p_capability': capability.value,
        'p_market_id': marketId,
        'p_expires_at': expiresAt?.toUtc().toIso8601String(),
        'p_reason': reason.trim(),
      },
    );
    return CreatorMutationResult.fromJson(
      Map<String, dynamic>.from(result as Map),
    );
  }

  Future<List<CreatorMerchant>> listMerchants({String? status}) async {
    final result = await _client.rpc(
      'creator_list_merchants',
      params: {'p_status': status, 'p_limit': 100, 'p_offset': 0},
    );
    return (result as List<dynamic>)
        .map(
          (row) =>
              CreatorMerchant.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList(growable: false);
  }

  Future<CreatorMutationResult> setMerchantVerification({
    required String merchantId,
    required String status,
    required String reason,
  }) async {
    final result = await _client.rpc(
      'creator_set_merchant_verification',
      params: {
        'p_merchant_id': merchantId,
        'p_status': status,
        'p_reason': reason.trim(),
      },
    );
    return CreatorMutationResult.fromJson(
      Map<String, dynamic>.from(result as Map),
    );
  }

  Future<List<CreatorShop>> listShops({String? status}) async {
    final result = await _client.rpc(
      'creator_list_shops',
      params: {'p_status': status, 'p_limit': 100, 'p_offset': 0},
    );
    return (result as List<dynamic>)
        .map(
          (row) => CreatorShop.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList(growable: false);
  }

  Future<CreatorMutationResult> setShopStatus({
    required String shopId,
    required String status,
    required String reason,
  }) async {
    final result = await _client.rpc(
      'creator_set_shop_status',
      params: {
        'p_shop_id': shopId,
        'p_status': status,
        'p_reason': reason.trim(),
      },
    );
    return CreatorMutationResult.fromJson(
      Map<String, dynamic>.from(result as Map),
    );
  }

  Future<List<CreatorMarket>> listMarkets() async {
    final result = await _client.rpc('creator_list_markets');
    return (result as List<dynamic>)
        .map(
          (row) =>
              CreatorMarket.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList(growable: false);
  }

  Future<CreatorMutationResult> setMarketStatus({
    required String marketId,
    required String status,
    required String reason,
  }) async {
    final result = await _client.rpc(
      'creator_set_market_status',
      params: {
        'p_market_id': marketId,
        'p_status': status,
        'p_reason': reason.trim(),
      },
    );
    return CreatorMutationResult.fromJson(
      Map<String, dynamic>.from(result as Map),
    );
  }

  Future<List<CreatorServiceArea>> listServiceAreas(String marketId) async {
    final rows = await _client
        .from('market_service_areas')
        .select(
          'id,market_id,name_ar,name_en,area_code,status,delivery_enabled,pickup_enabled',
        )
        .eq('market_id', marketId)
        .order('name_ar');
    return (rows as List<dynamic>)
        .map(
          (row) => CreatorServiceArea.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList(growable: false);
  }

  Future<List<CreatorPickupPoint>> listPickupPoints(String marketId) async {
    final rows = await _client
        .from('pickup_points')
        .select(
          'id,market_id,service_area_id,name_ar,name_en,address_details,contact_phone,operating_hours,status',
        )
        .eq('market_id', marketId)
        .order('name_ar');
    return (rows as List<dynamic>)
        .map(
          (row) => CreatorPickupPoint.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList(growable: false);
  }

  Future<CreatorMutationResult> saveServiceArea({
    String? id,
    required String marketId,
    required String nameAr,
    String? nameEn,
    required String areaCode,
    required String status,
    required bool deliveryEnabled,
    required bool pickupEnabled,
    required String reason,
  }) async {
    final result = await _client.rpc(
      'creator_save_service_area',
      params: {
        'p_id': id,
        'p_market_id': marketId,
        'p_name_ar': nameAr.trim(),
        'p_name_en': nameEn?.trim(),
        'p_area_code': areaCode.trim(),
        'p_status': status,
        'p_delivery_enabled': deliveryEnabled,
        'p_pickup_enabled': pickupEnabled,
        'p_reason': reason.trim(),
      },
    );
    return CreatorMutationResult.fromJson(
      Map<String, dynamic>.from(result as Map),
    );
  }

  Future<CreatorMutationResult> savePickupPoint({
    String? id,
    required String marketId,
    String? serviceAreaId,
    required String nameAr,
    String? nameEn,
    required String addressDetails,
    String? contactPhone,
    String? operatingHours,
    required String status,
    required String reason,
  }) async {
    final result = await _client.rpc(
      'creator_save_pickup_point',
      params: {
        'p_id': id,
        'p_market_id': marketId,
        'p_service_area_id': serviceAreaId,
        'p_name_ar': nameAr.trim(),
        'p_name_en': nameEn?.trim(),
        'p_address_details': addressDetails.trim(),
        'p_contact_phone': contactPhone?.trim(),
        'p_operating_hours': operatingHours?.trim(),
        'p_status': status,
        'p_reason': reason.trim(),
      },
    );
    return CreatorMutationResult.fromJson(
      Map<String, dynamic>.from(result as Map),
    );
  }

  Future<CreatorMutationResult> moderateProductReview({
    required String reviewId,
    required String status,
    required String reason,
  }) async {
    final result = await _client.rpc(
      'moderate_product_review',
      params: {
        'p_review_id': reviewId,
        'p_status': status,
        'p_reason': reason.trim(),
      },
    );
    return CreatorMutationResult.fromJson(
      Map<String, dynamic>.from(result as Map),
    );
  }

  Future<List<CreatorPolicy>> listPolicies(String marketId) async {
    final result = await _client.rpc(
      'creator_list_policies',
      params: {'p_market_id': marketId},
    );
    return (result as List<dynamic>)
        .map(
          (row) =>
              CreatorPolicy.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList(growable: false);
  }

  Future<CreatorMutationResult> upsertPolicy({
    required String marketId,
    required String key,
    required Map<String, dynamic> value,
    required String reason,
    DateTime? effectiveFrom,
  }) async {
    final result = await _client.rpc(
      'creator_upsert_policy',
      params: {
        'p_market_id': marketId,
        'p_key': key.trim(),
        'p_value': value,
        'p_effective_from': effectiveFrom?.toUtc().toIso8601String(),
        'p_reason': reason.trim(),
      },
    );
    return CreatorMutationResult.fromJson(
      Map<String, dynamic>.from(result as Map),
    );
  }

  Future<List<CreatorCapabilityState>> listCapabilities(String marketId) async {
    final result = await _client.rpc(
      'creator_list_capabilities',
      params: {'p_market_id': marketId},
    );
    return (result as List<dynamic>)
        .map(
          (row) => CreatorCapabilityState.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList(growable: false);
  }

  Future<CreatorMutationResult> setMarketCapability({
    required String marketId,
    required String capabilityId,
    required bool enabled,
    required String reason,
  }) async {
    final result = await _client.rpc(
      'creator_set_market_capability',
      params: {
        'p_market_id': marketId,
        'p_capability_id': capabilityId,
        'p_enabled': enabled,
        'p_reason': reason.trim(),
      },
    );
    return CreatorMutationResult.fromJson(
      Map<String, dynamic>.from(result as Map),
    );
  }

  Future<Map<String, dynamic>> aiPlatformSettings() async {
    final result = await _client.rpc('ai_get_platform_settings');
    return Map<String, dynamic>.from(result as Map);
  }

  Future<List<Map<String, dynamic>>> aiActionDefinitions() async {
    final result = await _client.rpc('ai_list_action_definitions');
    return (result as List<dynamic>)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> publishAiPlatformSettings({
    String? model,
    required bool providerEnabled,
    required bool backgroundEnabled,
    required bool knowledgeEnabled,
    required bool externalAgentEnabled,
    required int maxToolCalls,
    required int maxWorkflowAttempts,
    required String reason,
  }) async {
    final result = await _client.rpc(
      'ai_publish_platform_settings',
      params: {
        'p_model': model?.trim().isEmpty == true ? null : model?.trim(),
        'p_provider_enabled': providerEnabled,
        'p_background_enabled': backgroundEnabled,
        'p_knowledge_enabled': knowledgeEnabled,
        'p_external_agent_enabled': externalAgentEnabled,
        'p_max_tool_calls': maxToolCalls,
        'p_max_workflow_attempts': maxWorkflowAttempts,
        'p_reason': reason.trim(),
      },
    );
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> setAiActionEnabled({
    required String actionKey,
    required bool enabled,
    required String reason,
  }) async {
    final result = await _client.rpc(
      'ai_set_action_enabled',
      params: {
        'p_action_key': actionKey,
        'p_enabled': enabled,
        'p_reason': reason.trim(),
      },
    );
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> aiUpsertKnowledgeSource({
    required String scopeType,
    String? scopeId,
    required String sourceKey,
    required String title,
    required String sourceKind,
    String? sourceUri,
    required int sourceVersion,
    required String status,
    required String trustClass,
    required String contentHash,
    Map<String, dynamic> metadata = const {},
    required String reason,
  }) async {
    final result = await _client.rpc(
      'ai_upsert_knowledge_source',
      params: {
        'p_scope_type': scopeType,
        'p_scope_id': scopeId,
        'p_source_key': sourceKey.trim(),
        'p_title': title.trim(),
        'p_source_kind': sourceKind,
        'p_source_uri': sourceUri?.trim().isEmpty == true
            ? null
            : sourceUri?.trim(),
        'p_source_version': sourceVersion,
        'p_status': status,
        'p_trust_class': trustClass,
        'p_content_hash': contentHash.trim(),
        'p_metadata': metadata,
        'p_reason': reason.trim(),
      },
    );
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> aiAddKnowledgeChunk({
    required String sourceId,
    required int ordinal,
    required String content,
    required String contentHash,
    required String reason,
  }) async {
    final result = await _client.rpc(
      'ai_add_knowledge_chunk',
      params: {
        'p_source_id': sourceId,
        'p_ordinal': ordinal,
        'p_content': content.trim(),
        'p_content_hash': contentHash.trim(),
        'p_reason': reason.trim(),
      },
    );
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> aiUpsertEvaluationSuite({
    required String suiteKey,
    required int version,
    required String name,
    String description = '',
    required String locale,
    required String status,
    required String reason,
  }) async {
    final result = await _client.rpc(
      'ai_upsert_evaluation_suite',
      params: {
        'p_suite_key': suiteKey.trim(),
        'p_version': version,
        'p_name': name.trim(),
        'p_description': description.trim(),
        'p_locale': locale,
        'p_status': status,
        'p_reason': reason.trim(),
      },
    );
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> aiUpsertTerminologyEntry({
    required String scopeType,
    String? scopeId,
    required String termKey,
    required String termArabic,
    required String canonicalTerm,
    List<String> aliases = const [],
    String definition = '',
    String? sourceId,
    required String status,
    required String contentHash,
    Map<String, dynamic> metadata = const {},
    required String reason,
  }) async {
    final result = await _client.rpc(
      'ai_upsert_terminology_entry',
      params: {
        'p_scope_type': scopeType,
        'p_scope_id': scopeId,
        'p_term_key': termKey.trim(),
        'p_term_ar': termArabic.trim(),
        'p_canonical_term': canonicalTerm.trim(),
        'p_aliases': aliases
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList(growable: false),
        'p_definition': definition.trim(),
        'p_source_id': sourceId?.trim().isEmpty == true
            ? null
            : sourceId?.trim(),
        'p_status': status,
        'p_content_hash': contentHash.trim(),
        'p_metadata': metadata,
        'p_reason': reason.trim(),
      },
    );
    return Map<String, dynamic>.from(result as Map);
  }

  Future<List<Map<String, dynamic>>> aiEvaluationSummary() async {
    final result = await _client.rpc('ai_list_evaluation_summary');
    return (result as List<dynamic>)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> aiWorkflows({String? status}) async {
    final result = await _client.rpc(
      'ai_list_my_workflows',
      params: {'p_status': status},
    );
    return (result as List<dynamic>)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> erpFeatureRegistry() async {
    final result = await _client.rpc('erp_list_feature_registry');
    return (result as List<dynamic>)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
  }

  Future<Map<String, dynamic>?> erpOrganizationDashboard(
    String organizationId,
  ) async {
    final result = await _client.rpc(
      'erp_get_org_dashboard',
      params: {'p_organization_id': organizationId},
    );
    if (result == null) return null;
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> erpCreateOrganization({
    required String marketId,
    required String code,
    required String nameAr,
    required String reason,
    String? legalName,
    String? merchantId,
  }) async {
    final result = await _client.rpc(
      'erp_create_organization',
      params: {
        'p_market_id': marketId,
        'p_code': code.trim(),
        'p_name_ar': nameAr.trim(),
        'p_reason': reason.trim(),
        'p_legal_name': legalName?.trim().isEmpty == true
            ? null
            : legalName?.trim(),
        'p_merchant_id': merchantId?.trim().isEmpty == true
            ? null
            : merchantId?.trim(),
      },
    );
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> erpCreateJournalBatch({
    required String organizationId,
    required String bookId,
    required String sourceType,
    String? sourceId,
    required String idempotencyKey,
    required String reason,
    String? descriptionAr,
  }) async {
    final result = await _client.rpc(
      'erp_create_journal_batch',
      params: {
        'p_organization_id': organizationId,
        'p_book_id': bookId,
        'p_source_type': sourceType.trim(),
        'p_source_id': sourceId?.trim().isEmpty == true
            ? null
            : sourceId?.trim(),
        'p_idempotency_key': idempotencyKey.trim(),
        'p_reason': reason.trim(),
        'p_description_ar': descriptionAr?.trim().isEmpty == true
            ? null
            : descriptionAr?.trim(),
      },
    );
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> erpPostJournalBatch({
    required String batchId,
    required String reason,
  }) async {
    final result = await _client.rpc(
      'erp_post_journal_batch',
      params: {'p_batch_id': batchId, 'p_reason': reason.trim()},
    );
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> erpCreateLegalEntity({
    required String organizationId,
    required String code,
    required String nameAr,
    required String reason,
    String? registrationReference,
    String? taxReference,
  }) async {
    final result = await _client.rpc(
      'erp_create_legal_entity',
      params: {
        'p_organization_id': organizationId,
        'p_code': code.trim(),
        'p_name_ar': nameAr.trim(),
        'p_reason': reason.trim(),
        'p_registration_reference':
            registrationReference?.trim().isEmpty == true
            ? null
            : registrationReference?.trim(),
        'p_tax_reference': taxReference?.trim().isEmpty == true
            ? null
            : taxReference?.trim(),
      },
    );
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> erpCreateBook({
    required String legalEntityId,
    required String code,
    required String nameAr,
    required String accountingBasis,
    required String reason,
    String currency = 'YER',
  }) async {
    final result = await _client.rpc(
      'erp_create_book',
      params: {
        'p_legal_entity_id': legalEntityId,
        'p_code': code.trim(),
        'p_name_ar': nameAr.trim(),
        'p_accounting_basis': accountingBasis,
        'p_reason': reason.trim(),
        'p_currency': currency.trim().toUpperCase(),
      },
    );
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> erpCreateAccount({
    required String bookId,
    String? parentAccountId,
    required String code,
    required String nameAr,
    required String accountType,
    required String normalBalance,
    required String reason,
  }) async {
    final result = await _client.rpc(
      'erp_create_account',
      params: {
        'p_book_id': bookId,
        'p_parent_account_id': parentAccountId,
        'p_code': code.trim(),
        'p_name_ar': nameAr.trim(),
        'p_account_type': accountType,
        'p_normal_balance': normalBalance,
        'p_reason': reason.trim(),
      },
    );
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> erpAddJournalLine({
    required String batchId,
    required String accountId,
    required int lineNumber,
    required int debitMinor,
    required int creditMinor,
    String? descriptionAr,
    Map<String, dynamic> dimensions = const {},
  }) async {
    final result = await _client.rpc(
      'erp_add_journal_line',
      params: {
        'p_batch_id': batchId,
        'p_account_id': accountId,
        'p_line_number': lineNumber,
        'p_debit_minor': debitMinor,
        'p_credit_minor': creditMinor,
        'p_description_ar': descriptionAr?.trim().isEmpty == true
            ? null
            : descriptionAr?.trim(),
        'p_dimensions': dimensions,
      },
    );
    return Map<String, dynamic>.from(result as Map);
  }
}

class CreatorRepositoryException implements Exception {
  const CreatorRepositoryException(this.code);
  final String code;
  @override
  String toString() => code;
}
