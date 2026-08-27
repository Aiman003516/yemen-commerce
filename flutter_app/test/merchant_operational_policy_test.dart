import 'package:flutter_test/flutter_test.dart';
import 'package:yemen_commerce/core/merchant_operational_policy.dart';

void main() {
  test('shipment creation requires merchant-confirmed payment', () {
    expect(MerchantOperationalPolicy.canCreateShipment('paid'), isTrue);
    expect(
      MerchantOperationalPolicy.canCreateShipment('payment_under_review'),
      isFalse,
    );
    expect(
      MerchantOperationalPolicy.canCreateShipment('awaiting_payment'),
      isFalse,
    );
  });

  test('transit and delivery statuses require confirmed payment', () {
    expect(
      MerchantOperationalPolicy.requiresConfirmedPayment('dispatched'),
      isTrue,
    );
    expect(
      MerchantOperationalPolicy.requiresConfirmedPayment('in_transit'),
      isTrue,
    );
    expect(
      MerchantOperationalPolicy.requiresConfirmedPayment('delivered'),
      isTrue,
    );
    expect(
      MerchantOperationalPolicy.requiresConfirmedPayment('ready'),
      isFalse,
    );
  });

  test('returns only legal state-machine transitions', () {
    expect(
      MerchantOperationalPolicy.nextShipmentStatuses('planned'),
      containsAll(<String>['ready', 'cancelled', 'failed']),
    );
    expect(
      MerchantOperationalPolicy.nextShipmentStatuses('delivered'),
      isEmpty,
    );
    expect(MerchantOperationalPolicy.nextReturnStatuses('inspected'), <String>[
      'closed',
    ]);
    expect(MerchantOperationalPolicy.nextReturnStatuses('closed'), isEmpty);
  });
}
