import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/job_qc.dart';
import '../../domain/entities/job_status.dart';
import '../providers/jobs_providers.dart';

/// Orchestrates job-detail writes (status moves, QC edits, delivery). Holds the
/// in-flight state; each method returns `null` on success or the [Failure] for
/// the screen to localize.
class JobDetailController extends AutoDisposeAsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  String get _uid => ref.read(currentUserProvider).valueOrNull?.uid ?? '';

  /// Moves [id] to [to] (the repository enforces the delivery gate).
  Future<Failure?> move(String id, JobStatus to) async {
    state = const AsyncValue<void>.loading();
    final result =
        await ref.read(jobsRepositoryProvider).moveStatus(id, to, _uid);
    state = const AsyncValue<void>.data(null);
    return result.failureOrNull;
  }

  /// Saves the QC checklist on [id].
  Future<Failure?> updateQc(String id, JobQc qc) async {
    state = const AsyncValue<void>.loading();
    final result = await ref.read(jobsRepositoryProvider).updateQc(id, qc, _uid);
    state = const AsyncValue<void>.data(null);
    return result.failureOrNull;
  }

  /// Delivers [id] (gated on complete QC + a delivery photo).
  Future<Failure?> deliver(String id) async {
    state = const AsyncValue<void>.loading();
    final result = await ref.read(jobsRepositoryProvider).deliver(id, by: _uid);
    state = const AsyncValue<void>.data(null);
    return result.failureOrNull;
  }
}

/// The job-detail controller provider.
final jobDetailControllerProvider =
    AutoDisposeAsyncNotifierProvider<JobDetailController, void>(
  JobDetailController.new,
);
