import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../models/scan_entry.dart';
import '../state/scanned_barcodes_store.dart';

class BarcodeListScreen extends StatefulWidget {
  const BarcodeListScreen({super.key, required this.store});

  final ScannedBarcodesStore store;

  @override
  State<BarcodeListScreen> createState() => _BarcodeListScreenState();
}

class _BarcodeListScreenState extends State<BarcodeListScreen> {
  final Set<String> _selectedIds = <String>{};
  String _query = '';

  bool _matchesQuery(ScanEntry e) {
    final q = _query.trim();
    if (q.isEmpty) return true;
    return e.value.toLowerCase().contains(q.toLowerCase());
  }

  Map<DateTime, List<ScanEntry>> _groupByDay(Iterable<ScanEntry> entries) {
    final Map<DateTime, List<ScanEntry>> map = {};
    for (final e in entries) {
      final dayKey = DateTime(e.scannedAt.year, e.scannedAt.month, e.scannedAt.day);
      (map[dayKey] ??= <ScanEntry>[]).add(e);
    }

    for (final list in map.values) {
      list.sort((a, b) => a.scannedAt.compareTo(b.scannedAt));
    }

    return map;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final filtered = widget.store.entries.where(_matchesQuery).toList(growable: false);
        final grouped = _groupByDay(filtered);
        final days = grouped.keys.toList(growable: false)
          ..sort((a, b) => b.compareTo(a)); // newest day first

        final totalCount = filtered.length;

        final allCount = widget.store.entries.length;
        final title = _query.trim().isEmpty
            ? 'Saved ($totalCount)'
            : 'Saved ($totalCount of $allCount)';

        return Scaffold(
          appBar: AppBar(
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(56),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search barcode...',
                    prefixIcon: const Icon(Icons.search, color: Colors.deepPurple),
                    suffixIcon: _query.trim().isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            onPressed: () => setState(() => _query = ''),
                            icon: const Icon(Icons.clear),
                          ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
            ),
            actions: [
              if (allCount > 0)
                PopupMenuButton<String>(
                  tooltip: 'More',
                  onSelected: (v) {
                    switch (v) {
                      case 'share_all':
                        _shareAll(filtered);
                        break;
                      case 'export_csv':
                        _exportCsv(filtered);
                        break;
                      case 'clear_all':
                        _confirmClearAll(context);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'share_all',
                      child: ListTile(
                        leading: Icon(Icons.share),
                        title: Text('Share all'),
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'export_csv',
                      child: ListTile(
                        leading: Icon(Icons.table_view),
                        title: Text('Export CSV'),
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'clear_all',
                      child: ListTile(
                        leading: Icon(Icons.delete_sweep),
                        title: Text('Clear all'),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          body: totalCount == 0
              ? Center(
                  child: Text(
                    _query.trim().isEmpty
                        ? 'No barcodes yet.'
                        : 'No results for "${_query.trim()}"',
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: days.length,
                  itemBuilder: (context, index) {
                    final day = days[index];
                    final entries = grouped[day] ?? const <ScanEntry>[];
                    return _DaySection(
                      day: day,
                      label: _dayLabel(day),
                      entries: entries,
                      isSelected: (id) => _selectedIds.contains(id),
                      onToggleEntry: (id, selected) {
                        setState(() {
                          if (selected) {
                            _selectedIds.add(id);
                          } else {
                            _selectedIds.remove(id);
                          }
                        });
                      },
                      onSelectAll: (allSelected) {
                        setState(() {
                          final ids = entries.map((e) => e.id);
                          if (allSelected) {
                            _selectedIds.addAll(ids);
                          } else {
                            _selectedIds.removeAll(ids);
                          }
                        });
                      },
                      onShare: () => _shareDay(day, entries),
                      onDeleteEntry: (id) => widget.store.removeById(id),
                      onCopy: (value) => _copy(context, value),
                      selectedIds: _selectedIds,
                    );
                  },
                ),
        );
      },
    );
  }

  String _dayLabel(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (day == today) return 'Today';
    if (day == yesterday) return 'Yesterday';

    return DateFormat('dd MMM yyyy').format(day);
  }

  Future<void> _shareAll(List<ScanEntry> entries) async {
    if (entries.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nothing to share.')),
        );
      }
      return;
    }

    final ordered = entries.toList()
      ..sort((a, b) => b.scannedAt.compareTo(a.scannedAt));

    final buffer = StringBuffer();
    for (var i = 0; i < ordered.length; i++) {
      buffer.writeln('${i + 1}) ${ordered[i].value}');
    }

    await Share.share(
      buffer.toString().trim(),
      subject: 'Barcodes (${entries.length})',
    );
  }

  String _csvEscape(String v) {
    final needsQuotes = v.contains(',') || v.contains('\n') || v.contains('"');
    final escaped = v.replaceAll('"', '""');
    return needsQuotes ? '"$escaped"' : escaped;
  }

  Future<void> _exportCsv(List<ScanEntry> entries) async {
    if (entries.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nothing to export.')),
        );
      }
      return;
    }

    final ordered = entries.toList()
      ..sort((a, b) => b.scannedAt.compareTo(a.scannedAt));

    final buffer = StringBuffer();
    buffer.writeln('value,scannedAt');
    for (final e in ordered) {
      buffer.writeln('${_csvEscape(e.value)},${_csvEscape(e.scannedAt.toIso8601String())}');
    }

    await Share.share(
      buffer.toString().trim(),
      subject: 'Barcodes export (${entries.length})',
    );
  }

  Future<void> _shareDay(DateTime day, List<ScanEntry> entries) async {
    final selected = entries.where((e) => _selectedIds.contains(e.id)).toList();
    if (selected.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select at least one barcode to share.')),
        );
      }
      return;
    }

    // Share only barcode values with numbering.
    final buffer = StringBuffer();
    for (var i = 0; i < selected.length; i++) {
      buffer.writeln('${i + 1}) ${selected[i].value}');
    }

    await Share.share(
      buffer.toString().trim(),
      subject: 'Barcodes - ${_dayLabel(day)}',
    );
  }

