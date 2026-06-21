import '../../../../core/errors/result.dart';

/// Allocates unique, human-readable job numbers.
///
/// Lives in `domain` (no Firebase imports); the `data` implementation backs it
/// with a transactional counter. The scheme is a ratified owner decision
/// (see HANDOFF / m3-decisions): `YYMM-NNNN`, sequential **per branch, reset
/// monthly** (e.g. `2606-0001`). Isolated behind this port so the format/counter
/// strategy can change without touching intake.
// ignore: one_member_abstracts
// Intentional repository-style port: a DI seam with a Firestore impl and a
// test fake, wired via Riverpod like the other repositories. The single method
// is by design, so the pedantic one-member-abstract hint does not apply.
abstract interface class JobNoAllocator {
  /// Returns the next job number for [branchId]. [now] defaults to the current
  /// time (injectable for tests); its year+month choose the monthly sequence.
  Future<Result<String>> nextJobNo(String branchId, {DateTime? now});
}
