import 'package:commerce_core/commerce_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreatorRepository {
  CreatorRepository({SupabaseClient? client})
    : _client = client ?? SupabaseRuntime.client;

  final SupabaseClient _client;

  Future<CreatorAccess> loadAccess() async {
    final user = _client.auth.currentUser;
    if (user == null) throw const CreatorRepositoryException('AUTH_REQUIRED');
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
}

class CreatorRepositoryException implements Exception {
  const CreatorRepositoryException(this.code);
  final String code;
  @override
  String toString() => code;
}
