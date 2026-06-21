import '../../../../core/errors/result.dart';
import '../entities/job.dart';
import '../entities/job_outcome.dart';
import '../entities/job_qc.dart';
import '../entities/job_status.dart';
import '../entities/warranty_type.dart';

/// Contract for reading and mutating service [Job]s.
///
/// Lives in `domain`, so it has no Firebase imports; the implementation in
/// `data` adapts Cloud Firestore to this interface. Reads that observe live
/// data expose a [Stream]; one-shot reads and writes return a [Result] and
/// never throw across layers.
abstract interface class JobsRepository {
  /// Streams the Kanban board for [branchId]: all jobs in the branch ordered by
  /// [JobStatus] then [Job.dueAt] (soonest first). Backed by the
  /// `branchId ASC, status ASC, dueAt ASC` composite index.
  Stream<List<Job>> watchBoard(String branchId);

  /// Streams every job for [customerId], most recently created first, for the
  /// customer's service history.
  Stream<List<Job>> watchJobsForCustomer(String customerId);

  /// Streams a single job by document [id], emitting `null` when it does not
  /// exist. Backs the live job-detail screen.
  Stream<Job?> watchJob(String id);

  /// Fetches a single job by document [id]. Returns a `NotFoundFailure` when no
  /// such job exists.
  Future<Result<Job>> getJob(String id);

  /// Creates a job in status [JobStatus.received], seeding `statusHistory` with
  /// the opening entry. [createdBy] is the acting user's uid. Returns the
  /// created [Job] (with its new id) on success.
  Future<Result<Job>> createJob({
    required String jobNo,
    required String customerId,
    required String branchId,
    required String fault,
    required String workRequested,
    required int tatTargetHrs,
    required DateTime dueAt,
    required String createdBy,
    String? watchId,
    String? sourceStore,
    String? assignedTo,
    bool isRework = false,
    String? parentJobId,
    List<String> intakePhotos = const [],
  });

  /// Moves job [id] to status [to], appending `{status, at, by}` to its
  /// `statusHistory` and updating `status`. [by] is the acting user's uid.
  ///
  /// The delivery gate is enforced here too: moving to [JobStatus.delivered]
  /// re-reads the job and returns `Err(ValidationFailure)` (writing nothing)
  /// unless its QC map is complete AND it has at least one delivery photo.
  Future<Result<void>> moveStatus(String id, JobStatus to, String by);

  /// Records/updates the QC checklist on job [id]. [by] is the acting uid.
  Future<Result<void>> updateQc(String id, JobQc qc, String by);

  /// Delivers job [id] (moves it to [JobStatus.delivered]), optionally recording
  /// the [outcome] and [warrantyType]. [by] is the acting uid.
  ///
  /// Gated (CLAUDE.md #4): returns `Err(ValidationFailure)` writing nothing
  /// unless the QC map is complete AND there is at least one delivery photo.
  Future<Result<void>> deliver(
    String id, {
    required String by,
    JobOutcome? outcome,
    WarrantyType? warrantyType,
  });
}
