import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:service_centre_app/core/errors/failure.dart';
import 'package:service_centre_app/features/jobs/data/repositories/firestore_jobs_repository.dart';
import 'package:service_centre_app/features/jobs/domain/entities/job_part.dart';

class _MockFirestore extends Mock implements FirebaseFirestore {}

void main() {
  final due = DateTime.utc(2026, 6, 25, 10);

  group('FirestoreJobsRepository.addPartUsed', () {
    late FakeFirebaseFirestore firestore;
    late FirestoreJobsRepository repo;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repo = FirestoreJobsRepository(firestore: firestore);
    });

    Future<String> newJob() async {
      final created = await repo.createJob(
        jobNo: 'J-1',
        customerId: 'c1',
        branchId: 'b1',
        fault: 'f',
        workRequested: 'w',
        tatTargetHrs: 24,
        dueAt: due,
        createdBy: 'u1',
      );
      return created.valueOrNull!.id;
    }

    test('appends a part line and logs a job.partUsed activity', () async {
      final id = await newJob();

      final result = await repo.addPartUsed(
        id,
        const JobPart(partId: 'p1', qty: 2, ref: 'BATT'),
        'u1',
      );

      expect(result.isOk, isTrue);
      final job = (await repo.getJob(id)).valueOrNull!;
      expect(job.partsUsed, hasLength(1));
      expect(
        job.partsUsed.single,
        const JobPart(partId: 'p1', qty: 2, ref: 'BATT'),
      );

      final raw = await firestore.collection('jobs').doc(id).get();
      expect(raw.data()!['partsUsed'] as List, hasLength(1));

      final log = await firestore.collection('activityLog').get();
      expect(
        log.docs.any((d) => d.data()['action'] == 'job.partUsed'),
        isTrue,
      );
    });

    test('accumulates identical lines (no arrayUnion dedup)', () async {
      final id = await newJob();

      await repo.addPartUsed(
        id,
        const JobPart(partId: 'p1', qty: 1, ref: 'BATT'),
        'u1',
      );
      await repo.addPartUsed(
        id,
        const JobPart(partId: 'p1', qty: 1, ref: 'BATT'),
        'u1',
      );

      final job = (await repo.getJob(id)).valueOrNull!;
      expect(job.partsUsed, hasLength(2));
    });

    test('preserves earlier lines when a different part is added', () async {
      final id = await newJob();

      await repo.addPartUsed(
        id,
        const JobPart(partId: 'p1', qty: 1, ref: 'BATT'),
        'u1',
      );
      await repo.addPartUsed(
        id,
        const JobPart(partId: 'p2', qty: 3, ref: 'GASKET'),
        'u1',
      );

      final job = (await repo.getJob(id)).valueOrNull!;
      expect(job.partsUsed.map((p) => p.partId).toList(), ['p1', 'p2']);
      expect(job.partsUsed.last.qty, 3);
    });

    test('returns NotFoundFailure for a missing job', () async {
      final result = await repo.addPartUsed(
        'ghost',
        const JobPart(partId: 'p1', qty: 1, ref: 'X'),
        'u1',
      );

      expect(result.isErr, isTrue);
      expect(result.failureOrNull, isA<NotFoundFailure>());
    });

    test('maps an unexpected error to UnexpectedFailure', () async {
      final mock = _MockFirestore();
      final mockRepo = FirestoreJobsRepository(firestore: mock);
      when(() => mock.collection('jobs')).thenThrow(Exception('boom'));

      final result = await mockRepo.addPartUsed(
        'j1',
        const JobPart(partId: 'p1', qty: 1, ref: 'X'),
        'u1',
      );

      expect(result.failureOrNull, isA<UnexpectedFailure>());
    });
  });
}
