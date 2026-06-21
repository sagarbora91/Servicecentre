import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../data/repositories/firestore_job_no_allocator.dart';
import '../../data/repositories/firestore_jobs_repository.dart';
import '../../domain/entities/job.dart';
import '../../domain/repositories/job_no_allocator.dart';
import '../../domain/repositories/jobs_repository.dart';

/// The app's [JobsRepository]. Override this (or the Firebase providers in
/// `core/firebase/firebase_providers.dart`) in tests.
final jobsRepositoryProvider = Provider<JobsRepository>(
  (ref) => FirestoreJobsRepository(
    firestore: ref.watch(firestoreProvider),
  ),
);

/// Streams the Kanban board (jobs ordered by status then due date) for the
/// given `branchId`.
final boardProvider = StreamProvider.family<List<Job>, String>(
  (ref, branchId) => ref.watch(jobsRepositoryProvider).watchBoard(branchId),
);

/// Streams a customer's service history (their jobs, newest first) for the
/// given `customerId`.
final customerJobsProvider = StreamProvider.family<List<Job>, String>(
  (ref, customerId) =>
      ref.watch(jobsRepositoryProvider).watchJobsForCustomer(customerId),
);

/// Streams a single job by id (or `null` when missing). Backs the job-detail
/// screen; `autoDispose` so it is dropped when detail leaves the tree.
final jobByIdProvider = StreamProvider.autoDispose.family<Job?, String>(
  (ref, id) => ref.watch(jobsRepositoryProvider).watchJob(id),
);

/// The app's [JobNoAllocator] (transactional `YYMM-NNNN` per-branch counter).
final jobNoAllocatorProvider = Provider<JobNoAllocator>(
  (ref) => FirestoreJobNoAllocator(firestore: ref.watch(firestoreProvider)),
);
