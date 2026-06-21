/// The lifecycle stage of a [Job] (BUILD_BRIEF.md §5.1).
///
/// Stored in `jobs/{id}.status` as a snake_case wire string (e.g.
/// `awaiting_part`). The data layer maps via [toWire]/[fromWire]; `domain`
/// never touches the raw string except through these helpers.
enum JobStatus {
  /// Watch taken in at the counter; awaiting diagnosis.
  received('received'),

  /// Fault assessed; estimate/work can be planned.
  diagnosed('diagnosed'),

  /// Blocked on a spare part that must be ordered/reserved.
  awaitingPart('awaiting_part'),

  /// Actively being repaired by a technician.
  inRepair('in_repair'),

  /// Repair finished; undergoing quality control.
  qc('qc'),

  /// Passed QC; ready for the customer to collect.
  ready('ready'),

  /// Handed back to the customer (terminal, gated on QC + delivery photo).
  delivered('delivered'),

  /// Returned without repair (declined/beyond repair).
  returned('returned');

  const JobStatus(this.wireName);

  /// The snake_case string persisted in Firestore.
  final String wireName;

  /// The Firestore wire string for this status.
  String get toWire => wireName;

  /// Parses a stored status string, returning `null` if it is missing or
  /// unrecognized (e.g. a future status this build does not know about).
  static JobStatus? fromWire(String? value) {
    for (final status in JobStatus.values) {
      if (status.wireName == value) return status;
    }
    return null;
  }
}

/// Left→right lifecycle order of the Kanban board columns (BUILD_BRIEF §7).
///
/// Defined explicitly rather than relying on [JobStatus.values] so reordering
/// the enum can't silently reshuffle the board. The board MUST group jobs by
/// this order client-side: `watchBoard` sorts by the snake_case wire string
/// (alphabetical), which is NOT the lifecycle order.
const List<JobStatus> kBoardColumnOrder = <JobStatus>[
  JobStatus.received,
  JobStatus.diagnosed,
  JobStatus.awaitingPart,
  JobStatus.inRepair,
  JobStatus.qc,
  JobStatus.ready,
  JobStatus.delivered,
  JobStatus.returned,
];
