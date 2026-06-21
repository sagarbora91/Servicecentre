import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/l10n/app_localizations.dart';
import '../../../auth/presentation/auth_guard.dart';

/// Placeholder job-detail screen reached from a board card (`/jobs/:id`). The
/// full detail (fields, status timeline, QC/delivery gate) is built in a later
/// M3 slice; this exists so the board's card navigation works end-to-end.
class JobDetailScreen extends StatelessWidget {
  /// Creates the placeholder, showing which [jobId] was opened.
  const JobDetailScreen({required this.jobId, super.key});

  /// The job document id from the route.
  final String jobId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      key: const Key('jobDetailScreen'),
      appBar: AppBar(
        title: Text(l10n.jobDetailTitle),
        leading: IconButton(
          key: const Key('jobDetailBack'),
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.board),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.jobDetailComingSoon, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(jobId, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
