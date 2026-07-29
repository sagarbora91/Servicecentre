import 'package:freezed_annotation/freezed_annotation.dart';

import 'job_status.dart';

part 'job_status_change.freezed.dart';

/// One transition in a [Job]'s `statusHistory` audit trail
/// (BUILD_BRIEF.md §5.1): which [status] it moved to, [at] what UTC instant,
/// and [by] which user (uid).
///
/// Firestore disallows `serverTimestamp()` sentinels inside array elements, so
/// [at] is a concrete UTC [DateTime] captured by the repository at write time.
/// The Firestore mapping lives in the `data` layer so `domain` stays
/// Firebase-free.
@freezed
abstract class JobStatusChange with _$JobStatusChange {
  /// Creates a status-change entry.
  const factory JobStatusChange({
    required JobStatus status,
    required DateTime at,
    required String by,
  }) = _JobStatusChange;

  const JobStatusChange._();
}
