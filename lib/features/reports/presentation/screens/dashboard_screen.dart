import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/l10n/app_localizations.dart';
import '../../../../core/utils/currency.dart';
import '../../../auth/presentation/auth_guard.dart';
import '../../../auth/presentation/providers/staff_providers.dart';
import '../../domain/kpi_summary.dart';
import '../providers/reports_providers.dart';

/// KPI dashboard (`/reports/dashboard`, finance roles): operational KPIs for the
/// selected window (last 7 or 30 days), computed live from jobs + invoice
/// revenue via [KpiSummary]. BUILD_BRIEF §12 M9.
class DashboardScreen extends ConsumerStatefulWidget {
  /// Creates the dashboard screen.
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _days = 7;

  static DateTime _todayUtc() {
    final now = DateTime.now().toUtc();
    return DateTime.utc(now.year, now.month, now.day);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final branchId = ref.watch(currentBranchIdProvider);

    return Scaffold(
      key: const Key('dashboardScreen'),
      appBar: AppBar(
        title: Text(l10n.dashboardTitle),
        leading: IconButton(
          key: const Key('dashboardBack'),
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.home),
        ),
      ),
      body: branchId == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.branchNotConfigured,
                  key: const Key('dashboardNoBranch'),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : _body(context, l10n, branchId),
    );
  }

  Widget _body(BuildContext context, AppLocalizations l10n, String branchId) {
    final to = _todayUtc().add(const Duration(days: 1));
    final from = to.subtract(Duration(days: _days));
    final range = (branchId: branchId, from: from, to: to);
    final kpiAsync = ref.watch(kpiSummaryProvider(range));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SegmentedButton<int>(
            key: const Key('dashboardRange'),
            segments: [
              ButtonSegment(value: 7, label: Text(l10n.dashboardRange7)),
              ButtonSegment(value: 30, label: Text(l10n.dashboardRange30)),
            ],
            selected: {_days},
            onSelectionChanged: (s) => setState(() => _days = s.first),
          ),
        ),
        Expanded(
          child: kpiAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.genericError,
                  key: const Key('dashboardError'),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            data: (kpi) => _cards(l10n, kpi),
          ),
        ),
      ],
    );
  }

  Widget _cards(AppLocalizations l10n, KpiSummary kpi) => ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _KpiTile(
            label: l10n.kpiReceived,
            value: '${kpi.jobsReceived}',
            valueKey: const Key('kpiReceived'),
          ),
          _KpiTile(
            label: l10n.kpiDelivered,
            value: '${kpi.jobsDelivered}',
            valueKey: const Key('kpiDelivered'),
          ),
          _KpiTile(
            label: l10n.kpiAvgTat,
            value: kpi.avgTatHours.toStringAsFixed(1),
            valueKey: const Key('kpiAvgTat'),
          ),
          _KpiTile(
            label: l10n.kpiFirstFix,
            value: '${kpi.firstTimeFixPct.toStringAsFixed(0)}%',
            valueKey: const Key('kpiFirstFix'),
          ),
          _KpiTile(
            label: l10n.kpiComebacks,
            value: '${kpi.comebacks}',
            valueKey: const Key('kpiComebacks'),
          ),
          _KpiTile(
            label: l10n.kpiUncollected,
            value: '${kpi.uncollected}',
            valueKey: const Key('kpiUncollected'),
          ),
          _KpiTile(
            label: l10n.kpiRevenue,
            value: formatPaise(kpi.revenuePaise),
            valueKey: const Key('kpiRevenue'),
          ),
        ],
      );
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.label,
    required this.value,
    required this.valueKey,
  });

  final String label;
  final String value;
  final Key valueKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(label),
        trailing: Text(
          value,
          key: valueKey,
          style: theme.textTheme.titleLarge,
        ),
      ),
    );
  }
}
