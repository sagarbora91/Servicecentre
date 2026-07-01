/// Which photo set a captured image belongs to on a job (BUILD_BRIEF.md §5.1:
/// `intakePhotos` / `deliveryPhotos`).
enum JobPhotoKind {
  /// Condition photos taken when the watch is received.
  intake,

  /// Hand-over photos taken at delivery (the delivery gate requires ≥ 1).
  delivery;

  /// The `jobs/{id}` array field this kind appends to.
  String get field =>
      this == JobPhotoKind.intake ? 'intakePhotos' : 'deliveryPhotos';
}
