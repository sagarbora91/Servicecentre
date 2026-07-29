import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../data/repositories/firestore_customers_repository.dart';
import '../../domain/entities/customer.dart';
import '../../domain/entities/watch.dart';
import '../../domain/repositories/customers_repository.dart';

/// The app's [CustomersRepository]. Override this (or `firestoreProvider` in
/// `core/firebase/firebase_providers.dart`) in tests with a fake Firestore.
final customersRepositoryProvider = Provider<CustomersRepository>(
  (ref) => FirestoreCustomersRepository(ref.watch(firestoreProvider)),
);

/// Streams every customer in a branch, ordered by name. Drives the customer
/// list screen.
final customersProvider =
    StreamProvider.family<List<Customer>, String>((ref, branchId) {
  return ref.watch(customersRepositoryProvider).watchCustomers(branchId);
});

/// Streams the watches belonging to a customer, ordered by brand. Drives the
/// customer-detail watch list.
final customerWatchesProvider =
    StreamProvider.family<List<Watch>, String>((ref, customerId) {
  return ref.watch(customersRepositoryProvider).watchesForCustomer(customerId);
});
