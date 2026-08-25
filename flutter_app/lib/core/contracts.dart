/// Mirrors the serialized values in ../../shared/domain.ts (API v1).
const marketplaceApiVersion = 'v1';

enum MarketplaceRole { customer, merchant, admin }

enum PaymentState { awaitingPayment, paymentUnderReview, paid, rejected, cancelled }

enum FulfilmentMethod { collection, digital, sellerArranged }

class MarketConfig {
  const MarketConfig({
    required this.id,
    required this.governorate,
    required this.city,
    required this.currency,
    required this.isPilot,
  });

  final int id;
  final String governorate;
  final String city;
  final String currency;
  final bool isPilot;

  factory MarketConfig.fromJson(Map<String, dynamic> json) => MarketConfig(
        id: json['id'] as int,
        governorate: json['governorate'] as String,
        city: json['city'] as String,
        currency: json['currency'] as String,
        isPilot: json['isPilot'] as bool,
      );
}

class FeatureAvailability {
  const FeatureAvailability({required this.key, required this.enabled, this.reasonAr});

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

  final int id;
  final String name;
  final int priceMinor;
  final String currency;
  final int stockQuantity;
  final String shopName;
  final String shopSlug;

  factory MarketplaceProduct.fromCatalogJson(Map<String, dynamic> json) {
    final product = json['product'] as Map<String, dynamic>;
    return MarketplaceProduct(
      id: product['id'] as int,
      name: product['name'] as String,
      priceMinor: product['priceMinor'] as int,
      currency: product['currency'] as String,
      stockQuantity: product['stockQuantity'] as int,
      shopName: json['shopName'] as String,
      shopSlug: json['shopSlug'] as String,
    );
  }
}

class SessionUser {
  const SessionUser({required this.id, this.name, required this.role});
  final int id;
  final String? name;
  final String role;

  factory SessionUser.fromJson(Map<String, dynamic> json) => SessionUser(
        id: json['id'] as int,
        name: json['name'] as String?,
        role: json['role'] as String,
      );
}
