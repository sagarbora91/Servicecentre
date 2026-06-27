import 'dart:typed_data';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_centre_app/core/errors/failure.dart';
import 'package:service_centre_app/core/errors/result.dart';
import 'package:service_centre_app/core/firebase/firebase_providers.dart';
import 'package:service_centre_app/features/auth/domain/entities/app_user.dart';
import 'package:service_centre_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:service_centre_app/features/jobs/data/repositories/firestore_jobs_repository.dart';
import 'package:service_centre_app/features/jobs/domain/entities/job_photo_kind.dart';
import 'package:service_centre_app/features/jobs/domain/repositories/photo_repository.dart';
import 'package:service_centre_app/features/jobs/presentation/controllers/job_detail_controller.dart';
import 'package:service_centre_app/features/jobs/presentation/providers/jobs_providers.dart';

/// A [PhotoRepository] stub returning a fixed result and recording the bytes.
class _FakePhotoRepo implements PhotoRepository {
  _FakePhotoRepo(this._result);

  final Result<String> _result;
  Uint8List? lastBytes;

  @override
  Future<Result<String>> uploadJobPhoto({
    required String jobId,
    required JobPhotoKind kind,
    required Uint8List bytes,
  }) async {
    lastBytes = bytes;
    return _result;
  }
}

void main() {
  late FakeFirebaseFirestore fs;

  setUp(() => fs = FakeFirebaseFirestore());

  Future<String> seedJob() async {
    final created = await FirestoreJobsRepository(firestore: fs).createJob(
      jobNo: 'J1',
      customerId: 'c1',
      branchId: 'b1',
      fault: 'f',
      workRequested: 'w',
      tatTargetHrs: 24,
      dueAt: DateTime.utc(2026),
      createdBy: 'u1',
    );
    return created.valueOrNull!.id;
  }

  ProviderContainer makeContainer(PhotoRepository photo) {
    final container = ProviderContainer(
      overrides: [
        firestoreProvider.overrideWithValue(fs),
        currentUserProvider.overrideWith((_) => Stream<AppUser?>.value(null)),
        photoRepositoryProvider.overrideWithValue(photo),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('addPhoto uploads then records the URL on the job (delivery)', () async {
    final id = await seedJob();
    final photo = _FakePhotoRepo(const Ok('https://x/d.jpg'));
    final container = makeContainer(photo);

    final failure = await container
        .read(jobDetailControllerProvider.notifier)
        .addPhoto(id, JobPhotoKind.delivery, Uint8List.fromList([1, 2, 3]));

    expect(failure, isNull);
    expect(photo.lastBytes, [1, 2, 3]);
    final job = (await fs.collection('jobs').doc(id).get()).data()!;
    expect(job['deliveryPhotos'], ['https://x/d.jpg']);
  });

  test('an upload failure is surfaced and the job is untouched', () async {
    final id = await seedJob();
    final container =
        makeContainer(_FakePhotoRepo(const Err(UnexpectedFailure('boom'))));

    final failure = await container
        .read(jobDetailControllerProvider.notifier)
        .addPhoto(id, JobPhotoKind.intake, Uint8List.fromList([9]));

    expect(failure, isA<UnexpectedFailure>());
    final job = (await fs.collection('jobs').doc(id).get()).data()!;
    expect((job['intakePhotos'] as List?) ?? const [], isEmpty);
  });
}
