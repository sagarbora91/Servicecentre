import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/collections.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/firebase/converters.dart';
import '../../domain/entities/job.dart';
import '../../domain/entities/job_outcome.dart';
import '../../domain/entities/job_part.dart';
import '../../domain/entities/job_qc.dart';
import '../../domain/entities/job_status.dart';
import '../../domain/entities/job_status_change.dart';
import '../../domain/entities/payment_status.dart';
import '../../domain/entities/warranty_type.dart';
import '../../domain/repositories/jobs_repository.dart';

/// [JobsRepository] backed by Cloud Firestore.
///
/// Maps Firestore documents to/from the [Job] domain model via the private
/// `_jobFromDoc`/`_jobToDoc` helpers (Timestamp <-> UTC DateTime via
/// [FirestoreConvert], keeping `domain` Firebase-free) and wraps every one-shot
/// read/write in `try/catch`, returning a [Result] so failures never throw
/// across layers. Streams surface Firestore errors to their listeners as usual.
class FirestoreJobsRepository implements JobsRepository {
  /// Creates the repository with an injected [FirebaseFirestore] so tests can
  /// pass a fake.
  FirestoreJobsRepository({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _jobs =>
      _firestore.collection(Collections.jobs);

  @override
  Stream<List<Job>> watchBoard(String branchId) => _jobs
      .where('branchId', isEqualTo: branchId)
      .orderBy('status')
      .orderBy('dueAt')
      .snapshots()
      .map(_toJobList);

  @override
  Stream<List<Job>> watchJobsForCustomer(String customerId) => _jobs
      .where('customerId', isEqualTo: customerId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map(_toJobList);

  @override
  Future<Result<Job>> getJob(String id) async {
    try {
      final snap = await _jobs.doc(id).get();
      final data = snap.data();
      if (!snap.exists || data == null) {
        return Err(NotFoundFailure('Job $id not found'));
      }
      return Ok(_fromDoc(snap.id, data));
    } on Object catch (e) {
      return Err(_failureFor(e));
    }
  }

  @override
  Future<Result<Job>> createJob({
    required String jobNo,
    required String customerId,
    required String branchId,
    required String fault,
    required String workRequested,
    required int tatTargetHrs,
    required DateTime dueAt,
    required String createdBy,
    String? watchId,
    String? sourceStore,
    String? assignedTo,
    bool isRework = false,
    String? parentJobId,
    List<String> intakePhotos = const [],
  }) async {
    try {
      final now = DateTime.now().toUtc();
      // Build the opening job in the domain, then serialize it via [_jobToDoc].
      // Audit timestamps are layered on with `serverTimestamp()`; the doc id is
      // assigned by Firestore, so a placeholder is fine here.
      final job = Job(
        id: '',
        jobNo: jobNo,
        customerId: customerId,
        status: JobStatus.received,
        fault: fault,
        workRequested: workRequested,
        tatTargetHrs: tatTargetHrs,
        dueAt: dueAt,
        paymentStatus: PaymentStatus.unbilled,
        isRework: isRework,
        branchId: branchId,
        watchId: watchId,
        sourceStore: sourceStore,
        assignedTo: assignedTo,
        intakePhotos: intakePhotos,
        parentJobId: parentJobId,
        statusHistory: [
          JobStatusChange(status: JobStatus.received, at: now, by: createdBy),
        ],
      );
      final doc = _jobs.doc();
      await doc.set(<String, dynamic>{
        ..._jobToDoc(job),
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': createdBy,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      final snap = await doc.get();
      return Ok(_fromDoc(snap.id, snap.data()!));
    } on Object catch (e) {
      return Err(_failureFor(e));
    }
  }

  @override
  Future<Result<void>> moveStatus(String id, JobStatus to, String by) async {
    try {
      final doc = _jobs.doc(id);
      final entry = JobStatusChange(
        status: to,
        at: DateTime.now().toUtc(),
        by: by,
      );
      await doc.update(<String, dynamic>{
        'status': to.toWire,
        'statusHistory': FieldValue.arrayUnion([_statusChangeToMap(entry)]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return const Ok(null);
    } on Object catch (e) {
      return Err(_failureFor(e));
    }
  }

  List<Job> _toJobList(QuerySnapshot<Map<String, dynamic>> snap) =>
      [for (final d in snap.docs) _fromDoc(d.id, d.data())];

  Job _fromDoc(String id, Map<String, dynamic> data) => _jobFromDoc(id, data);

  /// Builds a [Job] from a Firestore document's [id] and [data].
  ///
  /// Missing/garbled fields default safely: an unknown `status` becomes
  /// [JobStatus.received], an unknown `paymentStatus` becomes
  /// [PaymentStatus.unbilled], and a missing `dueAt` falls back to the Unix
  /// epoch, so a malformed document still renders.
  Job _jobFromDoc(String id, Map<String, dynamic> data) {
    final qcData = data['qc'];
    return Job(
      id: id,
      jobNo: FirestoreConvert.toStr(data['jobNo']),
      customerId: FirestoreConvert.toStr(data['customerId']),
      status:
          JobStatus.fromWire(data['status'] as String?) ?? JobStatus.received,
      fault: FirestoreConvert.toStr(data['fault']),
      workRequested: FirestoreConvert.toStr(data['workRequested']),
      tatTargetHrs: FirestoreConvert.toInt(data['tatTargetHrs']),
      dueAt: FirestoreConvert.toDateTime(data['dueAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      paymentStatus: PaymentStatus.fromWire(data['paymentStatus'] as String?) ??
          PaymentStatus.unbilled,
      isRework: FirestoreConvert.toBool(data['isRework']),
      branchId: FirestoreConvert.toStr(data['branchId']),
      watchId: data['watchId'] as String?,
      sourceStore: data['sourceStore'] as String?,
      assignedTo: data['assignedTo'] as String?,
      intakePhotos: FirestoreConvert.toStringList(data['intakePhotos']),
      deliveryPhotos: FirestoreConvert.toStringList(data['deliveryPhotos']),
      qc: qcData is Map<String, dynamic> ? _qcFromMap(qcData) : null,
      partsUsed: _partsFrom(data['partsUsed']),
      outcome: JobOutcome.fromWire(data['outcome'] as String?),
      warrantyType: WarrantyType.fromWire(data['warrantyType'] as String?),
      parentJobId: data['parentJobId'] as String?,
      amountPaise: data['amountPaise'] == null
          ? null
          : FirestoreConvert.toInt(data['amountPaise']),
      statusHistory: _historyFrom(data['statusHistory']),
      createdAt: FirestoreConvert.toDateTime(data['createdAt']),
      createdBy: data['createdBy'] as String?,
      updatedAt: FirestoreConvert.toDateTime(data['updatedAt']),
    );
  }

  /// Serializes a [Job]'s domain content to a Firestore-friendly map (excludes
  /// the doc-id [Job.id]). Audit fields are written only when set;
  /// create/update supply `serverTimestamp()`/uid separately.
  Map<String, dynamic> _jobToDoc(Job job) => <String, dynamic>{
        'jobNo': job.jobNo,
        'customerId': job.customerId,
        'status': job.status.toWire,
        'fault': job.fault,
        'workRequested': job.workRequested,
        'tatTargetHrs': job.tatTargetHrs,
        'dueAt': FirestoreConvert.toTimestamp(job.dueAt),
        'paymentStatus': job.paymentStatus.toWire,
        'isRework': job.isRework,
        'branchId': job.branchId,
        'intakePhotos': job.intakePhotos,
        'deliveryPhotos': job.deliveryPhotos,
        'partsUsed': [for (final p in job.partsUsed) _partToMap(p)],
        'statusHistory': [
          for (final h in job.statusHistory) _statusChangeToMap(h),
        ],
        if (job.watchId != null) 'watchId': job.watchId,
        if (job.sourceStore != null) 'sourceStore': job.sourceStore,
        if (job.assignedTo != null) 'assignedTo': job.assignedTo,
        if (job.qc != null) 'qc': _qcToMap(job.qc!),
        if (job.outcome != null) 'outcome': job.outcome!.toWire,
        if (job.warrantyType != null) 'warrantyType': job.warrantyType!.toWire,
        if (job.parentJobId != null) 'parentJobId': job.parentJobId,
        if (job.amountPaise != null) 'amountPaise': job.amountPaise,
        if (job.createdAt != null)
          'createdAt': FirestoreConvert.toTimestamp(job.createdAt),
        if (job.createdBy != null) 'createdBy': job.createdBy,
        if (job.updatedAt != null)
          'updatedAt': FirestoreConvert.toTimestamp(job.updatedAt),
      };

  /// Builds a [JobQc] from a `jobs/{id}.qc` map, defaulting each missing flag
  /// to `false`.
  JobQc _qcFromMap(Map<String, dynamic> data) => JobQc(
        timekeeping: FirestoreConvert.toBool(data['timekeeping']),
        gasket: FirestoreConvert.toBool(data['gasket']),
        glassClean: FirestoreConvert.toBool(data['glassClean']),
        strap: FirestoreConvert.toBool(data['strap']),
        crown: FirestoreConvert.toBool(data['crown']),
      );

  /// Serializes a [JobQc] to a Firestore-friendly map.
  Map<String, dynamic> _qcToMap(JobQc qc) => <String, dynamic>{
        'timekeeping': qc.timekeeping,
        'gasket': qc.gasket,
        'glassClean': qc.glassClean,
        'strap': qc.strap,
        'crown': qc.crown,
      };

  /// Builds a [JobPart] from a `partsUsed` element, defaulting missing fields.
  JobPart _partFromMap(Map<String, dynamic> data) => JobPart(
        partId: FirestoreConvert.toStr(data['partId']),
        qty: FirestoreConvert.toInt(data['qty']),
        ref: FirestoreConvert.toStr(data['ref']),
      );

  /// Serializes a [JobPart] to a Firestore-friendly map.
  Map<String, dynamic> _partToMap(JobPart part) => <String, dynamic>{
        'partId': part.partId,
        'qty': part.qty,
        'ref': part.ref,
      };

  /// Builds a [JobStatusChange] from a `statusHistory` element. An unrecognized
  /// status falls back to [JobStatus.received] and a missing timestamp to the
  /// Unix epoch, so a garbled history entry never crashes the board.
  JobStatusChange _statusChangeFromMap(Map<String, dynamic> data) =>
      JobStatusChange(
        status:
            JobStatus.fromWire(data['status'] as String?) ?? JobStatus.received,
        at: FirestoreConvert.toDateTime(data['at']) ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        by: FirestoreConvert.toStr(data['by']),
      );

  /// Serializes a [JobStatusChange] to a Firestore-friendly map (UTC
  /// [DateTime] -> `Timestamp`).
  Map<String, dynamic> _statusChangeToMap(JobStatusChange change) =>
      <String, dynamic>{
        'status': change.status.toWire,
        'at': FirestoreConvert.toTimestamp(change.at),
        'by': change.by,
      };

  /// Maps the `partsUsed` array, skipping any non-map element.
  List<JobPart> _partsFrom(Object? value) => value is List
      ? [
          for (final e in value)
            if (e is Map<String, dynamic>) _partFromMap(e),
        ]
      : const [];

  /// Maps the `statusHistory` array, skipping any non-map element.
  List<JobStatusChange> _historyFrom(Object? value) => value is List
      ? [
          for (final e in value)
            if (e is Map<String, dynamic>) _statusChangeFromMap(e),
        ]
      : const [];

  Failure _failureFor(Object error) {
    if (error is FirebaseException && error.code == 'permission-denied') {
      return PermissionFailure(error.message ?? error.code);
    }
    return UnexpectedFailure(error.toString());
  }
}
