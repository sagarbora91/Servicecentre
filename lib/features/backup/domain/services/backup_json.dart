import 'dart:convert';
import 'dart:typed_data';

import '../entities/backup_file.dart';

/// Builds a stable, versioned JSON artifact from already JSON-safe documents.
BackupFile buildBackupJson({
  required String branchId,
  required DateTime generatedAt,
  required Map<String, List<Map<String, Object?>>> collections,
}) {
  final utc = generatedAt.toUtc();
  final content = const JsonEncoder.withIndent('  ').convert({
    'schemaVersion': 1,
    'generatedAt': utc.toIso8601String(),
    'branchId': branchId,
    'collections': collections,
  });
  final stamp = utc.toIso8601String().replaceAll(RegExp('[:.-]'), '');
  return BackupFile(
    fileName: 'service-centre-$branchId-$stamp.json',
    mimeType: 'application/json',
    bytes: Uint8List.fromList(utf8.encode(content)),
  );
}
