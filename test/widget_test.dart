// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:scanner/main.dart';
import 'package:scanner/state/scanned_barcodes_store.dart';

void main() {
  testWidgets('App shows scanner screen', (WidgetTester tester) async {
    final store = ScannedBarcodesStore();
    await tester.pumpWidget(MyApp(store: store));

    // We only verify the basic UI exists in widget tests.
    expect(find.text('Scanner'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
  });
}
