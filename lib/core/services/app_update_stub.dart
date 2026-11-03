import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_version.dart';
import 'app_update_service.dart';

const String _kPrefVersionKey = 'ks_mobile_installed_version';

Future<void> checkAndApplyUpdate() async {
  try {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();

    final prefs = await SharedPreferences.getInstance();
    final lastVersion = prefs.getString(_kPrefVersionKey);

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

Future<UpdateCheckResult> checkUpdateDetailed() async {
  try {
    final rawUri = Uri.parse(
      'https://raw.githubusercontent.com/lNyctophilia/KafaSayimi/main/lib/core/config/app_version.dart?_t=${DateTime.now().millisecondsSinceEpoch}',
    );
    final response = await http.get(rawUri).timeout(const Duration(seconds: 6));
    if (response.statusCode == 200) {
      final match =
          RegExp(r"current\s*=\s*['""]([^'""]+)['""]").firstMatch(response.body);
      if (match != null) {
        final remoteVersion = match.group(1)?.trim();
        if (remoteVersion != null &&
            remoteVersion.isNotEmpty &&
            remoteVersion != AppVersion.current) {
          return UpdateCheckResult(
            status: UpdateCheckStatus.updateAvailable,
            currentVersion: AppVersion.current,
            availableVersion: remoteVersion,
          );
        }
      }
    }
    return const UpdateCheckResult(
      status: UpdateCheckStatus.upToDate,
      currentVersion: AppVersion.current,
    );
  } catch (e) {
    debugPrint('[AppUpdateService Stub] Kontrol hatası: $e');
    return UpdateCheckResult(
      status: UpdateCheckStatus.error,
      currentVersion: AppVersion.current,
      message: 'İnternet bağlantınızı kontrol edin: $e',
    );
  }
}

Future<void> performHardReload([String? newVersion]) async {
  PaintingBinding.instance.imageCache.clear();
  PaintingBinding.instance.imageCache.clearLiveImages();
}
