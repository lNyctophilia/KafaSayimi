import 'dart:convert';
import '../models/barcode_entry.dart';

/// Parses raw Tesseract.js OCR JSON output into a list of [BarcodeEntry].
///
/// The count sheet has 3 columns × ~11 rows of cells. Each cell contains:
///   - A printed barcode code (e.g. RR-0133/2710)
///   - An "Adet:" label
///   - A handwritten digit (the quantity)
///
/// Strategy:
///  1. Parse the JSON from Tesseract and extract line texts.
///  2. Use positional word data to pair barcodes with their quantities.
///  3. Fall back to regex on the full text when positional data is incomplete.
class TextParserService {
  // Primary: RR-0133/2710 with optional space around slash
  // Also catches OCR errors like RR0133/2710, Rr-0133 /2710
  static final _barcodeRegex = RegExp(
    r'[Rr]{2}-?\d{3,4}[\s]*[/\\][\s]*\d{3,5}',
    caseSensitive: false,
  );

  // Matches the short form too: just "RR-0133" when slash part was missed
  static final _barcodeShortRegex = RegExp(
    r'[Rr]{2}-\d{3,4}',
    caseSensitive: false,
  );

  // Quantity: 1–3 digit number ONLY.
  // 4-digit numbers are likely barcode parts (e.g. 2710), not quantities.
  // Must be the whole trimmed string.
  static final _quantityRegex = RegExp(r'^\d{1,3}$');

  // "Adet:" label — OCR may produce "Adet", "Adet:", "Adct:", "Adot:" etc.
  static final _adetRegex = RegExp(r'[Aa]d[eo][ct]t?\s*:?', caseSensitive: false);

  /// Parse Tesseract JSON (string) into entries.
  static List<BarcodeEntry> parseOcrJson(String ocrJson) {
    try {
      final Map<String, dynamic> data =
          jsonDecode(ocrJson) as Map<String, dynamic>;
      final lines = data['lines'] as List<dynamic>? ?? [];
      final words = data['words'] as List<dynamic>? ?? [];

      List<BarcodeEntry> entries = [];

      if (words.isNotEmpty) {
        entries = _parseByPosition(words, lines);
      }

      // If positional parsing yielded nothing or very few results, fall back
      if (entries.isEmpty) {
        final fullText = data['text'] as String? ?? '';
        entries = _parseByText(fullText);
      }

      return entries;
    } catch (e) {
      return [];
    }
  }

