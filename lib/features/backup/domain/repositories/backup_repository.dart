// ignore_for_file: one_member_abstracts

import '../../../../core/errors/result.dart';
import '../entities/backup_file.dart';

/// Builds a portable backup of one branch's operational data.
abstract interface class BackupRepository {
  /// Generates a versioned JSON backup for [branchId].
  Future<Result<BackupFile>> buildBranchBackup(
    String branchId, {
    DateTime? generatedAt,
  });
}
