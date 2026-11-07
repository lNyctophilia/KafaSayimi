import 'package:flutter_test/flutter_test.dart';
import 'package:kafa_sayimi/core/models/sheet_header_info.dart';
import 'package:kafa_sayimi/core/providers/scan_provider.dart';
import 'package:kafa_sayimi/core/services/gemini_vision_service.dart';

void main() {
  group('Gemini JSON Header and Entry Parsing tests', () {
    test('parses JSON with header object and entries', () {
      const rawJson = '''
      {
        "header": {
          "area": "reyon",
          "venue": "flormar",
          "date": "26_12_2026",
          "raw_top_left": "26.12.2026 - FLORMAR - KADIKÖY",
          "raw_top_right": "REYON"
        },
        "entries": [
          {"barcode": "RR01332710", "quantity": "34", "confidence": 98},
          {"barcode": "RR01332711", "quantity": "12", "confidence": 85}
        ]
      }
      ''';

      final output = GeminiVisionService.parseJsonOutput(rawJson);

      expect(output.entries.length, 2);
      expect(output.entries[0].barcodeCode, 'RR01332710');
      expect(output.entries[0].quantity, '34');
      expect(output.entries[1].confidence, 85);

      expect(output.header.area, 'reyon');
      expect(output.header.venue, 'flormar');
      expect(output.header.date, '26_12_2026');
      expect(output.header.generateFileName(), 'reyon_flormar_26_12_2026.txt');
    });

    test('parses JSON with raw_top_left fallback for venue and date', () {
      const rawJson = '''
      {
        "header": {
          "raw_top_left": "26.12.2026 - FLORMAR - 01",
          "raw_top_right": "Alan: TESTER"
        },
        "entries": [
          {"barcode": "RR100", "quantity": "5", "confidence": 99}
        ]
      }
      ''';

      final output = GeminiVisionService.parseJsonOutput(rawJson);

      expect(output.entries.length, 1);
      expect(output.header.generateFileName(), 'tester_flormar_26_12_2026.txt');
    });

    test('backward compatibility: parses legacy array-only JSON', () {
      const legacyJson = '''
      [
        {"barcode": "RR01332710", "quantity": "34", "confidence": 98}
      ]
      ''';

      final output = GeminiVisionService.parseJsonOutput(legacyJson);

      expect(output.entries.length, 1);
      expect(output.entries[0].barcodeCode, 'RR01332710');
      expect(output.header.isEmpty, isTrue);
      expect(output.header.generateFileName(), isNull);
    });

    test('parses flat map with Turkish keys', () {
      const turkishJson = '''
      {
        "alan": "depo",
        "mekan": "gratis",
        "tarih": "10_01_2027",
        "barkodlar": [
          {"barcode": "GR123", "quantity": "42"}
        ]
      }
      ''';

      final output = GeminiVisionService.parseJsonOutput(turkishJson);

      expect(output.entries.length, 1);
      expect(output.header.generateFileName(), 'depo_gratis_10_01_2027.txt');
    });
  });

  group('ScanNotifier exportFileName tests', () {
    test('uses header generated filename when header is present', () {
      final notifier = ScanNotifier();
      notifier.setEntries(
        [],
        headerInfo: const SheetHeaderInfo(
          area: 'reyon',
          venue: 'flormar',
          date: '26_12_2026',
        ),
      );

      expect(notifier.getExportFileName(), 'reyon_flormar_26_12_2026.txt');
    });

    test('falls back to sayim_ timestamp when header is empty', () {
      final notifier = ScanNotifier();
      notifier.setEntries([], headerInfo: const SheetHeaderInfo());

      final filename = notifier.getExportFileName();
      expect(filename.startsWith('sayim_'), isTrue);
      expect(filename.endsWith('.txt'), isTrue);
    });

    test('respects custom filename set by user', () {
      final notifier = ScanNotifier();
      notifier.setEntries(
        [],
        headerInfo: const SheetHeaderInfo(
          area: 'reyon',
          venue: 'flormar',
          date: '26_12_2026',
        ),
      );

      notifier.setCustomFileName('ozel_sayim_listesi');
      expect(notifier.getExportFileName(), 'ozel_sayim_listesi.txt');
    });
  });
}

