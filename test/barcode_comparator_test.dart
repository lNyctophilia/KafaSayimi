import 'package:flutter_test/flutter_test.dart';
import 'package:kafa_sayimi/core/models/barcode_entry.dart';

void main() {
  group('BarcodeComparator tests', () {
    test('Sorts barcodes in natural ascending order', () {
      final barcodes = [
        'RR-0133/2710',
        'RR-0010/1000',
        'RR-0005/0500',
        'AA-0001/0001',
        'RR-0020/2000',
        'RR-2/10',
        'RR-10/20',
      ];

      barcodes.sort(BarcodeComparator.compare);

      expect(barcodes, [
        'AA-0001/0001',
        'RR-2/10',
        'RR-0005/0500',
        'RR-10/20',
        'RR-0010/1000',
        'RR-0020/2000',
        'RR-0133/2710',
      ]);
    });

    test('Empty barcodes placed at the end', () {
      final barcodes = ['', 'RR-0100', '', 'AA-0010'];
      barcodes.sort(BarcodeComparator.compare);

      expect(barcodes[0], 'AA-0010');
      expect(barcodes[1], 'RR-0100');
      expect(barcodes[2], '');
      expect(barcodes[3], '');
    });
  });
}
