import 'dart:async';
import 'package:flutter/foundation.dart';
import 'app_update_stub.dart'
    if (dart.library.js_interop) 'app_update_web.dart' as platform;

enum UpdateCheckStatus {
  upToDate,
  updateAvailable,
  error,
}

class UpdateCheckResult {
  final UpdateCheckStatus status;
  final String currentVersion;
  final String? availableVersion;
  final String? message;

  const UpdateCheckResult({
    required this.status,
    required this.currentVersion,
    this.availableVersion,
    this.message,
  });
}

class AppUpdateService {
  static bool _initialized = false;
  static Timer? _periodicTimer;

  /// Uygulama ilk açıldığında arka planda sessizce güncelleme ve önbellek kontrolü yapar.
  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // İlk açılış kontrolü (kullanıcıya çaktırmadan)
    await checkForUpdates();

    // Web ortamında açık kalan sekmeler için 15 dakikada bir otomatik kontrol
    if (kIsWeb) {
      _periodicTimer?.cancel();
      _periodicTimer = Timer.periodic(const Duration(minutes: 15), (_) {
        checkForUpdates();
      });
    }
  }

  /// Arka plan güncelleme kontrolü yap ve gerekiyorsa hard cache clear uygulayarak baştan yükle
  static Future<void> checkForUpdates() async {
    try {
      await platform.checkAndApplyUpdate();
    } catch (e) {
      debugPrint('[AppUpdateService] Kontrol hatası: $e');
    }
  }

  /// Manuel güncelleme kontrolü ve sonuç bilgisi
  static Future<UpdateCheckResult> checkForUpdatesManual() async {
    try {
      return await platform.checkUpdateDetailed();
    } catch (e) {
      debugPrint('[AppUpdateService] Manuel kontrol hatası: $e');
      return UpdateCheckResult(
        status: UpdateCheckStatus.error,
        currentVersion: '',
        message: 'Güncelleme kontrolü yapılamadı: $e',
      );
    }
  }

  /// Elle önbelleği temizleyip uygulamayı baştan başlatmak için
  static Future<void> forceHardReload([String? newVersion]) async {
    await platform.performHardReload(newVersion);
  }
}
