import 'package:commerce_core/commerce_core.dart';

import 'api_client.dart';

class OutboxDiagnostic {
  const OutboxDiagnostic({required this.command, required this.state});

  final QueuedCommand command;
  final String state;
}

class OutboxReplaySummary {
  const OutboxReplaySummary({
    this.completed = 0,
    this.failed = 0,
    this.skipped = 0,
    this.pendingBefore = 0,
    this.pendingAfter = 0,
  });

  final int completed;
  final int failed;
  final int skipped;
  final int pendingBefore;
  final int pendingAfter;
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

  Future<List<OutboxDiagnostic>> diagnostics() async {
    final commands = await outbox.pending();
    return commands
        .map(
          (command) => OutboxDiagnostic(
            command: command,
            state: command.attempts >= _maxAttempts
                ? 'blocked'
                : command.attempts > 0
                ? 'failed'
                : 'pending',
          ),
        )
        .toList(growable: false);
  }

  Future<void> retry(String idempotencyKey) => outbox.retry(idempotencyKey);

  Future<void> discard(String idempotencyKey) =>
      outbox.markCompleted(idempotencyKey);

  static Future<OutboxReplaySummary>? _activeReplay;

  Future<OutboxReplaySummary> replay() {
    final active = _activeReplay;
    if (active != null) return active;
    final current = _replayInternal();
    _activeReplay = current;
    return current.whenComplete(() {
      if (identical(_activeReplay, current)) _activeReplay = null;
    });
  }

  Future<OutboxReplaySummary> _replayInternal() async {
    var completed = 0;
    var failed = 0;
    var skipped = 0;
    final commands = await outbox.pending();
    final pendingBefore = commands.length;
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
    final pendingAfter = (await outbox.pending()).length;
    return OutboxReplaySummary(
      completed: completed,
      failed: failed,
      skipped: skipped,
      pendingBefore: pendingBefore,
      pendingAfter: pendingAfter,
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
