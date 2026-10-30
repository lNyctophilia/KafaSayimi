import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafa_sayimi/core/models/barcode_entry.dart';
import 'package:kafa_sayimi/features/results/widgets/entry_row_widget.dart';

void main() {
  group('BarcodeEntry Confidence Logic', () {
    test('Threshold checks work as specified (< 92% yellow, < 87% red)', () {
      const highEntry = BarcodeEntry(
        id: '1',
        barcodeCode: 'RR-0133/2710',
        quantity: '25',
        confidence: 95.0,
      );
      expect(highEntry.isUnder92, isFalse);
      expect(highEntry.isUnder87, isFalse);
      expect(highEntry.confidencePercentage, 95);

      const thresholdEntry92 = BarcodeEntry(
        id: '1b',
        barcodeCode: 'RR-0133/2710',
        quantity: '25',
        confidence: 92.0,
      );
      expect(thresholdEntry92.isUnder92, isFalse);
      expect(thresholdEntry92.isUnder87, isFalse);

      const midEntry = BarcodeEntry(
        id: '2',
        barcodeCode: 'RR-0134/2711',
        quantity: '12',
        confidence: 90.0,
      );
      expect(midEntry.isUnder92, isTrue);
      expect(midEntry.isUnder87, isFalse);
      expect(midEntry.confidencePercentage, 90);

      const thresholdEntry87 = BarcodeEntry(
        id: '2b',
        barcodeCode: 'RR-0134/2711',
        quantity: '12',
        confidence: 87.0,
      );
      expect(thresholdEntry87.isUnder92, isTrue);
      expect(thresholdEntry87.isUnder87, isFalse);

      const lowEntry = BarcodeEntry(
        id: '3',
        barcodeCode: 'RR-0135/2712',
        quantity: '40',
        confidence: 85.0,
      );
      expect(lowEntry.isUnder92, isTrue);
      expect(lowEntry.isUnder87, isTrue);
      expect(lowEntry.confidencePercentage, 85);
    });
  });

  group('EntryRowWidget Confidence Visuals', () {
    testWidgets('Row with confidence < 87% shows red warning with exclamation mark',
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
      // Warning icon (Icons.error_outline_rounded)
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    });

    testWidgets('Row with 87% <= confidence < 92% shows amber warning with exclamation mark',
        (tester) async {
      const midEntry = BarcodeEntry(
        id: '2',
        barcodeCode: 'RR-0134/2711',
        quantity: '34',
        confidence: 90.0,
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

      // Warning badge text '%90' should be present
      expect(find.text('%90'), findsOneWidget);
      // Warning icon (Icons.warning_amber_rounded)
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('Row with confidence >= 92% does not show warning badge',
        (tester) async {
      const safeEntry = BarcodeEntry(
        id: '3',
        barcodeCode: 'RR-0135/2712',
        quantity: '50',
        confidence: 92.0,
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

      expect(find.text('%92'), findsNothing);
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
      expect(find.byIcon(Icons.error_outline_rounded), findsNothing);
    });

    testWidgets('Confidence badge aligns vertically with the quantity box',
        (tester) async {
      const midEntry = BarcodeEntry(
        id: '2',
        barcodeCode: 'RR-0134/2711',
        quantity: '34',
        confidence: 90.0,
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

      // Find TextFormField for quantity
      final qtyFinder = find.widgetWithText(TextFormField, '34');
      expect(qtyFinder, findsOneWidget);
      final qtyRenderBox = tester.renderObject<RenderBox>(qtyFinder);
      final qtyTop = qtyRenderBox.localToGlobal(Offset.zero).dy;
      final qtyHeight = qtyRenderBox.size.height;

      // Find the confidence badge
      final badgeTextFinder = find.text('%90');
      expect(badgeTextFinder, findsOneWidget);

      final badgeContainerFinder = find.ancestor(
        of: badgeTextFinder,
        matching: find.byType(Container),
      ).first;
      final badgeRenderBox = tester.renderObject<RenderBox>(badgeContainerFinder);
      final badgeTop = badgeRenderBox.localToGlobal(Offset.zero).dy;
      final badgeHeight = badgeRenderBox.size.height;

      // The top and height of the badge should match the quantity input box closely
      expect((badgeTop - qtyTop).abs(), lessThanOrEqualTo(2.0),
          reason: 'Badge top ($badgeTop) should match quantity input top ($qtyTop)');
      expect((badgeHeight - qtyHeight).abs(), lessThanOrEqualTo(2.0),
          reason: 'Badge height ($badgeHeight) should match quantity input height ($qtyHeight)');
    });
  });
}
