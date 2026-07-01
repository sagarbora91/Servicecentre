import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/l10n/app_localizations.dart';
import '../../../auth/presentation/auth_guard.dart';
import '../controllers/job_search_controller.dart';
import '../jobs_labels.dart';

/// Job search (`/jobs/search`, any active staff): find jobs by phone, job
/// number, watch serial, or customer name. Tapping a result opens its detail.
class JobSearchScreen extends ConsumerStatefulWidget {
  /// Creates the search screen.
  const JobSearchScreen({super.key});

  @override
  ConsumerState<JobSearchScreen> createState() => _JobSearchScreenState();
}

class _JobSearchScreenState extends ConsumerState<JobSearchScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final resultsAsync = ref.watch(jobSearchControllerProvider);

    return Scaffold(
      key: const Key('jobSearchScreen'),
      appBar: AppBar(
        title: Text(l10n.searchTitle),
        leading: IconButton(
          key: const Key('searchBack'),
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.board),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              key: const Key('jobSearchField'),
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: l10n.searchHint,
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (value) => unawaited(
                ref.read(jobSearchControllerProvider.notifier).search(value),
              ),
            ),
          ),
          Expanded(
            child: resultsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => _Centered(
                key: const Key('searchError'),
                message: l10n.genericError,
              ),
              data: (jobs) {
                if (_controller.text.trim().isEmpty) {
                  return _Centered(
                    key: const Key('searchPrompt'),
                    message: l10n.searchPrompt,
                  );
                }
                if (jobs.isEmpty) {
                  return _Centered(
                    key: const Key('searchNoResults'),
                    message: l10n.searchNoResults,
                  );
                }
                return ListView.builder(
                  itemCount: jobs.length,
                  itemBuilder: (context, index) {
                    final job = jobs[index];
                    return ListTile(
                      key: Key('searchResult_${job.id}'),
                      title: Text(job.jobNo),
                      subtitle: Text(jobStatusLabel(job.status, l10n)),
                      onTap: () => context.go(Routes.jobDetail(job.id)),
                    );
                  },
                );
              },
            ),
          ),
        ],
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
