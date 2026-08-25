/// Stable provider metadata shared by customer, merchant, and creator clients.
///
/// This catalog intentionally describes capabilities only. It does not contain
/// credentials, call external services, or imply that an API integration is
/// active. Provider-specific network behavior belongs behind a server-side
/// adapter after commercial and technical approval.
class PaymentProviderDescriptor {
  const PaymentProviderDescriptor({
    required this.code,
    required this.nameAr,
    required this.nameEn,
    required this.integrationMode,
    required this.verificationState,
    required this.supportsQrOrPos,
    required this.supportsOfflineFallback,
    required this.activationNoteAr,
  });

  final String code;
  final String nameAr;
  final String nameEn;
  final String integrationMode;
  final String verificationState;
  final bool supportsQrOrPos;
  final bool supportsOfflineFallback;
  final String activationNoteAr;

  bool get isManual => integrationMode == 'manual';
  bool get isApiEnabled =>
      integrationMode == 'provider_api' && verificationState == 'verified';
}

class PaymentProviderCatalog {
  PaymentProviderCatalog._();

  static const manual = PaymentProviderDescriptor(
    code: 'manual',
    nameAr: 'طريقة يدوية',
    nameEn: 'Manual method',
    integrationMode: 'manual',
    verificationState: 'manual_only',
    supportsQrOrPos: false,
    supportsOfflineFallback: true,
    activationNoteAr: 'يؤكد التاجر الدفع يدوياً من حسابه.',
  );

  static const jaib = PaymentProviderDescriptor(
    code: 'jaib',
    nameAr: 'جيب',
    nameEn: 'Jaib',
    integrationMode: 'manual',
    verificationState: 'manual_only',
    supportsQrOrPos: true,
    supportsOfflineFallback: true,
    activationNoteAr: 'جيب متاح حالياً كطريقة يدوية عبر رقم نقطة البيع أو رمز QR. لا يتم تأكيد الدفع تلقائياً.',
  );

  static const kuraimi = PaymentProviderDescriptor(
    code: 'kuraimi',
    nameAr: 'الكريمي',
    nameEn: 'Al Kuraimi',
    integrationMode: 'manual',
    verificationState: 'manual_only',
    supportsQrOrPos: true,
    supportsOfflineFallback: true,
    activationNoteAr: 'الكريمي متاح حالياً كطريقة يدوية، ويمكن تفعيل الربط الرسمي بعد اعتماد الاتفاقية والاختبارات.',
  );

  static const cash = PaymentProviderDescriptor(
    code: 'cash',
    nameAr: 'الدفع عند الاستلام',
    nameEn: 'Cash on delivery',
    integrationMode: 'manual',
    verificationState: 'manual_only',
    supportsQrOrPos: false,
    supportsOfflineFallback: true,
    activationNoteAr: 'يؤكد التاجر الاستلام النقدي عند التسليم أو الاستلام.',
  );

  static const values = <PaymentProviderDescriptor>[
    manual,
    jaib,
    kuraimi,
    cash,
  ];

  static PaymentProviderDescriptor byCode(String? code) {
    for (final provider in values) {
      if (provider.code == code) return provider;
    }
    return manual;
  }
}
