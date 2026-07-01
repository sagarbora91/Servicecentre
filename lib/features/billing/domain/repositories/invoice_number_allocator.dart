// Single-method repository PORT (a DI seam with a Firestore implementation and
// a test fake), like JobNoAllocator. The one method is by design; disable the
// pedantic one-member-abstract hint for this file.
// ignore_for_file: one_member_abstracts
import '../../../../core/errors/result.dart';

/// Allocates unique, human-readable invoice numbers.
///
/// Lives in `domain` (no Firebase imports); the `data` implementation backs it
/// with a transactional counter, mirroring [JobNoAllocator]. The scheme is
/// `INV-YYMM-NNNN`, sequential **per branch, reset monthly** (e.g.
/// `INV-2607-0001`) — a documented default to confirm with the owner.
abstract interface class InvoiceNumberAllocator {
  /// Returns the next invoice number for [branchId]. [now] defaults to the
  /// current time (injectable for tests); its year+month choose the monthly
  /// sequence.
  Future<Result<String>> nextInvoiceNumber(String branchId, {DateTime? now});
}
