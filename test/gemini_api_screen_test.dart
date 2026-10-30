import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kafa_sayimi/features/settings/gemini_api_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('GeminiApiScreen renders correctly with new layout requirements',
      (WidgetTester tester) async {
    // Set larger test surface to simulate modern mobile device (400 x 900)
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: GeminiApiScreen(),
        ),
      ),
    );

    // Initial pump
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // 1. Verify Screen title in AppBar (new page, not popup)
    expect(find.text('Gemini API Ayarları'), findsOneWidget);

    // 2. Verify "API Key'in yok mu?" button at top
    expect(find.text('API Key\'in yok mu?'), findsOneWidget);

    // 3. Verify quota section is HIDDEN when key is not valid/entered
    expect(find.textContaining('Kalan İstek:'), findsNothing);

    // 4. Verify "Yapıştır" button is NOT present (removed)
    expect(find.text('Yapıştır'), findsNothing);

    // 5. Verify "Sıfırla" button is present (replaces "Varsayılana Dön")
    expect(find.text('Sıfırla'), findsOneWidget);
    expect(find.text('Varsayılana Dön'), findsNothing);

    // 6. Verify "Şimdi Doğrula" button is present with check-in-circle icon
    expect(find.text('Şimdi Doğrula'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);

    // 7. Verify tapping "API Key'in yok mu?" opens bottom sheet with step-by-step instructions
    await tester.tap(find.text('API Key\'in yok mu?'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('API Anahtarı Nasıl Alınır?'), findsOneWidget);
    expect(find.text('Google AI Studio Web Sitesini Açın'), findsOneWidget);
    expect(find.text('Google AI Studio\'ya Git'), findsOneWidget);

    // Close bottom sheet
    await tester.tap(find.text('Kapat'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // 8. Test entering text and clicking "Sıfırla"
    await tester.enterText(find.byType(TextField), 'TEST_KEY_123');
    await tester.pump();
    expect(find.text('TEST_KEY_123'), findsOneWidget);

    await tester.tap(find.text('Sıfırla'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // After reset, text field should be empty
    expect(find.text('TEST_KEY_123'), findsNothing);
  });
}
