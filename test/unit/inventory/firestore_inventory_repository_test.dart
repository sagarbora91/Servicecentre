import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_centre_app/core/errors/failure.dart';
import 'package:service_centre_app/features/inventory/data/repositories/firestore_inventory_repository.dart';
import 'package:service_centre_app/features/inventory/domain/entities/part.dart';
import 'package:service_centre_app/features/inventory/domain/entities/stock_movement.dart';

Part _part({
  String id = 'p1',
  int onHand = 0,
  int reserved = 0,
  String branchId = 'b1',
  String category = 'Battery',
  String reference = 'SR626',
}) =>
    Part(
      id: id,
      category: category,
      reference: reference,
      binCode: 'A1',
      onHand: onHand,
      reserved: reserved,
      minLevel: 1,
      reorderPoint: 2,
      serviceOnly: false,
      costPaise: 1000,
      mrpPaise: 2500,
      branchId: branchId,
    );

Future<void> _seedPart(
  FakeFirebaseFirestore fs, {
  String id = 'p1',
  required int onHand,
  int reserved = 0,
  String branchId = 'b1',
}) {
  return fs.collection('parts').doc(id).set(<String, dynamic>{
    'category': 'Battery',
    'reference': 'SR626',
    'binCode': 'A1',
    'onHand': onHand,
    'reserved': reserved,
    'minLevel': 1,
    'reorderPoint': 2,
    'serviceOnly': false,
    'costPaise': 1000,
    'mrpPaise': 2500,
    'branchId': branchId,
  });
}

Future<int> _onHand(FakeFirebaseFirestore fs, String id) async {
  final snap = await fs.collection('parts').doc(id).get();
  return (snap.data()!['onHand'] as num).toInt();
}

Future<List<Map<String, dynamic>>> _movements(FakeFirebaseFirestore fs) async {
  final snap = await fs.collection('stockMovements').get();
  return snap.docs.map((d) => d.data()).toList();
}

