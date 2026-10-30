# 📋 Kafa Sayımı

**Kafa Sayımı**, depo ve mağaza sayım kağıtlarındaki barkod kodlarını ve yanlarındaki el yazısı adet bilgilerini kamera veya galeriden alınan fotoğraflar üzerinden otomatik olarak tanıyan, sayısallaştıran ve dışa aktaran modern bir Flutter mobil uygulamasıdır.

Geleneksel optik karakter tanıma (OCR) motorlarının el yazılarında yetersiz kaldığı durumları aşmak için **Google Gemini Multimodal Vision API** modellerini kullanır.

---

## ✨ Öne Çıkan Özellikler

- 🤖 **Yapay Zeka Destekli OCR (Gemini Vision)**:
  - 3 sütunlu sayım kağıtlarındaki barkod kodlarını (`RR-XXXX/YYYY` standardında) ve yanlarındaki el yazısı sayıları yüksek doğrulukla okur.
  - "SON", "Adet" gibi el yazısı ek ibareleri otomatik olarak ayıklar, yalnızca saf adet bilgisini alır.
  - Model yedekleme (fallback) mimarisi: `gemini-3-flash-preview`, `gemini-flash-lite-latest` ve `gemini-3.1-flash-lite-preview` modelleri sıralı olarak denenir.

- 🎯 **Akıllı Eminlik (Confidence) ve Renk Kodlu Uyarı Rozetleri**:
  - Yapay zeka her satır için 0-100 arasında bir güven skoru üretir.
  - 🟢 **%92 ve üzeri**: Yüksek güvenilirlik (normal görünüm).
  - 🟡 **%87 - %91**: Sarı uyarı rozeti (silik veya tereddütlü okumalar için gözden geçirme tavsiyesi).
  - 🔴 **%87 altı**: Kırmızı uyarı rozeti (şüpheli, silik veya karalanmış rakamlar için dikkat uyarısı).

- 🔍 **Dahili Fotoğraf İnceleme ve Zoom**:
  - Okunan sayım kağıdının orijinal fotoğrafını tam ekran açma ve iki parmakla yakınlaştırma (`InteractiveViewer`).
  - Sayım kağıdını elinize almadan uygulama içinden şüpheli el yazılarını orijinal görüntüyle birebir kontrol etme imkanı.

- ✏️ **Hızlı Düzenleme ve Satır Yönetimi**:
  - Tespit edilen barkod ve adetler üzerinde anında düzenleme.
  - Eksik kalan satırları manuel ekleme veya hatalı satırları tek tuşla silme.
  - Toplam taranan satır ve toplam adet özetini anlık görüntüleme.

- 📤 **TXT Dışa Aktarma & Paylaşım**:
  - Tek dokunuşla tüm sayım verilerini standart metin (.txt) formatında WhatsApp, E-posta, Telegram veya dosya yöneticisiyle paylaşma / cihaza kaydetme.

- 🔑 **Kişisel Gemini API ve Canlı Kota Takibi**:
  - Kullanıcılar kendi ücretsiz Google Gemini API anahtarlarını uygulama içerisinden kolayca tanımlayabilir.
  - "Şimdi Doğrula" butonu ile API anahtarının geçerliliğini anında test etme.
  - Google AI Studio üzerinden ücretsiz API anahtarı alma rehberi.
  - Günlük güvenlik kotasını (1000 istek) ve kalan hak yüzdesini AppBar ve ayarlar ekranında canlı izleme.
  - API anahtarı cihazın yerel hafızasında (`SharedPreferences`) şifrelenmiş/güvenli olarak tutulur.

- 🎨 **Modern Koyu Tema (Dark UI)**:
  - Sayım ortamlarında ve gece kullanımında göz yormayan, lacivert-siyah kontrastına sahip arayüz tasarımı.

---

## 📱 Ekran Görüntüleri ve Akış

```text
[ Fotoğraf Çek / Galeriden Seç ]
               │
               ▼
   [ Gemini Vision Analizi ]
   (Görüntü Arka Planda İşlenir)
               │
               ▼
      [ Sonuçlar Ekranı ]
  - Barkod & Adet Listesi
  - Eminlik Skoru Rozetleri (Sarı/Kırmızı)
  - Fotoğraf İnceleme (Zoom)
  - Düzenleme & Satır Ekleme
               │
               ▼
      [ TXT Paylaş / Kaydet ]
```

