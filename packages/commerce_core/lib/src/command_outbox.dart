/// A command queued while a client is offline or the network is unreliable.
///
/// The outbox is intentionally transport-agnostic. Persistence can be supplied
/// by a Flutter platform store later; replay must always call an authenticated
/// server RPC and use [idempotencyKey] to prevent duplicate mutations.
class QueuedCommand {
  const QueuedCommand({
    required this.idempotencyKey,
    required this.kind,
    required this.payload,
    required this.createdAt,
    this.attempts = 0,
    this.lastError,
  });

  final String idempotencyKey;
  final String kind;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int attempts;
  final String? lastError;

  QueuedCommand copyWith({int? attempts, String? lastError}) => QueuedCommand(
    idempotencyKey: idempotencyKey,
    kind: kind,
    payload: payload,
    createdAt: createdAt,
    attempts: attempts ?? this.attempts,
    lastError: lastError ?? this.lastError,
  );
}

abstract interface class CommandOutbox {
  Future<void> enqueue(QueuedCommand command);
  Future<List<QueuedCommand>> pending();
  Future<void> markCompleted(String idempotencyKey);
  Future<void> markFailed(String idempotencyKey, String error);
}

/// Deterministic reference implementation for tests and non-persistent use.
/// Production Flutter clients should provide a persistent implementation using
/// an encrypted/local store selected for the target platform.
class InMemoryCommandOutbox implements CommandOutbox {
  final Map<String, QueuedCommand> _commands = {};

  @override
  Future<void> enqueue(QueuedCommand command) async {
    _commands.putIfAbsent(command.idempotencyKey, () => command);
  }

  @override
  Future<List<QueuedCommand>> pending() async =>
      _commands.values.toList(growable: false);

  @override
  Future<void> markCompleted(String idempotencyKey) async {
    _commands.remove(idempotencyKey);
  }

  @override
  Future<void> markFailed(String idempotencyKey, String error) async {
    final command = _commands[idempotencyKey];
    if (command == null) return;
    _commands[idempotencyKey] = command.copyWith(
      attempts: command.attempts + 1,
      lastError: error,
    );
  }
}
