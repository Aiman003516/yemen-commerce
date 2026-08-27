abstract final class MerchantOperationalPolicy {
  static bool canCreateShipment(String paymentStatus) =>
      paymentStatus == 'paid';

  static bool requiresConfirmedPayment(String nextStatus) =>
      const {'dispatched', 'in_transit', 'delivered'}.contains(nextStatus);

  static List<String> nextShipmentStatuses(String current) =>
      <String, List<String>>{
        'planned': ['ready', 'cancelled', 'failed'],
        'ready': ['dispatched', 'cancelled', 'failed'],
        'dispatched': ['in_transit', 'failed', 'cancelled'],
        'in_transit': ['delivered', 'failed'],
        'failed': ['ready'],
      }[current] ??
      const [];

  static List<String> nextReturnStatuses(String current) =>
      <String, List<String>>{
        'requested': ['label_pending', 'awaiting_handoff', 'cancelled'],
        'label_pending': ['awaiting_handoff', 'cancelled'],
        'awaiting_handoff': ['in_transit', 'cancelled'],
        'in_transit': ['received', 'cancelled'],
        'received': ['inspected'],
        'inspected': ['closed'],
      }[current] ??
      const [];
}
