import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kPrefVersionKey = 'ks_mobile_installed_version';

Future<void> checkAndApplyUpdate() async {
  try {
    // Görsel önbelleğini her açılışta taze tut
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();

    // Sürüm değişikliği kontrolü (yeni APK yüklendiğinde eski geçici dosyaları silme)
    final prefs = await SharedPreferences.getInstance();
    final lastVersion = prefs.getString(_kPrefVersionKey);

    // Mobil cihazda geçici taranmış fotoğraf önbelleğini temizleme
    if (lastVersion != null) {
      final tempDir = await getTemporaryDirectory();
      if (tempDir.existsSync()) {
        try {
          final files = tempDir.listSync();
          for (final file in files) {
            if (file is File &&
                (file.path.endsWith('.jpg') ||
                    file.path.endsWith('.png') ||
                    file.path.endsWith('.txt'))) {
              file.deleteSync();
            }
          }
        } catch (_) {}
      }
    }
  } catch (e) {
    debugPrint('[AppUpdateService Mobile] Hata: $e');
  }
}

Future<void> performHardReload([String? newVersion]) async {
  PaintingBinding.instance.imageCache.clear();
  PaintingBinding.instance.imageCache.clearLiveImages();
}

