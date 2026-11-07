import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/barcode_entry.dart';
import '../config/api_config.dart';

class ApiKeyValidationResult {
  final bool isValid;
  final String message;

  const ApiKeyValidationResult({
    required this.isValid,
    required this.message,
  });
}

class GeminiAnalysisResult {
  final List<BarcodeEntry> entries;
  final int remainingRequests;
  final int totalLimit;

  GeminiAnalysisResult({
    required this.entries,
    required this.remainingRequests,
    required this.totalLimit,
  });

  /// Kalan günlük hak yüzdesi (0 - 100)
  int get remainingPercentage {
    if (totalLimit <= 0) return 0;
    return ((remainingRequests / totalLimit) * 100).round().clamp(0, 100);
  }
}

class GeminiVisionService {
  static const String _prefKey = 'gemini_api_key';

  // ── In-memory cache ───────────────────────────────────────────────────────
  static String? _cachedApiKey;
  static SharedPreferences? _prefs;

  static Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Active working models tested with user's key
  static const List<String> _models = [
    'gemini-3-flash-preview',
    'gemini-flash-lite-latest',
    'gemini-3.1-flash-lite-preview',
  ];

  /// Get active API key (User custom key or default embedded key)
  static Future<String> getApiKey() async {
    if (_cachedApiKey != null) return _cachedApiKey!;
    final prefs = await _getPrefs();
    final customKey = prefs.getString(_prefKey);
    if (customKey != null && customKey.trim().isNotEmpty) {
      _cachedApiKey = customKey.trim();
      return _cachedApiKey!;
    }
    return ApiConfig.defaultGeminiApiKey;
  }

  /// Save custom API key to SharedPreferences
  static Future<void> saveApiKey(String apiKey) async {
    final prefs = await _getPrefs();
    await prefs.setString(_prefKey, apiKey.trim());
    _cachedApiKey = apiKey.trim(); // update cache
  }

  /// Remove custom key and revert to embedded key
  static Future<void> clearApiKey() async {
    final prefs = await _getPrefs();
    await prefs.remove(_prefKey);
    _cachedApiKey = null; // invalidate cache
  }

  /// Check if user has saved a custom API key
  static Future<bool> hasCustomApiKey() async {
    final prefs = await _getPrefs();
    final customKey = prefs.getString(_prefKey);
    return customKey != null && customKey.trim().isNotEmpty;
  }

  /// Validate a Gemini API key by making a lightweight request
  static Future<ApiKeyValidationResult> validateApiKey(String apiKey) async {
    final cleanKey = apiKey.trim();
    if (cleanKey.isEmpty) {
      return const ApiKeyValidationResult(
        isValid: false,
        message: 'API anahtarı boş bırakılamaz.',
      );
    }

    try {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models?key=$cleanKey',
      );
      final response = await http
          .get(url)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return const ApiKeyValidationResult(
          isValid: true,
          message: 'API anahtarı geçerli ve çalışıyor.',
        );
      }

      String? errorDetail;
      try {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final error = decoded['error'] as Map<String, dynamic>?;
        errorDetail = error?['message'] as String?;
      } catch (_) {}

