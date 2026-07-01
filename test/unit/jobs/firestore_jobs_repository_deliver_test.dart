import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:service_centre_app/core/errors/failure.dart';
import 'package:service_centre_app/features/jobs/data/repositories/firestore_jobs_repository.dart';
import 'package:service_centre_app/features/jobs/domain/entities/job_outcome.dart';
import 'package:service_centre_app/features/jobs/domain/entities/job_qc.dart';
import 'package:service_centre_app/features/jobs/domain/entities/job_status.dart';
import 'package:service_centre_app/features/jobs/domain/entities/warranty_type.dart';

/// A [FirebaseFirestore] whose `collection` throws, to drive the
/// `UnexpectedFailure` branch of the repository's try/catch.
class _ThrowingFirestore extends Mock implements FirebaseFirestore {
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      throw StateError('boom');
}

const _completeQc = <String, dynamic>{
  'timekeeping': true,
  'gasket': true,
  'glassClean': true,
  'strap': true,
  'crown': true,
};

void main() {
  group('FirestoreJobsRepository delivery/QC/move', () {
    late FakeFirebaseFirestore firestore;
    late FirestoreJobsRepository repo;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repo = FirestoreJobsRepository(firestore: firestore);
    });

    Future<void> seedJob({
      required String id,
      String status = 'ready',
      Map<String, dynamic>? qc,
      List<String> deliveryPhotos = const [],
    }) =>
        firestore.collection('jobs').doc(id).set(<String, dynamic>{
          'jobNo': '2606-0001',
          'customerId': 'c1',
          'status': status,
          'fault': 'f',
          'workRequested': 'w',
          'tatTargetHrs': 24,
          'dueAt': Timestamp.fromDate(DateTime.utc(2030)),
          'paymentStatus': 'unbilled',
          'isRework': false,
          'branchId': 'b1',
          if (qc != null) 'qc': qc,
          'deliveryPhotos': deliveryPhotos,
        });

    Future<Map<String, dynamic>?> readJob(String id) async =>
        (await firestore.collection('jobs').doc(id).get()).data();

    Future<int> activityLogCount() async =>
        (await firestore.collection('activityLog').get()).docs.length;

    group('deliver', () {
      test('delivers when QC is complete and a photo exists, logging it',
          () async {
        await seedJob(id: 'j1', qc: _completeQc, deliveryPhotos: ['p.jpg']);

        final result = await repo.deliver('j1', by: 'u1');

        expect(result.isOk, isTrue);
        final job = await readJob('j1');
        expect(job!['status'], 'delivered');
        expect(await activityLogCount(), 1);
      });

      test('records outcome and warranty type when given', () async {
        await seedJob(id: 'j1', qc: _completeQc, deliveryPhotos: ['p.jpg']);

        final result = await repo.deliver(
          'j1',
          by: 'u1',
          outcome: JobOutcome.repaired,
          warrantyType: WarrantyType.paid,
        );

        expect(result.isOk, isTrue);
        final job = await readJob('j1');
        expect(job!['outcome'], 'repaired');
        expect(job['warrantyType'], 'paid');
      });

      test('rejects when QC is incomplete, writing nothing', () async {
        await seedJob(
          id: 'j1',
          qc: <String, dynamic>{..._completeQc, 'crown': false},
          deliveryPhotos: ['p.jpg'],
        );

        final result = await repo.deliver('j1', by: 'u1');

        expect(result.isErr, isTrue);
        final failure = result.failureOrNull;
        expect(failure, isA<ValidationFailure>());
        expect(
          (failure! as ValidationFailure).reason,
          ValidationReason.deliveryQcIncomplete,
        );
        expect((await readJob('j1'))!['status'], 'ready');
        expect(await activityLogCount(), 0);
      });

      test('rejects when there is no delivery photo', () async {
        await seedJob(id: 'j1', qc: _completeQc);

        final result = await repo.deliver('j1', by: 'u1');

        expect(result.isErr, isTrue);
        expect(
          (result.failureOrNull! as ValidationFailure).reason,
          ValidationReason.deliveryNoPhoto,
        );
      });

      test('rejects when QC is missing entirely', () async {
        await seedJob(id: 'j1', deliveryPhotos: ['p.jpg']);

        final result = await repo.deliver('j1', by: 'u1');

        expect(
          (result.failureOrNull! as ValidationFailure).reason,
          ValidationReason.deliveryQcIncomplete,
        );
      });

      test('returns NotFoundFailure for a missing job', () async {
        final result = await repo.deliver('ghost', by: 'u1');
        expect(result.failureOrNull, isA<NotFoundFailure>());
      });

      test('maps an unexpected error to UnexpectedFailure', () async {
        final throwing =
            FirestoreJobsRepository(firestore: _ThrowingFirestore());
        final result = await throwing.deliver('j1', by: 'u1');
        expect(result.failureOrNull, isA<UnexpectedFailure>());
      });
    });

    group('moveStatus delivery gate', () {
      test('moving to delivered enforces the gate', () async {
        await seedJob(id: 'j1', deliveryPhotos: ['p.jpg']); // no QC

        final result = await repo.moveStatus('j1', JobStatus.delivered, 'u1');

        expect(result.failureOrNull, isA<ValidationFailure>());
        expect((await readJob('j1'))!['status'], 'ready');
      });

      test('moving to a non-delivered status skips the gate and logs',
          () async {
        await seedJob(id: 'j1', status: 'received');

        final result = await repo.moveStatus('j1', JobStatus.inRepair, 'u1');

        expect(result.isOk, isTrue);
        expect((await readJob('j1'))!['status'], 'in_repair');
        expect(await activityLogCount(), 1);
      });

      test('moving to delivered succeeds when the gate is satisfied', () async {
        await seedJob(id: 'j1', qc: _completeQc, deliveryPhotos: ['p.jpg']);

        final result = await repo.moveStatus('j1', JobStatus.delivered, 'u1');

        expect(result.isOk, isTrue);
        expect((await readJob('j1'))!['status'], 'delivered');
      });
    });

    group('updateQc', () {
      test('writes the QC map and logs the change', () async {
        await seedJob(id: 'j1');

        final result = await repo.updateQc(
          'j1',
          const JobQc(
            timekeeping: true,
            gasket: true,
            glassClean: true,
            strap: true,
            crown: true,
          ),
          'u1',
        );

        expect(result.isOk, isTrue);
        final job = await readJob('j1');
        expect((job!['qc'] as Map)['crown'], true);
        expect(await activityLogCount(), 1);
      });

      test('returns NotFoundFailure for a missing job', () async {
        final result = await repo.updateQc(
          'ghost',
          const JobQc(
            timekeeping: true,
            gasket: true,
            glassClean: true,
            strap: true,
            crown: true,
          ),
          'u1',
        );
        expect(result.failureOrNull, isA<NotFoundFailure>());
      });
    });

    group('watchJob', () {
      test('emits the job, then null once deleted', () async {
        await seedJob(id: 'j1');

        final first = await repo.watchJob('j1').first;
        expect(first, isNotNull);
        expect(first!.id, 'j1');

        await firestore.collection('jobs').doc('j1').delete();
        final afterDelete = await repo.watchJob('j1').first;
        expect(afterDelete, isNull);
      });
    });
  });
}
