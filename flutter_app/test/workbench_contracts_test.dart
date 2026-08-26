import 'package:flutter_test/flutter_test.dart';

import 'package:yemen_commerce/core/contracts.dart';

void main() {
  test('parses a merchant order workbench row', () {
    final row = MerchantOrderWorkbenchEntry.fromJson({
      'id': 'order-1',
      'order_reference': 'YC-123',
      'shop_id': 'shop-1',
      'payment_status': 'paid',
      'fulfilment_status': 'ready',
      'cod_status': 'not_applicable',
      'currency': 'YER',
      'subtotal_minor': 1000,
      'fee_minor': 50,
      'tax_minor': 0,
      'total_minor': 1050,
      'cod_expected_minor': 0,
      'cod_collected_minor': 0,
      'fulfilment_method': 'collection',
      'created_at': '2026-08-26T10:00:00Z',
      'updated_at': '2026-08-26T10:01:00Z',
      'item_count': 2,
      'has_open_case': false,
      'has_active_courier_assignment': false,
    });

    expect(row.orderReference, 'YC-123');
    expect(row.totalMinor, 1050);
    expect(row.itemCount, 2);
    expect(row.fulfilmentStatus, 'ready');
  });

  test('parses the COD close result without missing batch metadata', () {
    final result = CodReconciliationCloseResult.fromJson({
      'batch_id': 'batch-1',
      'status': 'reconciled',
      'expected_total_minor': 5000,
      'collected_total_minor': 5000,
      'variance_minor': 0,
    });

    expect(result.batchId, 'batch-1');
    expect(result.status, 'reconciled');
    expect(result.varianceMinor, 0);
  });

  test('parses C quote, price-list, rollup, asset, and provider contracts', () {
    final priceList = WholesalePriceListSummary.fromJson({
      'price_list_id': 'list-1',
      'shop_id': 'shop-1',
      'name_ar': 'سعر الجملة',
      'currency': 'YER',
      'status': 'active',
      'items': [
        {
          'price_list_item_id': 'line-1',
          'product_id': 'product-1',
          'product_name': 'منتج',
          'unit_price_minor': 900,
          'min_quantity': 10,
          'status': 'active',
        },
      ],
    });
    final quote = WholesaleQuoteSummary.fromJson({
      'quote_id': 'quote-1',
      'shop_id': 'shop-1',
      'buyer_user_id': 'buyer-1',
      'status': 'sent',
      'current_version_no': 2,
      'latest_version': {
        'quote_id': 'quote-1',
        'quote_version_id': 'version-2',
        'version_no': 2,
        'status': 'sent',
        'currency': 'YER',
        'reason': 'تفاوض موسمي',
        'items': [
          {
            'id': 'quote-line-1',
            'product_id': 'product-1',
            'product_name_snapshot': 'منتج',
            'unit_price_minor': 850,
            'quantity': 10,
            'line_total_minor': 8500,
          },
        ],
      },
    });
    final rollup = MerchantDailyRollup.fromJson({
      'id': 'rollup-1',
      'shop_id': 'shop-1',
      'business_date': '2026-08-26',
      'order_count': 4,
      'paid_order_count': 3,
      'gross_total_minor': 12000,
      'cod_expected_minor': 3000,
      'cod_collected_minor': 2500,
      'wholesale_request_count': 2,
      'wholesale_approved_count': 1,
      'pos_sale_count': 3,
      'pos_gross_total_minor': 5000,
    });
    final asset = ProductAssetVariantSummary.fromJson({
      'asset_variant_id': 'asset-1',
      'product_id': 'product-1',
      'format': 'jpeg',
      'status': 'ready',
      'width': 1600,
      'height': 800,
      'byte_size': 120000,
    });
    final provider = ProviderAdapterOperation.fromJson({
      'provider_code': 'jaib',
      'operation_key': 'verify_payment',
      'category': 'payment',
      'enabled': false,
      'required_readiness_state': 'pending_approval',
      'notes_ar': 'تشغيل يدوي فقط',
    });

    expect(priceList.items.single.unitPriceMinor, 900);
    expect(quote.latestVersion?.versionNo, 2);
    expect(quote.latestVersion?.items.single.lineTotalMinor, 8500);
    expect(rollup.grossTotalMinor, 12000);
    expect(asset.width, 1600);
    expect(provider.enabled, isFalse);
    expect(provider.providerCode, 'jaib');
  });

  test('parses a COD reconciliation batch and its latest order rows', () {
    final snapshot = CodReconciliationSnapshot.fromJson({
      'batch': {
        'batch_id': 'batch-1',
        'shop_id': 'shop-1',
        'business_date': '2026-08-26',
        'status': 'variance',
        'expected_total_minor': 5000,
        'collected_total_minor': 4500,
        'variance_minor': -500,
      },
      'rows': [
        {
          'record_id': 'record-1',
          'merchant_order_id': 'order-1',
          'order_reference': 'YC-123',
          'expected_minor': 5000,
          'collected_minor': 4500,
          'status': 'mismatch',
          'created_at': '2026-08-26T10:00:00Z',
        },
      ],
      'limit': 50,
      'offset': 0,
    });

    expect(snapshot.batch?.status, 'variance');
    expect(snapshot.batch?.varianceMinor, -500);
    expect(snapshot.rows.single.status, 'mismatch');
    expect(snapshot.rows.single.orderReference, 'YC-123');
  });
}