      if (response.statusCode == 400 || response.statusCode == 403) {
        return ApiKeyValidationResult(
          isValid: false,
          message: errorDetail ?? 'API anahtarı geçersiz veya yetkisiz (Kod: ${response.statusCode}).',
        );
      } else if (response.statusCode == 429) {
        return const ApiKeyValidationResult(
          isValid: true,
          message: 'API anahtarı geçerli (ancak anlık istek limiti dolu).',
        );
      } else {
        return ApiKeyValidationResult(
          isValid: false,
          message: errorDetail ?? 'Doğrulama başarısız oldu (Hata: ${response.statusCode}).',
        );
      }
    } on SocketException {
      return const ApiKeyValidationResult(
        isValid: false,
        message: 'İnternet bağlantısı yok veya sunucuya erişilemiyor.',
      );
    } on TimeoutException {
      return const ApiKeyValidationResult(
        isValid: false,
        message: 'Bağlantı zaman aşımına uğradı. Lütfen internetinizi kontrol edin.',
      );
    } catch (e) {
      return ApiKeyValidationResult(
        isValid: false,
        message: 'Bağlantı hatası: ${e.toString().replaceAll('Exception: ', '')}',
      );
    }
  }

  /// Get today's usage key: e.g. "gemini_usage_2026-10-30"
  static String _todayUsageKey() {
    final now = DateTime.now();
    return 'gemini_usage_${now.year}_${now.month}_${now.day}';
  }

  /// Check how many requests remain today
  static Future<int> getRemainingRequests() async {
    final prefs = await _getPrefs();
    final used = prefs.getInt(_todayUsageKey()) ?? 0;
    final remaining = ApiConfig.dailyRequestLimit - used;
    return remaining < 0 ? 0 : remaining;
  }

  /// Get remaining daily requests as a percentage (0 - 100)
  static Future<int> getRemainingPercentage() async {
    final remaining = await getRemainingRequests();
    if (ApiConfig.dailyRequestLimit <= 0) return 0;
    return ((remaining / ApiConfig.dailyRequestLimit) * 100).round().clamp(0, 100);
  }

  /// Check API connectivity and query quota if endpoint provides rate limit headers
  static Future<int> checkApiQuota() async {
    try {
      final apiKey = await getApiKey();
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        // If API returns quota or rate limit headers, read them
        final header = response.headers['x-ratelimit-remaining-requests'] ??
            response.headers['x-ratelimit-remaining'] ??
            response.headers['x-quota-remaining'];
        if (header != null) {
          final parsed = int.tryParse(header);
          if (parsed != null) return parsed;
        }
      }
    } catch (_) {
      // Network/timeout error during quota check, fallback to local tracker
    }
    return await getRemainingRequests();
  }

  /// Increment today's usage counter
  static Future<int> _recordUsage() async {
    final prefs = await _getPrefs();
    final key = _todayUsageKey();
    final current = prefs.getInt(key) ?? 0;
    final updated = current + 1;
    await prefs.setInt(key, updated);
    return ApiConfig.dailyRequestLimit - updated;
  }

  /// Send image to Gemini Vision API with automatic model fallback
  static Future<GeminiAnalysisResult> analyzeImage({
    String? imagePath,
    Uint8List? imageBytes,
  }) async {
    final remainingBefore = await getRemainingRequests();
    if (remainingBefore <= 0) {
      throw Exception(
        'Günlük güvenlik limitine (${ApiConfig.dailyRequestLimit} istek) ulaştınız. '
        'Yarın haklarınız otomatik yenilenecektir.',
      );
    }

    final apiKey = await getApiKey();
    if (apiKey.isEmpty) {
      throw Exception(
        'Gemini API anahtarı girilmedi. Lütfen sağ üstteki ayarlar simgesinden API anahtarınızı girin.',
      );
    }

    final Uint8List bytes;
    if (imageBytes != null) {
      bytes = imageBytes;
    } else if (imagePath != null && !kIsWeb) {
      final file = File(imagePath);
      if (!await file.exists()) {
        throw Exception('Görüntü dosyası bulunamadı: $imagePath');
      }
      bytes = await file.readAsBytes();
    } else {
      throw Exception('Görüntü verisi bulunamadı.');
    }

    // ── Base64 encoding'i isolate'ta yap (UI donmaz) ──
    final String base64Image = await compute(_encodeBase64Isolate, bytes);

    const prompt = '''
Bu görselde bir sayım kağıdı var. 3 sütun halinde kutucuklar var.
Her kutucukta:
- Barkod ve altında basılmış kodu/yazısı
- "Adet:" etiketi ve yanında/altında el yazısı sayılar (örn: 34, 24, 15, 42, 53, 40, 9 SON vs.)

GÖREV:
1. Yalnızca el yazısı ile adet girilmiş olan hücreleri sırasıyla listele. Boş hücreleri ALMA.
2. "quantity" (adet) kısmında YALNIZCA RAKAM / SAYI olmalıdır! "SON", "Adet" gibi hiçbir harf veya kelimeyi YAZMA (örn: "9 SON" yazıyorsa YALNIZCA "9" yaz).
3. BARKODUN ALTINDAKİ YAZIYI OKUMA (ÇOK ÖNEMLİ):
   - Barkodun hemen altında basılı metin/kod ne yazıyorsa doğrudan ve aynen onu oku.
   - Bazı kağıtlarda tarih yerine farklı ibareler, harfler veya sayılar yazabilir; kesinlikle belirli bir tarih formatı veya kalıp (RR-XXXX/YYYY gibi) dayatma.
   - Araya veya başına tire ('-'), eğik çizgi ('/') gibi işaretler KOYMA / EKLEME. Tire falan koymadan doğrudan barkodun altında ne yazıyorsa onu düz bir şekilde yaz.
4. ÜSTÜ ÇİZİLİ / KARALANMIŞ ADETLER (ÇOK ÖNEMLİ):
   - Bazen el yazısı adetlerin üzeri çizilmiş, karalanmış veya iptal edilmiş olabilir.
   - Üstü çizili veya karalanmış sayıları kesin doğru bir adetmiş gibi okumaya veya tahmin etmeye ÇALIŞMA!
   - Eğer sayının üstü çizilip yanına/üstüne YENİ ve net bir sayı yazılmışsa, yalnızca o yeni sayıyı adet olarak al.
   - Eğer kutucuktaki sayının üzeri çizilmiş/karalanmışsa ve yanında yeni bir sayı yoksa (veya karalama nedeniyle ne yazdığı tereddütlüyse):
     * Sayıyı kesin gibi kabul edip okumaya zorlama.
     * Bu hücre için "confidence" (eminlik skoru) değerini MUTLAKA %87'nin altında (60 - 75 arasında) DÜŞÜK ver ki sistem bu satırda kullanıcıya doğrudan kırmızı uyarı göstersin!
5. "confidence": Okuma doğruluğu ve el yazısı netliği için 0-100 arasında bir eminlik skoru belirle (sayı olarak):
   - El yazısı ve barkod net ve tereddütsüz ise: 92 - 100
   - El yazısı biraz silik, tereddütlü veya rakamlar tam net değilse (%92 altı sarı uyarı): 87 - 91
   - Üstü çizili, karalanmış, üzeri karalamayla kapatılmış, çok silik veya 1/7, 0/6, 3/8 gibi tereddüt içeren tüm şüpheli okumalarda (%87 altı KIRMIZI UYARI): 60 - 75 (Kesinlikle 87'nin altında olmalı!)

YALNIZCA geçerli bir JSON array döndür:
[
  {"barcode": "RR01332710", "quantity": "34", "confidence": 98}
]
''';

    final requestBody = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt},
            {
              'inline_data': {
                'mime_type': 'image/jpeg',
                'data': base64Image,
              }
            }
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.1,
        'response_mime_type': 'application/json',
      }
    });

    String? lastError;

    // Try working models in order: gemini-3-flash-preview, gemini-flash-lite-latest
    for (final model in _models) {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
      );

      try {
        final response = await http
            .post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: requestBody,
            )
            .timeout(const Duration(seconds: 28));

        if (response.statusCode == 200) {
          int remainingAfter = await _recordUsage();

          // Check if response contains rate limit / quota headers from API
          final header = response.headers['x-ratelimit-remaining-requests'] ??
              response.headers['x-ratelimit-remaining'] ??
              response.headers['x-quota-remaining'];
          if (header != null) {
            final parsed = int.tryParse(header);
            if (parsed != null) remainingAfter = parsed;
          }

          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final candidates = data['candidates'] as List<dynamic>?;
          if (candidates == null || candidates.isEmpty) {
            throw Exception('Gemini geçerli bir yanıt üretemedi.');
          }

          final content = candidates.first['content'] as Map<String, dynamic>?;
          final parts = content?['parts'] as List<dynamic>?;
          final text = parts?.first['text'] as String?;

          if (text == null || text.trim().isEmpty) {
            return GeminiAnalysisResult(
              entries: [],
              remainingRequests: remainingAfter,
              totalLimit: ApiConfig.dailyRequestLimit,
            );
          }

          final entries = _parseJsonOutput(text);
          entries.sort((a, b) => BarcodeComparator.compare(a.barcodeCode, b.barcodeCode));

          return GeminiAnalysisResult(
            entries: entries,
            remainingRequests: remainingAfter,
            totalLimit: ApiConfig.dailyRequestLimit,
          );
        } else if (response.statusCode == 404) {
          lastError = 'Model $model bulunamadı (404), alternatif deneniyor...';
          continue;
        } else if (response.statusCode == 400 || response.statusCode == 403) {
          throw Exception(
            'API Anahtarı geçersiz veya yetkisiz (Kod: ${response.statusCode}). Lütfen anahtarınızı kontrol edin.',
          );
        } else if (response.statusCode == 429) {
          // Rate limit - wait 2 seconds and retry next model
          await Future.delayed(const Duration(seconds: 2));
          lastError = 'Dakikalık istek sınırı (429), alternatif deneniyor...';
          continue;
        } else {
          lastError = 'Gemini API Hatası ($model - ${response.statusCode}): ${response.body}';
        }
      } catch (e) {
        if (e.toString().contains('API Anahtarı')) rethrow;
        lastError = e.toString();
      }
    }

    throw Exception(lastError ?? 'Tüm Gemini modelleri denendi ancak yanıt alınamadı.');
  }

  /// Çoklu sayım kağıdı görüntüsünü paralel havuz (worker pool) ile analiz eder.
  /// Sonuçları barkod adına göre artan (A-Z) sırada birleştirir ve döndürür.
  static Future<GeminiAnalysisResult> analyzeMultipleImages({
    required List<Uint8List> imagesBytes,
    List<String?>? imagesPaths,
    void Function(int completed, int total, String status)? onProgress,
  }) async {
    final total = imagesBytes.length;
    if (total == 0) {
      return GeminiAnalysisResult(
        entries: [],
        remainingRequests: await getRemainingRequests(),
        totalLimit: ApiConfig.dailyRequestLimit,
      );
    }

    if (total == 1) {
      final res = await analyzeImage(
        imageBytes: imagesBytes.first,
        imagePath: (imagesPaths != null && imagesPaths.isNotEmpty)
            ? imagesPaths.first
            : null,
      );
      final singleEntries =
          res.entries.map((e) => e.copyWith(pageIndex: 1)).toList();
      singleEntries.sort(
          (a, b) => BarcodeComparator.compare(a.barcodeCode, b.barcodeCode));
      return GeminiAnalysisResult(
        entries: singleEntries,
        remainingRequests: res.remainingRequests,
        totalLimit: res.totalLimit,
      );
    }

    final remainingBefore = await getRemainingRequests();
    if (remainingBefore <= 0) {
      throw Exception(
        'Günlük güvenlik limitine (${ApiConfig.dailyRequestLimit} istek) ulaştınız. '
        'Yarın haklarınız otomatik yenilenecektir.',
      );
    }

    final List<List<BarcodeEntry>?> results = List.filled(total, null);
    final List<String> errors = [];
    int completedCount = 0;
    int remainingAfter = remainingBefore;

    // Maksimum eşzamanlı istek (hız + kota dengesi için 3)
    const int maxConcurrency = 3;
    int nextIndex = 0;

    Future<void> worker() async {
      while (true) {
        final currentIndex = nextIndex++;
        if (currentIndex >= total) break;

        final pageNumber = currentIndex + 1;
        onProgress?.call(
          completedCount,
          total,
          'Sayfa $pageNumber taranıyor... ($completedCount/$total tamamlandı)',
        );

        try {
          final bytes = imagesBytes[currentIndex];
          final path =
              (imagesPaths != null && currentIndex < imagesPaths.length)
                  ? imagesPaths[currentIndex]
                  : null;

          final result = await analyzeImage(
            imageBytes: bytes,
            imagePath: path,
          );

          remainingAfter = result.remainingRequests;

          // Her kayda ait olduğu sayfa numarasını ekle ve sayfa içi barkoda göre artan sırala
          final pageEntries = result.entries
              .map((e) => e.copyWith(pageIndex: pageNumber))
              .toList();
          pageEntries.sort(
              (a, b) => BarcodeComparator.compare(a.barcodeCode, b.barcodeCode));

          results[currentIndex] = pageEntries;
        } catch (e) {
          errors.add('Sayfa $pageNumber hatası: $e');
        } finally {
          completedCount++;
          onProgress?.call(
            completedCount,
            total,
            '$completedCount / $total sayfa tamamlandı',
          );
        }
      }
    }

    final workerCount = total < maxConcurrency ? total : maxConcurrency;
    await Future.wait(List.generate(workerCount, (_) => worker()));

    // Tüm sayfaların sonuçlarını birleştir:
    // Önce Sayfa 1, sonra Sayfa 2, Sayfa 3... şeklinde; her sayfa kendi içinde barkoda göre artan sırada
    final allEntries = <BarcodeEntry>[];
    for (int i = 0; i < results.length; i++) {
      final list = results[i];
      if (list != null) {
        list.sort(
            (a, b) => BarcodeComparator.compare(a.barcodeCode, b.barcodeCode));
        allEntries.addAll(list);
      }
    }

    if (allEntries.isEmpty && errors.isNotEmpty) {
      throw Exception(
          'Sayfalar taranırken hata oluştu:\n${errors.join("\n")}');
    }

    // Sayfa sırasına (Sayfa 1, 2, 3...) ve sayfa içinde barkoda göre artan sıraya göre sırala
    allEntries.sort((a, b) {
      final pageA = a.pageIndex ?? 1;
      final pageB = b.pageIndex ?? 1;
      final pageCmp = pageA.compareTo(pageB);
      if (pageCmp != 0) return pageCmp;
      return BarcodeComparator.compare(a.barcodeCode, b.barcodeCode);
    });

    // Sıralı liste için temiz sıralı ID'ler ata
    final sortedWithCleanIds = <BarcodeEntry>[];
    for (int i = 0; i < allEntries.length; i++) {
      final e = allEntries[i];
      sortedWithCleanIds.add(BarcodeEntry(
        id: i.toString(),
        barcodeCode: e.barcodeCode,
        quantity: e.quantity,
        isQuantityConfident: e.isQuantityConfident,
        confidence: e.confidence,
        pageIndex: e.pageIndex,
      ));
    }

    return GeminiAnalysisResult(
      entries: sortedWithCleanIds,
      remainingRequests: remainingAfter,
      totalLimit: ApiConfig.dailyRequestLimit,
    );
  }

  static List<BarcodeEntry> _parseJsonOutput(String rawText) {
    var cleaned = rawText.trim();
    if (cleaned.startsWith('```json')) {
      cleaned = cleaned.substring(7);
    } else if (cleaned.startsWith('```')) {
      cleaned = cleaned.substring(3);
    }
    if (cleaned.endsWith('```')) {
      cleaned = cleaned.substring(0, cleaned.length - 3);
    }
    cleaned = cleaned.trim();

    final dynamic parsed = jsonDecode(cleaned);
    final List<dynamic> list = parsed is List ? parsed : [];

    final entries = <BarcodeEntry>[];
    int idCounter = 0;

    for (final item in list) {
      if (item is Map<String, dynamic>) {
        var barcode = (item['barcode'] ?? item['code'] ?? '').toString().trim();
        // Tire veya bölü işaretlerini temizle (tire falan koymadan düz metin olarak al)
        barcode = barcode.replaceAll(RegExp(r'[-/]'), '').trim();
        var quantity = (item['quantity'] ?? item['adet'] ?? '').toString().trim();

        // Strip any letters or words like "SON", keeping only pure digits
        final digitsOnly = quantity.replaceAll(RegExp(r'[^0-9]'), '');
        if (digitsOnly.isNotEmpty) {
          quantity = digitsOnly;
        }

        // Parse confidence score (0 - 100)
        double confidence = 98.0;
        final rawConfidence = item['confidence'] ?? item['score'] ?? item['eminlik'];
        if (rawConfidence != null) {
          if (rawConfidence is num) {
            confidence = rawConfidence.toDouble();
          } else if (rawConfidence is String) {
            final parsed = double.tryParse(rawConfidence.replaceAll('%', '').trim());
            if (parsed != null) confidence = parsed;
          }
          // If returned as 0.0 - 1.0 (e.g. 0.92), normalize to 0 - 100 (92.0)
          if (confidence > 0 && confidence <= 1.0) {
            confidence = confidence * 100;
          }
        }

        if (barcode.isNotEmpty) {
          entries.add(BarcodeEntry(
            id: (idCounter++).toString(),
            barcodeCode: barcode,
            quantity: quantity,
            isQuantityConfident: confidence >= 92.0,
            confidence: confidence,
          ));
        }
      }
    }

    return entries;
  }

  // ── Yardımcı fonksiyon ─────────────────────────────────────────────────────

  /// Base64 encoding'i isolate'ta yapar — UI thread'i bloklamaz.
  static String _encodeBase64Isolate(Uint8List bytes) => base64Encode(bytes);
}
