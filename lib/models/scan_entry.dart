import 'dart:convert';

/// A single scan result with timestamp.
class ScanEntry {
  ScanEntry({required this.id, required this.value, required this.scannedAt});

  final String id;
  final String value;
  final DateTime scannedAt;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'value': value,
        'scannedAt': scannedAt.toIso8601String(),
      };

  static ScanEntry fromJson(Map<String, Object?> json) {
    return ScanEntry(
      id: (json['id'] as String?) ?? '',
      value: (json['value'] as String?) ?? '',
      scannedAt: DateTime.tryParse((json['scannedAt'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true).toLocal(),
    );
  }

  static String encodeList(List<ScanEntry> entries) {
    final list = entries.map((e) => e.toJson()).toList(growable: false);
    return jsonEncode(list);
  }

  static List<ScanEntry> decodeList(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return <ScanEntry>[];
    return decoded
        .whereType<Map>()
        .map((m) => ScanEntry.fromJson(m.cast<String, Object?>()))
        .where((e) => e.id.isNotEmpty && e.value.trim().isNotEmpty)
        .toList(growable: false);
  }
}
