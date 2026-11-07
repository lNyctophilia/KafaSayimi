class BarcodeEntry {
  final String id;
  final String barcodeCode; // örn: RR01332710
  final String quantity;    // örn: 34
  final bool isQuantityConfident;
  final double confidence;   // Eminlik skoru: 0.0 - 100.0 (örn: 98.0, 92.0, 85.0)
  final int? pageIndex;      // 1-based sayfa numarası (örn: 1, 2, 3...)

  const BarcodeEntry({
    required this.id,
    required this.barcodeCode,
    required this.quantity,
    this.isQuantityConfident = true,
    this.confidence = 100.0,
    this.pageIndex,
  });

  /// Yüzde olarak tam sayı eminlik skoru (0 - 100)
  int get confidencePercentage => confidence.clamp(0.0, 100.0).round();

  /// %92 altı eminlik uyarısı (%92'den düşükse sarı)
  bool get isUnder92 => confidence < 92.0 || !isQuantityConfident;

  /// %87 altı kritik kırmızı uyarı (yalnızca 87'nin altındaysa kırmızı)
  bool get isUnder87 => confidence < 87.0;

  /// Geriye dönük uyumluluk aliasları
  bool get isUnder95 => isUnder92;
  bool get isUnder90 => isUnder87;

  BarcodeEntry copyWith({
    String? id,
    String? barcodeCode,
    String? quantity,
    bool? isQuantityConfident,
    double? confidence,
    int? pageIndex,
  }) {
    return BarcodeEntry(
      id: id ?? this.id,
      barcodeCode: barcodeCode ?? this.barcodeCode,
      quantity: quantity ?? this.quantity,
      isQuantityConfident: isQuantityConfident ?? this.isQuantityConfident,
      confidence: confidence ?? this.confidence,
      pageIndex: pageIndex ?? this.pageIndex,
    );
  }

  String toOutputLine() {
    final cleanCode = barcodeCode.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final cleanQty = quantity.replaceAll(RegExp(r'[^0-9]'), '');
    return '$cleanCode,$cleanQty,';
  }

  @override
  String toString() =>
      'BarcodeEntry(code: $barcodeCode, qty: $quantity, conf: $confidencePercentage%, confident: $isQuantityConfident, page: $pageIndex)';
}

/// Barkod kodlarını doğal artan (A-Z, 0-9) sırada karşılaştırır
class BarcodeComparator {
  /// Compares two barcode strings in natural ascending order (A to Z, 0 to 9).
  /// Numbers within strings are compared by their numerical value.
  static int compare(String a, String b) {
    final cleanA = a.trim();
    final cleanB = b.trim();

    if (cleanA.isEmpty && cleanB.isEmpty) return 0;
    if (cleanA.isEmpty) return 1;
    if (cleanB.isEmpty) return -1;

    final regExp = RegExp(r'(\d+)|(\D+)');
    final matchesA = regExp.allMatches(cleanA.toUpperCase()).toList();
    final matchesB = regExp.allMatches(cleanB.toUpperCase()).toList();

    final minLen = matchesA.length < matchesB.length ? matchesA.length : matchesB.length;

    for (int i = 0; i < minLen; i++) {
      final tokenA = matchesA[i].group(0)!;
      final tokenB = matchesB[i].group(0)!;

      final numA = BigInt.tryParse(tokenA);
      final numB = BigInt.tryParse(tokenB);

      if (numA != null && numB != null) {
        final cmp = numA.compareTo(numB);
        if (cmp != 0) return cmp;
      } else {
        final cmp = tokenA.compareTo(tokenB);
        if (cmp != 0) return cmp;
      }
    }

    return matchesA.length.compareTo(matchesB.length);
  }
}
