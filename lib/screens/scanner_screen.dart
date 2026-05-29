import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';

import '../state/scan_add_outcome.dart';
import '../state/scanned_barcodes_store.dart';
import '../state/auth_store.dart';
import '../services/api_service.dart';
import 'barcode_list_screen.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({
    super.key, 
    required this.store,
    required this.authStore,
    required this.apiService,
  });

  final ScannedBarcodesStore store;
  final AuthStore authStore;
  final ApiService apiService;

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> with WidgetsBindingObserver {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool _isReadyForNext = true;
  String? _lastScanned;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Safe camera handling.
    if (state == AppLifecycleState.resumed) {
      _controller.start();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _controller.stop();
    }
  }

  Future<void> _openList() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BarcodeListScreen(store: widget.store),
      ),
    );
  }

  DateTime? _cooldownUntil;

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (!_isReadyForNext) return;

    final now = DateTime.now();
    if (_cooldownUntil != null && now.isBefore(_cooldownUntil!)) return;

    final String? raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.trim().isEmpty) return;

    final outcome = await widget.store.addScan(raw);

    if (!mounted) return;

    switch (outcome.status) {
      case ScanAddStatus.added:
        setState(() {
          _isReadyForNext = false;
          _lastScanned = raw.trim();
        });

        // Pause camera until user presses Next.
        await _controller.stop();
        
        // Try sending to the backend
        final apiSuccess = await widget.apiService.sendScan(raw.trim());
        if (apiSuccess) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Successfully synced with server!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        } else {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Saved locally. Backend sync failed (Order not found or Offline).'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
        
        break;

      case ScanAddStatus.duplicate:
        _cooldownUntil = DateTime.now().add(const Duration(seconds: 1));
        final ts = outcome.existingScannedAt;
        final formatted = ts == null ? '' : DateFormat('dd MMM yyyy, hh:mm a').format(ts);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              formatted.isEmpty
                  ? 'Already scanned.'
                  : 'Already scanned on $formatted',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
        break;

      case ScanAddStatus.ignored:
        break;
    }
  }

  Future<void> _onNextPressed() async {
    setState(() {
      _isReadyForNext = true;
      _lastScanned = null;
    });
    await _controller.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Return Scanner', style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          tooltip: 'Toggle Flashlight',
          icon: ValueListenableBuilder<TorchState>(
            valueListenable: _controller.torchState,
            builder: (context, state, child) {
              switch (state) {
                case TorchState.off:
                  return const Icon(Icons.flash_off, color: Colors.grey);
                case TorchState.on:
                  return const Icon(Icons.flash_on, color: Colors.yellowAccent);
              }
            },
          ),
          onPressed: () => _controller.toggleTorch(),
        ),
        actions: [
          IconButton(
            tooltip: 'Unpair Device',
            onPressed: () async {
              await widget.authStore.unpair();
            },
            icon: const Icon(Icons.logout),
          ),
          IconButton(
            tooltip: 'History',
            onPressed: _openList,
            icon: const Icon(Icons.history),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error, child) {
              return _ScannerErrorOverlay(
                title: 'Camera not available',
                message: error.errorDetails?.message ?? error.toString(),
              );
            },
          ),
          // Overlay guidance
          IgnorePointer(
            child: Container(
              alignment: Alignment.center,
              child: Container(
                width: 260,
                height: 180,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.85),
                    width: 3,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          // Status text
          Positioned(
            left: 16,
            right: 16,
            bottom: 96,
            child: _StatusCard(
              isReadyForNext: _isReadyForNext,
              lastScanned: _lastScanned,
            ),
          ),
          // Bottom center Next button
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Center(
              child: FilledButton(
                onPressed: _isReadyForNext ? null : _onNextPressed,
                child: const Text('Next'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerErrorOverlay extends StatelessWidget {
  const _ScannerErrorOverlay({required this.title, required this.message});

  final String title;
  final String message;

  Future<void> _openSettings() async {
    final uri = Uri(scheme: 'app-settings');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white.withOpacity(0.95), // Light background instead of black
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.no_photography_outlined, size: 64, color: Colors.deepPurple),
              const SizedBox(height: 16),
              Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(color: Colors.deepPurple, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: const TextStyle(color: Colors.black87),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _openSettings,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Open Settings'),
              ),
              const SizedBox(height: 12),
              const Text(
                'Enable Camera permission for this app.',
                style: TextStyle(color: Colors.black54),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.isReadyForNext, required this.lastScanned});

  final bool isReadyForNext;
  final String? lastScanned;

  @override
  Widget build(BuildContext context) {
    final text = isReadyForNext
        ? 'Scan a barcode...'
        : 'Saved: ${lastScanned ?? ''}\nPress Next to scan another.';

    return Card(
      elevation: 4,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Colors.deepPurple, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.deepPurple,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            height: 1.25,
          ),
        ),
      ),
    );
  }
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
