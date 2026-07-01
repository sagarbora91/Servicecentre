import '../../../../core/errors/result.dart';
import '../entities/estimate.dart';
import '../entities/estimate_line.dart';
import '../entities/estimate_status.dart';

/// Contract for reading and mutating job [Estimate]s (quotes).
///
/// Lives in `domain`, so it has no Firebase imports; the `data` implementation
/// adapts Cloud Firestore to this interface. Live reads expose a [Stream];
/// one-shot writes return a [Result] and never throw across layers.
abstract interface class EstimatesRepository {
  /// Streams the estimates for [jobId], newest first.
  Stream<List<Estimate>> watchEstimatesForJob(String jobId);

  /// Creates a [EstimateStatus.draft] estimate for [jobId] with [lines]. The
  /// stored `totalPaise` is computed from the lines.
  Future<Result<Estimate>> createEstimate({
    required String jobId,
    required String branchId,
    required List<EstimateLine> lines,
    required String createdBy,
  });

  /// Replaces the [lines] of estimate [id] and recomputes its total. Intended
  /// while the estimate is still editable (draft/sent).
  Future<Result<void>> updateLines(
    String id,
    List<EstimateLine> lines,
    String by,
  );

  /// Transitions estimate [id] to [to]. When [to] is
  /// [EstimateStatus.approved], `approvedAt` is stamped and [approvedVia]
  /// (e.g. how the customer approved) is recorded when given.
  Future<Result<void>> setStatus(
    String id,
    EstimateStatus to,
    String by, {
    String? approvedVia,
  });
}
