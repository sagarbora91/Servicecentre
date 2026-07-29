import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/backup_file.dart';
import '../../domain/repositories/backup_repository.dart';
import '../../domain/services/backup_json.dart';

const _branchCollections = <String>[
  'users',
  'customers',
  'watches',
  'jobs',
  'parts',
  'stockMovements',
  'estimates',
  'invoices',
  'payments',
  'suppliers',
  'orders',
  'stockTakes',
  'warranties',
  'feedback',
  'messages',
  'reminders',
  'dailyStats',
];

/// Firestore-backed branch snapshot generator.
class FirestoreBackupRepository implements BackupRepository {
  /// Creates the repository with an injected Firestore instance.
  FirestoreBackupRepository(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Future<Result<BackupFile>> buildBranchBackup(
    String branchId, {
    DateTime? generatedAt,
  }) async {
    try {
      final collections = <String, List<Map<String, Object?>>>{};
      for (final name in _branchCollections) {
        final snapshot = await _firestore
            .collection(name)
            .where('branchId', isEqualTo: branchId)
            .get();
        collections[name] = [
          for (final document in snapshot.docs)
            {'id': document.id, ..._mapToJson(document.data())},
        ];
      }
      final settings = await _firestore.collection('settings').doc(branchId).get();
      collections['settings'] = settings.exists && settings.data() != null
          ? [
              {'id': settings.id, ..._mapToJson(settings.data()!)},
            ]
          : const [];
      return Ok(
        buildBackupJson(
          branchId: branchId,
          generatedAt: generatedAt ?? DateTime.now().toUtc(),
          collections: collections,
        ),
      );
    } on Object catch (error) {
      return Err(UnexpectedFailure(error.toString()));
    }
  }
}

Map<String, Object?> _mapToJson(Map<String, dynamic> value) => {
      for (final entry in value.entries) entry.key: _toJson(entry.value),
    };

Object? _toJson(Object? value) => switch (value) {
      final Timestamp timestamp => timestamp.toDate().toUtc().toIso8601String(),
      final DocumentReference<Object?> reference => reference.path,
      final DateTime date => date.toUtc().toIso8601String(),
      final Map<Object?, Object?> map => <String, Object?>{
          for (final entry in map.entries)
            entry.key.toString(): _toJson(entry.value),
        },
      final Iterable<Object?> values => [for (final item in values) _toJson(item)],
      final String value => value,
      final num value => value,
      final bool value => value,
      null => null,
      _ => value.toString(),
    };
