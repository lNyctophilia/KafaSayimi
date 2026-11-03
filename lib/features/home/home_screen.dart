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

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _picker = ImagePicker();
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

  Future<void> _pickAndProcess(ImageSource source) async {
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
      return;
    }

    final notifier = ref.read(scanProvider.notifier);
    notifier.reset();
    notifier.setStep(ProcessingStep.loadingImage);

    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
      );

      if (file == null) {
        notifier.setStep(ProcessingStep.idle);
        return;
      }

      final imageBytes = await file.readAsBytes();
      notifier.setImage(path: file.path, bytes: imageBytes);
      notifier.setStep(ProcessingStep.runningOcr);

      final result = await GeminiVisionService.analyzeImage(
        imagePath: file.path,
        imageBytes: imageBytes,
      );

      final entries = result.entries;
      if (mounted) {
        setState(() {
          _remainingRequests = result.remainingRequests;
        });
      }


      notifier.setStep(ProcessingStep.parsing);
      notifier.setEntries(entries);

      if (mounted) {
        context.go('/results');
      }
    } catch (e) {
      notifier.setError('İşleme hatası: $e');
    }
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
              icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
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
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.document_scanner_rounded,
                    size: 50,
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
                const SizedBox(height: 32),

                if (scanState.isProcessing) ...[
                  _ProcessingCard(
                    state: scanState,
                  ),
                ] else ...[
                  // Camera button
                  FilledButton.icon(
                    onPressed: () => _pickAndProcess(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_rounded),
                    label: const Text('Fotoğraf Çek'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 56),
                      backgroundColor: AppColors.accentLight,
                      foregroundColor: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Gallery button
                  FilledButton.tonalIcon(
                    onPressed: () => _pickAndProcess(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_rounded),
                    label: const Text('Galeriden Seç'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 56),
                      backgroundColor: AppColors.cardLight,
                      foregroundColor: AppColors.textPrimary,
                    ),
                  ),

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
}

class _ProcessingCard extends StatelessWidget {
  final ScanState state;

  const _ProcessingCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const CircularProgressIndicator(color: AppColors.accentLight),
            const SizedBox(height: 16),
            Text(
              'Fotoğraf işleniyor...',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
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
