import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/collections.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/firebase/activity_log.dart';
import '../../../../core/firebase/converters.dart';
import '../../domain/entities/job_feedback.dart';
import '../../domain/repositories/feedback_repository.dart';

/// [FeedbackRepository] backed by Cloud Firestore.
class FirestoreFeedbackRepository implements FeedbackRepository {
  /// Creates the repository with an injected [FirebaseFirestore] so tests can
  /// pass a fake.
  FirestoreFeedbackRepository({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _feedback =>
      _firestore.collection(Collections.feedback);

  @override
  Stream<List<JobFeedback>> watchFeedbackForJob(String jobId) => _feedback
      .where('jobId', isEqualTo: jobId)
      .orderBy('at', descending: true)
      .snapshots()
      .map((s) => [for (final d in s.docs) _fromDoc(d.id, d.data())]);

  @override
  Future<Result<void>> submitFeedback({
    required String jobId,
    required int rating,
    required String branchId,
    required String by,
    String? comment,
  }) async {
    if (rating < 1 || rating > 5) {
      return const Err(
        ValidationFailure(
          ValidationReason.feedbackRatingInvalid,
          'Rating must be between 1 and 5',
        ),
      );
    }
    try {
      final doc = _feedback.doc();
      await doc.set(<String, dynamic>{
        'jobId': jobId,
        'rating': rating,
        'branchId': branchId,
        if (comment != null && comment.trim().isNotEmpty)
          'comment': comment.trim(),
        'at': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': by,
      });
      await writeActivityLog(
        _firestore,
        actor: by,
        action: 'feedback.submit',
        entity: Collections.feedback,
        entityId: doc.id,
        after: <String, dynamic>{'jobId': jobId, 'rating': rating},
      );
      return const Ok(null);
    } on Object catch (e) {
      return Err(_failureFor(e));
    }
  }

  JobFeedback _fromDoc(String id, Map<String, dynamic> data) => JobFeedback(
        id: id,
        jobId: FirestoreConvert.toStr(data['jobId']),
        rating: FirestoreConvert.toInt(data['rating']),
        branchId: FirestoreConvert.toStr(data['branchId']),
        comment: data['comment'] as String?,
        at: FirestoreConvert.toDateTime(data['at']),
      );

  Failure _failureFor(Object error) {
    if (error is FirebaseException && error.code == 'permission-denied') {
      return PermissionFailure(error.message ?? error.code);
    }
    return UnexpectedFailure(error.toString());
  }
}
