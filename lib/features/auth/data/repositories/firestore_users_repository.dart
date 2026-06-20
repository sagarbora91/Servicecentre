import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/collections.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/users_repository.dart';

/// [UsersRepository] backed by Cloud Firestore (`users/{uid}`).
///
/// Conversion stays in this `data` layer: [AppUser.toMap]/[AppUser.fromMap]
/// translate between the domain model and the document, and the universal audit
/// fields (`createdAt`/`createdBy`/`updatedAt`/`branchId`) are written here.
class FirestoreUsersRepository implements UsersRepository {
  /// Creates the repository with an injected [FirebaseFirestore] so tests can
  /// pass a fake.
  FirestoreUsersRepository({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection(Collections.users);

  @override
  Stream<List<AppUser>> watchStaff(String branchId) => _users
      .where('branchId', isEqualTo: branchId)
      .orderBy('name')
      .snapshots()
      .map(
        (snap) => snap.docs
            .map((doc) => AppUser.fromMap(doc.id, doc.data()))
            .whereType<AppUser>()
            .toList(),
      );

  @override
  Future<Result<AppUser>> getUser(String uid) async {
    try {
      final snap = await _users.doc(uid).get();
      final data = snap.data();
      if (!snap.exists || data == null) {
        return Err(NotFoundFailure('No user $uid'));
      }
      final user = AppUser.fromMap(uid, data);
      if (user == null) {
        return Err(NotFoundFailure('User $uid has no valid role'));
      }
      return Ok(user);
    } on Object catch (e) {
      return Err(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> upsertStaff(AppUser user, {required String by}) async {
    try {
      final doc = _users.doc(user.uid);
      final exists = (await doc.get()).exists;
      await doc.set(<String, dynamic>{
        ...user.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
        if (!exists) ...<String, dynamic>{
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': by,
        },
      }, SetOptions(merge: true));
      return const Ok(null);
    } on Object catch (e) {
      return Err(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> setActive(
    String uid, {
    required bool active,
    required String by,
  }) async {
    try {
      final doc = _users.doc(uid);
      if (!(await doc.get()).exists) {
        return Err(NotFoundFailure('No user $uid'));
      }
      await doc.update(<String, dynamic>{
        'active': active,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': by,
      });
      return const Ok(null);
    } on Object catch (e) {
      return Err(UnexpectedFailure(e.toString()));
    }
  }
}
