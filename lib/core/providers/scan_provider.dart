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
    return state.entries.map((e) => e.toOutputLine()).join('\n');
  }
}

final scanProvider = StateNotifierProvider<ScanNotifier, ScanState>(
  (ref) => ScanNotifier(),
);
