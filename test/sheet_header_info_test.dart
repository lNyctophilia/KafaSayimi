import 'package:flutter_test/flutter_test.dart';
import 'package:kafa_sayimi/core/models/sheet_header_info.dart';

void main() {
  group('SheetHeaderInfo tests', () {
    test('generates expected filename when all fields are present', () {
      const header = SheetHeaderInfo(
        area: 'reyon',
        venue: 'flormar',
        date: '26_12_2026',
      );
      expect(header.generateFileName(), 'reyon_flormar_26_12_2026.txt');
    });

    test('extracts area, venue and date from raw header strings', () {
      final header = SheetHeaderInfo.fromExtracted(
        rawTopLeft: '26.12.2026 - FLORMAR - KADIKÖY',
        rawTopRight: 'REYON',
      );

      expect(header.area, 'REYON');
      expect(header.venue, 'FLORMAR');
      expect(header.date, '26_12_2026');
      expect(header.generateFileName(), 'reyon_flormar_26_12_2026.txt');
    });

    test('handles date with slashes and area prefix', () {
      final header = SheetHeaderInfo.fromExtracted(
        rawTopLeft: '26/12/2026 - FLORMAR - 1002',
        rawTopRight: 'Alan: TESTER',
      );

      expect(header.generateFileName(), 'tester_flormar_26_12_2026.txt');
    });

    test('handles Turkish characters and normalizes safely', () {
      final header = SheetHeaderInfo.fromExtracted(
        rawTopLeft: '15.05.2026 - BEŞİKTAŞ - MERKEZ',
        rawTopRight: 'ÇEKMECE',
      );

      expect(header.generateFileName(), 'cekmece_besiktas_15_05_2026.txt');
    });

    test('handles only area and date when venue is missing', () {
      const header = SheetHeaderInfo(
        area: 'reyon',
        date: '26_12_2026',
      );

      expect(header.generateFileName(), 'reyon_26_12_2026.txt');
    });

    test('handles only venue and date when area is missing', () {
      const header = SheetHeaderInfo(
        venue: 'flormar',
        date: '26_12_2026',
      );

      expect(header.generateFileName(), 'flormar_26_12_2026.txt');
    });

    test('returns null when all fields are empty or whitespace', () {
      const header = SheetHeaderInfo(
        area: '   ',
        venue: '',
        date: null,
      );

      expect(header.generateFileName(), isNull);
    });

    test('merges headers across multi-page scans', () {
      const page1 = SheetHeaderInfo(
        area: 'depo',
      );
      const page2 = SheetHeaderInfo(
        venue: 'flormar',
        date: '26_12_2026',
      );

      final merged = page1.mergeWith(page2);
      expect(merged.generateFileName(), 'depo_flormar_26_12_2026.txt');
    });
  });
}

