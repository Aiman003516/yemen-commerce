String outboxCommandLabel(String kind) => switch (kind) {
  'checkout_create_orders' => 'إنشاء الطلبات',
  'apply_order_promotion' => 'تطبيق عرض',
  'record_inventory_adjustment' => 'تعديل مخزون',
  'complete_inventory_transfer' => 'نقل مخزون',
  'apply_inventory_count' => 'تطبيق جرد',
  _ => 'عملية غير معروفة',
};

String outboxStateLabel(String state) => switch (state) {
  'pending' => 'قيد الانتظار',
  'failed' => 'يحتاج إعادة محاولة',
  'blocked' => 'متوقف للمراجعة',
  _ => 'حالة غير معروفة',
};

String outboxErrorHint(String state) => state == 'blocked'
    ? 'تم إيقاف الإعادة بسبب تعارض أو خطأ نهائي. صحّح بيانات المخزون أو الصلاحيات ثم أعد المحاولة.'
    : 'تعذر التنفيذ مؤقتاً. أعد المحاولة عند استقرار الاتصال أو احذف الأمر.';

const outboxEmptyStateDetail =
    'ستظهر هنا أوامر إنشاء الطلبات والعروض وعمليات المخزون غير المالية إذا انقطع الاتصال أثناء الحفظ.';
