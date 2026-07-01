import 'package:freezed_annotation/freezed_annotation.dart';

import 'estimate_line.dart';
import 'estimate_status.dart';

part 'estimate.freezed.dart';

/// A customer quote for a job (`estimates/{id}`, BUILD_BRIEF.md §5.1).
///
/// An estimate holds a list of [lines] and a lifecycle [status]
/// (draft → sent → approved/declined). [totalPaise] is the persisted sum of the
/// line amounts; [computedTotalPaise] recomputes it from [lines] so callers can
/// keep the stored total consistent. All money is integer paise (BUILD_BRIEF
/// §4). freezed value type; the Firestore mapping lives in the `data` layer so
/// `domain` stays Firebase-free.
@freezed
abstract class Estimate with _$Estimate {
  /// Creates an estimate. [totalPaise] should equal [computedTotalPaise]; the
  /// data layer stamps it on write.
  const factory Estimate({
    required String id,
    required String jobId,
    required String branchId,
    required List<EstimateLine> lines,
    required int totalPaise,
    required EstimateStatus status,
    String? approvedVia,
    DateTime? approvedAt,
    DateTime? createdAt,
    String? createdBy,
    DateTime? updatedAt,
  }) = _Estimate;

  const Estimate._();

  /// The sum of the line amounts in paise (the source of truth for
  /// [totalPaise]).
  int get computedTotalPaise {
    var sum = 0;
    for (final line in lines) {
      sum += line.amountPaise;
    }
    return sum;
  }

  /// Whether the customer has approved this estimate.
  bool get isApproved => status == EstimateStatus.approved;
}
