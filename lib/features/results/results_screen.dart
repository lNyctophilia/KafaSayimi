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
                if (state.imageBytes != null ||
                    state.imageDataUrl != null ||
                    state.allImageBytes.isNotEmpty)
                  _ImagePreviewBanner(
                    imagePath: state.imageDataUrl,
                    imageBytes: state.imageBytes,
                    allImageBytes: state.allImageBytes,
                    allImagePaths: state.allImagePaths,
                  ),

                // Dosya Adı Bilgi ve Düzenleme Kartı
                _FileNameBanner(
                  filename: state.exportFileName,
                  onEdit: () => _showEditFileNameDialog(
                    context,
                    ref,
                    state.exportFileName,
                  ),
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
    final filename = notifier.getExportFileName();

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

  void _showEditFileNameDialog(
      BuildContext context, WidgetRef ref, String currentName) {
    final controller = TextEditingController(text: currentName);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dosya Adını Düzenle', style: TextStyle(fontSize: 18)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Dosya Adı',
            hintText: 'reyon_flormar_26_12_2026.txt',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                ref.read(scanProvider.notifier).setCustomFileName(newName);
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }
}

class _FileNameBanner extends StatelessWidget {
  final String filename;
  final VoidCallback onEdit;

  const _FileNameBanner({
    required this.filename,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.description_outlined,
            size: 18,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              filename,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.edit_outlined,
              size: 16,
              color: colorScheme.primary,
            ),
            tooltip: 'Dosya adını değiştir',
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(4),
            onPressed: onEdit,
          ),
        ],
      ),
    );
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
    final pageCount = entries
        .map((e) => e.pageIndex)
        .whereType<int>()
        .toSet()
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
                'Adet: $filled',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (pageCount > 1) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$pageCount Sayfa',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
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
  final List<Uint8List> allImageBytes;
  final List<String?> allImagePaths;

  const _ImagePreviewBanner({
    this.imagePath,
    this.imageBytes,
    this.allImageBytes = const [],
    this.allImagePaths = const [],
  });

  @override
  State<_ImagePreviewBanner> createState() => _ImagePreviewBannerState();
}

class _ImagePreviewBannerState extends State<_ImagePreviewBanner> {
  bool _expanded = false;
  int _selectedPageIndex = 0;

  int get _totalImages {
    if (widget.allImageBytes.isNotEmpty) return widget.allImageBytes.length;
    if (widget.allImagePaths.isNotEmpty) return widget.allImagePaths.length;
    if (widget.imageBytes != null || widget.imagePath != null) return 1;
    return 0;
  }

  Uint8List? get _currentBytes {
    if (widget.allImageBytes.isNotEmpty &&
        _selectedPageIndex < widget.allImageBytes.length) {
      return widget.allImageBytes[_selectedPageIndex];
    }
    return widget.imageBytes;
  }

  String? get _currentPath {
    if (widget.allImagePaths.isNotEmpty &&
        _selectedPageIndex < widget.allImagePaths.length) {
      return widget.allImagePaths[_selectedPageIndex];
    }
    return widget.imagePath;
  }

  void _openFullScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FullScreenImageViewer(
          imagePath: _currentPath,
          imageBytes: _currentBytes,
          allImageBytes:
              widget.allImageBytes.isNotEmpty ? widget.allImageBytes : null,
          allImagePaths:
              widget.allImagePaths.isNotEmpty ? widget.allImagePaths : null,
          initialIndex: _selectedPageIndex,
          heroTag: 'scanned_image_preview',
        ),
      ),
    );
  }

  Widget _buildPreviewImage() {
    final bytes = _currentBytes;
    final path = _currentPath;

    if (bytes != null) {
      return Image.memory(
        bytes,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) =>
            const Center(child: Text('Görüntü önizlemesi yok')),
      );
    } else if (path != null && path.isNotEmpty) {
      if (kIsWeb) {
        return Image.network(
          path,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) =>
              const Center(child: Text('Görüntü önizlemesi yok')),
        );
      } else {
        return Image.file(
          File(path),
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
                    child: Row(
                      children: [
                        const Icon(Icons.image_rounded, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _totalImages > 1
                                ? 'Sayfa ${_selectedPageIndex + 1} / $_totalImages'
                                : 'Taranan görüntü',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_totalImages > 1) ...[
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 16),
                    tooltip: 'Önceki Sayfa',
                    onPressed: _selectedPageIndex > 0
                        ? () => setState(() => _selectedPageIndex--)
                        : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios_rounded,
                        size: 16),
                    tooltip: 'Sonraki Sayfa',
                    onPressed: _selectedPageIndex < _totalImages - 1
                        ? () => setState(() => _selectedPageIndex++)
                        : null,
                  ),
                ],
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
