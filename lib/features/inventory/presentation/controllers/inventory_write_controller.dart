import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/inventory_providers.dart';

/// Orchestrates transactional stock writes (receive, adjust) for the inventory
/// screens. Holds the in-flight state; each method returns `null` on success or
/// the [Failure] for the screen to localize (e.g. an [InsufficientStockFailure]
/// when an adjustment would drive on-hand below zero — the repository writes
/// nothing in that case).
class InventoryWriteController extends AutoDisposeAsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  String get _uid => ref.read(currentUserProvider).valueOrNull?.uid ?? '';

  Future<Failure?> _run(Future<Result<void>> Function() op) async {
    state = const AsyncValue<void>.loading();
    final result = await op();
    state = const AsyncValue<void>.data(null);
    return result.failureOrNull;
  }

  /// Receives [qty] (> 0) of part [partId] into stock (transactional `in`).
  Future<Failure?> receiveStock({required String partId, required int qty}) =>
      _run(
        () => ref
            .read(inventoryRepositoryProvider)
            .receiveStock(partId: partId, qty: qty, by: _uid),
      );

  /// Adjusts on-hand of part [partId] by [delta] (may be negative; guarded at
  /// zero, transactional `adjust`).
  Future<Failure?> adjustStock({required String partId, required int delta}) =>
      _run(
        () => ref
            .read(inventoryRepositoryProvider)
            .adjustStock(partId: partId, delta: delta, by: _uid),
      );
}

/// The inventory-write controller provider.
final inventoryWriteControllerProvider =
    AutoDisposeAsyncNotifierProvider<InventoryWriteController, void>(
  InventoryWriteController.new,
);
