import 'package:flutter/material.dart';

import 'screens/scanner_screen.dart';
import 'state/scanned_barcodes_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final store = ScannedBarcodesStore();
  await store.load();

  runApp(MyApp(store: store));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.store});

  final ScannedBarcodesStore store;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Scanner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: ScannerScreen(store: store),
    );
  }
}
