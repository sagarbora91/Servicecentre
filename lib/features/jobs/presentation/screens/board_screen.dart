import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/l10n/app_localizations.dart';
import '../../../auth/presentation/auth_guard.dart';
import '../../../auth/presentation/providers/staff_providers.dart';
import '../../../customers/domain/entities/customer.dart';
import '../../../customers/presentation/providers/customers_providers.dart';
import '../../domain/entities/job.dart';
import '../../domain/entities/job_status.dart';
import '../jobs_labels.dart';
import '../providers/jobs_providers.dart';

/// The Kanban jobs board: a column per [JobStatus] in lifecycle order
/// ([kBoardColumnOrder]), each listing that branch's jobs. Read-only for now;
/// intake (new-job) and status moves arrive in later M3 slices.
///
/// Reached at `/board` (any active staff). Branch comes from the signed-in
/// profile via [currentBranchIdProvider]; until a branch is configured it shows
/// the no-branch state.
class BoardScreen extends ConsumerWidget {
  /// Creates the board screen.
  const BoardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final branchId = ref.watch(currentBranchIdProvider);

    return Scaffold(
      key: const Key('boardScreen'),
      appBar: AppBar(
        title: Text(l10n.boardTitle),
        leading: IconButton(
          key: const Key('boardBack'),
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.home),
        ),
      ),
      body: branchId == null
          ? _Centered(
              key: const Key('boardNoBranch'),
              message: l10n.branchNotConfigured,
            )
          : _BoardBody(branchId: branchId),
    );
  }
}

class _BoardBody extends ConsumerWidget {
  const _BoardBody({required this.branchId});

  final String branchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final jobsAsync = ref.watch(boardProvider(branchId));
    // Customer names are best-effort: the jobs stream drives the screen state.
    final customers = ref.watch(customersProvider(branchId)).valueOrNull ??
        const <Customer>[];
    final nameById = {for (final c in customers) c.id: c.name};

    return jobsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => _Centered(
        key: const Key('boardError'),
        message: l10n.genericError,
      ),
      data: (jobs) {
        if (jobs.isEmpty) {
          return _Centered(
            key: const Key('boardEmpty'),
            message: l10n.boardEmpty,
          );
        }
        // watchBoard orders by the wire string (alphabetical), so group into
        // lifecycle columns client-side rather than trusting stream order.
        final byStatus = <JobStatus, List<Job>>{};
        for (final job in jobs) {
          (byStatus[job.status] ??= <Job>[]).add(job);
        }
        return LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final status in kBoardColumnOrder)
                  SizedBox(
                    width: 300,
                    height: constraints.maxHeight,
                    child: _BoardColumn(
                      status: status,
                      jobs: byStatus[status] ?? const <Job>[],
                      nameById: nameById,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BoardColumn extends StatelessWidget {
  const _BoardColumn({
    required this.status,
    required this.jobs,
    required this.nameById,
  });

  final JobStatus status;
  final List<Job> jobs;
  final Map<String, String> nameById;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              key: Key('boardColumnHeader_${status.wireName}'),
              children: [
                Expanded(
                  child: Text(
                    jobStatusLabel(status, l10n),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                Text('${jobs.length}', style: theme.textTheme.labelLarge),
              ],
            ),
          ),
          Expanded(
            child: jobs.isEmpty
                ? Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        l10n.boardColumnEmpty,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    child: Column(
                      children: [
                        for (final job in jobs)
                          _JobCard(
                            job: job,
                            customerName: nameById[job.customerId],
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({required this.job, required this.customerName});

  final Job job;
  final String? customerName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isClosed =
        job.status == JobStatus.delivered || job.status == JobStatus.returned;
    final overdue = !isClosed && job.dueAt.isBefore(DateTime.now().toUtc());
    final dueText =
        MaterialLocalizations.of(context).formatShortDate(job.dueAt.toLocal());
    final name = customerName;
    final displayName = (name == null || name.trim().isEmpty)
        ? l10n.jobUnknownCustomer
        : name;
    final dueColor = overdue ? theme.colorScheme.error : null;

    return Card(
      key: Key('jobCard_${job.id}'),
      child: InkWell(
        onTap: () => context.go(Routes.jobDetail(job.id)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(job.jobNo, style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(displayName, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.event_outlined, size: 14, color: dueColor),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      '${l10n.jobDueLabel} $dueText',
                      overflow: TextOverflow.ellipsis,
                      style:
                          theme.textTheme.bodySmall?.copyWith(color: dueColor),
                    ),
                  ),
                  if (overdue) ...[
                    const SizedBox(width: 6),
                    Text(
                      l10n.jobOverdue,
                      key: Key('overdue_${job.id}'),
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: theme.colorScheme.error),
                    ),
                  ],
                ],
              ),
            ],
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
