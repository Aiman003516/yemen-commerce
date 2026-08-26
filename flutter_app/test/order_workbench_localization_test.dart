import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yemen_commerce/core/api_client.dart';
import 'package:yemen_commerce/core/order_workbench_localization.dart';

void main() {
  PostgrestException error(String code) =>
      PostgrestException(code: code, message: 'database message: $code');

  test('renders known order and COD statuses in Arabic', () {
    expect(merchantOrderStatusLabel('paid'), 'مدفوع');
    expect(merchantOrderStatusLabel('preparing'), 'قيد التجهيز');
    expect(merchantOrderStatusLabel('mismatch'), 'فرق في التحصيل');
    expect(merchantCodBatchStatusLabel('reconciled'), 'مطابقة');
    expect(merchantCodEntryStatusLabel('collected'), 'تم التحصيل');
  });

  test('renders C increment B2B, provider, and asset states in Arabic', () {
    expect(merchantB2bRequestStatusLabel('approved'), 'معتمد');
    expect(merchantPriceListStatusLabel('active'), 'نشطة');
    expect(merchantQuoteStatusLabel('accepted'), 'مقبولة');
    expect(providerAdapterOperationLabel('verify_payment'), 'التحقق من الدفع');
    expect(providerReadinessLabel('pending_approval'), 'بانتظار الاعتماد');
    expect(productAssetVariantStatusLabel('pending'), 'بانتظار التحسين');
  });

  test('does not expose unknown backend status identifiers', () {
    expect(merchantOrderStatusLabel('internal_new_status'), 'حالة غير معروفة');
    expect(
      merchantCodBatchStatusLabel('internal_batch_state'),
      'حالة دفعة غير معروفة',
    );
    expect(
      merchantCodEntryStatusLabel('internal_entry_state'),
      'حالة تحصيل غير معروفة',
    );
  });

  test('maps workbench and COD authorization errors to Arabic guidance', () {
    expect(
      localizedSupabaseErrorForTest(error('AUTH_REQUIRED'), 'fallback'),
      contains('سجّل الدخول'),
    );
    expect(
      localizedSupabaseErrorForTest(error('SHOP_NOT_OWNED'), 'fallback'),
      contains('لا يمكن الوصول'),
    );
    expect(
      localizedSupabaseErrorForTest(
        error('INVALID_ORDER_WORKBENCH_PAGINATION'),
        'fallback',
      ),
      contains('نطاق البحث غير صالح'),
    );
    expect(
      localizedSupabaseErrorForTest(error('INVALID_COD_FILTER'), 'fallback'),
      contains('مرشح الطلبات غير صالح'),
    );
    expect(
      localizedSupabaseErrorForTest(error('COD_BATCH_NOT_FOUND'), 'fallback'),
      contains('دفعة المطابقة غير موجودة'),
    );
    expect(
      localizedSupabaseErrorForTest(
        error('COD_BATCH_ALREADY_CLOSED'),
        'fallback',
      ),
      contains('أُغلقت دفعة المطابقة'),
    );
    expect(
      localizedSupabaseErrorForTest(error('COD_BATCH_NOT_OPEN'), 'fallback'),
      contains('ليست مفتوحة'),
    );
    expect(
      localizedSupabaseErrorForTest(
        error('COD_ORDER_BATCH_DATE_MISMATCH'),
        'fallback',
      ),
      contains('بتاريخ مختلف'),
    );
    expect(
      localizedSupabaseErrorForTest(error('COD_NOT_APPLICABLE'), 'fallback'),
      contains('ليس طلب تحصيل نقدي'),
    );
    expect(
      localizedSupabaseErrorForTest(error('COD_ALREADY_FINAL'), 'fallback'),
      contains('لا يمكن تعديله'),
    );
    expect(
      localizedSupabaseErrorForTest(error('INVALID_COD_AMOUNT'), 'fallback'),
      contains('مبلغ التحصيل غير صالح'),
    );
  });

  test(
    'maps C quote, rollup, asset, and provider errors to Arabic guidance',
    () {
      final cases = <String, String>{
        'QUOTE_REASON_REQUIRED': 'سبب',
        'INVALID_QUOTE_ITEMS': 'بنود',
        'QUOTE_NOT_AVAILABLE': 'غير متاح',
        'QUOTE_ITEMS_MISMATCH': 'تطابق',
        'QUOTE_ORDER_ALREADY_PRICED': 'سعر',
        'INVALID_ROLLUP_DATE': 'تاريخ',
        'INVALID_ROLLUP_RANGE': 'نطاق',
        'INVALID_ASSET_VARIANT': 'صورة',
        'INVALID_ASSET_PATH': 'مسار',
        'ASSET_VARIANT_NOT_FOUND': 'صورة',
        'PROVIDER_UNAVAILABLE': 'المزود',
      };
      for (final entry in cases.entries) {
        final message = localizedSupabaseErrorForTest(
          error(entry.key),
          'fallback',
        );
        expect(message, contains(entry.value), reason: entry.key);
        expect(message, isNot(contains(entry.key)), reason: entry.key);
      }
    },
  );

  test('uses a safe Arabic fallback for unknown database errors', () {
    const fallback = 'تعذر تنفيذ العملية. حاول مجدداً.';
    final message = localizedSupabaseErrorForTest(
      error('UNEXPECTED_INTERNAL_SIGNAL'),
      fallback,
    );
    expect(message, fallback);
    expect(message, isNot(contains('UNEXPECTED_INTERNAL_SIGNAL')));
    expect(message, isNot(contains('database message')));
  });
}
