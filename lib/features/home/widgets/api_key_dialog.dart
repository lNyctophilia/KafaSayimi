import 'dart:async';
import 'package:flutter/material.dart';

import '../../../core/config/api_config.dart';
import '../../../core/services/gemini_vision_service.dart';
import '../../../core/theme/app_colors.dart';

enum ValidationState {
  idle,
  validating,
  valid,
  invalid,
}

class ApiKeyDialog extends StatefulWidget {
  final int remainingRequests;
  final int remainingPercent;
  final VoidCallback onKeySaved;

  const ApiKeyDialog({
    super.key,
    required this.remainingRequests,
    required this.remainingPercent,
    required this.onKeySaved,
  });

  @override
  State<ApiKeyDialog> createState() => _ApiKeyDialogState();
}

class _ApiKeyDialogState extends State<ApiKeyDialog> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounceTimer;

  ValidationState _validationState = ValidationState.idle;
  String? _validationMessage;
  bool _obscureText = true;
  bool _isCustomKey = false;
  bool _isLoadingInitial = true;

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

    // Auto-validate after 700ms when typing/pasting stops
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

  Future<void> _restoreDefaultKey() async {
    await GeminiVisionService.clearApiKey();
    if (!mounted) return;

    _controller.text = ApiConfig.defaultGeminiApiKey;
    setState(() {
      _isCustomKey = false;
    });
    _runValidation(ApiConfig.defaultGeminiApiKey);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Varsayılan API anahtarı yüklendi.',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColors.cardLight),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
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
        ),
      );
      return;
    }

    // If currently validating, wait for it
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
        ),
      );
      return;
    }

    // If not verified yet, test it now before saving
    if (_validationState == ValidationState.idle) {
      await _runValidation(val);
      if (!mounted) return;
    }

    if (_validationState == ValidationState.invalid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: AppColors.danger),
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

    // Valid - save it
    await GeminiVisionService.saveApiKey(val);
    widget.onKeySaved();

    if (!mounted) return;
    Navigator.of(context).pop();

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
  }

  Widget _buildStatusIndicator() {
    switch (_validationState) {
      case ValidationState.validating:
        return const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
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
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Icon(
              Icons.check_circle_rounded,
              color: AppColors.success,
              size: 24,
            ),
          ),
        );
      case ValidationState.invalid:
        return Tooltip(
          message: _validationMessage ?? 'API Anahtarı Geçersiz',
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Icon(
              Icons.cancel_rounded,
              color: AppColors.danger,
              size: 24,
            ),
          ),
        );
      case ValidationState.idle:
        return const SizedBox.shrink();
    }
  }

  Widget _buildValidationBanner() {
    switch (_validationState) {
      case ValidationState.validating:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppColors.accentLight.withValues(alpha: 0.6),
            ),
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
            color: AppColors.card,
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
            color: AppColors.card,
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
                      _validationMessage ?? 'API anahtarı geçersiz veya yetkisiz.',
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
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.divider),
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
                  'Anahtar yazıldığında veya yapıştırıldığında otomatik doğrulanır.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.cardLight, width: 1.2),
      ),
      title: const Row(
        children: [
          Icon(Icons.auto_awesome_rounded, color: AppColors.accentLight),
          SizedBox(width: 8),
          Text(
            'Gemini API Ayarları',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Quota & Key Type Info
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.cardLight),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.bolt_rounded,
                          color: AppColors.accentLight,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Kalan İstek: %${widget.remainingPercent} (${widget.remainingRequests} / ${ApiConfig.dailyRequestLimit})',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _isCustomKey
                                ? AppColors.accentLight
                                : AppColors.cardLight,
                            borderRadius: BorderRadius.circular(6),
                            border: _isCustomKey
                                ? null
                                : Border.all(color: AppColors.divider),
                          ),
                          child: Text(
                            _isCustomKey ? 'Özel Anahtar' : 'Varsayılan',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: _isCustomKey
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: widget.remainingPercent / 100,
                        minHeight: 5,
                        backgroundColor: AppColors.surface,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          widget.remainingPercent > 20
                              ? AppColors.accentLight
                              : AppColors.warning,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // API Key Input
              if (_isLoadingInitial)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(
                      color: AppColors.accentLight,
                    ),
                  ),
                )
              else ...[
                TextField(
                  controller: _controller,
                  obscureText: _obscureText,
                  onChanged: _onKeyChanged,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                  cursorColor: AppColors.accentLight,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.divider),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.divider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: AppColors.accentLight,
                        width: 2,
                      ),
                    ),
                    fillColor: AppColors.card,
                    filled: true,
                    labelText: 'API Anahtarı',
                    labelStyle: const TextStyle(color: AppColors.textSecondary),
                    hintText: 'AIzaSy...',
                    hintStyle: const TextStyle(color: AppColors.textHint),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildStatusIndicator(),
                        IconButton(
                          icon: Icon(
                            _obscureText
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 20,
                            color: AppColors.textSecondary,
                          ),
                          tooltip:
                              _obscureText ? 'Anahtarı Göster' : 'Anahtarı Gizle',
                          onPressed: () {
                            setState(() {
                              _obscureText = !_obscureText;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Quick helper button: Validate Now
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: _validationState == ValidationState.validating
                          ? null
                          : () => _runValidation(_controller.text),
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Şimdi Doğrula', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.accentLight,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const Spacer(),
                    if (_isCustomKey ||
                        _controller.text.trim() !=
                            ApiConfig.defaultGeminiApiKey)
                      TextButton(
                        onPressed: _restoreDefaultKey,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Varsayılana Dön',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Status Banner (Tik veya Çarpı ile sonuç gösterimi)
                _buildValidationBanner(),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
          ),
          child: const Text('Kapat'),
        ),
        FilledButton.icon(
          onPressed: _validationState == ValidationState.validating
              ? null
              : _saveKey,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accentLight,
            foregroundColor: AppColors.textPrimary,
          ),
          icon: _validationState == ValidationState.valid
              ? const Icon(Icons.check_rounded, size: 18)
              : const Icon(Icons.save_rounded, size: 18),
          label: const Text('Kaydet'),
        ),
      ],
    );
  }
}
