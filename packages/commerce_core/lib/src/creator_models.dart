class CreatorDashboardSummary {
  const CreatorDashboardSummary({
    this.activeMarkets = 0,
    this.pendingMerchants = 0,
    this.pendingIdentityCases = 0,
    this.pendingShopApprovals = 0,
    this.paymentClaimsUnderReview = 0,
    this.openReports = 0,
    this.generatedAt,
  });

  final int activeMarkets;
  final int pendingMerchants;
  final int pendingIdentityCases;
  final int pendingShopApprovals;
  final int paymentClaimsUnderReview;
  final int openReports;
  final DateTime? generatedAt;

  factory CreatorDashboardSummary.fromJson(
    Map<String, dynamic> json,
  ) => CreatorDashboardSummary(
    activeMarkets:
        (json['active_markets'] ?? json['activeMarkets'] ?? 0) as int,
    pendingMerchants:
        (json['pending_merchants'] ?? json['pendingMerchants'] ?? 0) as int,
    pendingIdentityCases:
        (json['pending_identity_cases'] ?? json['pendingIdentityCases'] ?? 0)
            as int,
    pendingShopApprovals:
        (json['pending_shop_approvals'] ?? json['pendingShopApprovals'] ?? 0)
            as int,
    paymentClaimsUnderReview:
        (json['payment_claims_under_review'] ??
                json['paymentClaimsUnderReview'] ??
                0)
            as int,
    openReports: (json['open_reports'] ?? json['openReports'] ?? 0) as int,
    generatedAt: DateTime.tryParse(
      (json['generated_at'] ?? json['generatedAt'] ?? '').toString(),
    ),
  );
}

class CreatorPerson {
  const CreatorPerson({
    required this.userId,
    this.displayName,
    this.email,
    this.phone,
    this.accountStatus = 'active',
    this.roles = const [],
    this.marketIds = const [],
    this.lastSignedIn,
  });
  final String userId;
  final String? displayName;
  final String? email;
  final String? phone;
  final String accountStatus;
  final List<String> roles;
  final List<String> marketIds;
  final DateTime? lastSignedIn;

  factory CreatorPerson.fromJson(Map<String, dynamic> json) => CreatorPerson(
    userId: (json['user_id'] ?? json['userId'] ?? json['id']).toString(),
    displayName:
        json['display_name'] as String? ?? json['displayName'] as String?,
    email: json['email'] as String?,
    phone: json['phone'] as String?,
    accountStatus: (json['account_status'] ?? json['accountStatus'] ?? 'active')
        .toString(),
    roles: ((json['roles'] ?? const []) as List<dynamic>)
        .map((item) => item.toString())
        .toList(growable: false),
    marketIds:
        ((json['market_ids'] ?? json['marketIds'] ?? const []) as List<dynamic>)
            .map((item) => item.toString())
            .toList(growable: false),
    lastSignedIn: DateTime.tryParse(
      (json['last_signed_in'] ?? json['lastSignedIn'] ?? '').toString(),
    ),
  );
}

class CreatorMutationResult {
  const CreatorMutationResult({
    required this.success,
    this.message,
    this.userId,
    this.role,
    this.accountStatus,
  });
  final bool success;
  final String? message;
  final String? userId;
  final String? role;
  final String? accountStatus;

  factory CreatorMutationResult.fromJson(Map<String, dynamic> json) =>
      CreatorMutationResult(
        success: json['success'] as bool? ?? true,
        message: json['message'] as String?,
        userId: (json['user_id'] ?? json['userId'])?.toString(),
        role: json['role']?.toString(),
        accountStatus: (json['account_status'] ?? json['accountStatus'])
            ?.toString(),
      );
}
