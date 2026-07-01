import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/l10n/app_localizations.dart';
import '../providers/feedback_providers.dart';

/// Feedback section for a delivered job: shows the captured rating/comment, or a
/// "Record feedback" action that opens a 1–5 rating dialog (BUILD_BRIEF §12 M11
/// customer feedback). Any staff may capture it on the customer's behalf.
class FeedbackSection extends ConsumerWidget {
  /// Creates the feedback section for [jobId].
  const FeedbackSection({required this.jobId, super.key});

  /// The job document id.
  final String jobId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final feedbackAsync = ref.watch(feedbackForJobProvider(jobId));

    return feedbackAsync.maybeWhen(
      orElse: () => const SizedBox.shrink(),
      data: (list) {
        if (list.isNotEmpty) {
          final f = list.first;
          return Padding(
            key: const Key('feedbackExisting'),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.star, size: 18, color: Colors.amber),
                const SizedBox(width: 4),
                Text('${l10n.feedbackLabel}: ${f.rating}/5'),
                if (f.comment != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      f.comment!,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          );
        }
        return Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            key: const Key('feedbackBtn'),
            onPressed: () => unawaited(_open(context, ref, l10n)),
            icon: const Icon(Icons.rate_review_outlined),
            label: Text(l10n.feedbackRecord),
          ),
        );
      },
    );
  }

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final entry = await showDialog<_FeedbackEntry>(
      context: context,
      builder: (_) => const _FeedbackDialog(),
    );
    if (entry == null) return;
    final failure = await ref.read(feedbackControllerProvider.notifier).submit(
          jobId: jobId,
          rating: entry.rating,
          comment: entry.comment,
        );
    messenger.showSnackBar(
      SnackBar(
        content: Text(failure == null ? l10n.feedbackSaved : l10n.saveFailed),
      ),
    );
  }
}

class _FeedbackEntry {
  const _FeedbackEntry({required this.rating, this.comment});

  final int rating;
  final String? comment;
}

class _FeedbackDialog extends StatefulWidget {
  const _FeedbackDialog();

  @override
  State<_FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<_FeedbackDialog> {
  int _rating = 5;
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      key: const Key('feedbackDialog'),
      title: Text(l10n.feedbackDialogTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.feedbackRatingLabel),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  key: Key('ratingStar_$i'),
                  onPressed: () => setState(() => _rating = i),
                  icon: Icon(
                    i <= _rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                  ),
                ),
            ],
          ),
          TextField(
            key: const Key('feedbackCommentField'),
            controller: _commentController,
            decoration: InputDecoration(labelText: l10n.feedbackCommentLabel),
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const Key('feedbackCancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancelButton),
        ),
        FilledButton(
          key: const Key('feedbackSubmit'),
          onPressed: () {
            final comment = _commentController.text.trim();
            Navigator.of(context).pop(
              _FeedbackEntry(
                rating: _rating,
                comment: comment.isEmpty ? null : comment,
              ),
            );
          },
          child: Text(l10n.feedbackSubmitButton),
        ),
      ],
    );
  }
}
