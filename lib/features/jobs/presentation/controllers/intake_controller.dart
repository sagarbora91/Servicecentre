import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/providers/staff_providers.dart';
import '../../domain/entities/job.dart';
import '../providers/jobs_providers.dart';

/// Orchestrates new-job intake: allocates a job number then creates the job in
/// the signed-in user's branch. Holds the in-flight state; returns a [Result]
/// the screen maps to navigation or a localized error.
class IntakeController extends AutoDisposeAsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  /// Creates a job. Returns the created [Job] on success, or an [Err] whose
  /// [Failure] the screen localizes. `dueAt` is derived as now + [tatTargetHrs].
  Future<Result<Job>> create({
    required String customerId,
    required String fault,
    required String workRequested,
    required int tatTargetHrs,
    String? watchId,
  }) async {
    final branchId = ref.read(currentBranchIdProvider);
    if (branchId == null) {
      return const Err(UnexpectedFailure('No branch configured'));
    }
    final by = ref.read(currentUserProvider).valueOrNull?.uid ?? '';

    state = const AsyncValue<void>.loading();
    final alloc = await ref.read(jobNoAllocatorProvider).nextJobNo(branchId);
    final jobNo = alloc.valueOrNull;
    if (jobNo == null) {
      state = const AsyncValue<void>.data(null);
      return Err(alloc.failureOrNull ?? const UnexpectedFailure('No jobNo'));
    }
    final now = DateTime.now().toUtc();
    final result = await ref.read(jobsRepositoryProvider).createJob(
          jobNo: jobNo,
          customerId: customerId,
          branchId: branchId,
          fault: fault,
          workRequested: workRequested,
          tatTargetHrs: tatTargetHrs,
          dueAt: now.add(Duration(hours: tatTargetHrs)),
          createdBy: by,
          watchId: watchId,
        );
    state = const AsyncValue<void>.data(null);
    return result;
  }
}

/// The intake controller provider.
final intakeControllerProvider =
    AutoDisposeAsyncNotifierProvider<IntakeController, void>(
  IntakeController.new,
);
