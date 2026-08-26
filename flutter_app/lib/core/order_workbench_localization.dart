/// Arabic-first labels used by the merchant order workbench and COD workspace.
///
/// Backend statuses remain machine-readable in contracts; this boundary keeps
/// the merchant UI from displaying English status identifiers by default.
String merchantOrderStatusLabel(String status) => switch (status) {
  'awaiting_payment' => 'بانتظار الدفع',
  'paid' => 'مدفوع',
  'payment_review' => 'مراجعة الدفع',
  'payment_under_review' => 'مراجعة الدفع',
  'pending' => 'قيد الانتظار',
  'preparing' => 'قيد التجهيز',
  'ready' => 'جاهز',
  'arranged' => 'تم ترتيب التنفيذ',
  'dispatched' => 'تم الإرسال',
  'delivered' => 'تم التسليم',
  'completed' => 'تم التنفيذ',
  'cancelled' => 'ملغى',
  'not_applicable' => 'غير منطبق',
  'waived' => 'معفى',
  'rejected' => 'مرفوض',
  'collected' => 'تم التحصيل',
  'mismatch' => 'فرق في التحصيل',
  'expected' => 'متوقع',
  'open' => 'مفتوحة',
  'closed' => 'مغلقة',
  'reconciled' => 'مطابقة',
  'variance' => 'بها فرق',
  _ => 'حالة غير معروفة',
};

String merchantCodBatchStatusLabel(String status) => switch (status) {
  'open' => 'مفتوحة',
  'closed' => 'مغلقة',
  'reconciled' => 'مطابقة',
  'variance' => 'بها فرق',
  _ => 'حالة دفعة غير معروفة',
};

String merchantCodEntryStatusLabel(String status) => switch (status) {
  'expected' => 'متوقع',
  'collected' => 'تم التحصيل',
  'mismatch' => 'فرق',
  _ => 'حالة تحصيل غير معروفة',
};

String merchantB2bRequestStatusLabel(String status) => switch (status) {
  'open' => 'مفتوح',
  'reviewing' => 'قيد المراجعة',
  'approved' => 'معتمد',
  'rejected' => 'مرفوض',
  'closed' => 'مغلق',
  _ => 'حالة طلب غير معروفة',
};

String merchantPriceListStatusLabel(String status) => switch (status) {
  'draft' => 'مسودة',
  'active' => 'نشطة',
  'paused' => 'متوقفة مؤقتاً',
  _ => 'حالة قائمة غير معروفة',
};

String merchantQuoteStatusLabel(String status) => switch (status) {
  'draft' => 'مسودة',
  'sent' => 'مرسلة',
  'accepted' => 'مقبولة',
  'expired' => 'منتهية',
  'rejected' => 'مرفوضة',
  'cancelled' => 'ملغاة',
  _ => 'حالة عرض غير معروفة',
};

String productAssetVariantStatusLabel(String status) => switch (status) {
  'pending' => 'بانتظار التحسين',
  'ready' => 'جاهزة',
  'failed' => 'تعذر التحسين',
  _ => 'حالة صورة غير معروفة',
};

String providerAdapterOperationLabel(String operationKey) =>
    switch (operationKey) {
      'send_template_message' => 'إرسال رسالة قالب',
      'send_sms' => 'إرسال رسالة SMS',
      'create_dispatch' => 'إنشاء شحنة',
      'geocode_address' => 'ترميز العنوان',
      'publish_catalog' => 'نشر الكتالوج',
      'request_financing' => 'طلب تمويل',
      'verify_payment' => 'التحقق من الدفع',
      _ => 'عملية مزود غير معروفة',
    };

String providerReadinessLabel(String state) => switch (state) {
  'configured' => 'مهيأ بعد الاعتماد',
  'pending_approval' => 'بانتظار الاعتماد',
  'mock' => 'معاينة فقط',
  'manual' => 'تشغيل يدوي',
  'blocked' => 'محجوب',
  _ => 'حالة اعتماد غير معروفة',
};