---

## 🛠️ Teknoloji Yığını

| Kategori | Teknoloji / Paket |
| :--- | :--- |
| **Framework** | Flutter 3.x (Dart 3.x) |
| **Durum Yönetimi** | Riverpod (`flutter_riverpod: ^2.5.1`) |
| **Yönlendirme (Routing)** | `go_router: ^14.2.0` |
| **Yapay Zeka (AI)** | Google Gemini Multimodal REST API |
| **Medya & Kamera** | `image_picker: ^1.1.2` |
| **Dosya & Paylaşım** | `share_plus: ^13.3.1`, `path_provider: ^2.1.6` |
| **Yerel Depolama** | `shared_preferences: ^2.5.6` |
| **Vektör & Grafikler** | `flutter_svg: ^2.3.2` |

---

## 📂 Proje Dizin Yapısı

```text
lib/
├── app.dart                   # GoRouter ve genel uygulama teması
├── main.dart                  # Uygulama başlangıç noktası (ProviderScope)
├── core/
│   ├── config/
│   │   └── api_config.dart    # API limit ve varsayılan yapılandırmalar
│   ├── models/
│   │   ├── barcode_entry.dart # Barkod satır modeli ve eminlik hesapları
│   │   └── scan_state.dart    # Tarama ve işleme durum modelleri
│   ├── providers/
│   │   └── scan_provider.dart # Riverpod tarama state yönetimi
│   ├── services/
│   │   ├── export_service.dart        # TXT oluşturma ve paylaşım servisi
│   │   └── gemini_vision_service.dart # Gemini API istemcisi, kota ve analiz
│   └── theme/
│       ├── app_colors.dart    # Renk paleti
│       └── app_theme.dart     # Koyu tema tanımlamaları
└── features/
    ├── home/
    │   └── home_screen.dart   # Ana ekran (Kamera/Galeri seçimi, kota takibi)
    ├── results/
    │   ├── results_screen.dart         # Sonuç listesi ve işlem butonları
    │   └── widgets/
    │       ├── entry_row_widget.dart   # Satır kartı, uyarı rozetleri ve kontroller
    │       └── full_screen_image_viewer.dart # Fotoğraf zoom görüntüleyici
    └── settings/
        └── gemini_api_screen.dart      # Gemini API anahtarı yönetimi ve rehber
```

---

## 🚀 Başlangıç & Kurulum

### Ön Koşullar

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.3.0 veya üzeri)
- Android Studio / VS Code ve Android SDK
- [Google AI Studio](https://aistudio.google.com/)'dan temin edilmiş ücretsiz bir Gemini API Anahtarı

### Adımlar

1. **Depoyu Klonlayın:**
   ```bash
   git clone https://github.com/kullanici_adiniz/kafa_sayimi.git
   cd kafa_sayimi
   ```

2. **Bağımlılıkları Yükleyin:**
   ```bash
   flutter pub get
   ```

3. **Uygulamayı Çalıştırın:**
   ```bash
   flutter run
   ```

4. **API Anahtarını Tanımlayın:**
   - Uygulamayı açtıktan sonra sağ üst köşedeki **Ayarlar** (çark) simgesine dokunun.
   - Google AI Studio'dan aldığınız API anahtarınızı yapıştırın ve **Kaydet** butonuna basın.
   - Dilerseniz **Şimdi Doğrula** butonu ile bağlantıyı hemen test edebilirsiniz.

---

## 📦 APK Derleme (Release Build)

Android cihazınıza yüklemek için optimize edilmiş imzalı/imzasız release APK çıktısı almak için:

```bash
flutter build apk --release
```

Derlenen APK dosyası şu dizinde oluşturulacaktır:
`build/app/outputs/flutter-apk/app-release.apk`

---

## 📄 Lisans

Bu proje kişisel ve kurumsal sayım süreçlerini dijitalleştirmek amacıyla geliştirilmiştir. Tüm hakları saklıdır.
