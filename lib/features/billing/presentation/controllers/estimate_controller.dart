import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/providers/staff_providers.dart';
import '../../domain/entities/estimate_line.dart';
import '../../domain/entities/estimate_status.dart';
import '../providers/billing_providers.dart';

/// Orchestrates estimate writes (create, edit lines, send/approve/decline) for
/// the estimate screen. Each method returns `null` on success or the [Failure]
/// for the screen to localize.
class EstimateController extends AutoDisposeAsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  String get _uid => ref.read(currentUserProvider).valueOrNull?.uid ?? '';
  String? get _branchId => ref.read(currentBranchIdProvider);

  Future<Failure?> _run(Future<Result<void>> Function() op) async {
    state = const AsyncValue<void>.loading();
    final result = await op();
    state = const AsyncValue<void>.data(null);
    return result.failureOrNull;
  }

  /// Creates a draft estimate for [jobId] with [lines]. Fails with an
  /// [UnexpectedFailure] if the branch is not yet known.
  Future<Failure?> createDraft({
    required String jobId,
    required List<EstimateLine> lines,
  }) async {
    final branchId = _branchId;
    if (branchId == null) {
      return const UnexpectedFailure('No branch selected');
    }
    state = const AsyncValue<void>.loading();
    final result = await ref.read(estimatesRepositoryProvider).createEstimate(
          jobId: jobId,
          branchId: branchId,
          lines: lines,
          createdBy: _uid,
        );
    state = const AsyncValue<void>.data(null);
    return result.failureOrNull;
  }

  /// Replaces the lines of estimate [id].
  Future<Failure?> updateLines(String id, List<EstimateLine> lines) => _run(
        () => ref.read(estimatesRepositoryProvider).updateLines(id, lines, _uid),
      );

  /// Marks estimate [id] as sent to the customer.
  Future<Failure?> markSent(String id) => _run(
        () => ref
            .read(estimatesRepositoryProvider)
            .setStatus(id, EstimateStatus.sent, _uid),
      );

  /// Records customer approval of estimate [id] (optionally how, via
  /// [approvedVia]).
  Future<Failure?> approve(String id, {String? approvedVia}) => _run(
        () => ref.read(estimatesRepositoryProvider).setStatus(
              id,
              EstimateStatus.approved,
              _uid,
              approvedVia: approvedVia,
            ),
      );

  /// Records that the customer declined estimate [id].
  Future<Failure?> decline(String id) => _run(
        () => ref
            .read(estimatesRepositoryProvider)
            .setStatus(id, EstimateStatus.declined, _uid),
      );
}

/// The estimate-write controller provider.
final estimateControllerProvider =
    AutoDisposeAsyncNotifierProvider<EstimateController, void>(
  EstimateController.new,
);
