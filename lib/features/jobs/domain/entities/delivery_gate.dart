import 'job.dart';

/// Why a [Job] may or may not be delivered (M3 delivery gate, CLAUDE.md #4 /
/// BUILD_BRIEF §7): a job can reach `delivered` only with a complete QC map AND
/// at least one delivery photo. [ready] means the gate is satisfied; the other
/// values say precisely why it is blocked, so the UI can explain it.
enum DeliveryGate {
  /// QC complete and at least one delivery photo — delivery is allowed.
  ready,

  /// No QC checklist has been recorded yet.
  qcMissing,

  /// A QC checklist exists but not every check has passed.
  qcIncomplete,

  /// QC is complete but no delivery photo has been captured.
  noDeliveryPhoto,
}

/// Evaluates the delivery gate for [job]. Pure (no Firebase), so the rule is
/// exhaustively unit-testable and identical on every call site.
DeliveryGate deliveryGateResult(Job job) {
  final qc = job.qc;
  if (qc == null) return DeliveryGate.qcMissing;
  if (!qc.isComplete) return DeliveryGate.qcIncomplete;
  if (job.deliveryPhotos.isEmpty) return DeliveryGate.noDeliveryPhoto;
  return DeliveryGate.ready;
}

/// Ergonomic access to the gate result on a [Job]. Defined as an extension so
/// `domain/entities/job.dart` need not import this file (no import cycle).
extension JobDelivery on Job {
  /// Whether this job satisfies the delivery gate (see [deliveryGateResult]).
  bool get canDeliver => deliveryGateResult(this) == DeliveryGate.ready;
}
