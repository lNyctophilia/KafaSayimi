import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

@JS('hardClearAndReload')
external void _hardClearAndReload([JSString? newVersion]);

const String _kPrefVersionKey = 'ks_dart_installed_version';

Future<void> checkAndApplyUpdate() async {
  try {
    final uri = Uri.parse(
      'version.json?_t=${DateTime.now().millisecondsSinceEpoch}',
    );
    final response = await http.get(
      uri,
      headers: {
        'Cache-Control': 'no-cache, no-store, must-revalidate',
        'Pragma': 'no-cache',
        'Expires': '0',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final etag =
          response.headers['etag'] ?? response.headers['last-modified'] ?? '';
      final remoteVersion =
          '${data['version'] ?? '1.0.0'}+${data['build_number'] ?? '1'}_$etag'
              .replaceAll('"', '')
              .replaceAll(' ', '');

      final prefs = await SharedPreferences.getInstance();
      final localVersion = prefs.getString(_kPrefVersionKey);

      if (localVersion != null && localVersion != remoteVersion) {
        debugPrint(
          '[AppUpdateService] Web yeni sürüm algılandı: $localVersion -> $remoteVersion',
        );
        await prefs.setString(_kPrefVersionKey, remoteVersion);
        await performHardReload(remoteVersion);
        return;
      }

      if (localVersion == null) {
        await prefs.setString(_kPrefVersionKey, remoteVersion);
      }
    }
  } catch (e) {
    debugPrint('[AppUpdateService Web] Hata: $e');
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
