import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/repositories/firestore_inventory_repository.dart';
import '../../domain/entities/part.dart';
import '../../domain/repositories/inventory_repository.dart';

/// The app's [InventoryRepository]. Override this (or `firestoreProvider` in
/// `core/firebase/firebase_providers.dart`) in tests.
final inventoryRepositoryProvider = Provider<InventoryRepository>(
  (ref) => FirestoreInventoryRepository(ref.watch(firestoreProvider)),
);

/// Whether the signed-in user may write inventory (parts/stock). Mirrors the
/// `parts` write rule in `firestore.rules` (owner/supervisor/store); the UI uses
/// it to show or hide stock-write actions. Defaults to `false` until the profile
/// resolves.
final canManageInventoryProvider = Provider<bool>(
  (ref) =>
      ref.watch(currentUserProvider).valueOrNull?.role.canManageInventory ??
      false,
);

/// Streams the parts in the given branch, ordered by category then reference.
final partsProvider = StreamProvider.family<List<Part>, String>(
  (ref, branchId) =>
      ref.watch(inventoryRepositoryProvider).watchParts(branchId),
);