  void _copy(BuildContext context, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard')),
    );
  }

  Future<void> _confirmClearAll(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear all?'),
        content: const Text('This will remove all saved barcodes.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (ok == true) {
      _selectedIds.clear();
      await widget.store.clearAll();
    }
  }
}

class _DaySection extends StatelessWidget {
  const _DaySection({
    required this.day,
    required this.label,
    required this.entries,
    required this.isSelected,
    required this.onToggleEntry,
    required this.onSelectAll,
    required this.onShare,
    required this.onDeleteEntry,
    required this.onCopy,
    required this.selectedIds,
  });

  final DateTime day;
  final String label;
  final List<ScanEntry> entries;
  final bool Function(String id) isSelected;
  final void Function(String id, bool selected) onToggleEntry;
  final void Function(bool allSelected) onSelectAll;
  final VoidCallback onShare;
  final void Function(String id) onDeleteEntry;
  final void Function(String value) onCopy;
  final Set<String> selectedIds;

  @override
  Widget build(BuildContext context) {
    final dayIds = entries.map((e) => e.id).toSet();
    final selectedInDay = dayIds.intersection(selectedIds).length;
    final allSelected = entries.isNotEmpty && selectedInDay == entries.length;

    // Newest first inside the day.
    final ordered = entries.toList()..sort((a, b) => b.scannedAt.compareTo(a.scannedAt));

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  '$selectedInDay/${entries.length}',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(width: 8),
                Checkbox(
                  value: allSelected,
                  onChanged: entries.isEmpty
                      ? null
                      : (v) => onSelectAll(v ?? false),
                ),
                IconButton(
                  tooltip: 'Share selected',
                  onPressed: onShare,
                  icon: const Icon(Icons.share),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...ordered.map(
            (e) => ListTile(
              dense: true,
              leading: Checkbox(
                value: isSelected(e.id),
                onChanged: (v) => onToggleEntry(e.id, v ?? false),
              ),
              title: Text(e.value),
              onTap: () => onToggleEntry(e.id, !isSelected(e.id)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Copy',
                    onPressed: () => onCopy(e.value),
                    icon: const Icon(Icons.copy),
                  ),
                  IconButton(
                    tooltip: 'Delete',
                    onPressed: () => onDeleteEntry(e.id),
                    icon: const Icon(Icons.delete),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
