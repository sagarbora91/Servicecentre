import 'package:freezed_annotation/freezed_annotation.dart';

part 'estimate_line.freezed.dart';

/// A single line on an [Estimate] (an entry in `estimates/{id}.lines`,
/// BUILD_BRIEF.md §5.1).
///
/// [amountPaise] is the line amount in integer paise (BUILD_BRIEF §4 — money is
/// never a float). freezed value type; Firestore mapping lives in the `data`
/// layer so `domain` stays Firebase-free.
@freezed
abstract class EstimateLine with _$EstimateLine {
  /// Creates an estimate line.
  const factory EstimateLine({
    required String desc,
    required int amountPaise,
  }) = _EstimateLine;

  const EstimateLine._();
}
