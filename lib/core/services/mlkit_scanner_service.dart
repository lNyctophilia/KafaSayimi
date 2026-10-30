import 'dart:ui';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/barcode_entry.dart';

class MLKitScannerService {
  static final _textRecognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  static final _barcodeScanner = BarcodeScanner(formats: [
    BarcodeFormat.code128,
    BarcodeFormat.code39,
    BarcodeFormat.code93,
    BarcodeFormat.ean13,
    BarcodeFormat.ean8,
    BarcodeFormat.upca,
    BarcodeFormat.upce,
    BarcodeFormat.itf,
    BarcodeFormat.all,
  ]);

  static final _barcodeRegex = RegExp(
    r'[Rr]{2}-?\d{3,4}[\s]*[/\\]?[\s]*\d{0,5}',
    caseSensitive: false,
  );

  static final _adetRegex =
      RegExp(r'[Aa]d[eo][ct]t?\s*:?', caseSensitive: false);

  /// Process the image file path using on-device ML Kit
  static Future<List<BarcodeEntry>> processImage(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);

    final barcodeFuture = _barcodeScanner.processImage(inputImage);
    final textFuture = _textRecognizer.processImage(inputImage);

    final results = await Future.wait([barcodeFuture, textFuture]);
    final List<Barcode> barcodes = results[0] as List<Barcode>;
    final RecognizedText recognizedText = results[1] as RecognizedText;

