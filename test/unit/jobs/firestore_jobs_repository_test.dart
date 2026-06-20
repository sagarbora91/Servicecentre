import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:service_centre_app/core/errors/failure.dart';
import 'package:service_centre_app/features/jobs/data/repositories/firestore_jobs_repository.dart';
import 'package:service_centre_app/features/jobs/domain/entities/job_outcome.dart';
import 'package:service_centre_app/features/jobs/domain/entities/job_part.dart';
import 'package:service_centre_app/features/jobs/domain/entities/job_status.dart';
import 'package:service_centre_app/features/jobs/domain/entities/payment_status.dart';
import 'package:service_centre_app/features/jobs/domain/entities/warranty_type.dart';

class _MockFirestore extends Mock implements FirebaseFirestore {}

class _MockCollection extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class _MockDoc extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

/// A full `jobs/{id}` document exercising every field the repository maps,
/// including nested `qc`, `partsUsed`, and `statusHistory`.
Map<String, dynamic> _fullDoc({
  required DateTime due,
  required DateTime at,
}) =>
    <String, dynamic>{
      'jobNo': 'J-001',
      'customerId': 'c1',
      'watchId': 'w1',
      'sourceStore': 'store-2',
      'status': 'in_repair',
      'fault': 'not running',
      'workRequested': 'full service',
      'assignedTo': 'tech1',
      'tatTargetHrs': 48,
      'dueAt': Timestamp.fromDate(due),
      'intakePhotos': ['a.jpg', 'b.jpg'],
      'deliveryPhotos': ['d.jpg'],
      'qc': <String, dynamic>{
        'timekeeping': true,
        'gasket': true,
        'glassClean': true,
        'strap': true,
        'crown': true,
      },
      'partsUsed': [
        <String, dynamic>{'partId': 'p1', 'qty': 1, 'ref': 'BATT'},
        <String, dynamic>{'partId': 'p2', 'qty': 2, 'ref': 'GASKET'},
      ],
      'outcome': 'repaired',
      'warrantyType': 'paid',
      'isRework': true,
      'parentJobId': 'j0',
      'amountPaise': 125000,
      'paymentStatus': 'partial',
      'statusHistory': [
        <String, dynamic>{
          'status': 'received',
          'at': Timestamp.fromDate(at),
          'by': 'u1',
        },
        <String, dynamic>{
          'status': 'in_repair',
          'at': Timestamp.fromDate(at.add(const Duration(hours: 1))),
          'by': 'tech1',
        },
      ],
      'branchId': 'b1',
      'createdAt': Timestamp.fromDate(at),
      'createdBy': 'u1',
      'updatedAt': Timestamp.fromDate(at),
    };

