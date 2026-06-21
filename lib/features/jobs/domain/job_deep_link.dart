/// Deep links for jobs, used by the QR box-label and scan-to-open.
///
/// Encodes the job's **document id** (not the human jobNo, which is undecided in
/// format and not globally unique forever), so a scanned label resolves to the
/// exact job. Pure functions — no Firebase, fully unit-testable.
library;

const String _scheme = 'servicecentre';
const String _host = 'job';

/// The deep link encoding [jobId], e.g. `servicecentre://job/<id>`.
String buildJobLink(String jobId) => '$_scheme://$_host/$jobId';

/// Extracts the job id from a scanned [raw] link, or `null` if it is not a
/// recognized job deep link.
String? parseJobId(String raw) {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null || uri.scheme != _scheme || uri.host != _host) return null;
  final segments = uri.pathSegments;
  if (segments.isEmpty || segments.first.isEmpty) return null;
  return segments.first;
}
