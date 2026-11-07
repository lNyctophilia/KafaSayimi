import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/models/scan_state.dart';
import '../../core/providers/scan_provider.dart';
import '../../core/services/gemini_vision_service.dart';
import '../../core/config/api_config.dart';
import '../../core/theme/app_colors.dart';

class StagedPhoto {
  final String? path;
  final Uint8List bytes;
  final String id;

  StagedPhoto({
    this.path,
    required this.bytes,
    String? id,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _picker = ImagePicker();
  final List<StagedPhoto> _stagedPhotos = [];
  int _remainingRequests = ApiConfig.dailyRequestLimit;

  /// Kalan kullanım yüzdesi (0 - 100)
  int get _remainingPercent => ApiConfig.dailyRequestLimit > 0
      ? ((_remainingRequests / ApiConfig.dailyRequestLimit) * 100)
          .round()
          .clamp(0, 100)
      : 0;

  @override
  void initState() {
    super.initState();
    _refreshQuota();
  }

  Future<void> _refreshQuota() async {
    final remaining = await GeminiVisionService.checkApiQuota();
    if (mounted) {
      setState(() {
        _remainingRequests = remaining;
      });
    }
  }

  Future<bool> _ensureApiKey() async {
    final apiKey = await GeminiVisionService.getApiKey();
    if (apiKey.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Lütfen önce ayarlar simgesinden Gemini API anahtarınızı girin.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _openGeminiSettings();
      }
      return false;
    }
    return true;
  }

  /// Kameradan fotoğraf çek
  Future<void> _takePhoto() async {
    if (!await _ensureApiKey()) return;

    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
      );

      if (file == null) return;

      final bytes = await file.readAsBytes();
      if (!mounted) return;

      setState(() {
        _stagedPhotos.add(StagedPhoto(path: file.path, bytes: bytes));
      });

      _showNextPhotoOrProcessSheet();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fotoğraf çekme hatası: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  /// Galeriden çoklu fotoğraf seç
  Future<void> _pickFromGallery() async {
    if (!await _ensureApiKey()) return;

    try {
      final List<XFile> files = await _picker.pickMultiImage(
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
      );

      if (files.isEmpty) return;

      final newStaged = <StagedPhoto>[];
      for (final file in files) {
        final bytes = await file.readAsBytes();
        newStaged.add(StagedPhoto(path: file.path, bytes: bytes));
      }

      if (!mounted) return;

      setState(() {
        _stagedPhotos.addAll(newStaged);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${files.length} fotoğraf eklendi. (Toplam ${_stagedPhotos.length} sayfa)',
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Galeri seçim hatası: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  /// Fotoğraf çekildikten sonra seri çekime devam veya başlatma sayfası
  void _showNextPhotoOrProcessSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final count = _stagedPhotos.length;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.cardLight,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.success,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$count. Sayfa Başarıyla Eklendi',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const Text(
                            'Sıradaki sayfayı çekebilir veya tümünü işleyebilirsiniz.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _takePhoto();
                  },
                  icon: const Icon(Icons.add_a_photo_rounded),
                  label: Text('Sıradaki Sayfayı Çek (Sayfa ${count + 1})'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: AppColors.cardLight,
                    foregroundColor: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _processAllStagedPhotos();
                  },
                  icon: const Icon(Icons.bolt_rounded),
                  label: Text(
                    'Sayımı Başlat ($count Sayfa)',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: AppColors.accentLight,
                    foregroundColor: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Listeyi İncele / Kapat'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Seçilen tüm fotoğrafları paralel analiz et ve sonuçları barkoda göre A-Z sırala
  Future<void> _processAllStagedPhotos() async {
    if (_stagedPhotos.isEmpty) return;
    if (!await _ensureApiKey()) return;

    final notifier = ref.read(scanProvider.notifier);
    notifier.reset();
    notifier.setStep(ProcessingStep.loadingImage);

    final bytesList = _stagedPhotos.map((p) => p.bytes).toList();
    final pathsList = _stagedPhotos.map((p) => p.path).toList();

    notifier.setImages(bytesList: bytesList, paths: pathsList);
    notifier.setStep(ProcessingStep.runningOcr);
    notifier.setMultiPageProgress(
      current: 0,
      total: bytesList.length,
      detail: '${bytesList.length} sayfa hazırlanıyor...',
    );

    try {
      final result = await GeminiVisionService.analyzeMultipleImages(
        imagesBytes: bytesList,
        imagesPaths: pathsList,
        onProgress: (completed, total, status) {
          if (mounted) {
            notifier.setMultiPageProgress(
              current: completed,
              total: total,
              detail: status,
              ocrProgress: total > 0 ? ((completed / total) * 100).round() : 0,
            );
          }
        },
      );

      if (mounted) {
        setState(() {
          _remainingRequests = result.remainingRequests;
          _stagedPhotos.clear();
        });
      }

      notifier.setStep(ProcessingStep.parsing);
      notifier.setEntries(result.entries);

      if (mounted) {
        context.go('/results');
      }
    } catch (e) {
      notifier.setError('İşleme hatası: $e');
    }
  }

  void _showStagedImagePreview(int index) {
    if (index < 0 || index >= _stagedPhotos.length) return;
    final photo = _stagedPhotos[index];

    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.surface,
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Text(
                    'Sayfa ${index + 1} Önizleme',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: AppColors.danger),
                    tooltip: 'Bu Sayfayı Sil',
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      setState(() {
                        _stagedPhotos.removeAt(index);
                      });
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 460),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                child: InteractiveViewer(
                  child: Image.memory(
                    photo.bytes,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openGeminiSettings() async {
    if (!mounted) return;
    await context.push('/gemini-settings');
    if (mounted) {
      _refreshQuota();
    }
  }

  void _showRemainingQuotaPopup() {
    final usedRequests = (ApiConfig.dailyRequestLimit - _remainingRequests)
        .clamp(0, ApiConfig.dailyRequestLimit);

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.cardLight, width: 1.2),
        ),
        titlePadding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
        contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.cardLight),
              ),
              child: const Icon(
                Icons.bolt_rounded,
                color: AppColors.accentLight,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Kalan Kullanım',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded,
                  color: AppColors.textSecondary),
              tooltip: 'Kapat',
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.cardLight),
              ),
              child: Column(
                children: [
                  Text(
                    '%$_remainingPercent',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: _remainingPercent > 20
                          ? AppColors.accentLight
                          : AppColors.warning,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: _remainingPercent / 100,
                      minHeight: 8,
                      backgroundColor: AppColors.surface,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _remainingPercent > 20
                            ? AppColors.accentLight
                            : AppColors.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildQuotaStatRow(
              icon: Icons.check_circle_outline_rounded,
              label: 'Kalan İstek:',
              value: '$_remainingRequests adet',
              color: AppColors.success,
            ),
            const SizedBox(height: 8),
            _buildQuotaStatRow(
              icon: Icons.history_rounded,
              label: 'Bugün Kullanılan:',
              value: '$usedRequests adet',
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 8),
            _buildQuotaStatRow(
              icon: Icons.all_inclusive_rounded,
              label: 'Toplam Günlük Limit:',
              value: '${ApiConfig.dailyRequestLimit} istek',
              color: AppColors.accentLight,
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.cardLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: AppColors.textHint,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'İstek hakları her gün otomatik olarak sıfırlanır.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuotaStatRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scanState = ref.watch(scanProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SvgPicture.asset(
              'assets/icon/app_icon.svg',
              width: 26,
              height: 26,
              colorFilter: const ColorFilter.mode(
                AppColors.accentLight,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: 10),
            const Text('Kafa Sayımı'),
          ],
        ),
        centerTitle: false,
        actions: [
          // Remaining Quota Percentage Badge
          InkWell(
            onTap: () => _showRemainingQuotaPopup(),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _remainingPercent > 20
                      ? AppColors.accentLight
                      : AppColors.warning,
                  width: 1.2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.bolt_rounded,
                    size: 15,
                    color: _remainingPercent > 20
                        ? AppColors.accentLight
                        : AppColors.warning,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '%$_remainingPercent',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            tooltip: 'Ayarlar',
            onPressed: () => _openGeminiSettings(),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo area
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.document_scanner_rounded,
                    size: 46,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  'Sayım Kağıdı Okuyucu',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'Kafa sayımı adetlerini otomatik .txt formatına dönüştür.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),

                if (scanState.isProcessing) ...[
                  _ProcessingCard(state: scanState),
                ] else ...[
                  // Staged photos tray (if photos exist)
                  if (_stagedPhotos.isNotEmpty) ...[
                    _buildStagedPhotosCard(colorScheme),
                    const SizedBox(height: 16),
                  ] else ...[
                    // Camera button (First photo or single photo)
                    FilledButton.icon(
                      onPressed: _takePhoto,
                      icon: const Icon(Icons.camera_alt_rounded),
                      label: const Text('Fotoğraf Çek'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 56),
                        backgroundColor: AppColors.accentLight,
                        foregroundColor: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Gallery button (multi-image picker)
                    FilledButton.tonalIcon(
                      onPressed: _pickFromGallery,
                      icon: const Icon(Icons.photo_library_rounded),
                      label: const Text('Galeriden Seç (Çoklu Fotoğraf)'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 56),
                        backgroundColor: AppColors.cardLight,
                        foregroundColor: AppColors.textPrimary,
                      ),
                    ),
                  ],

                  // Error message
                  if (scanState.step == ProcessingStep.error) ...[
                    const SizedBox(height: 16),
                    _ErrorCard(
                      message: scanState.errorMessage ?? 'Bilinmeyen hata',
                      onDismiss: () =>
                          ref.read(scanProvider.notifier).reset(),
                    ),
                  ],

                  // Go to results if already done
                  if (scanState.step == ProcessingStep.done &&
                      scanState.entries.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () => context.go('/results'),
                      icon: const Icon(Icons.table_rows_rounded),
                      label: Text(
                          'Sonuçlara Git (${scanState.entries.length} kayıt)'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 52),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Seçilen sayfaları gösteren ve ekleme/işleme seçenekleri sunan kart
  Widget _buildStagedPhotosCard(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardLight, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.collections_rounded,
                size: 20,
                color: AppColors.accentLight,
              ),
              const SizedBox(width: 8),
              Text(
                'Hazırlanan Sayfalar (${_stagedPhotos.length})',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() => _stagedPhotos.clear()),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Temizle', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Horizontal thumbnail list
          SizedBox(
            height: 110,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _stagedPhotos.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (ctx, index) {
                // Last item is the "+" add card
                if (index == _stagedPhotos.length) {
                  return InkWell(
                    onTap: _takePhoto,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 80,
                      decoration: BoxDecoration(
                        color: AppColors.cardLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.accentLight.withValues(alpha: 0.3),
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo_rounded,
                              size: 24, color: AppColors.accentLight),
                          SizedBox(height: 4),
                          Text(
                            '+ Sayfa',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final photo = _stagedPhotos[index];
                return GestureDetector(
                  onTap: () => _showStagedImagePreview(index),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: 80,
                          height: 110,
                          color: Colors.black,
                          child: Image.memory(
                            photo.bytes,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      // Page badge (Top-left)
                      Positioned(
                        left: 4,
                        top: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'S.${index + 1}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      // Delete button (Top-right)
                      Positioned(
                        right: 2,
                        top: 2,
                        child: InkWell(
                          onTap: () =>
                              setState(() => _stagedPhotos.removeAt(index)),
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: AppColors.danger,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 13,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Add more buttons row
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _takePhoto,
                  icon: const Icon(Icons.camera_alt_rounded, size: 18),
                  label: const Text('+ Sayfa Çek'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.cardLight),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickFromGallery,
                  icon: const Icon(Icons.photo_library_rounded, size: 18),
                  label: const Text('+ Galeri Ekle'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.cardLight),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Primary Process Button
          FilledButton.icon(
            onPressed: _processAllStagedPhotos,
            icon: const Icon(Icons.bolt_rounded, size: 24),
            label: Text(
              'Tümünü İşle (${_stagedPhotos.length} Sayfa)',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 54),
              backgroundColor: AppColors.accentLight,
              foregroundColor: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Center(
            child: Text(
              'Sayfalar sırayla listelenir, her sayfa kendi içinde barkoda göre artan sıralanır',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProcessingCard extends StatelessWidget {
  final ScanState state;

  const _ProcessingCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = state.totalPagesToProcess;
    final current = state.currentProcessingPage;
    final progress = total > 0 ? (current / total).clamp(0.0, 1.0) : null;

    return Card(
      color: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.cardLight, width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const CircularProgressIndicator(color: AppColors.accentLight),
            const SizedBox(height: 18),
            Text(
              total > 1
                  ? 'Sayfalar Analiz Ediliyor ($current / $total)'
                  : 'Fotoğraf İşleniyor...',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            if (total > 1 && progress != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress == 0 ? null : progress,
                  minHeight: 6,
                  backgroundColor: AppColors.surface,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.accentLight,
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            Text(
              state.statusDetail ??
                  'Gemini yapay zeka sayım kutucuklarını okuyor...',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            const Text(
              'Kayıtlar sayfa sırasına göre ve her sayfa kendi içinde artan sıralanır.',
              style: TextStyle(
                fontSize: 11.5,
                color: AppColors.textHint,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;

  const _ErrorCard({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded,
                color: colorScheme.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: colorScheme.onErrorContainer),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: onDismiss,
              color: colorScheme.onErrorContainer,
            ),
          ],
        ),
      ),
    );
  }
}