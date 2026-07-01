import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/repositories/firestore_estimates_repository.dart';
import '../../data/repositories/firestore_invoice_number_allocator.dart';
import '../../data/repositories/firestore_invoices_repository.dart';
import '../../domain/entities/estimate.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/repositories/estimates_repository.dart';
import '../../domain/repositories/invoice_number_allocator.dart';
import '../../domain/repositories/invoices_repository.dart';

/// The app's [EstimatesRepository]. Override this (or the Firebase providers in
/// `core/firebase/firebase_providers.dart`) in tests.
final estimatesRepositoryProvider = Provider<EstimatesRepository>(
  (ref) => FirestoreEstimatesRepository(
    firestore: ref.watch(firestoreProvider),
  ),
);

/// Streams the estimates for [jobId] (newest first). `autoDispose` so it is
/// dropped when the estimate screen leaves the tree.
final estimatesForJobProvider =
    StreamProvider.autoDispose.family<List<Estimate>, String>(
  (ref, jobId) =>
      ref.watch(estimatesRepositoryProvider).watchEstimatesForJob(jobId),
);

/// Whether the current user may prepare/progress customer quotes (estimates).
/// Mirrors `canQuote()` in `firestore.rules`.
final canQuoteProvider = Provider<bool>(
  (ref) => ref.watch(currentUserProvider).valueOrNull?.role.canQuote ?? false,
);

/// Whether the current user may view/edit finance (invoices, payments).
/// Mirrors `canFinance()` in `firestore.rules`.
final canFinanceProvider = Provider<bool>(
  (ref) => ref.watch(currentUserProvider).valueOrNull?.role.canFinance ?? false,
);

/// The app's [InvoiceNumberAllocator] (transactional `INV-YYMM-NNNN` counter).
final invoiceNumberAllocatorProvider = Provider<InvoiceNumberAllocator>(
  (ref) => FirestoreInvoiceNumberAllocator(
    firestore: ref.watch(firestoreProvider),
  ),
);

/// The app's [InvoicesRepository].
final invoicesRepositoryProvider = Provider<InvoicesRepository>(
  (ref) => FirestoreInvoicesRepository(
    firestore: ref.watch(firestoreProvider),
    numberAllocator: ref.watch(invoiceNumberAllocatorProvider),
  ),
);

/// Streams the invoices for [jobId] (newest first). `autoDispose` so it drops
/// when the invoice screen leaves the tree.
final invoicesForJobProvider =
    StreamProvider.autoDispose.family<List<Invoice>, String>(
  (ref, jobId) =>
      ref.watch(invoicesRepositoryProvider).watchInvoicesForJob(jobId),
);
