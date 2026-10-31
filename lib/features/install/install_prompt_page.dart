import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class InstallPromptPage extends StatelessWidget {
  const InstallPromptPage({super.key});

  Widget _buildPlatformSection({
    required IconData icon,
    required Color iconColor,
    required String title,
    required List<String> steps,
    String? warning,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 24),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...steps.map((step) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  step,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: step.startsWith('✅')
                        ? AppColors.accentLight
                        : AppColors.textSecondary,
                    fontWeight:
                        step.startsWith('✅') ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              )),
          if (warning != null) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFA726).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                warning,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFFFFA726),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 8),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.accentLight.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.add_to_home_screen_rounded,
                      color: AppColors.accentLight,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Uygulamayı Ana Ekrana Ekle',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Cihazınıza göre aşağıdaki adımları takip edin:',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.divider, height: 32),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPlatformSection(
                      icon: Icons.android_rounded,
                      iconColor: const Color(0xFF3DDC84),
                      title: 'Android (Chrome)',
                      steps: const [
                        '1. Chrome\'da sağ üstteki üç nokta menüsüne (⋮) dokunun',
                        '2. Biraz aşağı kaydırıp "Yükle ve kısayol oluştur" seçeneğine basın',
                        '3. Açılan pencerede onaylayarak işlemi tamamlayın',
                        '✅ Artık ana ekranınızda uygulama ikonu görünecek!',
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildPlatformSection(
                      icon: Icons.apple_rounded,
                      iconColor: AppColors.textPrimary,
                      title: 'iOS (Safari)',
                      steps: const [
                        '1. Safari\'nin alt menüsündeki Paylaş (⬆) ikonuna dokunun',
                        '2. Biraz aşağı kaydırıp gri listeden "Ana Ekrana Ekle"ye dokunun. (Eğer görünmüyorsa "Daha Fazla" seçeneği içinden bulabilirsiniz)',
                        '3. Açılan pencerede onaylayarak işlemi tamamlayın',
                        '✅ Artık ana ekranınızda uygulama ikonu görünecek!',
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

