import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_centre_app/core/errors/failure.dart';
import 'package:service_centre_app/features/inventory/data/repositories/firestore_inventory_repository.dart';

Future<void> _seed(
  FakeFirebaseFirestore firestore, {
  int onHand = 10,
  int reserved = 2,
}) =>
    firestore.collection('parts').doc('p1').set({
      'branchId': 'MAIN',
      'onHand': onHand,
      'reserved': reserved,
    });

Future<Map<String, dynamic>> _part(FakeFirebaseFirestore firestore) async =>
    (await firestore.collection('parts').doc('p1').get()).data()!;

void main() {
  late FakeFirebaseFirestore firestore;
  late FirestoreInventoryRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = FirestoreInventoryRepository(firestore);
  });

  test('reserve increments reserved, preserves onHand, and appends movement',
      () async {
    await _seed(firestore);

    final result = await repository.reserveStock(
      partId: 'p1',
      qty: 5,
      by: 'u1',
    );

    expect(result.isOk, isTrue);
    expect((await _part(firestore))['reserved'], 7);
    expect((await _part(firestore))['onHand'], 10);
    final movements = await firestore.collection('stockMovements').get();
    expect(movements.docs.single.data()['type'], 'reserve');
    expect(movements.docs.single.data()['qty'], 5);
  });

  test('reserve cannot exceed available stock and writes nothing', () async {
    await _seed(firestore, onHand: 10, reserved: 8);

    final result = await repository.reserveStock(
      partId: 'p1',
      qty: 3,
      by: 'u1',
    );

    expect(result.failureOrNull, isA<InsufficientStockFailure>());
    expect((await _part(firestore))['reserved'], 8);
    expect((await firestore.collection('stockMovements').get()).docs, isEmpty);
  });

  test('release decrements reserved and appends a release movement', () async {
    await _seed(firestore, reserved: 6);

    final result = await repository.releaseStock(
      partId: 'p1',
      qty: 4,
      by: 'u1',
    );

    expect(result.isOk, isTrue);
    expect((await _part(firestore))['reserved'], 2);
    final movements = await firestore.collection('stockMovements').get();
    expect(movements.docs.single.data()['type'], 'release');
  });

  test('release cannot exceed reserved stock and writes nothing', () async {
    await _seed(firestore, reserved: 2);

    final result = await repository.releaseStock(
      partId: 'p1',
      qty: 3,
      by: 'u1',
    );

    expect(result.failureOrNull, isA<InsufficientStockFailure>());
    expect((await _part(firestore))['reserved'], 2);
    expect((await firestore.collection('stockMovements').get()).docs, isEmpty);
  });

  test('rejects non-positive quantities and a missing part', () async {
    await _seed(firestore);

    final invalid = await repository.reserveStock(
      partId: 'p1',
      qty: 0,
      by: 'u1',
    );
    final missing = await repository.releaseStock(
      partId: 'missing',
      qty: 1,
      by: 'u1',
    );

    expect(invalid.failureOrNull, isA<UnexpectedFailure>());
    expect(missing.failureOrNull, isA<NotFoundFailure>());
    expect((await firestore.collection('stockMovements').get()).docs, isEmpty);
  });
}
