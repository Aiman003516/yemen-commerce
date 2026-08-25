/// Serialized values mirror `shared/domain.ts` API v1 contracts.
const apiVersion = 'v1';

enum UserRole { customer, merchant, admin }
enum MarketStatus { draft, active, paused }
enum PaymentStatus { awaitingPayment, paymentUnderReview, paid, rejected, cancelled }
enum FulfilmentMethod { collection, digital, sellerArranged }

class MarketConfig {
  const MarketConfig({
    required this.id,
    required this.governorate,
    required this.city,
    required this.status,
    required this.currency,
    required this.isPilot,
  });

  final int id;
  final String governorate;
  final String city;
  final MarketStatus status;
  final String currency;
  final bool isPilot;
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
