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

class CreatorMerchant {
  const CreatorMerchant({
    required this.id,
    required this.ownerName,
    required this.phone,
    required this.marketId,
    required this.verificationStatus,
    this.phoneVerificationStatus,
    this.createdAt,
  });
  final String id;
  final String ownerName;
  final String phone;
  final String marketId;
  final String verificationStatus;
  final String? phoneVerificationStatus;
  final DateTime? createdAt;

  factory CreatorMerchant.fromJson(
    Map<String, dynamic> json,
  ) => CreatorMerchant(
    id: (json['id'] ?? '').toString(),
    ownerName: (json['owner_name'] ?? json['ownerName'] ?? '').toString(),
    phone: (json['phone'] ?? '').toString(),
    marketId: (json['market_id'] ?? json['marketId'] ?? '').toString(),
    verificationStatus:
        (json['verification_status'] ?? json['verificationStatus'] ?? 'pending')
            .toString(),
    phoneVerificationStatus:
        (json['phone_verification_status'] ?? json['phoneVerificationStatus'])
            ?.toString(),
    createdAt: DateTime.tryParse(
      (json['created_at'] ?? json['createdAt'] ?? '').toString(),
    ),
  );
}

class CreatorShop {
  const CreatorShop({
    required this.id,
    required this.name,
    required this.slug,
    required this.merchantId,
    required this.marketId,
    required this.status,
    this.areaLabel,
  });
  final String id;
  final String name;
  final String slug;
  final String merchantId;
  final String marketId;
  final String status;
  final String? areaLabel;

  factory CreatorShop.fromJson(Map<String, dynamic> json) => CreatorShop(
    id: (json['id'] ?? '').toString(),
    name: (json['name'] ?? '').toString(),
    slug: (json['slug'] ?? '').toString(),
    merchantId: (json['merchant_id'] ?? json['merchantId'] ?? '').toString(),
    marketId: (json['market_id'] ?? json['marketId'] ?? '').toString(),
    status: (json['status'] ?? 'pending').toString(),
    areaLabel: (json['area_label'] ?? json['areaLabel'])?.toString(),
  );
}

class CreatorMarket {
  const CreatorMarket({
    required this.id,
    required this.governorate,
    required this.city,
    required this.status,
    required this.currency,
    required this.isPilot,
    this.district,
    this.serviceArea,
  });
  final String id;
  final String governorate;
  final String city;
  final String status;
  final String currency;
  final bool isPilot;
  final String? district;
  final String? serviceArea;

  factory CreatorMarket.fromJson(Map<String, dynamic> json) => CreatorMarket(
    id: (json['id'] ?? '').toString(),
    governorate: (json['governorate'] ?? '').toString(),
    city: (json['city'] ?? '').toString(),
    status: (json['status'] ?? 'draft').toString(),
    currency: (json['currency'] ?? 'YER').toString(),
    isPilot: json['is_pilot'] as bool? ?? json['isPilot'] as bool? ?? false,
    district: (json['district'])?.toString(),
    serviceArea: (json['service_area'] ?? json['serviceArea'])?.toString(),
  );
}

class CreatorServiceArea {
  const CreatorServiceArea({
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

  factory CreatorServiceArea.fromJson(Map<String, dynamic> json) =>
      CreatorServiceArea(
        id: (json['id'] ?? '').toString(),
        marketId: (json['market_id'] ?? json['marketId'] ?? '').toString(),
        nameAr: (json['name_ar'] ?? json['nameAr'] ?? '').toString(),
        areaCode: (json['area_code'] ?? json['areaCode'] ?? '').toString(),
        status: (json['status'] ?? 'draft').toString(),
        deliveryEnabled:
            json['delivery_enabled'] as bool? ??
            json['deliveryEnabled'] as bool? ??
            true,
        pickupEnabled:
            json['pickup_enabled'] as bool? ??
            json['pickupEnabled'] as bool? ??
            true,
      );
}

class CreatorPickupPoint {
  const CreatorPickupPoint({
    required this.id,
    required this.marketId,
    required this.nameAr,
    required this.addressDetails,
    required this.status,
    this.serviceAreaId,
    this.contactPhone,
    this.operatingHours,
  });

  final String id;
  final String marketId;
  final String nameAr;
  final String addressDetails;
  final String status;
  final String? serviceAreaId;
  final String? contactPhone;
  final String? operatingHours;

  factory CreatorPickupPoint.fromJson(
    Map<String, dynamic> json,
  ) => CreatorPickupPoint(
    id: (json['id'] ?? '').toString(),
    marketId: (json['market_id'] ?? json['marketId'] ?? '').toString(),
    nameAr: (json['name_ar'] ?? json['nameAr'] ?? '').toString(),
    addressDetails: (json['address_details'] ?? json['addressDetails'] ?? '')
        .toString(),
    status: (json['status'] ?? 'draft').toString(),
    serviceAreaId: (json['service_area_id'] ?? json['serviceAreaId'])
        ?.toString(),
    contactPhone: (json['contact_phone'] ?? json['contactPhone'])?.toString(),
    operatingHours: (json['operating_hours'] ?? json['operatingHours'])
        ?.toString(),
  );
}

class CreatorPolicy {
  const CreatorPolicy({
    required this.id,
    required this.marketId,
    required this.key,
    required this.version,
    required this.value,
    required this.isActive,
    this.effectiveFrom,
  });
  final String id;
  final String marketId;
  final String key;
  final int version;
  final Map<String, dynamic> value;
  final bool isActive;
  final DateTime? effectiveFrom;

  factory CreatorPolicy.fromJson(Map<String, dynamic> json) => CreatorPolicy(
    id: (json['id'] ?? '').toString(),
    marketId: (json['market_id'] ?? json['marketId'] ?? '').toString(),
    key: (json['key'] ?? '').toString(),
    version: int.tryParse((json['version'] ?? 0).toString()) ?? 0,
    value: Map<String, dynamic>.from((json['value'] as Map?) ?? const {}),
    isActive: json['is_active'] as bool? ?? json['isActive'] as bool? ?? false,
    effectiveFrom: DateTime.tryParse(
      (json['effective_from'] ?? json['effectiveFrom'] ?? '').toString(),
    ),
  );
}

class CreatorCapabilityState {
  const CreatorCapabilityState({
    required this.id,
    required this.key,
    required this.marketId,
    required this.enabled,
    required this.defaultEnabled,
    this.reasonAr,
  });
  final String id;
  final String key;
  final String marketId;
  final bool enabled;
  final bool defaultEnabled;
  final String? reasonAr;

  factory CreatorCapabilityState.fromJson(Map<String, dynamic> json) =>
      CreatorCapabilityState(
        id: (json['id'] ?? '').toString(),
        key: (json['key'] ?? '').toString(),
        marketId: (json['market_id'] ?? json['marketId'] ?? '').toString(),
        enabled: json['enabled'] as bool? ?? false,
        defaultEnabled:
            json['default_enabled'] as bool? ??
            json['defaultEnabled'] as bool? ??
            false,
        reasonAr: (json['reason_ar'] ?? json['reasonAr'])?.toString(),
      );
}
