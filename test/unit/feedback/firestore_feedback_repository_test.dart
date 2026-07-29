import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:service_centre_app/core/errors/failure.dart';
import 'package:service_centre_app/features/feedback/data/repositories/firestore_feedback_repository.dart';
import 'package:service_centre_app/features/feedback/domain/entities/job_feedback.dart';

class _MockFirestore extends Mock implements FirebaseFirestore {}

void main() {
  group('JobFeedback', () {
    test('isValidRating checks the 1–5 range', () {
      expect(
        const JobFeedback(id: 'f', jobId: 'j', rating: 3, branchId: 'b')
            .isValidRating,
        isTrue,
      );
      expect(
        const JobFeedback(id: 'f', jobId: 'j', rating: 0, branchId: 'b')
            .isValidRating,
        isFalse,
      );
    });
  });

  group('FirestoreFeedbackRepository', () {
    late FakeFirebaseFirestore firestore;
    late FirestoreFeedbackRepository repo;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repo = FirestoreFeedbackRepository(firestore: firestore);
    });

    test('submitFeedback stores a rating and comment, streamable', () async {
      final result = await repo.submitFeedback(
        jobId: 'j1',
        rating: 4,
        branchId: 'b1',
        by: 'u1',
        comment: 'Great service',
      );

      expect(result.isOk, isTrue);
      final list = await repo.watchFeedbackForJob('j1').first;
      expect(list.single.rating, 4);
      expect(list.single.comment, 'Great service');
    });

    test('rejects an out-of-range rating, writing nothing', () async {
      final result = await repo.submitFeedback(
        jobId: 'j1',
        rating: 6,
        branchId: 'b1',
        by: 'u1',
      );

      final failure = result.failureOrNull;
      expect(failure, isA<ValidationFailure>());
      expect(
        (failure! as ValidationFailure).reason,
        ValidationReason.feedbackRatingInvalid,
      );
      final list = await repo.watchFeedbackForJob('j1').first;
      expect(list, isEmpty);
    });

    test('logs a feedback activity', () async {
      await repo.submitFeedback(jobId: 'j1', rating: 5, branchId: 'b1', by: 'u1');
      final log = await firestore.collection('activityLog').get();
      expect(
        log.docs.any((d) => d.data()['action'] == 'feedback.submit'),
        isTrue,
      );
    });

    test('maps an unexpected error to UnexpectedFailure', () async {
      final mock = _MockFirestore();
      when(() => mock.collection('feedback')).thenThrow(Exception('boom'));
      final mockRepo = FirestoreFeedbackRepository(firestore: mock);

      final result = await mockRepo.submitFeedback(
        jobId: 'j1',
        rating: 3,
        branchId: 'b1',
        by: 'u1',
      );
      expect(result.failureOrNull, isA<UnexpectedFailure>());
    });
  });
}
