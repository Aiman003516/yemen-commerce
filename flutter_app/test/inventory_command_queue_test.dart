import 'dart:io';

import 'package:commerce_core/commerce_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yemen_commerce/core/api_client.dart';
import 'package:yemen_commerce/core/contracts.dart';
import 'package:yemen_commerce/core/inventory_command_queue.dart';
import 'package:yemen_commerce/core/outbox_replay_worker.dart';

class _FakeMarketplaceApi extends MarketplaceApiClient {
  _FakeMarketplaceApi({this.error});

  final Object? error;

  void _throwIfConfigured() {
    final configured = error;
    if (configured != null) throw configured;
  }

  @override
  Future<InventoryAdjustmentResult> recordInventoryAdjustment({
    required String shopId,
    required String productId,
    required String locationId,
    required int quantityDelta,
    required String reason,
    required String idempotencyKey,
  }) async {
    _throwIfConfigured();
    return const InventoryAdjustmentResult(
      movementId: 'movement-1',
      productId: 'product-1',
      locationId: 'location-1',
      previousQuantity: 1,
      resultingQuantity: 2,
      totalProductQuantity: 2,
      idempotent: false,
    );
  }

  @override
  Future<InventoryCommandResult> completeInventoryTransfer({
    required String shopId,
    required String fromLocationId,
    required String toLocationId,
    required List<Map<String, dynamic>> items,
    required String reason,
    required String idempotencyKey,
  }) async {
    _throwIfConfigured();
    return const InventoryCommandResult(
      id: 'transfer-1',
      status: 'completed',
      idempotent: false,
    );
  }

  @override
  Future<InventoryCommandResult> applyInventoryCount({
    required String shopId,
    required String locationId,
    required List<Map<String, dynamic>> items,
    required String reason,
    required String idempotencyKey,
  }) async {
    _throwIfConfigured();
    return const InventoryCommandResult(
      id: 'count-1',
      status: 'completed',
      idempotent: false,
      itemCount: 1,
    );
  }
}

void main() {
  const shopId = 'shop-1';
  const productId = 'product-1';
  const locationId = 'location-1';

  test('queues transient inventory failure with a scoped command', () async {
    final outbox = InMemoryCommandOutbox();
    final queue = InventoryCommandQueue(
      userScope: 'user-1',
      api: _FakeMarketplaceApi(
        error: const SocketException('network is unreachable'),
      ),
      outbox: outbox,
    );

    final outcome = await queue.recordAdjustment(
      shopId: shopId,
      productId: productId,
      locationId: locationId,
      quantityDelta: 1,
      reason: 'استلام مخزون',
    );

    expect(outcome.queued, isTrue);
    final pending = await outbox.pending();
    expect(pending, hasLength(1));
    expect(pending.single.kind, 'record_inventory_adjustment');
    expect(pending.single.payload['productId'], productId);
  });

  test('does not queue permanent inventory conflict', () async {
    final outbox = InMemoryCommandOutbox();
    final queue = InventoryCommandQueue(
      userScope: 'user-1',
      api: _FakeMarketplaceApi(error: StateError('INVENTORY_STOCK_CONFLICT')),
      outbox: outbox,
    );

    expect(
      () => queue.recordAdjustment(
        shopId: shopId,
        productId: productId,
        locationId: locationId,
        quantityDelta: -4,
        reason: 'تسوية مخزون',
      ),
      throwsStateError,
    );
    expect(await outbox.pending(), isEmpty);
  });

  test('blocks permanent replay failures instead of retrying them', () async {
    final outbox = InMemoryCommandOutbox();
    await outbox.enqueue(
      QueuedCommand(
        idempotencyKey: 'inventory-adjust-user-1-1',
        kind: 'record_inventory_adjustment',
        payload: {
          'shopId': shopId,
          'productId': productId,
          'locationId': locationId,
          'quantityDelta': -4,
          'reason': 'تسوية مخزون',
        },
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    );

    final summary = await OutboxReplayWorker(
      outbox: outbox,
      userScope: 'user-1',
      api: _FakeMarketplaceApi(error: StateError('INVENTORY_STOCK_CONFLICT')),
    ).replay();

    expect(summary.skipped, 1);
    final pending = await outbox.pending();
    expect(pending.single.blocked, isTrue);
    expect(pending.single.attempts, 0);
  });

  test('replays queued inventory adjustment successfully', () async {
    final outbox = InMemoryCommandOutbox();
    await outbox.enqueue(
      QueuedCommand(
        idempotencyKey: 'inventory-adjust-user-1-2',
        kind: 'record_inventory_adjustment',
        payload: {
          'shopId': shopId,
          'productId': productId,
          'locationId': locationId,
          'quantityDelta': 1,
          'reason': 'استلام مخزون',
        },
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    );

    final summary = await OutboxReplayWorker(
      outbox: outbox,
      userScope: 'user-1',
      api: _FakeMarketplaceApi(),
    ).replay();

    expect(summary.completed, 1);
    expect(await outbox.pending(), isEmpty);
  });
}
