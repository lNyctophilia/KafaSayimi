import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_version.dart';
import 'app_update_service.dart';

@JS('hardClearAndReload')
external void _hardClearAndReload([JSString? newVersion]);

const String _kPrefVersionKey = 'ks_dart_installed_version';

Future<void> checkAndApplyUpdate() async {
  try {
    final result = await checkUpdateDetailed();
    if (result.status == UpdateCheckStatus.updateAvailable) {
      debugPrint(
        '[AppUpdateService Web] Otomatik yeni sürüm algılandı: ${result.availableVersion}',
      );
      await performHardReload(result.availableVersion);
    }
  } catch (e) {
    debugPrint('[AppUpdateService Web] Hata: $e');
  }
}

Future<UpdateCheckResult> checkUpdateDetailed() async {
  try {
    final uri = Uri.base.resolve(
      'version.json?_t=${DateTime.now().millisecondsSinceEpoch}',
    );
    final response = await http.get(
      uri,
      headers: {
        'Cache-Control': 'no-cache, no-store, must-revalidate',
        'Pragma': 'no-cache',
        'Expires': '0',
      },
    ).timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final etag =
          response.headers['etag'] ?? response.headers['last-modified'] ?? '';

      // 1. version.json içinde version_tag varsa karşılaştır
      final versionTag = data['version_tag']?.toString().trim();
      if (versionTag != null && versionTag.isNotEmpty) {
        if (versionTag != AppVersion.current) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_kPrefVersionKey, versionTag);
          return UpdateCheckResult(
            status: UpdateCheckStatus.updateAvailable,
            currentVersion: AppVersion.current,
            availableVersion: versionTag,
          );
        }
      }

      // 2. etag veya build number karşılaştırması
      final remoteVersion =
          '${data['version'] ?? '1.0.0'}+${data['build_number'] ?? '1'}_$etag'
              .replaceAll('"', '')
              .replaceAll(' ', '');

      final prefs = await SharedPreferences.getInstance();
      final localVersion = prefs.getString(_kPrefVersionKey);

      if (localVersion != null &&
          localVersion != remoteVersion &&
          versionTag == null) {
        await prefs.setString(_kPrefVersionKey, remoteVersion);
        return UpdateCheckResult(
          status: UpdateCheckStatus.updateAvailable,
          currentVersion: AppVersion.current,
          availableVersion: remoteVersion,
        );
      }

      if (localVersion == null) {
        await prefs.setString(_kPrefVersionKey, versionTag ?? remoteVersion);
      }
    }

    // 3. GitHub repository üzerinden doğrudan app_version.dart kontrolü
    try {
      final rawUri = Uri.parse(
        'https://raw.githubusercontent.com/lNyctophilia/KafaSayimi/main/lib/core/config/app_version.dart?_t=${DateTime.now().millisecondsSinceEpoch}',
      );
      final rawRes = await http.get(rawUri).timeout(const Duration(seconds: 5));
      if (rawRes.statusCode == 200) {
        final match =
            RegExp(r"current\s*=\s*['""]([^'""]+)['""]").firstMatch(rawRes.body);
        if (match != null) {
          final githubVersion = match.group(1)?.trim();
          if (githubVersion != null &&
              githubVersion.isNotEmpty &&
              githubVersion != AppVersion.current) {
            return UpdateCheckResult(
              status: UpdateCheckStatus.updateAvailable,
              currentVersion: AppVersion.current,
              availableVersion: githubVersion,
            );
          }
        }
      }
    } catch (_) {}

    return const UpdateCheckResult(
      status: UpdateCheckStatus.upToDate,
      currentVersion: AppVersion.current,
    );
  } catch (e) {
    debugPrint('[AppUpdateService Web] Detaylı kontrol hatası: $e');
    return const UpdateCheckResult(
      status: UpdateCheckStatus.error,
      currentVersion: AppVersion.current,
      message: 'İnternet bağlantınızı kontrol edin veya daha sonra tekrar deneyin.',
    );
  }
}

Future<void> performHardReload([String? newVersion]) async {
  try {
    if (newVersion != null) {
      _hardClearAndReload(newVersion.toJS);
    } else {
      _hardClearAndReload();
    }
  } catch (e) {
    debugPrint('[AppUpdateService Web] Reload hatası: $e');
  }
}
