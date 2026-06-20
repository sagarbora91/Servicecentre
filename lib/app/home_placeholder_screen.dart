import 'package:flutter/material.dart';

import 'l10n/app_localizations.dart';

/// Temporary landing screen shown until feature screens land (M1+).
///
/// Verifies the M0 acceptance criterion: the app boots to a placeholder home.
class HomePlaceholderScreen extends StatelessWidget {
  const HomePlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.watch_outlined,
                size: 64,
                key: Key('homePlaceholderIcon'),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.homePlaceholderMessage,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
