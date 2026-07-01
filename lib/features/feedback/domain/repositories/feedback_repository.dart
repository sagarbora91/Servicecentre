import '../../../../core/errors/result.dart';
import '../entities/job_feedback.dart';

/// Contract for capturing and reading customer [JobFeedback]. Lives in `domain`
/// (no Firebase imports); the `data` implementation adapts Cloud Firestore.
abstract interface class FeedbackRepository {
  /// Streams the feedback for [jobId], newest first.
  Stream<List<JobFeedback>> watchFeedbackForJob(String jobId);

  /// Records feedback for [jobId]. [rating] must be 1–5 (otherwise
  /// `Err(ValidationFailure)` is returned and nothing is written).
  Future<Result<void>> submitFeedback({
    required String jobId,
    required int rating,
    required String branchId,
    required String by,
    String? comment,
  });
}
