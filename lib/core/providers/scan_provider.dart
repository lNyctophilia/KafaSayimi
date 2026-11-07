import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/barcode_entry.dart';
import '../models/scan_state.dart';

class ScanNotifier extends StateNotifier<ScanState> {
  ScanNotifier() : super(const ScanState());

  void setStep(ProcessingStep step, {int progress = 0}) {
    state = state.copyWith(step: step, ocrProgress: progress);
  }

  void setOcrProgress(int progress) {
    state = state.copyWith(ocrProgress: progress);
  }

  void setEntries(List<BarcodeEntry> entries) {
    state = state.copyWith(
      entries: entries,
      step: ProcessingStep.done,
    );
  }

  void setError(String message) {
    state = state.copyWith(
      errorMessage: message,
      step: ProcessingStep.error,
    );
  }

  void setImageDataUrl(String url) {
    state = state.copyWith(imageDataUrl: url);
  }

  void setImage({String? path, Uint8List? bytes}) {
    state = state.copyWith(
      imageDataUrl: path,
      imageBytes: bytes,
      allImagePaths: path != null ? [path] : [],
      allImageBytes: bytes != null ? [bytes] : [],
      currentProcessingPage: 1,
      totalPagesToProcess: 1,
    );
  }

  void setImages({
    required List<Uint8List> bytesList,
    List<String?>? paths,
  }) {
    state = state.copyWith(
      imageBytes: bytesList.isNotEmpty ? bytesList.first : null,
      imageDataUrl: (paths != null && paths.isNotEmpty) ? paths.first : null,
      allImageBytes: bytesList,
      allImagePaths: paths ?? [],
      currentProcessingPage: 0,
      totalPagesToProcess: bytesList.length,
    );
  }

  void setMultiPageProgress({
    required int current,
    required int total,
    String? detail,
    int? ocrProgress,
  }) {
    state = state.copyWith(
      currentProcessingPage: current,
      totalPagesToProcess: total,
      statusDetail: detail,
      ocrProgress: ocrProgress ?? state.ocrProgress,
    );
  }

  /// Barkod koduna göre A-Z (artan) sırala
  void sortAscending() {
    final list = List<BarcodeEntry>.from(state.entries);
    list.sort((a, b) => BarcodeComparator.compare(a.barcodeCode, b.barcodeCode));
    state = state.copyWith(entries: list);
  }

  /// Barkod koduna göre Z-A (azalan) sırala
  void sortDescending() {
    final list = List<BarcodeEntry>.from(state.entries);
    list.sort((a, b) => BarcodeComparator.compare(b.barcodeCode, a.barcodeCode));
    state = state.copyWith(entries: list);
  }

  /// Sayfa numarasına göre sırala
  void sortByPage() {
    final list = List<BarcodeEntry>.from(state.entries);
    list.sort((a, b) {
      final pageA = a.pageIndex ?? 1;
      final pageB = b.pageIndex ?? 1;
      final pageCmp = pageA.compareTo(pageB);
      if (pageCmp != 0) return pageCmp;
      return BarcodeComparator.compare(a.barcodeCode, b.barcodeCode);
    });
    state = state.copyWith(entries: list);
  }

  void updateEntry(int index, BarcodeEntry updated) {
    final list = List<BarcodeEntry>.from(state.entries);
    if (index >= 0 && index < list.length) {
      list[index] = updated;
      state = state.copyWith(entries: list);
    }
  }

  void deleteEntry(int index) {
    final list = List<BarcodeEntry>.from(state.entries);
    if (index >= 0 && index < list.length) {
      list.removeAt(index);
      state = state.copyWith(entries: list);
    }
  }

  void addEntry() {
    final list = List<BarcodeEntry>.from(state.entries);
    list.add(BarcodeEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      barcodeCode: '',
      quantity: '',
      isQuantityConfident: true,
      confidence: 100.0,
    ));
    state = state.copyWith(entries: list);
  }

  void reset() {
    state = const ScanState();
  }

  String exportToText() {
    final validEntries = state.entries.where(
      (e) => e.barcodeCode.trim().isNotEmpty || e.quantity.trim().isNotEmpty,
    );
    return validEntries.map((e) => e.toOutputLine()).join('\n');
  }
}

final scanProvider = StateNotifierProvider<ScanNotifier, ScanState>(
  (ref) => ScanNotifier(),
);
