import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../app/l10n/app_localizations.dart';
import '../../../auth/presentation/auth_guard.dart';
import '../../../customers/domain/entities/customer.dart';
import '../../../customers/presentation/providers/customers_providers.dart';
import '../../domain/entities/job.dart';
import '../../domain/job_deep_link.dart';
import '../providers/jobs_providers.dart';

/// QR box-label for a job (`/jobs/:id/label`): the jobNo, the customer, and a
/// QR encoding the job deep link so scanning it opens this job. Physical
/// printing lands with the slip/PDF work in M6; this shows the printable label.
class QrLabelScreen extends ConsumerWidget {
  /// Creates the label screen for [jobId].
  const QrLabelScreen({required this.jobId, super.key});

  /// The job document id from the route.
  final String jobId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final jobAsync = ref.watch(jobByIdProvider(jobId));

    return Scaffold(
      key: const Key('qrLabelScreen'),
      appBar: AppBar(
        title: Text(l10n.labelTitle),
        leading: IconButton(
          key: const Key('labelBack'),
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.jobDetail(jobId)),
        ),
      ),
      body: jobAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _Centered(message: l10n.genericError),
        data: (job) => job == null
            ? _Centered(
                key: const Key('labelJobMissing'),
                message: l10n.jobNotFound,
              )
            : _Label(job: job),
      ),
    );
  }
}

class _Label extends ConsumerWidget {
  const _Label({required this.job});

  final Job job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final customers = ref.watch(customersProvider(job.branchId)).valueOrNull ??
        const <Customer>[];
    String? name;
    for (final c in customers) {
      if (c.id == job.customerId) {
        name = c.name;
        break;
      }
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(job.jobNo, style: theme.textTheme.headlineMedium),
                const SizedBox(height: 4),
                Text(
                  name ?? job.customerId,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(l10n.detailCustomer, style: theme.textTheme.bodySmall),
                const SizedBox(height: 20),
                QrImageView(
                  key: const Key('jobQr'),
                  data: buildJobLink(job.id),
                  size: 220,
                ),
              ],
            ),
          ),
        ),
      ),
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
