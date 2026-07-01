import '../../../../core/errors/result.dart';
import '../entities/customer.dart';
import '../entities/watch.dart';

/// Contract for reading and writing customers and their watches.
///
/// Lives in `domain`, so it has no Firebase imports; the implementation in
/// `data` adapts Cloud Firestore to this interface. All fallible writes return
/// a [Result] and never throw across layers; streams surface live data.
abstract interface class CustomersRepository {
  /// Streams every customer in [branchId], ordered by [Customer.name].
  Stream<List<Customer>> watchCustomers(String branchId);

  /// Fetches a single customer by [id]. Returns an `Err(NotFoundFailure)` when
  /// no such document exists.
  Future<Result<Customer>> getCustomer(String id);

  /// Creates a customer in [branchId], stamping audit fields from [uid].
  ///
  /// Enforces phone de-dupe: if a customer with the same [phone] already exists
  /// in [branchId], returns an [Err] so the UI can warn instead of creating a
  /// duplicate.
  Future<Result<Customer>> createCustomer({
    required String branchId,
    required String name,
    required String phone,
    required String uid,
    bool consentWhatsApp = false,
    String? email,
    String? address,
  });

  /// Applies a partial update to the customer [id], setting `updatedAt`. Only
  /// non-null arguments are written. Returns an `Err(NotFoundFailure)` when the
  /// customer does not exist.
  Future<Result<Customer>> updateCustomer({
    required String id,
    String? name,
    String? phone,
    String? email,
    String? address,
    bool? consentWhatsApp,
    int? serviceCount,
    DateTime? lastVisitAt,
  });

  /// Searches customers in [branchId] whose name OR phone starts with [query]
  /// (case-sensitive prefix). An empty [query] yields no results.
  Future<Result<List<Customer>>> searchCustomers(String branchId, String query);

  /// Searches watches in [branchId] whose serial starts with [query]
  /// (case-sensitive prefix). An empty [query] yields no results. Backs
  /// job search by watch serial.
  Future<Result<List<Watch>>> searchWatchesBySerial(
    String branchId,
    String query,
  );

  /// Streams the watches belonging to [customerId], ordered by [Watch.brand].
  Stream<List<Watch>> watchesForCustomer(String customerId);

  /// Adds a watch for [customerId] in [branchId], stamping audit fields from
  /// [uid].
  Future<Result<Watch>> addWatch({
    required String branchId,
    required String customerId,
    required String brand,
    required String model,
    required String uid,
    String? serial,
    DateTime? warrantyUntil,
    List<String> photos = const [],
  });

  /// Applies a partial update to the watch [id], setting `updatedAt`. Only
  /// non-null arguments are written. Returns an `Err(NotFoundFailure)` when the
  /// watch does not exist.
  Future<Result<Watch>> updateWatch({
    required String id,
    String? brand,
    String? model,
    String? serial,
    DateTime? warrantyUntil,
    List<String>? photos,
  });
}
