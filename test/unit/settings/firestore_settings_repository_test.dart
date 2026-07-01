import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:service_centre_app/core/errors/failure.dart';
import 'package:service_centre_app/features/settings/data/repositories/firestore_settings_repository.dart';
import 'package:service_centre_app/features/settings/domain/entities/branch_settings.dart';

class _MockFirestore extends Mock implements FirebaseFirestore {}

void main() {
  group('FirestoreSettingsRepository', () {
    late FakeFirebaseFirestore firestore;
    late FirestoreSettingsRepository repo;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repo = FirestoreSettingsRepository(firestore: firestore);
    });

    test('watchSettings emits defaults when no document exists', () async {
      final s = await repo.watchSettings('MAIN').first;
      expect(s.gstEnabled, isFalse);
      expect(s.branchId, 'MAIN');
    });

    test('saveSettings persists and is read back', () async {
      const settings = BranchSettings(
        branchId: 'MAIN',
        gstEnabled: true,
        gstin: '27ABCDE1234F1Z5',
        legalName: 'Acme Watch Co',
      );

      final result = await repo.saveSettings(settings, 'owner1');
      expect(result.isOk, isTrue);

      final read = await repo.watchSettings('MAIN').first;
      expect(read.gstEnabled, isTrue);
      expect(read.gstin, '27ABCDE1234F1Z5');
      expect(read.legalName, 'Acme Watch Co');
    });

    test('saveSettings logs an activity', () async {
      await repo.saveSettings(
        const BranchSettings(branchId: 'MAIN', gstEnabled: true),
        'owner1',
      );
      final log = await firestore.collection('activityLog').get();
      expect(
        log.docs.any((d) => d.data()['action'] == 'settings.save'),
        isTrue,
      );
    });

    test('maps an unexpected error to UnexpectedFailure', () async {
      final mock = _MockFirestore();
      when(() => mock.collection('settings')).thenThrow(Exception('boom'));
      final mockRepo = FirestoreSettingsRepository(firestore: mock);

      final result = await mockRepo.saveSettings(
        const BranchSettings(branchId: 'MAIN'),
        'owner1',
      );

      expect(result.failureOrNull, isA<UnexpectedFailure>());
    });
  });
}
