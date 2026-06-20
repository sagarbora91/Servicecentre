import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../data/repositories/firestore_inventory_repository.dart';
import '../../domain/entities/part.dart';
import '../../domain/repositories/inventory_repository.dart';

/// The app's [InventoryRepository]. Override this (or `firestoreProvider` in
/// `core/firebase/firebase_providers.dart`) in tests.
final inventoryRepositoryProvider = Provider<InventoryRepository>(
  (ref) => FirestoreInventoryRepository(ref.watch(firestoreProvider)),
);

/// Streams the parts in the given branch, ordered by category then reference.
final partsProvider = StreamProvider.family<List<Part>, String>(
  (ref, branchId) =>
      ref.watch(inventoryRepositoryProvider).watchParts(branchId),
);
