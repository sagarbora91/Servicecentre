import 'package:freezed_annotation/freezed_annotation.dart';

part 'job_part.freezed.dart';

/// A spare part consumed on a [Job] (an entry in `jobs/{id}.partsUsed`,
/// BUILD_BRIEF.md §5.1).
///
/// [partId] is the `parts/{id}` document id; [ref] is the human-readable part
/// reference captured at the time of use. freezed value type; the Firestore
/// mapping lives in the `data` layer so `domain` stays Firebase-free.
@freezed
abstract class JobPart with _$JobPart {
  /// Creates a consumed-part line.
  const factory JobPart({
    required String partId,
    required int qty,
    required String ref,
  }) = _JobPart;

  const JobPart._();
}
