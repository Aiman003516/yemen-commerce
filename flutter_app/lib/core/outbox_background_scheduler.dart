import 'dart:async';

import 'package:commerce_core/commerce_core.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import 'outbox_replay_worker.dart';
import 'secure_command_outbox.dart';
import 'supabase_config.dart';
import 'supabase_marketplace_client.dart';

const _periodicTask = 'yemen-commerce-outbox-periodic';
const _connectivityTask = 'yemen-commerce-outbox-connectivity';

@pragma('vm:entry-point')
void outboxBackgroundCallback() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    if (task != _periodicTask && task != _connectivityTask) return true;
    if (!SupabaseConfig.isConfigured) return true;
    try {
      await SupabaseRuntime.initialize();
      final userId = SupabaseMarketplaceClient().currentAuthUser?.id;
      if (userId == null || userId.isEmpty) return true;
      final summary = await OutboxReplayWorker(
        outbox: SecureCommandOutbox(userScope: userId),
        userScope: userId,
      ).replay();
      return summary.failed == 0;
    } on Object {
      // Returning false lets the OS apply its own retry/backoff policy. No
      // secrets or queued payloads are written to logs.
      return false;
    }
  });
}

/// Registers OS-managed replay and triggers a constrained one-off task when a
/// network interface becomes available. Actual reachability is still verified
/// by the RPC call; connectivity type alone is never treated as proof of access.
final outboxBackgroundScheduler = OutboxBackgroundScheduler();

class OutboxBackgroundScheduler {
  OutboxBackgroundScheduler({
    Connectivity? connectivity,
    Workmanager? workmanager,
  }) : _connectivity = connectivity ?? Connectivity(),
       _workmanager = workmanager ?? Workmanager();

  final Connectivity _connectivity;
  final Workmanager _workmanager;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _started = false;
  DateTime? _lastConnectedEventAt;

  bool get isStarted => _started;
  DateTime? get lastConnectedEventAt => _lastConnectedEventAt;
  String get modeLabel => kIsWeb
      ? 'الويب: مزامنة الجلسة والاتصال والمزامنة اليدوية فقط'
      : _started
      ? 'الهاتف: جدولة نظام التشغيل مفعلة بأفضل جهد'
      : 'جدولة الهاتف غير مهيأة';

  Future<void> start() async {
    if (_started || kIsWeb || !SupabaseConfig.isConfigured) return;
    try {
      await _workmanager.initialize(outboxBackgroundCallback);
      await _workmanager.registerPeriodicTask(
        _periodicTask,
        'outbox_replay',
        frequency: const Duration(minutes: 15),
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
        backoffPolicy: BackoffPolicy.exponential,
        backoffPolicyDelay: const Duration(minutes: 1),
        tag: 'commerce-outbox',
      );
      _started = true;
      _subscription = _connectivity.onConnectivityChanged.listen((results) {
        if (results.any((result) => result != ConnectivityResult.none)) {
          _lastConnectedEventAt = DateTime.now();
          unawaited(_tryRegisterConnectedOneOff());
        }
      });
      final initial = await _connectivity.checkConnectivity();
      if (initial.any((result) => result != ConnectivityResult.none)) {
        _lastConnectedEventAt = DateTime.now();
        unawaited(_tryRegisterConnectedOneOff());
      }
    } on Object {
      _started = false;
      await _subscription?.cancel();
      _subscription = null;
      // Background scheduling is optional; app startup and foreground sync
      // remain available when a platform plugin or OS policy rejects setup.
    }
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    _started = false;
  }

  Future<void> _tryRegisterConnectedOneOff() async {
    try {
      await _registerConnectedOneOff();
    } on Object {
      // The next connectivity event or periodic task can try again.
    }
  }

  Future<void> _registerConnectedOneOff() => _workmanager.registerOneOffTask(
    _connectivityTask,
    'outbox_replay',
    constraints: Constraints(networkType: NetworkType.connected),
    existingWorkPolicy: ExistingWorkPolicy.keep,
    backoffPolicy: BackoffPolicy.exponential,
    backoffPolicyDelay: const Duration(minutes: 1),
    tag: 'commerce-outbox-connectivity',
  );
}
