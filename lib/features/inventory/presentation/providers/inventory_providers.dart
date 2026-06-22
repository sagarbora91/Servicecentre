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

/// Whether the signed-in user may manage inventory: stock receive/adjust on the
/// part-detail screen (owner/supervisor/store). The UI uses it to show or hide
/// those actions. Defaults to `false` until the profile resolves.
final canManageInventoryProvider = Provider<bool>(
  (ref) =>
      ref.watch(currentUserProvider).valueOrNull?.role.canManageInventory ??
      false,
);

/// Whether the signed-in user may log parts consumed on a job
/// (owner/supervisor/store/technician — a technician records parts they use).
/// Mirrors the `parts` write rule in `firestore.rules`. Defaults to `false`
/// until the profile resolves.
final canLogJobPartsProvider = Provider<bool>(
  (ref) =>
      ref.watch(currentUserProvider).valueOrNull?.role.canLogJobParts ?? false,
);

/// Streams the parts in the given branch, ordered by category then reference.
final partsProvider = StreamProvider.family<List<Part>, String>(
  (ref, branchId) =>
      ref.watch(inventoryRepositoryProvider).watchParts(branchId),
);
