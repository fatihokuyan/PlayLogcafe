import 'package:flutter/material.dart';

/// Uygulama genelinde kullanılan renk paleti.
/// PlayStation temasına uygun koyu-mavi tonlar ağırlıklı.
class AppColors {
  AppColors._(); // instance oluşturmayı engelle

  // ── Ana renkler ──
  static const Color primary = Color(0xFF003087); // PlayStation mavi
  static const Color primaryLight = Color(0xFF1E5BC6);
  static const Color primaryDark = Color(0xFF001D5E);

  // ── Accent / Vurgu ──
  static const Color accent = Color(0xFF00D4FF); // Açık mavi vurgu
  static const Color accentDark = Color(0xFF0097B2);

  // ── Arka plan ──
  static const Color backgroundLight = Color(0xFFCDD3DC); // Belirgin grimsi — göz yormaz
  static const Color backgroundDark = Color(0xFF0F1923); // Koyu mavi-siyah
  static const Color surfaceLight = Color(0xFFF4F6FA); // Kart yüzeyi — hafif gri
  static const Color surfaceDark = Color(0xFF1A2634); // Kart / yüzey koyu

  // ── Koyu tema ek yüzeyler ──
  static const Color surfaceDarkElevated = Color(
    0xFF223344,
  ); // Yükseltilmiş kart
  static const Color surfaceDarkOverlay = Color(0xFF2A3A4A); // Dialog/overlay

  // ── Masa durumları ──
  static const Color masaBos = Color(0xFF4CAF50); // Yeşil — boş
  static const Color masaDolu = Color(0xFFF44336); // Kırmızı — dolu
  static const Color masaRezerve = Color(0xFFFF9800); // Turuncu — rezerve
  static const Color masaDondurulmus = Color(0xFF42A5F5); // Mavi — dondurulmuş

  // ── Muhasebe ──
  static const Color gelir = Color(0xFF4CAF50); // Yeşil
  static const Color gider = Color(0xFFF44336); // Kırmızı

  // ── Metin ──
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  // Koyu tema metin
  static const Color textPrimaryDark = Color(0xFFE8EAF0);
  static const Color textSecondaryDark = Color(0xFF9CA8B8);

  // ── Genel ──
  static const Color divider = Color(0xFFE0E0E0);
  static const Color dividerDark = Color(0xFF2E3D4F);
  static const Color error = Color(0xFFD32F2F);
  static const Color warning = Color(0xFFFFA726);
  static const Color success = Color(0xFF66BB6A);

  // ── Tema-uyumlu yardımcı metotlar ──

  /// Arka plan rengi (scaffold)
  static Color background(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? backgroundDark
      : backgroundLight;

  /// Kart / Yüzey rengi
  static Color surface(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? surfaceDark
      : surfaceLight;

  /// Yükseltilmiş yüzey
  static Color surfaceElevated(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? surfaceDarkElevated
      : surfaceLight;

  /// Birincil metin
  static Color textP(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? textPrimaryDark
      : textPrimary;

  /// İkincil metin
  static Color textS(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? textSecondaryDark
      : textSecondary;

  /// Ayraç çizgisi
  static Color dividerColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dividerDark : divider;

  /// Hafif overlay (sidebar border, card border vs.)
  static Color borderColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF2E3D4F)
      : Colors.grey.shade300;

  /// Koyu temada mı?
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// Mavi vurgu — dark mode'da açık mavi, light'ta primary.
  /// Metin ve ikon rengi olarak kullanılır.
  static Color vurguMavi(BuildContext context) =>
      isDark(context) ? const Color(0xFF64B5F6) : primary;

  /// Saf mavi — dark mode'da okunabilir açık mavi.
  static Color mavi(BuildContext context) =>
      isDark(context) ? const Color(0xFF90CAF9) : Colors.blue;
}
