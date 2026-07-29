import '../../../app/l10n/app_localizations.dart';
import '../domain/entities/job_status.dart';

/// Localized label for a [JobStatus], used for board column headers and the
/// job-detail status chip. Lives in `presentation` because it needs
/// [AppLocalizations]; `domain` stays Flutter-free.
String jobStatusLabel(JobStatus status, AppLocalizations l10n) =>
    switch (status) {
      JobStatus.received => l10n.jobStatusReceived,
      JobStatus.diagnosed => l10n.jobStatusDiagnosed,
      JobStatus.awaitingPart => l10n.jobStatusAwaitingPart,
      JobStatus.inRepair => l10n.jobStatusInRepair,
      JobStatus.qc => l10n.jobStatusQc,
      JobStatus.ready => l10n.jobStatusReady,
      JobStatus.delivered => l10n.jobStatusDelivered,
      JobStatus.returned => l10n.jobStatusReturned,
    };