  /// Position-based parsing: groups words into cells using their y-coordinates.
  static List<BarcodeEntry> _parseByPosition(
    List<dynamic> words,
    List<dynamic> lines,
  ) {
    final wordList = words.map((w) => _Word.fromJson(w as Map<String, dynamic>)).toList();

    // ── Step 1: Find all barcode words ───────────────────────────────────────
    // A barcode word is one whose text (possibly joined with next word) matches
    // the barcode pattern. We join adjacent words within the same line to
    // reconstruct "RR-0133 /2710" which OCR may split.
    final barcodeWords = <_BarcodeHit>[];

    for (int i = 0; i < wordList.length; i++) {
      final w = wordList[i];
      final cleaned = w.text.replaceAll(' ', '');

      // Try the full barcode pattern first
      if (_barcodeRegex.hasMatch(cleaned)) {
        barcodeWords.add(_BarcodeHit(word: w, rawText: cleaned));
        continue;
      }

      // Try joining with next word (OCR splits "RR-0133" and "/2710")
      if (i + 1 < wordList.length) {
        final next = wordList[i + 1];
        final joined = (w.text + next.text).replaceAll(' ', '');
        if (_barcodeRegex.hasMatch(joined)) {
          // Use a merged word spanning both bboxes
          final merged = _Word(
            text: joined,
            confidence: (w.confidence + next.confidence) / 2,
            x0: w.x0,
            y0: w.y0 < next.y0 ? w.y0 : next.y0,
            x1: next.x1 > w.x1 ? next.x1 : w.x1,
            y1: w.y1 > next.y1 ? w.y1 : next.y1,
          );
          barcodeWords.add(_BarcodeHit(word: merged, rawText: joined));
          i++; // skip next word — already consumed
          continue;
        }
      }

      // Short form fallback: "RR-0133" alone (slash part missed)
      if (_barcodeShortRegex.hasMatch(cleaned) && !cleaned.contains('/')) {
        barcodeWords.add(_BarcodeHit(word: w, rawText: cleaned, shortForm: true));
      }
    }

    if (barcodeWords.isEmpty) {
      final fullText = lines
          .map((l) => (l['text'] as String?) ?? '')
          .join('\n');
      return _parseByText(fullText);
    }

    // ── Step 2: For each barcode, find its quantity ──────────────────────────
    // Strategy:
    //  a) Find "Adet:" label that is in the same cell (close x, below or same y)
    //  b) Find the nearest 1–3 digit number to that "Adet:" label
    //     — It must NOT be a barcode-part number (like 2710)
    //     — It must have confidence > 40
    //  c) If no "Adet:" found, skip (don't guess a quantity)

    final entries = <BarcodeEntry>[];
    int idCounter = 0;

    for (final hit in barcodeWords) {
      final bw = hit.word;
      final barcodeCode = _normalizeBarcodeCode(hit.rawText);

      // Cell width estimate: the sheet has 3 columns, so each column ≈ 1/3 of image
      // We use bw.width * 3 as a rough horizontal search radius
      final cellWidth = bw.width * 4.0;
      final cellHeight = bw.height * 8.0; // search 8 line-heights below barcode

      // Find "Adet:" labels in the same column and below this barcode
      final adetCandidates = wordList.where((w) {
        if (!_adetRegex.hasMatch(w.text)) return false;
        final dx = (w.centerX - bw.centerX).abs();
        final dy = w.centerY - bw.centerY;
        return dx < cellWidth && dy >= -bw.height && dy <= cellHeight;
      }).toList();

      adetCandidates.sort((a, b) =>
          (a.centerY - bw.centerY).abs().compareTo((b.centerY - bw.centerY).abs()));

      String quantity = '';
      bool confident = false;

      if (adetCandidates.isNotEmpty) {
        final adet = adetCandidates.first;

        // Search for a quantity word near the "Adet:" label
        // — same row or 1-2 rows below
        // — to the right of or below the Adet label
        // — 1–3 digit number only
        final qtyCandidates = wordList.where((w) {
          final text = w.text.trim();
          if (!_quantityRegex.hasMatch(text)) return false;

          // Must be right of or below the Adet: label
          final dx = w.centerX - adet.centerX;
          final dy = w.centerY - adet.centerY;
          if (dx < -adet.width) return false; // too far left
          if (dy < -adet.height) return false; // above the Adet label
          if (dy > adet.height * 4) return false; // too far below

          // Must be in the same column as the barcode (not an adjacent cell's number)
          final dxFromBarcode = (w.centerX - bw.centerX).abs();
          if (dxFromBarcode > cellWidth) return false;

          // Must have decent confidence
          if (w.confidence < 40) return false;

          return true;
        }).toList();

        qtyCandidates.sort((a, b) => _dist(a, adet).compareTo(_dist(b, adet)));

        if (qtyCandidates.isNotEmpty) {
          quantity = qtyCandidates.first.text.trim();
          confident = qtyCandidates.first.confidence > 60;
        }
        // If no quantity found near Adet: → leave quantity empty (blank cell)
      }

      entries.add(BarcodeEntry(
        id: (idCounter++).toString(),
        barcodeCode: barcodeCode,
        quantity: quantity,
        isQuantityConfident: confident,
        confidence: confident ? 96.0 : 88.0,
      ));
    }

    return entries;
  }

