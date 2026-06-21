import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/l10n/app_localizations.dart';
import '../../../auth/presentation/auth_guard.dart';
import '../../../auth/presentation/providers/staff_providers.dart';
import '../providers/customers_providers.dart';

/// Customer list + search (`/customers`, any active staff). Streams the branch's
/// customers and filters them live by name or phone; tapping one opens detail.
class CustomerListScreen extends ConsumerStatefulWidget {
  /// Creates the customer list screen.
  const CustomerListScreen({super.key});

  @override
  ConsumerState<CustomerListScreen> createState() =>
      _CustomerListScreenState();
}

class _CustomerListScreenState extends ConsumerState<CustomerListScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final branchId = ref.watch(currentBranchIdProvider);

    return Scaffold(
      key: const Key('customerListScreen'),
      appBar: AppBar(
        title: Text(l10n.customersTitle),
        leading: IconButton(
          key: const Key('customersBack'),
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.home),
        ),
      ),
      body: branchId == null
          ? _Centered(
              key: const Key('customersNoBranch'),
              message: l10n.branchNotConfigured,
            )
          : _body(l10n, branchId),
    );
  }

  Widget _body(AppLocalizations l10n, String branchId) {
    final customersAsync = ref.watch(customersProvider(branchId));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            key: const Key('customerSearchField'),
            decoration: InputDecoration(
              hintText: l10n.customerSearchHint,
              prefixIcon: const Icon(Icons.search),
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
        ),
        Expanded(
          child: customersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => _Centered(
              key: const Key('customersError'),
              message: l10n.genericError,
            ),
            data: (customers) {
              if (customers.isEmpty) {
                return _Centered(
                  key: const Key('customersEmpty'),
                  message: l10n.customersEmpty,
                );
              }
              final q = _query.trim().toLowerCase();
              final filtered = q.isEmpty
                  ? customers
                  : customers.where((c) => c.name.toLowerCase().contains(q) || c.phone.toLowerCase().contains(q)).toList();
              if (filtered.isEmpty) {
                return _Centered(
                  key: const Key('customersNoMatch'),
                  message: l10n.customersNoMatch,
                );
              }
              return ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final customer = filtered[index];
                  return ListTile(
                    key: Key('customerTile_${customer.id}'),
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(customer.name),
                    subtitle: Text(customer.phone),
                    onTap: () =>
                        context.go(Routes.customerDetail(customer.id)),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}
