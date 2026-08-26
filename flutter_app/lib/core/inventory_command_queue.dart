import 'dart:async';

import 'package:commerce_core/commerce_core.dart';

import 'api_client.dart';
import 'secure_command_outbox.dart';

class InventoryQueueOutcome {
  const InventoryQueueOutcome({
    required this.idempotencyKey,
    this.queued = false,
  });

  final String idempotencyKey;
  final bool queued;
}

/// Coordinates merchant inventory mutations across unstable connectivity.
///
/// Only transport failures are queued. Validation errors, auth failures, stock
/// conflicts, and duplicate/business-rule errors are returned to the caller so
/// they are not replayed blindly later.
class InventoryCommandQueue {
  InventoryCommandQueue({
    required String userScope,
    MarketplaceApiClient? api,
    CommandOutbox? outbox,
  }) : _api = api ?? MarketplaceApiClient(),
       _outbox = outbox ?? SecureCommandOutbox(userScope: userScope) {
    if (userScope.trim().isEmpty) {
      throw ArgumentError.value(userScope, 'userScope', 'must be non-empty');
    }
  }

  final MarketplaceApiClient _api;
  final CommandOutbox _outbox;

  Future<InventoryQueueOutcome> recordAdjustment({
    required String shopId,
    required String productId,
    required String locationId,
    required int quantityDelta,
    required String reason,
  }) async {
    final key = _commandKey('inventory-adjust');
    try {
      await _api.recordInventoryAdjustment(
        shopId: shopId,
        productId: productId,
        locationId: locationId,
        quantityDelta: quantityDelta,
        reason: reason,
        idempotencyKey: key,
      );
      return InventoryQueueOutcome(idempotencyKey: key);
    } on Object catch (error) {
      return _queueIfTransient(
        error: error,
        key: key,
        kind: 'record_inventory_adjustment',
        payload: {
          'shopId': shopId,
          'productId': productId,
          'locationId': locationId,
          'quantityDelta': quantityDelta,
          'reason': reason,
        },
      );
    }
  }

  Future<InventoryQueueOutcome> completeTransfer({
    required String shopId,
    required String fromLocationId,
    required String toLocationId,
    required List<Map<String, dynamic>> items,
    required String reason,
  }) async {
    final key = _commandKey('inventory-transfer');
    try {
      await _api.completeInventoryTransfer(
        shopId: shopId,
        fromLocationId: fromLocationId,
        toLocationId: toLocationId,
        items: items,
        reason: reason,
        idempotencyKey: key,
      );
      return InventoryQueueOutcome(idempotencyKey: key);
    } on Object catch (error) {
      return _queueIfTransient(
        error: error,
        key: key,
        kind: 'complete_inventory_transfer',
        payload: {
          'shopId': shopId,
          'fromLocationId': fromLocationId,
          'toLocationId': toLocationId,
          'items': items,
          'reason': reason,
        },
      );
    }
  }

  Future<InventoryQueueOutcome> applyCount({
    required String shopId,
    required String locationId,
    required List<Map<String, dynamic>> items,
    required String reason,
  }) async {
    final key = _commandKey('inventory-count');
    try {
      await _api.applyInventoryCount(
        shopId: shopId,
        locationId: locationId,
        items: items,
        reason: reason,
        idempotencyKey: key,
      );
      return InventoryQueueOutcome(idempotencyKey: key);
    } on Object catch (error) {
      return _queueIfTransient(
        error: error,
        key: key,
        kind: 'apply_inventory_count',
        payload: {
          'shopId': shopId,
          'locationId': locationId,
          'items': items,
          'reason': reason,
        },
      );
    }
  }

  Future<InventoryQueueOutcome> _queueIfTransient({
    required Object error,
    required String key,
    required String kind,
    required Map<String, dynamic> payload,
  }) async {
    if (!isTransientNetworkError(error)) {
      throw error;
    }
    await _outbox.enqueue(
      QueuedCommand(
        idempotencyKey: key,
        kind: kind,
        payload: payload,
        createdAt: DateTime.now(),
        lastError: safeOutboxError(error),
      ),
    );
    return InventoryQueueOutcome(idempotencyKey: key, queued: true);
  }

  String _commandKey(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}';
}

bool isTransientNetworkError(Object error) {
  if (error is TimeoutException) return true;
  final value = error.toString().toLowerCase();
  const permanentMarkers = [
    'auth_required',
    'shop_not_owned',
    'product_not_found',
    'inventory_location_not_found',
    'inventory_stock_conflict',
    'inventory_transfer_stock_conflict',
    'inventory_count_below_reserved',
    'invalid_inventory_',
    'product_barcode_duplicate',
    'catalog_import_duplicate_barcode',
    'permission denied',
    '42501',
    '23505',
    'p0001',
  ];
  if (permanentMarkers.any(value.contains)) return false;
  const transientMarkers = [
    'socketexception',
    'clientexception',
    'failed host lookup',
    'network is unreachable',
    'connection reset',
    'connection closed',
    'connection refused',
    'timed out',
    'timeout',
    'network request failed',
    'xmlhttprequest error',
    'fetch failed',
    'offline',
  ];
  return transientMarkers.any(value.contains);
}

String safeOutboxError(Object error) {
  final value = error.toString();
  return value.length > 240 ? value.substring(0, 240) : value;
}
