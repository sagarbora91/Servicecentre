import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:service_centre_app/core/errors/failure.dart';
import 'package:service_centre_app/features/billing/data/repositories/firestore_estimates_repository.dart';
import 'package:service_centre_app/features/billing/domain/entities/estimate_line.dart';
import 'package:service_centre_app/features/billing/domain/entities/estimate_status.dart';

class _MockFirestore extends Mock implements FirebaseFirestore {}

void main() {
  group('FirestoreEstimatesRepository', () {
    late FakeFirebaseFirestore firestore;
    late FirestoreEstimatesRepository repo;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repo = FirestoreEstimatesRepository(firestore: firestore);
    });

    Future<String> newEstimate({
      List<EstimateLine> lines = const [
        EstimateLine(desc: 'Service', amountPaise: 150000),
        EstimateLine(desc: 'Battery', amountPaise: 25000),
      ],
    }) async {
      final created = await repo.createEstimate(
        jobId: 'j1',
        branchId: 'b1',
        lines: lines,
        createdBy: 'u1',
      );
      return created.valueOrNull!.id;
    }

    test('createEstimate stores a draft with the computed total', () async {
      final created = await repo.createEstimate(
        jobId: 'j1',
        branchId: 'b1',
        lines: const [
          EstimateLine(desc: 'Service', amountPaise: 150000),
          EstimateLine(desc: 'Battery', amountPaise: 25000),
        ],
        createdBy: 'u1',
      );

      final estimate = created.valueOrNull!;
      expect(estimate.status, EstimateStatus.draft);
      expect(estimate.totalPaise, 175000);
      expect(estimate.lines, hasLength(2));
      expect(estimate.jobId, 'j1');
    });

    test('createEstimate logs an activity', () async {
      await newEstimate();

      final log = await firestore.collection('activityLog').get();
      expect(
        log.docs.any((d) => d.data()['action'] == 'estimate.create'),
        isTrue,
      );
    });

    test('watchEstimatesForJob emits the job estimates', () async {
      await newEstimate();

      final list = await repo.watchEstimatesForJob('j1').first;
      expect(list, hasLength(1));
      expect(list.first.jobId, 'j1');
    });

    test('updateLines replaces the lines and recomputes the total', () async {
      final id = await newEstimate();

      final result = await repo.updateLines(
        id,
        const [EstimateLine(desc: 'Full overhaul', amountPaise: 500000)],
        'u1',
      );

      expect(result.isOk, isTrue);
      final list = await repo.watchEstimatesForJob('j1').first;
      expect(list.first.totalPaise, 500000);
      expect(list.first.lines, hasLength(1));
    });

    test('updateLines on a missing estimate returns NotFoundFailure', () async {
      final result = await repo.updateLines('ghost', const [], 'u1');
      expect(result.failureOrNull, isA<NotFoundFailure>());
    });

    test('setStatus to approved stamps approvedAt and approvedVia', () async {
      final id = await newEstimate();

      final result = await repo.setStatus(
        id,
        EstimateStatus.approved,
        'u1',
        approvedVia: 'in person',
      );

      expect(result.isOk, isTrue);
      final estimate = (await repo.watchEstimatesForJob('j1').first).first;
      expect(estimate.status, EstimateStatus.approved);
      expect(estimate.approvedAt, isNotNull);
      expect(estimate.approvedVia, 'in person');
    });

    test('setStatus to sent does not stamp approvedAt', () async {
      final id = await newEstimate();

      await repo.setStatus(id, EstimateStatus.sent, 'u1');

      final estimate = (await repo.watchEstimatesForJob('j1').first).first;
      expect(estimate.status, EstimateStatus.sent);
      expect(estimate.approvedAt, isNull);
    });

    test('setStatus on a missing estimate returns NotFoundFailure', () async {
      final result = await repo.setStatus('ghost', EstimateStatus.sent, 'u1');
      expect(result.failureOrNull, isA<NotFoundFailure>());
    });

    test('maps an unexpected error to UnexpectedFailure', () async {
      final mock = _MockFirestore();
      final mockRepo = FirestoreEstimatesRepository(firestore: mock);
      when(() => mock.collection('estimates')).thenThrow(Exception('boom'));

      final result = await mockRepo.createEstimate(
        jobId: 'j1',
        branchId: 'b1',
        lines: const [],
        createdBy: 'u1',
      );

      expect(result.failureOrNull, isA<UnexpectedFailure>());
    });
  });
}
