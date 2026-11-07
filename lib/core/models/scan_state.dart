import 'dart:typed_data';
import 'barcode_entry.dart';
import 'sheet_header_info.dart';

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
  final List<Uint8List> allImageBytes;
  final List<String?> allImagePaths;
  final int currentProcessingPage;
  final int totalPagesToProcess;
  final String? statusDetail;
  final SheetHeaderInfo? headerInfo;
  final String? customFileName;

  const ScanState({
    this.entries = const [],
    this.step = ProcessingStep.idle,
    this.ocrProgress = 0,
    this.errorMessage,
    this.imageDataUrl,
    this.imageBytes,
    this.allImageBytes = const [],
    this.allImagePaths = const [],
    this.currentProcessingPage = 0,
    this.totalPagesToProcess = 0,
    this.statusDetail,
    this.headerInfo,
    this.customFileName,
  });

  /// Dışa aktarma veya paylaşım için dosya adı belirler.
  /// Fotoğrafta alan (reyon/depo vb.), mekan (flormar vb.) veya tarih tespit edildiyse
  /// 'reyon_flormar_26_12_2026.txt' tarzı format üretir.
  /// Hiçbiri yoksa varsayılan 'sayim_YYYY-MM-DDTHH-mm-ss.txt' formatına döner.
  String get exportFileName {
    if (customFileName != null && customFileName!.trim().isNotEmpty) {
      var name = customFileName!.trim();
      if (!name.endsWith('.txt')) name = '$name.txt';
      return name;
    }
    final generated = headerInfo?.generateFileName();
    if (generated != null && generated.isNotEmpty) {
      return generated;
    }
    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .substring(0, 19);
    return 'sayim_$timestamp.txt';
  }

  bool get isProcessing =>
      step == ProcessingStep.loadingImage ||
      step == ProcessingStep.runningOcr ||
      step == ProcessingStep.parsing;

  String get statusMessage {
    switch (step) {
      case ProcessingStep.idle:
        return '';
      case ProcessingStep.loadingImage:
        return totalPagesToProcess > 1
            ? '$totalPagesToProcess sayfa yükleniyor...'
            : 'Fotoğraf yükleniyor...';
      case ProcessingStep.runningOcr:
      case ProcessingStep.parsing:
        if (statusDetail != null && statusDetail!.isNotEmpty) {
          return statusDetail!;
        }
        if (totalPagesToProcess > 1) {
          return 'Sayfalar taranıyor ($currentProcessingPage / $totalPagesToProcess)...';
        }
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
    List<Uint8List>? allImageBytes,
    List<String?>? allImagePaths,
    int? currentProcessingPage,
    int? totalPagesToProcess,
    String? statusDetail,
    SheetHeaderInfo? headerInfo,
    String? customFileName,
  }) {
    return ScanState(
      entries: entries ?? this.entries,
      step: step ?? this.step,
      ocrProgress: ocrProgress ?? this.ocrProgress,
      errorMessage: errorMessage ?? this.errorMessage,
      imageDataUrl: imageDataUrl ?? this.imageDataUrl,
      imageBytes: imageBytes ?? this.imageBytes,
      allImageBytes: allImageBytes ?? this.allImageBytes,
      allImagePaths: allImagePaths ?? this.allImagePaths,
      currentProcessingPage:
          currentProcessingPage ?? this.currentProcessingPage,
      totalPagesToProcess: totalPagesToProcess ?? this.totalPagesToProcess,
      statusDetail: statusDetail ?? this.statusDetail,
      headerInfo: headerInfo ?? this.headerInfo,
      customFileName: customFileName ?? this.customFileName,
    );
  }
}
