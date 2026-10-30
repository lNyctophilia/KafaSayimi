import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ExportService {
  /// Save text to file and share/download it
  static Future<void> exportText(String filename, String content) async {
    if (kIsWeb) {
      return;
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$filename');
      await file.writeAsString(content);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Kafa Sayımı Sonuçları ($filename)',
          subject: filename,
        ),
      );
    } catch (_) {
      // Fallback
      await SharePlus.instance.share(
        ShareParams(
          text: content,
          subject: filename,
        ),
      );
    }
  }
}
