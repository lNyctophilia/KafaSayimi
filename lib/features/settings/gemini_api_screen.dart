import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_version.dart';
import '../../../core/services/app_update_service.dart';
import '../../../core/services/gemini_vision_service.dart';
import '../../../core/theme/app_colors.dart';

enum ValidationState {
  idle,
  validating,
  valid,
  invalid,
}

class GeminiApiScreen extends StatefulWidget {
  const GeminiApiScreen({super.key});

  @override
  State<GeminiApiScreen> createState() => _GeminiApiScreenState();
}

class _GeminiApiScreenState extends State<GeminiApiScreen> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounceTimer;

  ValidationState _validationState = ValidationState.idle;
  String? _validationMessage;
  bool _isCustomKey = false;
  bool _isLoadingInitial = true;
  bool _isCheckingForUpdates = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentKey();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentKey() async {
    final key = await GeminiVisionService.getApiKey();
    final hasCustom = await GeminiVisionService.hasCustomApiKey();

    if (!mounted) return;

    setState(() {
      _controller.text = key;
      _isCustomKey = hasCustom;
      _isLoadingInitial = false;
    });

    if (key.trim().isNotEmpty) {
      _runValidation(key.trim());
    }
  }

  void _onKeyChanged(String value) {
    _debounceTimer?.cancel();

    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _validationState = ValidationState.idle;
        _validationMessage = null;
      });
      return;
    }

    setState(() {
      _validationState = ValidationState.idle;
      _validationMessage = null;
    });

    // Auto-validate after 700ms when typing stops
    _debounceTimer = Timer(const Duration(milliseconds: 700), () {
      _runValidation(trimmed);
    });
  }

  Future<void> _runValidation(String key) async {
    _debounceTimer?.cancel();
    final cleanKey = key.trim();

    if (cleanKey.isEmpty) {
      setState(() {
        _validationState = ValidationState.idle;
        _validationMessage = null;
      });
      return;
    }

    setState(() {
      _validationState = ValidationState.validating;
      _validationMessage = 'API anahtarı doğrulanıyor...';
    });

    final result = await GeminiVisionService.validateApiKey(cleanKey);
    if (!mounted) return;

    setState(() {
      if (result.isValid) {
        _validationState = ValidationState.valid;
        _validationMessage = result.message;
      } else {
        _validationState = ValidationState.invalid;
        _validationMessage = result.message;
      }
    });
  }

  Future<void> _resetKey() async {
    _debounceTimer?.cancel();
    await GeminiVisionService.clearApiKey();
    if (!mounted) return;

    _controller.clear();
    setState(() {
      _isCustomKey = false;
      _validationState = ValidationState.idle;
      _validationMessage = null;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'API anahtarı sıfırlandı.',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: AppColors.cardLight),
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _saveKey() async {
    final val = _controller.text.trim();
    if (val.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Lütfen geçerli bir API anahtarı girin.',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          backgroundColor: AppColors.danger,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_validationState == ValidationState.validating) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Doğrulama işlemi sürüyor, lütfen bekleyin...',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: AppColors.cardLight),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_validationState == ValidationState.idle) {
      await _runValidation(val);
      if (!mounted) return;
    }

    if (_validationState == ValidationState.invalid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.cancel_rounded, color: AppColors.danger),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _validationMessage ??
                      'API anahtarı geçersiz olduğu için kaydedilemedi.',
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: AppColors.danger, width: 1.2),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    await GeminiVisionService.saveApiKey(val);
    if (!mounted) return;

    setState(() {
      _isCustomKey = true;
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AppColors.success),
            SizedBox(width: 8),
            Text(
              'API Anahtarı başarıyla doğrulandı ve kaydedildi.',
              style: TextStyle(color: AppColors.textPrimary),
            ),
          ],
        ),
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColors.success, width: 1.2),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );

    Navigator.of(context).pop(true);
  }

  Future<void> _launchAiStudio() async {
    final uri = Uri.parse('https://aistudio.google.com/app/apikey');
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        await launchUrl(uri);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Bağlantı açılamadı: $e',
              style: const TextStyle(color: AppColors.textPrimary),
            ),
            backgroundColor: AppColors.card,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showHowToGetApiKeyBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.88,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(
            top: BorderSide(color: AppColors.cardLight, width: 1.5),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: AppColors.cardLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                // Title
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.cardLight),
                      ),
                      child: const Icon(
                        Icons.vpn_key_rounded,
                        color: AppColors.accentLight,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'API Anahtarı Nasıl Alınır?',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Tamamen ücretsiz ve 1 dakikada alınabilir',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Steps list
                _buildInstructionStep(
                  stepNumber: '1',
                  title: 'Google AI Studio Web Sitesini Açın',
                  description:
                      'Aşağıdaki butona dokunarak doğrudan API anahtarı sayfasına gidin.',
                  actionWidget: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: OutlinedButton.icon(
                      onPressed: _launchAiStudio,
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      label: const Text('Google AI Studio\'yu Aç'),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: AppColors.accentLight,
                        side: const BorderSide(color: AppColors.accentLight),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _buildInstructionStep(
                  stepNumber: '2',
                  title: 'Google Hesabınızla Giriş Yapın',
                  description:
                      'Mevcut Google (Gmail) hesabınızla ücretsiz oturum açın.',
                ),
                const SizedBox(height: 14),
                _buildInstructionStep(
                  stepNumber: '3',
                  title: '"Create API key" Butonuna Basın',
                  description:
                      'Sayfadaki mavi "Create API key" (API Anahtarı Oluştur) butonuna tıklayın.',
                ),
                const SizedBox(height: 14),
                _buildInstructionStep(
                  stepNumber: '4',
                  title: 'Anahtarı Kopyalayın',
                  description:
                      'Oluşturulan anahtarı kopyalayın ve bu sayfadaki "API Anahtarı" alanına yapıştırın.',
                ),
                const SizedBox(height: 14),
                _buildInstructionStep(
                  stepNumber: '5',
                  title: 'Doğrulayın ve Kaydedin',
                  description:
                      '"Şimdi Doğrula" butonuna basarak yeşil tiki görün ve ardından "Kaydet"e basın.',
                ),

                const SizedBox(height: 24),

                // Open Site Button
                FilledButton.icon(
                  onPressed: _launchAiStudio,
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Google AI Studio\'ya Git'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accentLight,
                    foregroundColor: AppColors.textPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                  ),
                  child: const Text('Kapat'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionStep({
    required String stepNumber,
    required String title,
    required String description,
    Widget? actionWidget,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.cardLight,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
          ),
          child: Text(
            stepNumber,
            style: const TextStyle(
              color: AppColors.accentLight,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                  height: 1.3,
                ),
              ),
              if (actionWidget != null) actionWidget,
            ],
          ),
        ),
      ],
    );
  }

  Widget? _buildKeySuffixIcon() {
    switch (_validationState) {
      case ValidationState.validating:
        return const Padding(
          padding: EdgeInsets.all(12),
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.accentLight,
            ),
          ),
        );
      case ValidationState.valid:
        return const Tooltip(
          message: 'API Anahtarı Doğrulandı',
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Icon(
              Icons.check_circle_rounded,
              color: AppColors.success,
              size: 22,
            ),
          ),
        );
      case ValidationState.invalid:
        return Tooltip(
          message: _validationMessage ?? 'API Anahtarı Geçersiz',
          child: const Padding(
            padding: EdgeInsets.all(12),
            child: Icon(
              Icons.cancel_rounded,
              color: AppColors.danger,
              size: 22,
            ),
          ),
        );
      case ValidationState.idle:
        return null;
    }
  }

  Widget _buildValidationBanner() {
    switch (_validationState) {
      case ValidationState.validating:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: AppColors.accentLight.withValues(alpha: 0.6)),
          ),
          child: const Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.accentLight,
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'API anahtarı kontrol ediliyor...',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.accentLight,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );

      case ValidationState.valid:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.success, width: 1.2),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.success,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'API Anahtarı Doğrulandı ✓',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _validationMessage ?? 'Gemini servisi kullanıma hazır.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

      case ValidationState.invalid:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.danger, width: 1.2),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.cancel_rounded,
                color: AppColors.danger,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'API Anahtarı Geçersiz ✕',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.danger,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _validationMessage ??
                          'API anahtarı geçersiz veya yetkisiz.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

      case ValidationState.idle:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Ayarlar'),
        centerTitle: false,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 580),
                child: _isLoadingInitial
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.accentLight,
                        ),
                      )
                    : SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 24,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 1. Instruction trigger button at top
                            Card(
                              elevation: 0,
                              color: AppColors.card,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: const BorderSide(
                                  color: AppColors.cardLight,
                                  width: 1.2,
                                ),
                              ),
                              child: InkWell(
                                onTap: _showHowToGetApiKeyBottomSheet,
                                borderRadius: BorderRadius.circular(14),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: AppColors.cardLight,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: const Icon(
                                          Icons.help_outline_rounded,
                                          color: AppColors.accentLight,
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      const Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'API Key\'in yok mu?',
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                            SizedBox(height: 2),
                                            Text(
                                              'Ücretsiz anahtar alma talimatları için dokunun',
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(
                                        Icons.chevron_right_rounded,
                                        color: AppColors.accentLight,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 18),

                            // 2. API Key Input Section
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: AppColors.card,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: AppColors.cardLight,
                                  width: 1.2,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Text(
                                        'API Anahtarınız',
                                        style: TextStyle(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _isCustomKey
                                              ? AppColors.accentLight
                                              : AppColors.cardLight,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          border: _isCustomKey
                                              ? null
                                              : Border.all(
                                                  color: AppColors.divider),
                                        ),
                                        child: Text(
                                          _isCustomKey
                                              ? 'Özel Anahtar'
                                              : 'Varsayılan',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: _isCustomKey
                                                ? AppColors.textPrimary
                                                : AppColors.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: _controller,
                                    obscureText: true,
                                    enableInteractiveSelection: true,
                                    contextMenuBuilder:
                                        (context, editableTextState) {
                                      final buttonItems = editableTextState
                                          .contextMenuButtonItems;
                                      buttonItems.removeWhere((item) =>
                                          item.type ==
                                              ContextMenuButtonType.copy ||
                                          item.type ==
                                              ContextMenuButtonType.cut ||
                                          item.type ==
                                              ContextMenuButtonType.share ||
                                          item.type ==
                                              ContextMenuButtonType.selectAll);
                                      return AdaptiveTextSelectionToolbar
                                          .buttonItems(
                                        anchors: editableTextState
                                            .contextMenuAnchors,
                                        buttonItems: buttonItems,
                                      );
                                    },
                                    onChanged: _onKeyChanged,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 14,
                                      letterSpacing: 1.5,
                                    ),
                                    cursorColor: AppColors.accentLight,
                                    decoration: InputDecoration(
                                      hintText: 'AIzaSy...',
                                      hintStyle: const TextStyle(
                                        color: AppColors.textHint,
                                        letterSpacing: 0,
                                      ),
                                      fillColor: AppColors.surface,
                                      filled: true,
                                      border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: AppColors.divider,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: AppColors.divider,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: AppColors.accentLight,
                                          width: 2,
                                        ),
                                      ),
                                      suffixIcon: _buildKeySuffixIcon(),
                                    ),
                                  ),
                                  const SizedBox(height: 14),

                                  // Action Buttons: Şimdi Doğrula & Sıfırla
                                  Row(
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: _validationState ==
                                                ValidationState.validating
                                            ? null
                                            : () => _runValidation(
                                                _controller.text),
                                        icon: const Icon(
                                          Icons.check_circle_outline_rounded,
                                          size: 18,
                                        ),
                                        label: const Text('Şimdi Doğrula'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor:
                                              AppColors.accentLight,
                                          side: const BorderSide(
                                            color: AppColors.accentLight,
                                            width: 1.2,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 10,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                        ),
                                      ),
                                      const Spacer(),

                                      // Sıfırla button
                                      TextButton.icon(
                                        onPressed: _resetKey,
                                        icon: const Icon(
                                          Icons.restart_alt_rounded,
                                          size: 18,
                                        ),
                                        label: const Text('Sıfırla'),
                                        style: TextButton.styleFrom(
                                          foregroundColor:
                                              AppColors.textSecondary,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 10,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  if (_validationState !=
                                      ValidationState.idle) ...[
                                    const SizedBox(height: 14),
                                    _buildValidationBanner(),
                                  ],
                                ],
                              ),
                            ),

                            const SizedBox(height: 24),

                            // 3. Save Button
                            FilledButton.icon(
                              onPressed: _validationState ==
                                      ValidationState.validating
                                  ? null
                                  : _saveKey,
                              icon: const Icon(Icons.save_rounded),
                              label: const Text(
                                'Kaydet',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.accentLight,
                                foregroundColor: AppColors.textPrimary,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),

                            // 4. App Info, Copyright & Update Check Section
                            _buildAppInfoSection(),
                          ],
                        ),
                      ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _checkForUpdatesManually() async {
    setState(() {
      _isCheckingForUpdates = true;
    });

    try {
      final result = await AppUpdateService.checkForUpdatesManual();
      if (!mounted) return;

      if (result.status == UpdateCheckStatus.updateAvailable) {
        final newVer = result.availableVersion ?? 'Yeni Sürüm';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.system_update_rounded,
                  color: AppColors.accentLight,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Yeni sürüm bulundu ($newVer)! Güncelleme uygulanıyor...',
                    style: const TextStyle(color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: AppColors.accentLight),
            ),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );

        await Future.delayed(const Duration(milliseconds: 1200));
        await AppUpdateService.forceHardReload(result.availableVersion);
      } else if (result.status == UpdateCheckStatus.upToDate) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.success,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Uygulamanız güncel (${AppVersion.current}). En son sürümü kullanıyorsunuz.',
                    style: TextStyle(color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
            action: SnackBarAction(
              label: 'Yenile',
              textColor: AppColors.accentLight,
              onPressed: () => AppUpdateService.forceHardReload(),
            ),
            backgroundColor: AppColors.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: AppColors.cardLight),
            ),
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.warning,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    result.message ??
                        'Güncelleme kontrolü yapılamadı. Lütfen internet bağlantınızı kontrol edin.',
                    style: const TextStyle(color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: AppColors.warning),
            ),
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Hata oluştu: $e',
            style: const TextStyle(color: AppColors.textPrimary),
          ),
          backgroundColor: AppColors.card,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingForUpdates = false;
        });
      }
    }
  }

  Widget _buildAppInfoSection() {
    return Container(
      margin: const EdgeInsets.only(top: 36, bottom: 16),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.cardLight,
          width: 1.2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Uygulama İkonu
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.asset(
                'assets/icon/app_icon.png',
                width: 72,
                height: 72,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: AppColors.cardLight,
                  padding: const EdgeInsets.all(16),
                  child: SvgPicture.asset(
                    'assets/icon/app_icon.svg',
                    colorFilter: const ColorFilter.mode(
                      AppColors.accentLight,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Uygulama İsmi
          const Text(
            'Kafa Sayımı',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),

          // Ana Sayfadaki Versiyon Kısmının Birebir Aynısı
          Tooltip(
            message: 'Basılı tutarak önbelleği temizleyip yenileyin',
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onLongPress: () async {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Önbellek temizleniyor ve uygulama sıfırdan başlatılıyor...',
                    ),
                    behavior: SnackBarBehavior.floating,
                    duration: Duration(seconds: 2),
                  ),
                );
                await Future.delayed(const Duration(milliseconds: 600));
                await AppUpdateService.forceHardReload();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Text(
                  AppVersion.current,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // İnce ayırıcı çizgi
          Container(
            height: 1,
            width: 80,
            color: AppColors.divider,
          ),
          const SizedBox(height: 14),

          // Geliştirici İsmi ve Copyright
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.code_rounded,
                size: 15,
                color: AppColors.accentLight,
              ),
              const SizedBox(width: 6),
              RichText(
                text: const TextSpan(
                  text: 'Geliştirici: ',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                  children: [
                    TextSpan(
                      text: 'lNyctophilia',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.accentLight,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            '© 2026 lNyctophilia. Tüm hakları saklıdır.',
            style: TextStyle(
              fontSize: 11.5,
              color: AppColors.textHint,
            ),
          ),
          const SizedBox(height: 20),

          // Güncellemeleri Denetle Butonu
          OutlinedButton.icon(
            onPressed: _isCheckingForUpdates ? null : _checkForUpdatesManually,
            icon: _isCheckingForUpdates
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.accentLight,
                    ),
                  )
                : const Icon(Icons.sync_rounded, size: 18),
            label: Text(
              _isCheckingForUpdates
                  ? 'Güncellemeler Denetleniyor...'
                  : 'Güncellemeleri Denetle',
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accentLight,
              side: const BorderSide(color: AppColors.accentLight, width: 1.2),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
