import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../data/repositories/firestore_settings_repository.dart';
import '../../domain/entities/branch_settings.dart';
import '../../domain/repositories/settings_repository.dart';

/// The app's [SettingsRepository]. Override this (or the Firebase providers) in
/// tests.
final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => FirestoreSettingsRepository(
    firestore: ref.watch(firestoreProvider),
  ),
);

/// Streams the [BranchSettings] for [branchId] (defaults when unset).
final branchSettingsProvider =
    StreamProvider.family<BranchSettings, String>(
  (ref, branchId) =>
      ref.watch(settingsRepositoryProvider).watchSettings(branchId),
);
