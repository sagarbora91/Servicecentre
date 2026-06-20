import 'package:freezed_annotation/freezed_annotation.dart';

part 'job_qc.freezed.dart';

/// The quality-control checklist completed before a [Job] can be delivered
/// (BUILD_BRIEF.md §5.1, stored under `jobs/{id}.qc`).
///
/// freezed value type: equality, `hashCode`, and `copyWith` are generated. The
/// Firestore mapping lives in the `data` layer's `FirestoreJobsRepository`, so
/// `domain` stays free of Firebase types.
@freezed
abstract class JobQc with _$JobQc {
  /// Creates a QC checklist.
  const factory JobQc({
    required bool timekeeping,
    required bool gasket,
    required bool glassClean,
    required bool strap,
    required bool crown,
  }) = _JobQc;

  const JobQc._();

  /// Whether every QC check has passed. The delivery gate (M3) requires this to
  /// be `true` alongside at least one delivery photo.
  bool get isComplete =>
      timekeeping && gasket && glassClean && strap && crown;
}
