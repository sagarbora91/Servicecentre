import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:service_centre_app/features/backup/domain/services/backup_json.dart';

void main() {
  test('builds a versioned, portable branch backup', () {
    final file = buildBackupJson(
      branchId: 'MAIN',
      generatedAt: DateTime.utc(2026, 7, 29, 10, 30),
      collections: const {
        'customers': [
          {'id': 'c1', 'name': 'Asha'},
        ],
        'jobs': [],
      },
    );

    final decoded = jsonDecode(utf8.decode(file.bytes)) as Map<String, dynamic>;
    expect(file.mimeType, 'application/json');
    expect(file.fileName, contains('service-centre-MAIN-'));
    expect(decoded['schemaVersion'], 1);
    expect(decoded['branchId'], 'MAIN');
    expect((decoded['collections'] as Map)['customers'], hasLength(1));
  });
}
