import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/providers/staff_providers.dart';
import '../../domain/entities/invoice_line.dart';
import '../../domain/entities/payment_mode.dart';
import '../providers/billing_providers.dart';

/// Orchestrates invoice creation for the invoice screen. Returns `null` on
/// success or the [Failure] for the screen to localize.
class InvoiceController extends AutoDisposeAsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  String get _uid => ref.read(currentUserProvider).valueOrNull?.uid ?? '';

  /// Raises an invoice for [jobId] from [lines]. GST totals and the invoice
  /// number are computed/allocated in the repository. Fails with an
  /// [UnexpectedFailure] if the branch or lines are missing.
  Future<Failure?> createInvoice({
    required String jobId,
    required List<InvoiceLine> lines,
  }) async {
    final branchId = ref.read(currentBranchIdProvider);
    if (branchId == null) {
      return const UnexpectedFailure('No branch selected');
    }
    if (lines.isEmpty) {
      return const UnexpectedFailure('An invoice needs at least one line');
    }
    state = const AsyncValue<void>.loading();
    final result = await ref.read(invoicesRepositoryProvider).createInvoice(
          jobId: jobId,
          branchId: branchId,
          lines: lines,
          createdBy: _uid,
        );
    state = const AsyncValue<void>.data(null);
    return result.failureOrNull;
  }

  /// Records a payment of [amountPaise] against [invoiceId] (transactional in
  /// the repository; over-collection is rejected there).
  Future<Failure?> recordPayment({
    required String invoiceId,
    required int amountPaise,
    required PaymentMode mode,
    String? ref,
  }) async {
    final branchId = this.ref.read(currentBranchIdProvider);
    if (branchId == null) {
      return const UnexpectedFailure('No branch selected');
    }
    state = const AsyncValue<void>.loading();
    final result =
        await this.ref.read(paymentsRepositoryProvider).recordPayment(
              invoiceId: invoiceId,
              branchId: branchId,
              amountPaise: amountPaise,
              mode: mode,
              by: _uid,
              ref: ref,
            );
    state = const AsyncValue<void>.data(null);
    return result.failureOrNull;
  }
}

/// The invoice-write controller provider.
final invoiceControllerProvider =
    AutoDisposeAsyncNotifierProvider<InvoiceController, void>(
  InvoiceController.new,
);
