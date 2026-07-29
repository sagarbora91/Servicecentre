import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:service_centre_app/core/errors/failure.dart';
import 'package:service_centre_app/features/jobs/data/repositories/firestore_jobs_repository.dart';
import 'package:service_centre_app/features/jobs/domain/entities/job_photo_kind.dart';

class _MockFirestore extends Mock implements FirebaseFirestore {}

void main() {
  final due = DateTime.utc(2026, 6, 25, 10);

  group('FirestoreJobsRepository.addPhoto', () {
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

    test('appends a delivery photo (satisfies the delivery gate field)',
        () async {
      final id = await newJob();

      final result =
          await repo.addPhoto(id, JobPhotoKind.delivery, 'd1.jpg', 'u1');

      expect(result.isOk, isTrue);
      final job = (await repo.getJob(id)).valueOrNull!;
      expect(job.deliveryPhotos, ['d1.jpg']);
      expect(job.intakePhotos, isEmpty);
    });

    test('appends an intake photo to the intake set', () async {
      final id = await newJob();

      await repo.addPhoto(id, JobPhotoKind.intake, 'i1.jpg', 'u1');
      await repo.addPhoto(id, JobPhotoKind.intake, 'i2.jpg', 'u1');

      final job = (await repo.getJob(id)).valueOrNull!;
      expect(job.intakePhotos, ['i1.jpg', 'i2.jpg']);
      expect(job.deliveryPhotos, isEmpty);
    });

    test('logs a job.photo activity', () async {
      final id = await newJob();

      await repo.addPhoto(id, JobPhotoKind.delivery, 'd1.jpg', 'u1');

      final log = await firestore.collection('activityLog').get();
      expect(
        log.docs.any((d) => d.data()['action'] == 'job.photo.delivery'),
        isTrue,
      );
    });

    test('returns NotFoundFailure for a missing job', () async {
      final result =
          await repo.addPhoto('ghost', JobPhotoKind.intake, 'x.jpg', 'u1');

      expect(result.failureOrNull, isA<NotFoundFailure>());
    });

    test('maps an unexpected error to UnexpectedFailure', () async {
      final mock = _MockFirestore();
      final mockRepo = FirestoreJobsRepository(firestore: mock);
      when(() => mock.collection('jobs')).thenThrow(Exception('boom'));

      final result =
          await mockRepo.addPhoto('j1', JobPhotoKind.intake, 'x.jpg', 'u1');

      expect(result.failureOrNull, isA<UnexpectedFailure>());
    });
  });
}
