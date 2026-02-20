/// Result of trying to add a scan.
enum ScanAddStatus {
  added,
  duplicate,
  ignored,
}

class ScanAddOutcome {
  const ScanAddOutcome._(this.status, {this.existingScannedAt});

  final ScanAddStatus status;

  /// For duplicates, the timestamp of the existing scan.
  final DateTime? existingScannedAt;

  factory ScanAddOutcome.added() => const ScanAddOutcome._(ScanAddStatus.added);

  factory ScanAddOutcome.ignored() => const ScanAddOutcome._(ScanAddStatus.ignored);

  factory ScanAddOutcome.duplicate(DateTime scannedAt) =>
      ScanAddOutcome._(ScanAddStatus.duplicate, existingScannedAt: scannedAt);
}
