import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../state/auth_store.dart';

class PairingScreen extends StatefulWidget {
  const PairingScreen({super.key, required this.authStore});

  final AuthStore authStore;

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  bool _isProcessing = false;

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final String? raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.trim().isEmpty) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final data = jsonDecode(raw);
      if (data['success'] == true && data['pairingData'] != null) {
        final pairingData = data['pairingData'];
        await widget.authStore.savePairingData(
          pairingData['sellerId'],
          pairingData['token'],
          pairingData['endpoint'],
        );
        // Once saved, the main.dart will automatically switch to the ScannerScreen
        // because authStore is a ChangeNotifier and it will trigger a rebuild.
        return;
      } else {
        _showError('Invalid QR Code. Please scan a valid OrderPilot pairing code.');
      }
    } catch (e) {
      _showError('Invalid format. Not a recognized OrderPilot QR code.');
    }

    setState(() {
      _isProcessing = false;
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pair Device'),
        backgroundColor: Colors.purple[900],
        foregroundColor: Colors.white,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            onDetect: _onDetect,
          ),
          IgnorePointer(
            child: Container(
              alignment: Alignment.center,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.blueAccent,
                    width: 4,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 60,
            left: 20,
            right: 20,
            child: Card(
              color: Colors.white.withOpacity(0.9),
              child: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Icon(Icons.qr_code_scanner, size: 40, color: Colors.blueAccent),
                    SizedBox(height: 8),
                    Text(
                      'Scan the QR Code from your Web Dashboard to connect this device to your store.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}
