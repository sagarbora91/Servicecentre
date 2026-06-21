import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/l10n/app_localizations.dart';
import '../../../auth/presentation/auth_guard.dart';
import '../../../auth/presentation/providers/staff_providers.dart';
import '../../../jobs/presentation/jobs_labels.dart';
import '../../../jobs/presentation/providers/jobs_providers.dart';
import '../../domain/entities/customer.dart';
import '../providers/customers_providers.dart';

/// Customer detail (`/customers/:id`): profile, the customer's watches, and
/// their service history (past jobs, newest first). Tapping a job opens it.
class CustomerDetailScreen extends ConsumerWidget {
  /// Creates the detail screen for [customerId].
  const CustomerDetailScreen({required this.customerId, super.key});

  /// The customer document id from the route.
  final String customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final branchId = ref.watch(currentBranchIdProvider);

    return Scaffold(
      key: const Key('customerDetailScreen'),
      appBar: AppBar(
        title: Text(l10n.customerDetailTitle),
        leading: IconButton(
          key: const Key('customerDetailBack'),
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.customers),
        ),
      ),
      body: branchId == null
          ? _Centered(
              key: const Key('customerDetailNoBranch'),
              message: l10n.branchNotConfigured,
            )
          : ref.watch(customersProvider(branchId)).when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (_, __) => _Centered(
                  key: const Key('customerDetailError'),
                  message: l10n.genericError,
                ),
                data: (customers) {
                  Customer? customer;
                  for (final c in customers) {
                    if (c.id == customerId) {
                      customer = c;
                      break;
                    }
                  }
                  if (customer == null) {
                    return _Centered(
                      key: const Key('customerNotFound'),
                      message: l10n.customerNotFound,
                    );
                  }
                  return _Detail(customer: customer);
                },
              ),
    );
  }
}

class _Detail extends ConsumerWidget {
  const _Detail({required this.customer});

  final Customer customer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final watchesAsync = ref.watch(customerWatchesProvider(customer.id));
    final jobsAsync = ref.watch(customerJobsProvider(customer.id));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(customer.name, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 12),
        _InfoRow(label: l10n.customerPhoneLabel, value: customer.phone),
        if (customer.email != null)
          _InfoRow(label: l10n.customerEmailLabel, value: customer.email!),
        if (customer.address != null)
          _InfoRow(label: l10n.customerAddressLabel, value: customer.address!),
        _InfoRow(
          label: l10n.customerVisitsLabel,
          value: '${customer.serviceCount}',
        ),
        const Divider(height: 32),
        Text(l10n.watchesSection, style: theme.textTheme.titleMedium),
        watchesAsync.when(
          loading: () => const _SectionLoader(),
          error: (_, __) => Text(l10n.genericError),
          data: (watches) => watches.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(l10n.noWatches, key: const Key('noWatches')),
                )
              : Column(
                  children: [
                    for (final w in watches)
                      ListTile(
                        key: Key('watchTile_${w.id}'),
                        leading: const Icon(Icons.watch_outlined),
                        title: Text('${w.brand} ${w.model}'.trim()),
                        subtitle: w.serial == null ? null : Text(w.serial!),
                      ),
                  ],
                ),
        ),
        const Divider(height: 32),
        Text(l10n.serviceHistorySection, style: theme.textTheme.titleMedium),
        jobsAsync.when(
          loading: () => const _SectionLoader(),
          error: (_, __) => Text(l10n.genericError),
          data: (jobs) => jobs.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    l10n.noServiceHistory,
                    key: const Key('noServiceHistory'),
                  ),
                )
              : Column(
                  children: [
                    for (final job in jobs)
                      ListTile(
                        key: Key('historyTile_${job.id}'),
                        leading: const Icon(Icons.work_outline),
                        title: Text(job.jobNo),
                        subtitle: Text(jobStatusLabel(job.status, l10n)),
                        onTap: () => context.go(Routes.jobDetail(job.id)),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: theme.textTheme.labelLarge),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _SectionLoader extends StatelessWidget {
  const _SectionLoader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(8),
      child: Center(child: CircularProgressIndicator()),
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
