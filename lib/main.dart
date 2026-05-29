import 'package:flutter/material.dart';

import 'screens/scanner_screen.dart';
import 'screens/pairing_screen.dart';
import 'screens/splash_screen.dart';
import 'state/scanned_barcodes_store.dart';
import 'state/auth_store.dart';
import 'services/api_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final store = ScannedBarcodesStore();
  await store.load();

  final authStore = AuthStore();
  await authStore.load();

  final apiService = ApiService(authStore: authStore);

  runApp(MyApp(store: store, authStore: authStore, apiService: apiService));
}

class MyApp extends StatefulWidget {
  const MyApp({
    super.key, 
    required this.store, 
    required this.authStore,
    required this.apiService,
  });

  final ScannedBarcodesStore store;
  final AuthStore authStore;
  final ApiService apiService;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _showSplash = true;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OrderPilot Scanner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light, // Explicitly enforce light theme
        colorScheme: ColorScheme.fromSeed(
          brightness: Brightness.light,
          seedColor: Colors.deepPurple,
          primary: Colors.deepPurple,
          secondary: Colors.blueAccent,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
        ),
        useMaterial3: true,
      ),
      home: _showSplash 
        ? SplashScreen(
            onInitializationComplete: () {
              setState(() {
                _showSplash = false;
              });
            },
          )
        : ListenableBuilder(
            listenable: widget.authStore,
            builder: (context, _) {
              if (widget.authStore.isPaired) {
                return ScannerScreen(
                  store: widget.store, 
                  authStore: widget.authStore, 
                  apiService: widget.apiService,
                );
              }
              return PairingScreen(authStore: widget.authStore);
            },
          ),
    );
  }
}
