import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/providers/staff_providers.dart';
import '../providers/customers_providers.dart';

/// Orchestrates all customer-feature writes (customer + watch create/update).
/// Holds the in-flight state; each method returns `null` on success or the
/// [Failure] for the form to localize (e.g. a duplicate-phone [ConflictFailure]).
class CustomerWriteController extends AutoDisposeAsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  String get _uid => ref.read(currentUserProvider).valueOrNull?.uid ?? '';

  Future<Failure?> _run(Future<Failure?> Function(String branchId) op) async {
    final branchId = ref.read(currentBranchIdProvider);
    if (branchId == null) return const UnexpectedFailure('No branch configured');
    state = const AsyncValue<void>.loading();
    final failure = await op(branchId);
    state = const AsyncValue<void>.data(null);
    return failure;
  }

  /// Creates a customer (enforces phone de-dupe in the repository).
  Future<Failure?> createCustomer({
    required String name,
    required String phone,
    String? email,
    String? address,
    bool consentWhatsApp = false,
  }) =>
      _run((branchId) async {
        final result = await ref.read(customersRepositoryProvider).createCustomer(
              branchId: branchId,
              name: name,
              phone: phone,
              uid: _uid,
              consentWhatsApp: consentWhatsApp,
              email: email,
              address: address,
            );
        return result.failureOrNull;
      });

  /// Updates an existing customer.
  Future<Failure?> updateCustomer(
    String id, {
    required String name,
    required String phone,
    String? email,
    String? address,
    bool? consentWhatsApp,
  }) =>
      _run((_) async {
        final result = await ref.read(customersRepositoryProvider).updateCustomer(
              id: id,
              name: name,
              phone: phone,
              email: email,
              address: address,
              consentWhatsApp: consentWhatsApp,
            );
        return result.failureOrNull;
      });

  /// Adds a watch for [customerId].
  Future<Failure?> addWatch({
    required String customerId,
    required String brand,
    required String model,
    String? serial,
  }) =>
      _run((branchId) async {
        final result = await ref.read(customersRepositoryProvider).addWatch(
              branchId: branchId,
              customerId: customerId,
              brand: brand,
              model: model,
              uid: _uid,
              serial: serial,
            );
        return result.failureOrNull;
      });

  /// Updates an existing watch.
  Future<Failure?> updateWatch(
    String id, {
    required String brand,
    required String model,
    String? serial,
  }) =>
      _run((_) async {
        final result = await ref.read(customersRepositoryProvider).updateWatch(
              id: id,
              brand: brand,
              model: model,
              serial: serial,
            );
        return result.failureOrNull;
      });
}

/// The customer-feature write controller provider.
final customerWriteControllerProvider =
    AutoDisposeAsyncNotifierProvider<CustomerWriteController, void>(
  CustomerWriteController.new,
);
