import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kafa_sayimi/app.dart';
import 'package:kafa_sayimi/core/models/scan_state.dart';
import 'package:kafa_sayimi/core/providers/scan_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Tapping remaining quota badge opens Kalan Kullanim popup',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const ProviderScope(
        child: KafaSayimiApp(),
      ),
    );

    await tester.pumpAndSettle();

    // Find the remaining quota badge in AppBar
    final quotaBadge = find.textContaining('%');
    expect(quotaBadge, findsOneWidget);

    // Tap quota badge
    await tester.tap(quotaBadge);
    await tester.pumpAndSettle();

    // Verify "Kalan Kullanım" popup opened
    expect(find.text('Kalan Kullanım'), findsOneWidget);
    expect(find.textContaining('Kalan İstek:'), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);

    // Close popup
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    // Verify popup closed
    expect(find.text('Kalan Kullanım'), findsNothing);
  });

  testWidgets('Shows CircularProgressIndicator and Fotoğraf işleniyor... during processing',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Set processing step
    container.read(scanProvider.notifier).setStep(ProcessingStep.runningOcr);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const KafaSayimiApp(),
      ),
    );

    await tester.pump();

    // Verify spinner and text
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Fotoğraf işleniyor...'), findsOneWidget);
    expect(find.textContaining('Gemini Flash'), findsNothing);
  });
}
