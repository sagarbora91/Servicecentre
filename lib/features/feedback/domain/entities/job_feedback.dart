import 'package:freezed_annotation/freezed_annotation.dart';

part 'job_feedback.freezed.dart';

/// Customer feedback on a delivered job (`feedback/{id}`, BUILD_BRIEF.md §5.1).
///
/// Named [JobFeedback] to avoid clashing with Flutter's `Feedback`. [rating] is
/// 1–5. freezed value type; Firestore mapping lives in `data`.
@freezed
abstract class JobFeedback with _$JobFeedback {
  /// Creates a feedback record.
  const factory JobFeedback({
    required String id,
    required String jobId,
    required int rating,
    required String branchId,
    String? comment,
    DateTime? at,
  }) = _JobFeedback;

  const JobFeedback._();

  /// Whether [rating] is within the valid 1–5 range.
  bool get isValidRating => rating >= 1 && rating <= 5;
}
