import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/scan_entry.dart';
import 'scan_add_outcome.dart';

/// Store for scanned barcodes.
///
/// - Persists data locally via SharedPreferences.
/// - Groups scans by local date (Today/Yesterday/other date labels handled in UI).
class ScannedBarcodesStore extends ChangeNotifier {
  static const _storageKey = 'scanned_entries_v1';

  final List<ScanEntry> _entries = <ScanEntry>[];

  /// All entries (oldest -> newest).
  List<ScanEntry> get entries => List.unmodifiable(_entries);

  /// Backwards-friendly list of values.
  List<String> get barcodes =>
      List.unmodifiable(_entries.map((e) => e.value).toList(growable: false));

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.trim().isEmpty) return;

    try {
      final decoded = ScanEntry.decodeList(raw);
      _entries
        ..clear()
        ..addAll(decoded);
      notifyListeners();
    } catch (_) {
      // Ignore corrupted data.
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = ScanEntry.encodeList(_entries);
    await prefs.setString(_storageKey, raw);
  }

  Future<ScanAddOutcome> addScan(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return ScanAddOutcome.ignored();

    // Global duplicate blocking (case-sensitive exact match).
    final existing = _entries.where((e) => e.value == trimmed).toList(growable: false);
    if (existing.isNotEmpty) {
      // Use most recent occurrence for the timestamp.
      final latest = existing.reduce(
        (a, b) => a.scannedAt.isAfter(b.scannedAt) ? a : b,
      );
      return ScanAddOutcome.duplicate(latest.scannedAt);
    }

    final id = _makeId();
    final entry = ScanEntry(id: id, value: trimmed, scannedAt: DateTime.now());
    _entries.add(entry);
    notifyListeners();
    await _save();
    return ScanAddOutcome.added();
  }

  Future<void> removeById(String id) async {
    _entries.removeWhere((e) => e.id == id);
    notifyListeners();
    await _save();
  }

  Future<void> clearAll() async {
    _entries.clear();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  /// Groups entries by local date (midnight).
  ///
  /// Map key is a DateTime of the day (year,month,day) in local time.
  Map<DateTime, List<ScanEntry>> groupedByDay() {
    final Map<DateTime, List<ScanEntry>> map = {};
    for (final e in _entries) {
      final dayKey = DateTime(e.scannedAt.year, e.scannedAt.month, e.scannedAt.day);
      (map[dayKey] ??= <ScanEntry>[]).add(e);
    }

    // Sort each day's entries oldest->newest.
    for (final list in map.values) {
      list.sort((a, b) => a.scannedAt.compareTo(b.scannedAt));
    }

    return map;
  }

  String _makeId() {
    // Unique-enough ID without extra deps.
    final ms = DateTime.now().microsecondsSinceEpoch;
    final rnd = Random().nextInt(1 << 32);
    return '$ms-$rnd';
  }
}
