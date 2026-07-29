import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/job_photo_kind.dart';
import '../../domain/repositories/photo_repository.dart';

/// [PhotoRepository] backed by Firebase Storage. Uploads each photo to
/// `jobs/{jobId}/{kind}/{epochMs}.jpg` and returns its download URL.
///
/// Not unit-tested (no Storage fake in the toolchain) — verified in device QA;
/// the path/encoding logic is intentionally thin.
class FirebaseStoragePhotoRepository implements PhotoRepository {
  /// Creates the repository with an injected [FirebaseStorage].
  FirebaseStoragePhotoRepository(this._storage);

  final FirebaseStorage _storage;

  @override
  Future<Result<String>> uploadJobPhoto({
    required String jobId,
    required JobPhotoKind kind,
    required Uint8List bytes,
  }) async {
    try {
      final stamp = DateTime.now().toUtc().millisecondsSinceEpoch;
      final ref = _storage.ref('jobs/$jobId/${kind.name}/$stamp.jpg');
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      final url = await ref.getDownloadURL();
      return Ok(url);
    } on Object catch (e) {
      return Err(UnexpectedFailure(e.toString()));
    }
  }
}
