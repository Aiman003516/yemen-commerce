import 'dart:convert';

import 'package:commerce_core/commerce_core.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// A persistent, encrypted outbox for retryable authenticated commands.
///
/// Payment finalization and proof submission must not be queued through this
/// class. Callers should enqueue only idempotent, non-financial commands whose
/// server-side RPCs enforce the same idempotency key.
class SecureCommandOutbox implements CommandOutbox {
  SecureCommandOutbox({
    required String userScope,
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? const FlutterSecureStorage(),
       _storageKey = _scopedStorageKey(userScope);

  static const _storageKeyPrefix = 'commerce_command_outbox_v1_';
  final FlutterSecureStorage _storage;
  final String _storageKey;

  static String _scopedStorageKey(String userScope) {
    final normalized = userScope.trim();
    if (normalized.isEmpty || normalized.length > 128) {
      throw ArgumentError.value(userScope, 'userScope', 'must be non-empty');
    }
    final safeScope = base64Url.encode(utf8.encode(normalized));
    return '$_storageKeyPrefix$safeScope';
  }

  @override
  Future<void> enqueue(QueuedCommand command) async {
    final commands = await _read();
    commands.putIfAbsent(command.idempotencyKey, () => command);
    await _write(commands);
  }

  @override
  Future<List<QueuedCommand>> pending() async {
    final commands = await _read();
    final result = commands.values.toList(growable: false)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return result;
  }

  @override
  Future<void> markCompleted(String idempotencyKey) async {
    final commands = await _read();
    if (commands.remove(idempotencyKey) != null) {
      await _write(commands);
    }
  }

  @override
  Future<void> retry(String idempotencyKey) async {
    final commands = await _read();
    final command = commands[idempotencyKey];
    if (command == null) return;
    commands[idempotencyKey] = QueuedCommand(
      idempotencyKey: command.idempotencyKey,
      kind: command.kind,
      payload: command.payload,
      createdAt: command.createdAt,
    );
    await _write(commands);
  }

  @override
  Future<void> markFailed(String idempotencyKey, String error) async {
    final commands = await _read();
    final command = commands[idempotencyKey];
    if (command == null) return;
    commands[idempotencyKey] = command.copyWith(
      attempts: command.attempts + 1,
      lastError: error,
    );
    await _write(commands);
  }

  Future<Map<String, QueuedCommand>> _read() async {
    final raw = await _storage.read(key: _storageKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return {
        for (final item in decoded)
          (item as Map<String, dynamic>)['idempotencyKey'] as String:
              QueuedCommand.fromJson(item),
      };
    } on Object {
      // A corrupt local queue must never block the app. Discard only the
      // queue payload, not auth credentials or any server-side state.
      await _storage.delete(key: _storageKey);
      return {};
    }
  }

  Future<void> _write(Map<String, QueuedCommand> commands) async {
    if (commands.isEmpty) {
      await _storage.delete(key: _storageKey);
      return;
    }
    final values = commands.values.toList(growable: false)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    await _storage.write(
      key: _storageKey,
      value: jsonEncode(values.map((command) => command.toJson()).toList()),
    );
  }
}
