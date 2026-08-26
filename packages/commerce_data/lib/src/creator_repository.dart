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
}

class CreatorRepositoryException implements Exception {
  const CreatorRepositoryException(this.code);
  final String code;
  @override
  String toString() => code;
}
