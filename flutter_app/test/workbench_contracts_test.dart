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
