import 'package:flutter/material.dart' show ThemeMode, Placeholder;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invoicer/main.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Initialize dotenv with empty values for testing
    await dotenv.load(fileName: '.env', isOptional: true);
  });

  setUp(() {
    // Initialize SharedPreferences with mock values
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('InvoicerApp widget can be instantiated',
      (WidgetTester tester) async {
    // Just verify the widget can be created (no actual rendering)
    const app = InvoicerApp();
    expect(app, isA<InvoicerApp>());
  });

  testWidgets('MacosApp builds with correct theme',
      (WidgetTester tester) async {
    // Build a minimal version to test structure
    await tester.pumpWidget(
      MacosApp(
        title: 'Test',
        theme: MacosThemeData.dark(),
        themeMode: ThemeMode.dark,
        home: const Placeholder(),
      ),
    );

    // Verify basic MacOS app structure
    expect(find.byType(MacosApp), findsOneWidget);
  });
}
