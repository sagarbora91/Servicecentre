import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../data/repositories/firestore_backup_repository.dart';
import '../../domain/repositories/backup_repository.dart';

/// Branch backup generator. Override in tests.
final backupRepositoryProvider = Provider<BackupRepository>(
  (ref) => FirestoreBackupRepository(ref.watch(firestoreProvider)),
);
