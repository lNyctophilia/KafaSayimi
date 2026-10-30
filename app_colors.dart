import 'package:flutter/material.dart';

/// Koyu lacivert renk paleti — siyaha yakın, asil tonlar
class AppColors {
  AppColors._();

  // Ana arka planlar
  static const Color background = Color(0xFF0A1128);
  static const Color surface = Color(0xFF131D35);
  static const Color card = Color(0xFF1B2845);
  static const Color cardLight = Color(0xFF223354);

  // Vurgu / Accent
  static const Color accent = Color(0xFF274472);
  static const Color accentLight = Color(0xFF3A86FF);

  // Gün renkleri (takvim)
  static const Color cityInner = Color(0xFF48BFE3); // Şehir içi — camgöbeği
  static const Color cityOuter = Color(0xFFF9A826); // Şehir dışı — turuncu

  // Metin
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF8899AA);
  static const Color textHint = Color(0xFF556677);

  // Durum renkleri
  static const Color success = Color(0xFF06D6A0);
  static const Color danger = Color(0xFFEF476F);
  static const Color warning = Color(0xFFF9A826);

  // Bugünün vurgu rengi
  static const Color todayBorder = Color(0xFF3A86FF);

  // Divider
  static const Color divider = Color(0xFF1E3050);
}