  static double _dist(_Word a, _Word b) {
    final dx = a.centerX - b.centerX;
    final dy = a.centerY - b.centerY;
    return dx * dx + dy * dy;
  }

  /// Text-only fallback: scan raw OCR text line by line.
  static List<BarcodeEntry> _parseByText(String text) {
    final lines = text.split('\n').map((l) => l.trim()).toList();
    final entries = <BarcodeEntry>[];
    int idCounter = 0;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final match = _barcodeRegex.firstMatch(line);
      if (match == null) continue;

      final rawCode = match.group(0)!.replaceAll(' ', '');
      final barcodeCode = _normalizeBarcodeCode(rawCode);

      // Search the next few lines for a quantity after "Adet:"
      String quantity = '';
      bool confident = false;

      for (int j = i + 1; j < lines.length && j <= i + 4; j++) {
        final nextLine = lines[j];
        if (_adetRegex.hasMatch(nextLine)) {
          // Quantity may be in the same line after "Adet:"
          final afterAdet =
              nextLine.replaceAll(_adetRegex, '').trim();
          if (_quantityRegex.hasMatch(afterAdet)) {
            quantity = afterAdet;
            confident = true;
            break;
          }
          // Or in the next line
          if (j + 1 < lines.length) {
            final maybeQty = lines[j + 1].trim();
            if (_quantityRegex.hasMatch(maybeQty)) {
              quantity = maybeQty;
              confident = true;
              break;
            }
          }
        }
        // Also: quantity standalone on a line within the barcode's cell range
        if (_quantityRegex.hasMatch(nextLine)) {
          // Only if we haven't found a better match
          if (quantity.isEmpty) {
            quantity = nextLine;
            confident = false;
          }
        }
        // Stop if we hit the next barcode
        if (_barcodeRegex.hasMatch(nextLine) && j > i) break;
      }

      entries.add(BarcodeEntry(
        id: (idCounter++).toString(),
        barcodeCode: barcodeCode,
        quantity: quantity,
        isQuantityConfident: confident,
        confidence: confident ? 96.0 : 88.0,
      ));
    }

    return entries;
  }

  /// Normalize OCR-mangled barcode codes to canonical format: RR-XXXX/YYYY
  static String _normalizeBarcodeCode(String raw) {
    // Ensure uppercase
    var code = raw.toUpperCase();
    // Fix missing dash: RRXXXX -> RR-XXXX
    code = code.replaceAllMapped(
      RegExp(r'^RR(\d{4})'),
      (m) => 'RR-${m.group(1)}',
    );
    // Normalize spaces around slash
    code = code.replaceAll(RegExp(r'\s*/\s*'), '/');
    return code;
  }
}

class _BarcodeHit {
  final _Word word;
  final String rawText;
  final bool shortForm;

  _BarcodeHit({
    required this.word,
    required this.rawText,
    this.shortForm = false,
  });
}

class _Word {
  final String text;
  final double confidence;
  final double x0, y0, x1, y1;

  _Word({
    required this.text,
    required this.confidence,
    required this.x0,
    required this.y0,
    required this.x1,
    required this.y1,
  });

  double get centerX => (x0 + x1) / 2;
  double get centerY => (y0 + y1) / 2;
  double get width => x1 - x0;
  double get height => y1 - y0;

  factory _Word.fromJson(Map<String, dynamic> json) {
    final bbox = json['bbox'] as Map<String, dynamic>? ?? {};
    return _Word(
      text: (json['text'] as String?) ?? '',
      confidence: ((json['confidence'] as num?) ?? 0).toDouble(),
      x0: ((bbox['x0'] as num?) ?? 0).toDouble(),
      y0: ((bbox['y0'] as num?) ?? 0).toDouble(),
      x1: ((bbox['x1'] as num?) ?? 0).toDouble(),
      y1: ((bbox['y1'] as num?) ?? 0).toDouble(),
    );
  }
}
