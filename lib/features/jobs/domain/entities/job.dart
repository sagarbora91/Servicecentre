import 'package:freezed_annotation/freezed_annotation.dart';

import 'job_outcome.dart';
import 'job_part.dart';
import 'job_qc.dart';
import 'job_status.dart';
import 'job_status_change.dart';
import 'payment_status.dart';
import 'warranty_type.dart';

part 'job.freezed.dart';

/// A service job: one watch taken in for repair and tracked through its
/// lifecycle (BUILD_BRIEF.md §5.1, `jobs/{id}`).
///
/// freezed value type; the Firestore mapping lives in the `data` layer's
/// `FirestoreJobsRepository`, so `domain` stays free of Firebase types.
/// References ([customerId], [watchId], [assignedTo], [parentJobId]) are stored
/// as the related document's String id. Money ([amountPaise]) is integer paise;
/// timestamps are UTC.
///
/// Audit fields ([createdAt], [createdBy], [updatedAt]) are nullable: they are
/// populated by the repository with `serverTimestamp()`/uid on write and read
/// back `null` until the write commits.
@freezed
abstract class Job with _$Job {
  /// Creates a job.
  const factory Job({
    required String id,
    required String jobNo,
    required String customerId,
    required JobStatus status,
    required String fault,
    required String workRequested,
    required int tatTargetHrs,
    required DateTime dueAt,
    required PaymentStatus paymentStatus,
    required bool isRework,
    required String branchId,
    String? watchId,
    String? sourceStore,
    String? assignedTo,
    @Default(<String>[]) List<String> intakePhotos,
    @Default(<String>[]) List<String> deliveryPhotos,
    JobQc? qc,
    @Default(<JobPart>[]) List<JobPart> partsUsed,
    JobOutcome? outcome,
    WarrantyType? warrantyType,
    String? parentJobId,
    int? amountPaise,
    @Default(<JobStatusChange>[]) List<JobStatusChange> statusHistory,
    DateTime? createdAt,
    String? createdBy,
    DateTime? updatedAt,
  }) = _Job;

  const Job._();
}