void main() {
  late FakeFirebaseFirestore fs;
  late FirestoreInventoryRepository repo;

  setUp(() {
    fs = FakeFirebaseFirestore();
    repo = FirestoreInventoryRepository(fs);
  });

  group('watchParts', () {
    test('streams parts of the branch ordered by category then reference',
        () async {
      await _seedPartDoc(fs, id: 'p1', category: 'Strap', reference: 'B');
      await _seedPartDoc(fs, id: 'p2', category: 'Battery', reference: 'Z');
      await _seedPartDoc(fs, id: 'p3', category: 'Battery', reference: 'A');

      final parts = await repo.watchParts('b1').first;

      expect(parts.map((p) => p.id), <String>['p3', 'p2', 'p1']);
    });

    test('excludes parts from other branches', () async {
      await _seedPart(fs, id: 'p1', onHand: 1);
      await _seedPart(fs, id: 'p2', onHand: 1, branchId: 'other');

      final parts = await repo.watchParts('b1').first;

      expect(parts.map((p) => p.id), <String>['p1']);
    });
  });

  group('getPart', () {
    test('returns the part when it exists, mapping every field', () async {
      await fs.collection('parts').doc('p1').set(<String, dynamic>{
        'category': 'Battery',
        'reference': 'SR626',
        'binCode': 'A1',
        'onHand': 7,
        'reserved': 2,
        'minLevel': 1,
        'reorderPoint': 3,
        'serviceOnly': true,
        'costPaise': 1500,
        'mrpPaise': 4000,
        'branchId': 'b1',
        'size': '20mm',
        'mfgDate': Timestamp.fromDate(DateTime.utc(2025, 3, 4)),
      });

      final result = await repo.getPart('p1');

      expect(result.isOk, isTrue);
      final part = result.valueOrNull!;
      expect(part.id, 'p1');
      expect(part.category, 'Battery');
      expect(part.reference, 'SR626');
      expect(part.binCode, 'A1');
      expect(part.onHand, 7);
      expect(part.reserved, 2);
      expect(part.minLevel, 1);
      expect(part.reorderPoint, 3);
      expect(part.serviceOnly, isTrue);
      expect(part.costPaise, 1500);
      expect(part.mrpPaise, 4000);
      expect(part.branchId, 'b1');
      expect(part.size, '20mm');
      expect(part.mfgDate, DateTime.utc(2025, 3, 4));
      expect(part.mfgDate!.isUtc, isTrue);
    });

    test('defaults missing/null fields and leaves optionals null', () async {
      // Only branchId present: every other field exercises its fallback.
      await fs
          .collection('parts')
          .doc('sparse')
          .set(<String, dynamic>{'branchId': 'b1'});

      final result = await repo.getPart('sparse');

      expect(result.isOk, isTrue);
      final part = result.valueOrNull!;
      expect(part.category, '');
      expect(part.reference, '');
      expect(part.binCode, '');
      expect(part.onHand, 0);
      expect(part.reserved, 0);
      expect(part.minLevel, 0);
      expect(part.reorderPoint, 0);
      expect(part.serviceOnly, isFalse);
      expect(part.costPaise, 0);
      expect(part.mrpPaise, 0);
      expect(part.size, isNull);
      expect(part.mfgDate, isNull);
      expect(part.createdAt, isNull);
      expect(part.createdBy, isNull);
      expect(part.updatedAt, isNull);
    });

    test('returns NotFoundFailure when the part is missing', () async {
      final result = await repo.getPart('ghost');

      expect(result.isErr, isTrue);
      expect(result.failureOrNull, isA<NotFoundFailure>());
    });
  });

  group('createPart', () {
    test('stores the part with audit stamps and returns the new id', () async {
      final result = await repo.createPart(_part(onHand: 5), by: 'u1');

      expect(result.isOk, isTrue);
      final id = result.valueOrNull!;
      final snap = await fs.collection('parts').doc(id).get();
      final data = snap.data()!;
      expect(data['category'], 'Battery');
      expect(data['onHand'], 5);
      expect(data['branchId'], 'b1');
      expect(data['createdBy'], 'u1');
      expect(data['createdAt'], isNotNull);
      expect(data['updatedAt'], isNotNull);
      // The generated doc-id is not persisted inside the document body.
      expect(data.containsKey('id'), isFalse);
    });

    test('omits null optional fields but writes present ones', () async {
      final withSize = _part(onHand: 1).copyWith(
        size: '18mm',
        mfgDate: DateTime.utc(2024, 1, 2),
      );

      final created = await repo.createPart(withSize, by: 'u1');
      final plain = await repo.createPart(_part(id: 'p2', onHand: 1), by: 'u1');

      final a = await fs.collection('parts').doc(created.valueOrNull!).get();
      final b = await fs.collection('parts').doc(plain.valueOrNull!).get();
      expect(a.data()!['size'], '18mm');
      expect(a.data()!['mfgDate'], isA<Timestamp>());
      expect(b.data()!.containsKey('size'), isFalse);
      expect(b.data()!.containsKey('mfgDate'), isFalse);
    });
  });

  group('updatePart', () {
    test('updates fields and bumps updatedAt', () async {
      await _seedPart(fs, id: 'p1', onHand: 5);

      final fetched = await repo.getPart('p1');
      final updated = fetched.valueOrNull!.copyWith(
        binCode: 'Z9',
        mrpPaise: 999,
      );
      final result = await repo.updatePart(updated, by: 'u2');

      expect(result.isOk, isTrue);
      final data = (await fs.collection('parts').doc('p1').get()).data()!;
      expect(data['binCode'], 'Z9');
      expect(data['mrpPaise'], 999);
      expect(data['updatedAt'], isNotNull);
    });
  });

  group('consume (transactional, never negative — §8.1)', () {
    test('decrements on-hand, records an out movement, and refuses to go '
        'negative', () async {
      // §8.1 example, verbatim in spirit.
      await _seedPart(fs, id: 'p1', onHand: 1);

      final r1 = await repo.consume(
        partId: 'p1',
        qty: 1,
        jobId: 'j1',
        by: 'u1',
      );
      expect(r1.isOk, isTrue);
      expect(await _onHand(fs, 'p1'), 0);

      final r2 = await repo.consume(
        partId: 'p1',
        qty: 1,
        jobId: 'j2',
        by: 'u1',
      );
      expect(r2.isErr, isTrue);
      expect(r2.failureOrNull, isA<InsufficientStockFailure>());
      // On-hand must remain 0 — never negative.
      expect(await _onHand(fs, 'p1'), 0);

      // Exactly one movement (the successful consume); the rejected one wrote
      // nothing.
      final moves = await _movements(fs);
      expect(moves, hasLength(1));
      final move = moves.single;
      expect(move['partId'], 'p1');
      expect(move['type'], 'out');
      expect(move['qty'], 1);
      expect(move['jobId'], 'j1');
      expect(move['by'], 'u1');
      expect(move['branchId'], 'b1');
      expect(move['at'], isNotNull);
      // The recorded type round-trips back through the domain enum.
      expect(
        StockMovementType.fromWireName(move['type'] as String?),
        StockMovementType.out,
      );
    });

    test('writes nothing at all when stock is insufficient', () async {
      await _seedPart(fs, id: 'p1', onHand: 2);

      final result =
          await repo.consume(partId: 'p1', qty: 5, jobId: 'j1', by: 'u1');

      expect(result.failureOrNull, isA<InsufficientStockFailure>());
      expect(await _onHand(fs, 'p1'), 2);
      expect(await _movements(fs), isEmpty);
    });

    test('consuming the exact on-hand quantity is allowed (boundary)',
        () async {
      await _seedPart(fs, id: 'p1', onHand: 3);

      final result =
          await repo.consume(partId: 'p1', qty: 3, jobId: 'j1', by: 'u1');

      expect(result.isOk, isTrue);
      expect(await _onHand(fs, 'p1'), 0);
    });

    test('returns NotFoundFailure for a missing part and writes nothing',
        () async {
      final result =
          await repo.consume(partId: 'ghost', qty: 1, jobId: 'j1', by: 'u1');

      expect(result.failureOrNull, isA<NotFoundFailure>());
      expect(await _movements(fs), isEmpty);
    });
  });

  group('receiveStock (transactional)', () {
    test('increments on-hand and records an in movement', () async {
      await _seedPart(fs, id: 'p1', onHand: 4);

      final result = await repo.receiveStock(partId: 'p1', qty: 6, by: 'u1');

      expect(result.isOk, isTrue);
      expect(await _onHand(fs, 'p1'), 10);
      final move = (await _movements(fs)).single;
      // The reserved-word value serializes as 'in'.
      expect(move['type'], 'in');
      expect(move['qty'], 6);
      expect(move['by'], 'u1');
      expect(move.containsKey('jobId'), isFalse);
      expect(
        StockMovementType.fromWireName(move['type'] as String?),
        StockMovementType.in_,
      );
    });

    test('returns NotFoundFailure for a missing part', () async {
      final result = await repo.receiveStock(partId: 'ghost', qty: 1, by: 'u1');

      expect(result.failureOrNull, isA<NotFoundFailure>());
      expect(await _movements(fs), isEmpty);
    });
  });

  group('adjustStock (transactional, guarded >= 0)', () {
    test('applies a positive delta and records an adjust movement', () async {
      await _seedPart(fs, id: 'p1', onHand: 4);

      final result = await repo.adjustStock(partId: 'p1', delta: 3, by: 'u1');

      expect(result.isOk, isTrue);
      expect(await _onHand(fs, 'p1'), 7);
      final move = (await _movements(fs)).single;
      expect(move['type'], 'adjust');
      expect(move['qty'], 3);
    });

    test('applies a negative delta down to zero (boundary)', () async {
      await _seedPart(fs, id: 'p1', onHand: 4);

      final result = await repo.adjustStock(partId: 'p1', delta: -4, by: 'u1');

      expect(result.isOk, isTrue);
      expect(await _onHand(fs, 'p1'), 0);
      expect((await _movements(fs)).single['qty'], -4);
    });

    test('rejects a negative delta that would go below zero, writing nothing',
        () async {
      await _seedPart(fs, id: 'p1', onHand: 4);

      final result = await repo.adjustStock(partId: 'p1', delta: -5, by: 'u1');

      expect(result.failureOrNull, isA<InsufficientStockFailure>());
      expect(await _onHand(fs, 'p1'), 4);
      expect(await _movements(fs), isEmpty);
    });

    test('returns NotFoundFailure for a missing part', () async {
      final result = await repo.adjustStock(
        partId: 'ghost',
        delta: 1,
        by: 'u1',
      );

      expect(result.failureOrNull, isA<NotFoundFailure>());
    });
  });
}

Future<void> _seedPartDoc(
  FakeFirebaseFirestore fs, {
  required String id,
  required String category,
  required String reference,
  String branchId = 'b1',
}) {
  return fs.collection('parts').doc(id).set(<String, dynamic>{
    'category': category,
    'reference': reference,
    'binCode': 'A1',
    'onHand': 1,
    'reserved': 0,
    'minLevel': 1,
    'reorderPoint': 2,
    'serviceOnly': false,
    'costPaise': 1000,
    'mrpPaise': 2500,
    'branchId': branchId,
  });
}
