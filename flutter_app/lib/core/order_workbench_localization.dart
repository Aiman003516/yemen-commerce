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
