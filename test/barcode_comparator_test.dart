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

    test('Sorts entries by page first, then barcode ascending within each page', () {
      final entries = [
        const BarcodeEntry(id: '1', barcodeCode: 'RR-0020/2000', quantity: '5', pageIndex: 2),
        const BarcodeEntry(id: '2', barcodeCode: 'RR-0133/2710', quantity: '10', pageIndex: 1),
        const BarcodeEntry(id: '3', barcodeCode: 'AA-0001/0001', quantity: '8', pageIndex: 2),
        const BarcodeEntry(id: '4', barcodeCode: 'RR-0010/1000', quantity: '12', pageIndex: 1),
      ];

      entries.sort((a, b) {
        final pageA = a.pageIndex ?? 1;
        final pageB = b.pageIndex ?? 1;
        final pageCmp = pageA.compareTo(pageB);
        if (pageCmp != 0) return pageCmp;
        return BarcodeComparator.compare(a.barcodeCode, b.barcodeCode);
      });

      expect(entries.map((e) => '${e.pageIndex}:${e.barcodeCode}').toList(), [
        '1:RR-0010/1000',
        '1:RR-0133/2710',
        '2:AA-0001/0001',
        '2:RR-0020/2000',
      ]);
    });
  });
}
