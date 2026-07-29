import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_centre_app/features/inventory/data/repositories/firestore_inventory_repository.dart';

import '../../support/jobs_harness.dart';

void main() {
  test('receiveGrn increments onHand and records a grn movement for the order',
      () async {
    final firestore = FakeFirebaseFirestore();
    final repo = FirestoreInventoryRepository(firestore);
    await firestore
        .collection('parts')
        .doc('p1')
        .set(partDoc(id: 'p1', reference: 'SR626', onHand: 5));

    final result =
        await repo.receiveGrn(partId: 'p1', qty: 10, orderId: 'o1', by: 'u1');

    expect(result.isOk, isTrue);
    final part = (await firestore.collection('parts').doc('p1').get()).data()!;
    expect(part['onHand'], 15);

    final moves = await firestore
        .collection('stockMovements')
        .where('partId', isEqualTo: 'p1')
        .get();
    final move = moves.docs.single.data();
    expect(move['type'], 'grn');
    expect(move['qty'], 10);
    expect(move['orderId'], 'o1');
  });
}
