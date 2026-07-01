import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../app/l10n/app_localizations.dart';
import '../../../auth/presentation/auth_guard.dart';
import '../../domain/job_deep_link.dart';

/// Scan-to-open (`/jobs/scan`, any active staff): points the camera at a job's
/// QR box-label and opens that job. The decode is the pure [jobIdFromScan]
/// (unit-tested); the camera surface is device-QA.
class JobScanScreen extends StatefulWidget {
  /// Creates the scan screen.
  const JobScanScreen({super.key});

  @override
  State<JobScanScreen> createState() => _JobScanScreenState();
}

class _JobScanScreenState extends State<JobScanScreen> {
  bool _handled = false;

  void _onDetect(BarcodeCapture capture) {
    if (_handled || !mounted) return;
    final id = jobIdFromScan(capture.barcodes.map((b) => b.rawValue));
    if (id == null) return;
    _handled = true;
    context.go(Routes.jobDetail(id));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      key: const Key('jobScanScreen'),
      appBar: AppBar(
        title: Text(l10n.scanTitle),
        leading: IconButton(
          key: const Key('scanBack'),
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.board),
        ),
      ),
      body: Column(
        children: [
          Expanded(child: MobileScanner(onDetect: _onDetect)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(l10n.scanPrompt, textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}
