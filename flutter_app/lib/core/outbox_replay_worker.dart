import 'package:commerce_core/commerce_core.dart';

import 'api_client.dart';

class OutboxReplaySummary {
  const OutboxReplaySummary({
    this.completed = 0,
    this.failed = 0,
    this.skipped = 0,
  });

  final int completed;
  final int failed;
  final int skipped;
}

/// Replays only safe, authenticated, non-financial commands.
/// Payment-proof submission and payment finalization are intentionally not
/// supported here. Checkout replay is protected by the server idempotency key.
class OutboxReplayWorker {
  OutboxReplayWorker({required this.outbox, MarketplaceApiClient? api})
    : _api = api ?? MarketplaceApiClient();

  final CommandOutbox outbox;
  final MarketplaceApiClient _api;

  static const _maxAttempts = 5;

  Future<OutboxReplaySummary> replay() async {
    var completed = 0;
    var failed = 0;
    var skipped = 0;
    final commands = await outbox.pending();
    for (final command in commands) {
      if (command.attempts >= _maxAttempts) {
        skipped++;
        continue;
      }
      try {
        await _replayCommand(command);
        await outbox.markCompleted(command.idempotencyKey);
        completed++;
      } on Object catch (error) {
        await outbox.markFailed(command.idempotencyKey, _safeError(error));
        failed++;
      }
    }
    return OutboxReplaySummary(
      completed: completed,
      failed: failed,
      skipped: skipped,
    );
  }

  Future<void> _replayCommand(QueuedCommand command) async {
    switch (command.kind) {
      case 'checkout_create_orders':
        await _api.checkoutCartIdempotent(
          fulfilmentByShop: _list(command.payload['fulfilmentByShop']),
          paymentMethodByMerchant: _list(command.payload['paymentByMerchant']),
          deliveryByShop: _list(command.payload['deliveryByShop']),
          commandKey: command.idempotencyKey,
        );
      case 'apply_order_promotion':
        await _api.applyOrderPromotion(
          merchantOrderId: command.payload['merchantOrderId'].toString(),
          code: command.payload['code'].toString(),
        );
      default:
        throw StateError('Unsupported offline command: ${command.kind}');
    }
  }

  List<Map<String, dynamic>> _list(Object? value) {
    if (value is! List) throw const FormatException('Invalid queued payload');
    return value
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList(growable: false);
  }

  String _safeError(Object error) => error.toString().length > 240
      ? error.toString().substring(0, 240)
      : error.toString();
}