void main() {
  final due = DateTime.utc(2026, 6, 25, 10);
  final at = DateTime.utc(2026, 6, 20, 9, 30);

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  group('FirestoreJobsRepository (fake_cloud_firestore)', () {
    late FakeFirebaseFirestore firestore;
    late FirestoreJobsRepository repo;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repo = FirestoreJobsRepository(firestore: firestore);
    });

    test('createJob seeds status received and one history entry', () async {
      final result = await repo.createJob(
        jobNo: 'J-001',
        customerId: 'c1',
        branchId: 'b1',
        fault: 'not running',
        workRequested: 'service',
        tatTargetHrs: 48,
        dueAt: due,
        createdBy: 'u1',
        watchId: 'w1',
        intakePhotos: const ['a.jpg'],
      );

      expect(result.isOk, isTrue);
      final job = result.valueOrNull!;
      expect(job.id, isNotEmpty);
      expect(job.status, JobStatus.received);
      expect(job.paymentStatus, PaymentStatus.unbilled);
      expect(job.jobNo, 'J-001');
      expect(job.watchId, 'w1');
      expect(job.intakePhotos, ['a.jpg']);
      expect(job.createdBy, 'u1');
      // serverTimestamp() resolves to a concrete value on read-back.
      expect(job.createdAt, isNotNull);
      expect(job.updatedAt, isNotNull);
      expect(job.statusHistory, hasLength(1));
      expect(job.statusHistory.single.status, JobStatus.received);
      expect(job.statusHistory.single.by, 'u1');

      // The document is actually persisted with wire-encoded enums.
      final stored = await firestore.collection('jobs').doc(job.id).get();
      expect(stored.exists, isTrue);
      expect(stored.data()!['status'], 'received');
      expect(stored.data()!['paymentStatus'], 'unbilled');
    });

    test('createJob omits unset optional fields', () async {
      final result = await repo.createJob(
        jobNo: 'J-002',
        customerId: 'c2',
        branchId: 'b1',
        fault: 'f',
        workRequested: 'w',
        tatTargetHrs: 24,
        dueAt: due,
        createdBy: 'u1',
      );

      final job = result.valueOrNull!;
      expect(job.watchId, isNull);
      expect(job.sourceStore, isNull);
      expect(job.assignedTo, isNull);
      expect(job.parentJobId, isNull);
      expect(job.isRework, isFalse);

      final raw = await firestore.collection('jobs').doc(job.id).get();
      expect(raw.data()!.containsKey('watchId'), isFalse);
      expect(raw.data()!.containsKey('sourceStore'), isFalse);
      expect(raw.data()!.containsKey('assignedTo'), isFalse);
      expect(raw.data()!.containsKey('parentJobId'), isFalse);
      // qc/outcome/warrantyType/amountPaise are never set at creation.
      expect(raw.data()!.containsKey('qc'), isFalse);
      expect(raw.data()!.containsKey('outcome'), isFalse);
      expect(raw.data()!.containsKey('warrantyType'), isFalse);
      expect(raw.data()!.containsKey('amountPaise'), isFalse);
    });

    test('createJob persists all passed-through optional fields', () async {
      final result = await repo.createJob(
        jobNo: 'J-006',
        customerId: 'c6',
        branchId: 'b1',
        fault: 'f',
        workRequested: 'w',
        tatTargetHrs: 12,
        dueAt: due,
        createdBy: 'u1',
        watchId: 'w6',
        sourceStore: 'store-9',
        assignedTo: 'tech9',
        isRework: true,
        parentJobId: 'j-parent',
        intakePhotos: const ['x.jpg', 'y.jpg'],
      );

      final job = result.valueOrNull!;
      expect(job.watchId, 'w6');
      expect(job.sourceStore, 'store-9');
      expect(job.assignedTo, 'tech9');
      expect(job.isRework, isTrue);
      expect(job.parentJobId, 'j-parent');
      expect(job.intakePhotos, ['x.jpg', 'y.jpg']);
      expect(job.dueAt, due);
      expect(job.dueAt.isUtc, isTrue);
    });

    test('getJob maps a full document including nested types', () async {
      await firestore
          .collection('jobs')
          .doc('j1')
          .set(_fullDoc(due: due, at: at));

      final result = await repo.getJob('j1');

      expect(result.isOk, isTrue);
      final job = result.valueOrNull!;
      expect(job.id, 'j1');
      expect(job.jobNo, 'J-001');
      expect(job.customerId, 'c1');
      expect(job.watchId, 'w1');
      expect(job.sourceStore, 'store-2');
      expect(job.status, JobStatus.inRepair);
      expect(job.fault, 'not running');
      expect(job.workRequested, 'full service');
      expect(job.assignedTo, 'tech1');
      expect(job.tatTargetHrs, 48);
      expect(job.dueAt, due);
      expect(job.dueAt.isUtc, isTrue);
      expect(job.intakePhotos, ['a.jpg', 'b.jpg']);
      expect(job.deliveryPhotos, ['d.jpg']);
      expect(job.qc, isNotNull);
      expect(job.qc!.isComplete, isTrue);
      expect(job.partsUsed, hasLength(2));
      expect(
        job.partsUsed.first,
        const JobPart(partId: 'p1', qty: 1, ref: 'BATT'),
      );
      expect(job.outcome, JobOutcome.repaired);
      expect(job.warrantyType, WarrantyType.paid);
      expect(job.isRework, isTrue);
      expect(job.parentJobId, 'j0');
      expect(job.amountPaise, 125000);
      expect(job.paymentStatus, PaymentStatus.partial);
      expect(job.statusHistory, hasLength(2));
      expect(job.statusHistory.last.status, JobStatus.inRepair);
      expect(job.statusHistory.last.by, 'tech1');
      expect(job.statusHistory.last.at, at.add(const Duration(hours: 1)));
      expect(job.branchId, 'b1');
      expect(job.createdAt, at);
      expect(job.createdBy, 'u1');
      expect(job.updatedAt, at);
    });

    test('getJob defaults missing fields and leaves qc/optionals null',
        () async {
      await firestore.collection('jobs').doc('sparse').set(<String, dynamic>{
        'jobNo': 'J-002',
        'customerId': 'c2',
        'branchId': 'b1',
      });

      final result = await repo.getJob('sparse');

      expect(result.isOk, isTrue);
      final job = result.valueOrNull!;
      expect(job.status, JobStatus.received);
      expect(job.paymentStatus, PaymentStatus.unbilled);
      expect(job.fault, '');
      expect(job.workRequested, '');
      expect(job.tatTargetHrs, 0);
      expect(job.isRework, isFalse);
      expect(job.watchId, isNull);
      expect(job.sourceStore, isNull);
      expect(job.assignedTo, isNull);
      expect(job.qc, isNull);
      expect(job.outcome, isNull);
      expect(job.warrantyType, isNull);
      expect(job.parentJobId, isNull);
      expect(job.amountPaise, isNull);
      expect(job.intakePhotos, isEmpty);
      expect(job.deliveryPhotos, isEmpty);
      expect(job.partsUsed, isEmpty);
      expect(job.statusHistory, isEmpty);
      expect(job.createdAt, isNull);
      expect(job.createdBy, isNull);
      expect(job.updatedAt, isNull);
      // dueAt falls back to the Unix epoch when missing.
      expect(job.dueAt, DateTime.fromMillisecondsSinceEpoch(0, isUtc: true));
    });

    test('getJob falls back to received/unbilled on unknown enum strings',
        () async {
      await firestore.collection('jobs').doc('weird').set(<String, dynamic>{
        'jobNo': 'J-003',
        'customerId': 'c3',
        'branchId': 'b1',
        'status': 'lost',
        'paymentStatus': 'refunded',
        'outcome': 'vanished',
        'warrantyType': 'forever',
      });

      final job = (await repo.getJob('weird')).valueOrNull!;

      expect(job.status, JobStatus.received);
      expect(job.paymentStatus, PaymentStatus.unbilled);
      expect(job.outcome, isNull);
      expect(job.warrantyType, isNull);
    });

    test('getJob ignores malformed list/map elements', () async {
      await firestore.collection('jobs').doc('messy').set(<String, dynamic>{
        'jobNo': 'J-004',
        'customerId': 'c4',
        'branchId': 'b1',
        'intakePhotos': ['ok.jpg', 42, null],
        'partsUsed': [
          <String, dynamic>{'partId': 'p1', 'qty': 1, 'ref': 'X'},
          'not-a-map',
        ],
        'statusHistory': 'not-a-list',
        'qc': 'not-a-map',
      });

      final job = (await repo.getJob('messy')).valueOrNull!;

      expect(job.intakePhotos, ['ok.jpg']);
      expect(job.partsUsed, hasLength(1));
      expect(job.partsUsed.single.partId, 'p1');
      expect(job.statusHistory, isEmpty);
      expect(job.qc, isNull);
    });

    test('getJob falls back on a garbled status-history entry', () async {
      await firestore.collection('jobs').doc('badhist').set(<String, dynamic>{
        'jobNo': 'J-007',
        'customerId': 'c7',
        'branchId': 'b1',
        'statusHistory': [
          <String, dynamic>{'status': 'teleported'},
        ],
      });

      final job = (await repo.getJob('badhist')).valueOrNull!;

      expect(job.statusHistory, hasLength(1));
      expect(job.statusHistory.single.status, JobStatus.received);
      expect(
        job.statusHistory.single.at,
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );
      expect(job.statusHistory.single.by, '');
    });

    test('createJob then getJob round-trips the stored job', () async {
      final created = await repo.createJob(
        jobNo: 'J-RT',
        customerId: 'c1',
        branchId: 'b1',
        fault: 'f',
        workRequested: 'w',
        tatTargetHrs: 24,
        dueAt: due,
        createdBy: 'u1',
        watchId: 'w1',
      );
      final id = created.valueOrNull!.id;

      final fetched = (await repo.getJob(id)).valueOrNull!;

      expect(fetched.id, id);
      expect(fetched.jobNo, 'J-RT');
      expect(fetched.status, JobStatus.received);
      expect(fetched.paymentStatus, PaymentStatus.unbilled);
      expect(fetched.watchId, 'w1');
      expect(fetched.dueAt, due);
      expect(fetched.statusHistory.single.by, 'u1');
    });

    test('moveStatus appends to history and updates status', () async {
      final created = await repo.createJob(
        jobNo: 'J-003',
        customerId: 'c3',
        branchId: 'b1',
        fault: 'f',
        workRequested: 'w',
        tatTargetHrs: 24,
        dueAt: due,
        createdBy: 'u1',
      );
      final id = created.valueOrNull!.id;

      final moved = await repo.moveStatus(id, JobStatus.inRepair, 'tech1');
      expect(moved.isOk, isTrue);

      final after = await repo.getJob(id);
      final job = after.valueOrNull!;
      expect(job.status, JobStatus.inRepair);
      expect(job.statusHistory, hasLength(2));
      expect(job.statusHistory.first.status, JobStatus.received);
      expect(job.statusHistory.last.status, JobStatus.inRepair);
      expect(job.statusHistory.last.by, 'tech1');

      // The appended entry is wire-encoded in the stored document.
      final raw = await firestore.collection('jobs').doc(id).get();
      expect(raw.data()!['status'], 'in_repair');
    });

    test('moveStatus twice keeps the full ordered history', () async {
      final created = await repo.createJob(
        jobNo: 'J-004',
        customerId: 'c4',
        branchId: 'b1',
        fault: 'f',
        workRequested: 'w',
        tatTargetHrs: 24,
        dueAt: due,
        createdBy: 'u1',
      );
      final id = created.valueOrNull!.id;

      await repo.moveStatus(id, JobStatus.diagnosed, 'u1');
      await repo.moveStatus(id, JobStatus.inRepair, 'tech1');

      final job = (await repo.getJob(id)).valueOrNull!;
      expect(
        job.statusHistory.map((h) => h.status).toList(),
        [JobStatus.received, JobStatus.diagnosed, JobStatus.inRepair],
      );
      expect(job.status, JobStatus.inRepair);
    });

    test('getJob returns Ok for an existing job', () async {
      final created = await repo.createJob(
        jobNo: 'J-005',
        customerId: 'c5',
        branchId: 'b1',
        fault: 'f',
        workRequested: 'w',
        tatTargetHrs: 24,
        dueAt: due,
        createdBy: 'u1',
      );
      final id = created.valueOrNull!.id;

      final result = await repo.getJob(id);

      expect(result.isOk, isTrue);
      expect(result.valueOrNull!.jobNo, 'J-005');
    });

    test('getJob returns NotFoundFailure for a missing job', () async {
      final result = await repo.getJob('does-not-exist');

      expect(result.isErr, isTrue);
      expect(result.failureOrNull, isA<NotFoundFailure>());
    });

    test('watchBoard filters by branch and orders by status then dueAt',
        () async {
      // Two jobs in branch b1, one in another branch (must be excluded).
      await firestore.collection('jobs').doc('late').set(<String, dynamic>{
        'jobNo': 'L',
        'customerId': 'c1',
        'branchId': 'b1',
        'status': 'received',
        'dueAt': Timestamp.fromDate(DateTime.utc(2026, 6, 26)),
        'paymentStatus': 'unbilled',
        'isRework': false,
      });
      await firestore.collection('jobs').doc('early').set(<String, dynamic>{
        'jobNo': 'E',
        'customerId': 'c1',
        'branchId': 'b1',
        'status': 'received',
        'dueAt': Timestamp.fromDate(DateTime.utc(2026, 6, 24)),
        'paymentStatus': 'unbilled',
        'isRework': false,
      });
      await firestore.collection('jobs').doc('diag').set(<String, dynamic>{
        'jobNo': 'D',
        'customerId': 'c1',
        'branchId': 'b1',
        'status': 'diagnosed',
        'dueAt': Timestamp.fromDate(DateTime.utc(2026, 6, 30)),
        'paymentStatus': 'unbilled',
        'isRework': false,
      });
      await firestore.collection('jobs').doc('other').set(<String, dynamic>{
        'jobNo': 'O',
        'customerId': 'c1',
        'branchId': 'b2',
        'status': 'received',
        'dueAt': Timestamp.fromDate(DateTime.utc(2026, 6, 23)),
        'paymentStatus': 'unbilled',
        'isRework': false,
      });

      final board = await repo.watchBoard('b1').first;

      expect(board.map((j) => j.id), isNot(contains('other')));
      // 'diagnosed' sorts before 'received'; within received, earlier dueAt
      // first.
      expect(board.map((j) => j.jobNo).toList(), ['D', 'E', 'L']);
    });

    test('watchJobsForCustomer returns that customer newest-first', () async {
      await firestore.collection('jobs').doc('j1').set(<String, dynamic>{
        'jobNo': 'J1',
        'customerId': 'cX',
        'branchId': 'b1',
        'status': 'received',
        'dueAt': Timestamp.fromDate(due),
        'paymentStatus': 'unbilled',
        'isRework': false,
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 1, 1)),
      });
      await firestore.collection('jobs').doc('j2').set(<String, dynamic>{
        'jobNo': 'J2',
        'customerId': 'cX',
        'branchId': 'b1',
        'status': 'ready',
        'dueAt': Timestamp.fromDate(due),
        'paymentStatus': 'unbilled',
        'isRework': false,
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 3, 1)),
      });
      await firestore.collection('jobs').doc('j3').set(<String, dynamic>{
        'jobNo': 'J3',
        'customerId': 'other',
        'branchId': 'b1',
        'status': 'received',
        'dueAt': Timestamp.fromDate(due),
        'paymentStatus': 'unbilled',
        'isRework': false,
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 2, 1)),
      });

      final jobs = await repo.watchJobsForCustomer('cX').first;

      expect(jobs.map((j) => j.jobNo).toList(), ['J2', 'J1']);
    });
  });

  group('FirestoreJobsRepository failure mapping (mocked Firestore)', () {
    late _MockFirestore firestore;
    late _MockCollection collection;
    late _MockDoc doc;
    late FirestoreJobsRepository repo;

    setUp(() {
      firestore = _MockFirestore();
      collection = _MockCollection();
      doc = _MockDoc();
      when(() => firestore.collection('jobs')).thenReturn(collection);
      when(() => collection.doc(any())).thenReturn(doc);
      when(() => collection.doc()).thenReturn(doc); // no-arg doc() in createJob
      repo = FirestoreJobsRepository(firestore: firestore);
    });

    test('getJob maps permission-denied to PermissionFailure', () async {
      when(() => doc.get()).thenThrow(
        FirebaseException(plugin: 'firestore', code: 'permission-denied'),
      );

      final result = await repo.getJob('j1');

      expect(result.isErr, isTrue);
      expect(result.failureOrNull, isA<PermissionFailure>());
    });

    test('getJob maps an unexpected error to UnexpectedFailure', () async {
      when(() => doc.get()).thenThrow(Exception('boom'));

      final result = await repo.getJob('j1');

      expect(result.failureOrNull, isA<UnexpectedFailure>());
    });

    test('moveStatus maps permission-denied to PermissionFailure', () async {
      when(() => doc.update(any())).thenThrow(
        FirebaseException(plugin: 'firestore', code: 'permission-denied'),
      );

      final result = await repo.moveStatus('j1', JobStatus.qc, 'u1');

      expect(result.failureOrNull, isA<PermissionFailure>());
    });

    test('moveStatus maps an unexpected error to UnexpectedFailure', () async {
      when(() => doc.update(any())).thenThrow(Exception('boom'));

      final result = await repo.moveStatus('j1', JobStatus.qc, 'u1');

      expect(result.failureOrNull, isA<UnexpectedFailure>());
    });

    test('createJob maps an unexpected error to UnexpectedFailure', () async {
      when(() => doc.set(any())).thenThrow(Exception('boom'));

      final result = await repo.createJob(
        jobNo: 'J-001',
        customerId: 'c1',
        branchId: 'b1',
        fault: 'f',
        workRequested: 'w',
        tatTargetHrs: 24,
        dueAt: due,
        createdBy: 'u1',
      );

      expect(result.failureOrNull, isA<UnexpectedFailure>());
    });
  });
}
