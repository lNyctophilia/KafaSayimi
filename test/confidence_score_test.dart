import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafa_sayimi/core/models/barcode_entry.dart';
import 'package:kafa_sayimi/features/results/widgets/entry_row_widget.dart';

void main() {
  group('BarcodeEntry Confidence Logic', () {
    test('Threshold checks work as specified', () {
      const highEntry = BarcodeEntry(
        id: '1',
        barcodeCode: 'RR-0133/2710',
        quantity: '25',
        confidence: 97.0,
      );
      expect(highEntry.isUnder95, isFalse);
      expect(highEntry.isUnder90, isFalse);
      expect(highEntry.confidencePercentage, 97);

      const midEntry = BarcodeEntry(
        id: '2',
        barcodeCode: 'RR-0134/2711',
        quantity: '12',
        confidence: 92.0,
      );
      expect(midEntry.isUnder95, isTrue);
      expect(midEntry.isUnder90, isFalse);
      expect(midEntry.confidencePercentage, 92);

      const lowEntry = BarcodeEntry(
        id: '3',
        barcodeCode: 'RR-0135/2712',
        quantity: '40',
        confidence: 85.0,
      );
      expect(lowEntry.isUnder95, isTrue);
      expect(lowEntry.isUnder90, isTrue);
      expect(lowEntry.confidencePercentage, 85);
    });
  });

  group('EntryRowWidget Confidence Visuals', () {
    testWidgets('Row with confidence < 90% shows red warning with exclamation mark',
        (tester) async {
      const lowEntry = BarcodeEntry(
        id: '1',
        barcodeCode: 'RR-0133/2710',
        quantity: '15',
        confidence: 85.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EntryRowWidget(
              entry: lowEntry,
              index: 0,
              onChanged: (_) {},
              onDelete: () {},
            ),
          ),
        ),
      );

      // Warning badge text '%85' should be present
      expect(find.text('%85'), findsOneWidget);
      // Warning icon (Icons.error_rounded)
      expect(find.byIcon(Icons.error_rounded), findsOneWidget);
    });

    testWidgets('Row with 90% <= confidence < 95% shows amber warning with exclamation mark',
        (tester) async {
      const midEntry = BarcodeEntry(
        id: '2',
        barcodeCode: 'RR-0134/2711',
        quantity: '34',
        confidence: 92.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EntryRowWidget(
              entry: midEntry,
              index: 0,
              onChanged: (_) {},
              onDelete: () {},
            ),
          ),
        ),
      );

      // Warning badge text '%92' should be present
      expect(find.text('%92'), findsOneWidget);
      // Warning icon (Icons.warning_rounded)
      expect(find.byIcon(Icons.warning_rounded), findsOneWidget);
    });

    testWidgets('Row with confidence >= 95% does not show warning badge',
        (tester) async {
      const safeEntry = BarcodeEntry(
        id: '3',
        barcodeCode: 'RR-0135/2712',
        quantity: '50',
        confidence: 98.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EntryRowWidget(
              entry: safeEntry,
              index: 0,
              onChanged: (_) {},
              onDelete: () {},
            ),
          ),
        ),
      );

      expect(find.text('%98'), findsNothing);
      expect(find.byIcon(Icons.warning_rounded), findsNothing);
      expect(find.byIcon(Icons.error_rounded), findsNothing);
    });
  });
}
