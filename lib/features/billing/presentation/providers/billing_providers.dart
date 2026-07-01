import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../data/repositories/firestore_estimates_repository.dart';
import '../../domain/entities/estimate.dart';
import '../../domain/repositories/estimates_repository.dart';

/// The app's [EstimatesRepository]. Override this (or the Firebase providers in
/// `core/firebase/firebase_providers.dart`) in tests.
final estimatesRepositoryProvider = Provider<EstimatesRepository>(
  (ref) => FirestoreEstimatesRepository(
    firestore: ref.watch(firestoreProvider),
  ),
);

/// Streams the estimates for [jobId] (newest first). `autoDispose` so it is
/// dropped when the estimate screen leaves the tree.
final estimatesForJobProvider =
    StreamProvider.autoDispose.family<List<Estimate>, String>(
  (ref, jobId) =>
      ref.watch(estimatesRepositoryProvider).watchEstimatesForJob(jobId),
);
