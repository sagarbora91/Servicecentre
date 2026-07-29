import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/collections.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/firebase/activity_log.dart';
import '../../../../core/firebase/converters.dart';
import '../../domain/entities/branch_settings.dart';
import '../../domain/repositories/settings_repository.dart';

/// [SettingsRepository] backed by Cloud Firestore (`settings/{branchId}`).
class FirestoreSettingsRepository implements SettingsRepository {
  /// Creates the repository with an injected [FirebaseFirestore] so tests can
  /// pass a fake.
  FirestoreSettingsRepository({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _doc(String branchId) =>
      _firestore.collection(Collections.settings).doc(branchId);

  @override
  Stream<BranchSettings> watchSettings(String branchId) =>
      _doc(branchId).snapshots().map((snap) {
        final data = snap.data();
        return (snap.exists && data != null)
            ? _fromDoc(branchId, data)
            : BranchSettings.defaults(branchId);
      });

  @override
  Future<Result<void>> saveSettings(BranchSettings settings, String by) async {
    try {
      await _doc(settings.branchId).set(
        <String, dynamic>{
          ..._toDoc(settings),
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': by,
        },
        SetOptions(merge: true),
      );
      await writeActivityLog(
        _firestore,
        actor: by,
        action: 'settings.save',
        entity: Collections.settings,
        entityId: settings.branchId,
        after: _toDoc(settings),
      );
      return const Ok(null);
    } on Object catch (e) {
      return Err(_failureFor(e));
    }
  }

  BranchSettings _fromDoc(String branchId, Map<String, dynamic> data) =>
      BranchSettings(
        branchId: branchId,
        gstEnabled: FirestoreConvert.toBool(data['gstEnabled']),
        gstin: data['gstin'] as String?,
        legalName: data['legalName'] as String?,
        address: data['address'] as String?,
      );

  Map<String, dynamic> _toDoc(BranchSettings settings) => <String, dynamic>{
        'gstEnabled': settings.gstEnabled,
        if (settings.gstin != null) 'gstin': settings.gstin,
        if (settings.legalName != null) 'legalName': settings.legalName,
        if (settings.address != null) 'address': settings.address,
      };

  Failure _failureFor(Object error) {
    if (error is FirebaseException && error.code == 'permission-denied') {
      return PermissionFailure(error.message ?? error.code);
    }
    return UnexpectedFailure(error.toString());
  }
}
