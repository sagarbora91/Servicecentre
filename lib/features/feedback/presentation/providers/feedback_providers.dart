import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/firebase/firebase_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/providers/staff_providers.dart';
import '../../data/repositories/firestore_feedback_repository.dart';
import '../../domain/entities/job_feedback.dart';
import '../../domain/repositories/feedback_repository.dart';

/// The app's [FeedbackRepository]. Override this (or `firestoreProvider`) in
/// tests.
final feedbackRepositoryProvider = Provider<FeedbackRepository>(
  (ref) => FirestoreFeedbackRepository(firestore: ref.watch(firestoreProvider)),
);

/// Streams the feedback for [jobId] (newest first). `autoDispose` so it drops
/// when the screen leaves the tree.
final feedbackForJobProvider =
    StreamProvider.autoDispose.family<List<JobFeedback>, String>(
  (ref, jobId) =>
      ref.watch(feedbackRepositoryProvider).watchFeedbackForJob(jobId),
);

/// Records customer feedback. Returns `null` on success or the [Failure] for
/// the screen to localize.
class FeedbackController extends AutoDisposeAsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  /// Submits [rating] (1–5) and optional [comment] for [jobId].
  Future<Failure?> submit({
    required String jobId,
    required int rating,
    String? comment,
  }) async {
    final branchId = ref.read(currentBranchIdProvider);
    if (branchId == null) {
      return const UnexpectedFailure('No branch selected');
    }
    final uid = ref.read(currentUserProvider).valueOrNull?.uid ?? '';
    state = const AsyncValue<void>.loading();
    final result = await ref.read(feedbackRepositoryProvider).submitFeedback(
          jobId: jobId,
          rating: rating,
          branchId: branchId,
          by: uid,
          comment: comment,
        );
    state = const AsyncValue<void>.data(null);
    return result.failureOrNull;
  }
}

/// The feedback controller provider.
final feedbackControllerProvider =
    AutoDisposeAsyncNotifierProvider<FeedbackController, void>(
  FeedbackController.new,
);
