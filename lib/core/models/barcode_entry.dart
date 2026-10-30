class BarcodeEntry {
  final String id;
  final String barcodeCode; // örn: RR-0133/2710
  final String quantity;    // örn: 34
  final bool isQuantityConfident;
  final double confidence;   // Eminlik skoru: 0.0 - 100.0 (örn: 98.0, 92.0, 85.0)

  const BarcodeEntry({
    required this.id,
    required this.barcodeCode,
    required this.quantity,
    this.isQuantityConfident = true,
    this.confidence = 100.0,
  });

  /// Yüzde olarak tam sayı eminlik skoru (0 - 100)
  int get confidencePercentage => confidence.clamp(0.0, 100.0).round();

  /// %95 altı eminlik uyarısı (veya güvensiz işaretlenmişse)
  bool get isUnder95 => confidence < 95.0 || !isQuantityConfident;

  /// %90 altı kritik kırmızı uyarı
  bool get isUnder90 => confidence < 90.0 || (!isQuantityConfident && confidence < 95.0);

  BarcodeEntry copyWith({
    String? barcodeCode,
    String? quantity,
    bool? isQuantityConfident,
    double? confidence,
  }) {
    return BarcodeEntry(
      id: id,
      barcodeCode: barcodeCode ?? this.barcodeCode,
      quantity: quantity ?? this.quantity,
      isQuantityConfident: isQuantityConfident ?? this.isQuantityConfident,
      confidence: confidence ?? this.confidence,
    );
  }

  String toOutputLine() => '$barcodeCode, $quantity';

  @override
  String toString() =>
      'BarcodeEntry(code: $barcodeCode, qty: $quantity, conf: $confidencePercentage%, confident: $isQuantityConfident)';
}
