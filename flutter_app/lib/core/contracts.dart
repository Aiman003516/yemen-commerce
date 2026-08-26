const marketplaceApiVersion = 'v1';

String _stringValue(dynamic value) => value.toString();
int _intValue(dynamic value) => (value as num).toInt();

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
    );
  }
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
  factory MerchantOrderSummary.fromJson(Map<String, dynamic> json) =>
      MerchantOrderSummary(
        id: _stringValue(json['id']),
        totalMinor: _intValue(json['totalMinor'] ?? json['total_minor']),
        currency: json['currency'] as String,
        paymentStatus:
            json['paymentStatus'] as String? ??
            json['payment_status'] as String,
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
