import 'package:flutter_test/flutter_test.dart';

import 'package:yemen_commerce/core/outbox_localization.dart';

void main() {
  test('labels every supported inventory command in Arabic', () {
    expect(outboxCommandLabel('record_inventory_adjustment'), 'تعديل مخزون');
    expect(outboxCommandLabel('complete_inventory_transfer'), 'نقل مخزون');
    expect(outboxCommandLabel('apply_inventory_count'), 'تطبيق جرد');
  });

  test('uses clear Arabic state labels', () {
    expect(outboxStateLabel('pending'), 'قيد الانتظار');
    expect(outboxStateLabel('failed'), 'يحتاج إعادة محاولة');
    expect(outboxStateLabel('blocked'), 'متوقف للمراجعة');
  });

  test('distinguishes blocked guidance from transient guidance', () {
    final blocked = outboxErrorHint('blocked');
    final failed = outboxErrorHint('failed');
    expect(blocked, contains('تعارض'));
    expect(blocked, contains('أعد المحاولة'));
    expect(failed, contains('استقرار الاتصال'));
    expect(failed, isNot(blocked));
  });

  test('does not expose an unknown command kind verbatim', () {
    expect(outboxCommandLabel('unexpected_raw_kind'), 'عملية غير معروفة');
    expect(outboxStateLabel('unexpected_raw_state'), 'حالة غير معروفة');
  });
}
