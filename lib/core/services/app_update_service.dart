import 'dart:async';
import 'package:flutter/foundation.dart';
import 'app_update_stub.dart'
    if (dart.library.js_interop) 'app_update_web.dart' as platform;

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

  /// Güncelleme kontrolü yap ve gerekiyorsa hard cache clear uygulayarak baştan yükle
  static Future<void> checkForUpdates() async {
    try {
      await platform.checkAndApplyUpdate();
    } catch (e) {
      debugPrint('[AppUpdateService] Kontrol hatası: $e');
    }
  }

  /// Elle önbelleği temizleyip uygulamayı baştan başlatmak için
  static Future<void> forceHardReload() async {
    await platform.performHardReload();
  }
}

