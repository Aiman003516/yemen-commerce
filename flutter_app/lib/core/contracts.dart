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
  });
  final String id;
  final String name;
  final String accountHolderName;
  final String receivingIdentifier;
  final String instructions;
  final String proofRequirement;
  final bool isActive;
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
      );
}

class MerchantManagedOrder {
  const MerchantManagedOrder({
    required this.id,
    required this.totalMinor,
    required this.paymentStatus,
    required this.fulfilmentStatus,
  });
  final String id;
  final int totalMinor;
  final String paymentStatus;
  final String fulfilmentStatus;
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
  });
  final String id;
  final int totalMinor;
  final String currency;
  final String paymentStatus;
  final String fulfilmentStatus;
  final String? accountHolderName;
  final String? receivingIdentifier;
  final String? paymentInstructions;
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
  const MerchantPaymentChoice({required this.id, required this.name});
  final String id;
  final String name;
  factory MerchantPaymentChoice.fromJson(Map<String, dynamic> json) =>
      MerchantPaymentChoice(
        id: _stringValue(json['id']),
        name: json['name'] as String,
      );
}
