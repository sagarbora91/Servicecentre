// This file defines a single-method repository PORT: a DI seam with a Firestore
// implementation and a test fake, wired via Riverpod like the other
// repositories. The single method is by design, so disable the pedantic
// one-member-abstract hint for this file (it does not fit the port idiom).
// ignore_for_file: one_member_abstracts
import '../../../../core/errors/result.dart';

/// Allocates unique, human-readable job numbers.
///
/// Lives in `domain` (no Firebase imports); the `data` implementation backs it
/// with a transactional counter. The scheme is a ratified owner decision
/// (see HANDOFF / m3-decisions): `YYMM-NNNN`, sequential **per branch, reset
/// monthly** (e.g. `2606-0001`). Isolated behind this port so the format/counter
/// strategy can change without touching intake.
abstract interface class JobNoAllocator {
  /// Returns the next job number for [branchId]. [now] defaults to the current
  /// time (injectable for tests); its year+month choose the monthly sequence.
  Future<Result<String>> nextJobNo(String branchId, {DateTime? now});
}
