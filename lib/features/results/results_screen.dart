import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/barcode_entry.dart';
import '../../core/providers/scan_provider.dart';
import '../../core/theme/app_colors.dart';
import 'widgets/entry_row_widget.dart';
import 'widgets/full_screen_image_viewer.dart';
import '../../core/services/export_service.dart';

class ResultsScreen extends ConsumerWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(scanProvider);
    final notifier = ref.read(scanProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sonuçlar'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/'),
          tooltip: 'Geri',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => notifier.addEntry(),
            tooltip: 'Satır Ekle',
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: const Icon(Icons.share_rounded),
              onPressed: state.entries.isEmpty
                  ? null
                  : () => _exportToTxt(context, ref),
              tooltip: 'TXT Paylaş / Kaydet',
            ),
          ),
        ],
      ),
      body: state.entries.isEmpty
          ? _EmptyState(onAdd: () => notifier.addEntry())
          : Column(
              children: [
                // Preview image (if available)
                if (state.imageBytes != null || state.imageDataUrl != null)
                  _ImagePreviewBanner(
                    imagePath: state.imageDataUrl,
                    imageBytes: state.imageBytes,
                  ),

                // Summary banner
                _SummaryBanner(entries: state.entries),

                // Entry rows
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 24),
                    itemCount: state.entries.length,
                    itemBuilder: (context, index) {
                      final entry = state.entries[index];
                      return EntryRowWidget(
                        key: ValueKey(entry.id),
                        entry: entry,
                        index: index,
                        onChanged: (updated) =>
                            notifier.updateEntry(index, updated),
                        onDelete: () => notifier.deleteEntry(index),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _exportToTxt(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(scanProvider.notifier);
    final text = notifier.exportToText();
    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .substring(0, 19);
    final filename = 'sayim_$timestamp.txt';

    try {
      await ExportService.exportText(filename, text);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$filename hazırlandı'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Paylaşım hatası: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

class _SummaryBanner extends StatelessWidget {
  final List<BarcodeEntry> entries;
  const _SummaryBanner({required this.entries});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final total = entries.length;
    final filled = entries.where((e) => e.quantity.trim().isNotEmpty).length;
    final empty = total - filled;
    final lowConfidenceCount = entries
        .where((e) => e.quantity.trim().isNotEmpty && e.isUnder92)
        .length;
    final criticalCount = entries
        .where((e) => e.quantity.trim().isNotEmpty && e.isUnder87)
        .length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_outline_rounded,
                  size: 18, color: colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                'Adet Girilen: $filled',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          if (lowConfidenceCount > 0)
            Row(
              children: [
                Icon(
                  criticalCount > 0
                      ? Icons.error_rounded
                      : Icons.warning_rounded,
                  size: 18,
                  color: criticalCount > 0 ? AppColors.danger : AppColors.warning,
                ),
                const SizedBox(width: 4),
                Text(
                  'Şüpheli: $lowConfidenceCount',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: criticalCount > 0 ? AppColors.danger : AppColors.warning,
                  ),
                ),
              ],
            ),
          if (empty > 0)
            Row(
              children: [
                Icon(Icons.edit_note_rounded,
                    size: 18, color: colorScheme.error),
                const SizedBox(width: 4),
                Text(
                  'Boş: $empty',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.error,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ImagePreviewBanner extends StatefulWidget {
  final String? imagePath;
  final Uint8List? imageBytes;
  const _ImagePreviewBanner({this.imagePath, this.imageBytes});

  @override
  State<_ImagePreviewBanner> createState() => _ImagePreviewBannerState();
}

class _ImagePreviewBannerState extends State<_ImagePreviewBanner> {
  bool _expanded = false;

  void _openFullScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FullScreenImageViewer(
          imagePath: widget.imagePath,
          imageBytes: widget.imageBytes,
          heroTag: 'scanned_image_preview',
        ),
      ),
    );
  }

  Widget _buildPreviewImage() {
    if (widget.imageBytes != null) {
      return Image.memory(
        widget.imageBytes!,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) =>
            const Center(child: Text('Görüntü önizlemesi yok')),
      );
    } else if (widget.imagePath != null && widget.imagePath!.isNotEmpty) {
      if (kIsWeb) {
        return Image.network(
          widget.imagePath!,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) =>
              const Center(child: Text('Görüntü önizlemesi yok')),
        );
      } else {
        return Image.file(
          File(widget.imagePath!),
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) =>
              const Center(child: Text('Görüntü önizlemesi yok')),
        );
      }
    }
    return const Center(child: Text('Görüntü önizlemesi yok'));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: _expanded ? 280 : 56,
      child: Column(
        children: [
          Container(
            height: 56,
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _expanded = !_expanded),
                    child: const Row(
                      children: [
                        Icon(Icons.image_rounded, size: 20),
                        SizedBox(width: 12),
                        Expanded(child: Text('Taranan görüntü')),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.fullscreen_rounded),
                  tooltip: 'Tam Ekran Büyüt',
                  onPressed: _openFullScreen,
                ),
                IconButton(
                  icon: Icon(_expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded),
                  tooltip: _expanded ? 'Küçült' : 'Genişlet',
                  onPressed: () => setState(() => _expanded = !_expanded),
                ),
              ],
            ),
          ),
          if (_expanded)
            Expanded(
              child: GestureDetector(
                onTap: _openFullScreen,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Hero(
                      tag: 'scanned_image_preview',
                      child: _buildPreviewImage(),
                    ),
                    Positioned(
                      right: 12,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.zoom_in_rounded,
                                size: 16, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              'Büyütmek için dokunun',
                              style:
                                  TextStyle(fontSize: 11, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.list_alt_rounded, size: 72, color: colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            'Henüz kayıt yok',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Satır Ekle'),
          ),
        ],
      ),
    );
  }
}
