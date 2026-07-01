// A single-method "port": the data layer adapts Firebase Storage to it. Keeping
// it an interface keeps `domain` Firebase-free and lets the controller test mock
// the upload, so one_member_abstracts is the wrong call here.
// ignore_for_file: one_member_abstracts
import 'dart:typed_data';

import '../../../../core/errors/result.dart';
import '../entities/job_photo_kind.dart';

/// Contract for uploading a job photo to object storage. Lives in `domain`
/// (no Firebase imports); the `data` impl adapts Firebase Storage.
abstract interface class PhotoRepository {
  /// Uploads [bytes] (a compressed JPEG) for [jobId] under [kind] and returns
  /// the stored download URL.
  Future<Result<String>> uploadJobPhoto({
    required String jobId,
    required JobPhotoKind kind,
    required Uint8List bytes,
  });
}
