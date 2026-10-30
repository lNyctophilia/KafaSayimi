import 'dart:typed_data';
import 'barcode_entry.dart';

enum ProcessingStep {
  idle,
  loadingImage,
  runningOcr,
  parsing,
  done,
  error,
}

class ScanState {
  final List<BarcodeEntry> entries;
  final ProcessingStep step;
  final int ocrProgress; // 0-100
  final String? errorMessage;
  final String? imageDataUrl;
  final Uint8List? imageBytes;

  const ScanState({
    this.entries = const [],
    this.step = ProcessingStep.idle,
    this.ocrProgress = 0,
    this.errorMessage,
    this.imageDataUrl,
    this.imageBytes,
  });

  bool get isProcessing =>
      step == ProcessingStep.loadingImage ||
      step == ProcessingStep.runningOcr ||
      step == ProcessingStep.parsing;

  String get statusMessage {
    switch (step) {
      case ProcessingStep.idle:
        return '';
      case ProcessingStep.loadingImage:
      case ProcessingStep.runningOcr:
      case ProcessingStep.parsing:
        return 'Fotoğraf işleniyor...';
      case ProcessingStep.done:
        return '${entries.length} kayıt bulundu';
      case ProcessingStep.error:
        return 'Hata: ${errorMessage ?? "Bilinmeyen hata"}';
    }
  }

  ScanState copyWith({
    List<BarcodeEntry>? entries,
    ProcessingStep? step,
    int? ocrProgress,
    String? errorMessage,
    String? imageDataUrl,
    Uint8List? imageBytes,
  }) {
    return ScanState(
      entries: entries ?? this.entries,
      step: step ?? this.step,
      ocrProgress: ocrProgress ?? this.ocrProgress,
      errorMessage: errorMessage ?? this.errorMessage,
      imageDataUrl: imageDataUrl ?? this.imageDataUrl,
      imageBytes: imageBytes ?? this.imageBytes,
    );
  }
}
