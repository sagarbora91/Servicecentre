import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_centre_app/features/backup/data/repositories/firestore_backup_repository.dart';

void main() {
  test('exports only the requested branch and normalizes timestamps', () async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('customers').doc('c1').set({
      'branchId': 'MAIN',
      'name': 'Asha',
      'createdAt': Timestamp.fromDate(DateTime.utc(2026, 7, 1)),
    });
    await firestore.collection('customers').doc('c2').set({
      'branchId': 'OTHER',
      'name': 'Other',
    });
    await firestore.collection('settings').doc('MAIN').set({
      'branchId': 'MAIN',
      'gstEnabled': false,
    });

    final result = await FirestoreBackupRepository(firestore).buildBranchBackup(
      'MAIN',
      generatedAt: DateTime.utc(2026, 7, 29),
    );

    expect(result.isOk, isTrue);
    final decoded = jsonDecode(utf8.decode(result.valueOrNull!.bytes))
        as Map<String, dynamic>;
    final collections = decoded['collections'] as Map<String, dynamic>;
    final customers = collections['customers'] as List<dynamic>;
    expect(customers, hasLength(1));
    expect((customers.single as Map)['name'], 'Asha');
    expect((customers.single as Map)['createdAt'], '2026-07-01T00:00:00.000Z');
    expect(collections['settings'], hasLength(1));
  });
}
