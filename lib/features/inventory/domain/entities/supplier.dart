import 'package:freezed_annotation/freezed_annotation.dart';

import 'supplier_type.dart';

part 'supplier.freezed.dart';

/// A parts supplier (`suppliers/{id}`, BUILD_BRIEF.md §5.1). freezed value type;
/// Firestore mapping lives in `data`.
@freezed
abstract class Supplier with _$Supplier {
  /// Creates a supplier.
  const factory Supplier({
    required String id,
    required String name,
    required SupplierType type,
    required String branchId,
    String? contact,
  }) = _Supplier;

  const Supplier._();
}