    return _correlate(barcodes, recognizedText);
  }

  static List<BarcodeEntry> _correlate(
    List<Barcode> barcodes,
    RecognizedText recognizedText,
  ) {
    // 1. Collect all detected text elements
    final allElements = <_BoxItem>[];
    final barcodeTextLines = <_BoxItem>[];

    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        final cleaned = line.text.replaceAll(' ', '');
        if (_barcodeRegex.hasMatch(cleaned)) {
          barcodeTextLines.add(_BoxItem(
            text: line.text,
            rect: line.boundingBox,
            isBarcode: true,
          ));
        }
        for (final el in line.elements) {
          allElements.add(_BoxItem(
            text: el.text,
            rect: el.boundingBox,
            isBarcode: false,
          ));
        }
      }
    }

    // 2. Build candidate barcode list (merging barcode scanner & OCR text)
    final candidateBarcodes = <_BarcodeCandidate>[];

    // From Barcode scanner
    for (final b in barcodes) {
      final val = b.rawValue ?? '';
      if (val.isNotEmpty) {
        candidateBarcodes.add(_BarcodeCandidate(
          code: val,
          rect: b.boundingBox,
        ));
      }
    }

    // From OCR text lines (if not already covered by a barcode bounding box)
    for (final line in barcodeTextLines) {
      final overlaps =
          candidateBarcodes.any((c) => _overlaps(c.rect, line.rect));
      if (!overlaps) {
        candidateBarcodes.add(_BarcodeCandidate(
          code: _normalizeBarcodeCode(line.text),
          rect: line.rect,
        ));
      } else {
        final existing =
            candidateBarcodes.firstWhere((c) => _overlaps(c.rect, line.rect));
        if (line.text.toUpperCase().startsWith('RR-') &&
            !existing.code.toUpperCase().startsWith('RR-')) {
          existing.code = _normalizeBarcodeCode(line.text);
        }
      }
    }

    if (candidateBarcodes.isEmpty) {
      return [];
    }

    // 3. Estimate average dimensions
    double avgHeight = 0;
    double avgWidth = 0;
    for (final c in candidateBarcodes) {
      avgHeight += c.rect.height;
      avgWidth += c.rect.width;
    }
    avgHeight /= candidateBarcodes.length;
    avgWidth /= candidateBarcodes.length;
    if (avgHeight < 20) avgHeight = 40;
    if (avgWidth < 50) avgWidth = 150;

    // 4. For each barcode, find the quantity in its cell
    final entries = <BarcodeEntry>[];
    int idCounter = 0;

    for (final bc in candidateBarcodes) {
      final bRect = bc.rect;

      // Define cell search region:
      // In the table, the "Adet:" label and the handwritten number
      // are to the right of the barcode and slightly below / on the same level.
      final searchLeft = bRect.left + bRect.width * 0.4;
      final searchRight = bRect.right + avgWidth * 1.5;
      final searchTop = bRect.top - avgHeight * 0.4;
      final searchBottom = bRect.bottom + avgHeight * 2.2;

      final cellElements = allElements.where((el) {
        final c = el.rect.center;
        return c.dx >= searchLeft &&
            c.dx <= searchRight &&
            c.dy >= searchTop &&
            c.dy <= searchBottom;
      }).toList();

      // Find "Adet:" label if present
      _BoxItem? adetLabel;
      for (final el in cellElements) {
        if (_adetRegex.hasMatch(el.text)) {
          adetLabel = el;
          break;
        }
      }

      // Quantity candidate tokens:
      final quantityCandidates = <_ScoredQuantity>[];

      for (final el in cellElements) {
        // Skip Adet label itself
        if (_adetRegex.hasMatch(el.text)) continue;

        final rawText = el.text.trim();
        final cleanedNum = _cleanHandwrittenNumber(rawText);

        if (cleanedNum.isNotEmpty) {
          // If the number is part of the barcode's own code (e.g. 2710 or 0133), ignore it
          if (bc.code.contains(cleanedNum) && cleanedNum.length >= 3) {
            continue;
          }

          // Calculate spatial score (closer to Adet label or below Adet is better)
          double distScore = 1000;
          if (adetLabel != null) {
            final dy = el.rect.center.dy - adetLabel.rect.center.dy;
            final dx = el.rect.center.dx - adetLabel.rect.center.dx;

            // Ideal position: right under "Adet:" (dy > 0) or directly to the right
            if (dy >= -5 && dy <= avgHeight * 1.8 && dx.abs() < avgWidth * 0.8) {
              distScore = dy.abs() * 0.5 + dx.abs() * 0.8;
            } else {
              distScore = _distSq(el.rect.center, adetLabel.rect.center);
            }
          } else {
            // No Adet label, distance to barcode right-center
            final targetPoint = Offset(bRect.right + avgWidth * 0.5, bRect.center.dy);
            distScore = _distSq(el.rect.center, targetPoint);
          }

          quantityCandidates.add(_ScoredQuantity(
            quantity: cleanedNum,
            score: distScore,
            isDirectDigits: RegExp(r'^\d{1,3}$').hasMatch(rawText),
          ));
        }
      }

      String quantity = '';
      bool isConfident = false;

      if (quantityCandidates.isNotEmpty) {
        // Sort: prefer pure digits first, then closest distance
        quantityCandidates.sort((a, b) {
          if (a.isDirectDigits && !b.isDirectDigits) return -1;
          if (!a.isDirectDigits && b.isDirectDigits) return 1;
          return a.score.compareTo(b.score);
        });

        quantity = quantityCandidates.first.quantity;
        isConfident = quantityCandidates.first.isDirectDigits;
      }

      entries.add(BarcodeEntry(
        id: (idCounter++).toString(),
        barcodeCode: _normalizeBarcodeCode(bc.code),
        quantity: quantity,
        isQuantityConfident: isConfident,
        confidence: isConfident ? 97.0 : 88.0,
      ));
    }

    // 5. SORT BARCODES IN NATURAL ALPHANUMERIC ORDER (RR-0133, RR-0134...)
    entries.sort((a, b) => _naturalCompare(a.barcodeCode, b.barcodeCode));

    return entries;
  }

  /// Cleans OCR quirks on handwritten digits:
  /// Examples: 'o' or 'O' -> '0', 'l' or 'I' or '|' -> '1', 's' or 'S' -> '5', 'q' or 'g' -> '9'
  static String _cleanHandwrittenNumber(String text) {
    var s = text.trim();
    if (s.isEmpty) return '';

    // Direct match: 1-3 digits
    if (RegExp(r'^\d{1,3}$').hasMatch(s)) {
      return s;
    }

    // Try common OCR confusion on handwritten characters
    var mapped = s
        .replaceAll('O', '0')
        .replaceAll('o', '0')
        .replaceAll('l', '1')
        .replaceAll('I', '1')
        .replaceAll('|', '1')
        .replaceAll('!', '1')
        .replaceAll('S', '5')
        .replaceAll('s', '5')
        .replaceAll('B', '8')
        .replaceAll('Z', '2')
        .replaceAll('z', '2')
        .replaceAll('q', '9')
        .replaceAll('g', '9');

    // Extract contiguous digits if present
    final match = RegExp(r'\d{1,3}').firstMatch(mapped);
    if (match != null) {
      return match.group(0)!;
    }

    return '';
  }

  /// Natural alphanumeric sorting: RR-0133 comes before RR-0134
  static int _naturalCompare(String a, String b) {
    final re = RegExp(r'(\d+)|(\D+)');
    final matchesA = re.allMatches(a).toList();
    final matchesB = re.allMatches(b).toList();

    for (int i = 0; i < matchesA.length && i < matchesB.length; i++) {
      final strA = matchesA[i].group(0)!;
      final strB = matchesB[i].group(0)!;

      final numA = int.tryParse(strA);
      final numB = int.tryParse(strB);

      if (numA != null && numB != null) {
        final cmp = numA.compareTo(numB);
        if (cmp != 0) return cmp;
      } else {
        final cmp = strA.compareTo(strB);
        if (cmp != 0) return cmp;
      }
    }
    return matchesA.length.compareTo(matchesB.length);
  }

  static bool _overlaps(Rect a, Rect b) {
    final expandedA = a.inflate(20);
    return expandedA.overlaps(b);
  }

  static double _distSq(Offset a, Offset b) {
    final dx = a.dx - b.dx;
    final dy = a.dy - b.dy;
    return dx * dx + dy * dy;
  }

  static String _normalizeBarcodeCode(String raw) {
    var code = raw.trim().toUpperCase();
    code = code.replaceAllMapped(
      RegExp(r'^RR(\d{4})'),
      (m) => 'RR-${m.group(1)}',
    );
    code = code.replaceAll(RegExp(r'\s*/\s*'), '/');
    return code;
  }

  static void dispose() {
    _textRecognizer.close();
    _barcodeScanner.close();
  }
}

class _BoxItem {
  final String text;
  final Rect rect;
  final bool isBarcode;

  _BoxItem({
    required this.text,
    required this.rect,
    required this.isBarcode,
  });
}

class _BarcodeCandidate {
  String code;
  final Rect rect;

  _BarcodeCandidate({
    required this.code,
    required this.rect,
  });
}

class _ScoredQuantity {
  final String quantity;
  final double score;
  final bool isDirectDigits;

  _ScoredQuantity({
    required this.quantity,
    required this.score,
    required this.isDirectDigits,
  });
}
