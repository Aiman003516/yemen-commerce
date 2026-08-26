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
    this.blocked = false,
  });

  final String idempotencyKey;
  final String kind;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int attempts;
  final String? lastError;
  final bool blocked;

  Map<String, dynamic> toJson() => {
    'idempotencyKey': idempotencyKey,
    'kind': kind,
    'payload': payload,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'attempts': attempts,
    'lastError': lastError,
    'blocked': blocked,
  };

  factory QueuedCommand.fromJson(Map<String, dynamic> json) => QueuedCommand(
    idempotencyKey: json['idempotencyKey'] as String,
    kind: json['kind'] as String,
    payload: Map<String, dynamic>.from(json['payload'] as Map),
    createdAt: DateTime.parse(json['createdAt'] as String),
    attempts: (json['attempts'] as num?)?.toInt() ?? 0,
    lastError: json['lastError'] as String?,
    blocked: json['blocked'] as bool? ?? false,
  );

  QueuedCommand copyWith({int? attempts, String? lastError, bool? blocked}) =>
      QueuedCommand(
        idempotencyKey: idempotencyKey,
        kind: kind,
        payload: payload,
        createdAt: createdAt,
        attempts: attempts ?? this.attempts,
        lastError: lastError ?? this.lastError,
        blocked: blocked ?? this.blocked,
      );
}

abstract interface class CommandOutbox {
  Future<void> enqueue(QueuedCommand command);
  Future<List<QueuedCommand>> pending();
  Future<void> markCompleted(String idempotencyKey);
  Future<void> markFailed(String idempotencyKey, String error);
  Future<void> retry(String idempotencyKey);
  Future<void> markBlocked(String idempotencyKey, String error);
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
  Future<void> retry(String idempotencyKey) async {
    final command = _commands[idempotencyKey];
    if (command == null) return;
    _commands[idempotencyKey] = QueuedCommand(
      idempotencyKey: command.idempotencyKey,
      kind: command.kind,
      payload: command.payload,
      createdAt: command.createdAt,
      blocked: false,
    );
  }

  @override
  Future<void> markFailed(String idempotencyKey, String error) async {
    final command = _commands[idempotencyKey];
    if (command == null) return;
    _commands[idempotencyKey] = command.copyWith(
      attempts: command.attempts + 1,
      lastError: error,
      blocked: false,
    );
  }

  @override
  Future<void> markBlocked(String idempotencyKey, String error) async {
    final command = _commands[idempotencyKey];
    if (command == null) return;
    _commands[idempotencyKey] = command.copyWith(
      lastError: error,
      blocked: true,
    );
  }
}
