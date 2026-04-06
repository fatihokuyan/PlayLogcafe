import 'package:flutter/material.dart';

/// Ekran boyutuna göre cihaz tipi belirleme ve responsive yardımcılar.
class ResponsiveHelper {
  ResponsiveHelper._();

  // ── Kırılım noktaları ──
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;

  /// Bu genişliğin altında sidebar kompakt (dar ikon) modda gösterilir.
  /// Modern telefonlar yatayda ~914px mantıksal genişliğe sahip olduğundan
  /// 1000px tüm telefon landscape'lerini kapsar.
  static const double compactSidebarBreakpoint = 1000;

  /// Mobil mi? (genişlik < 600)
  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < mobileBreakpoint;

  /// Tablet mi? (600 ≤ genişlik < 900)
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= mobileBreakpoint && width < tabletBreakpoint;
  }

  /// Desktop mi? (genişlik ≥ 900)
  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tabletBreakpoint;

  /// Sidebar gösterilmeli mi? (tablet ve üstü)
  static bool showSidebar(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= mobileBreakpoint;

  /// Sidebar kompakt modda mı? (dar ekran — yatay telefon).
  static bool isCompactSidebar(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= mobileBreakpoint && width < compactSidebarBreakpoint;
  }

  /// Sidebar genişliği: kompakt modda 62, normalde ekran genişliğine göre 170–220.
  static double sidebarWidth(BuildContext context) {
    if (isCompactSidebar(context)) return 62;
    final width = MediaQuery.sizeOf(context).width;
    // 1000px → 170,  1400px+ → 220
    return (width * 0.155).clamp(170.0, 220.0);
  }

  /// Sidebar ölçek faktörü (font, ikon, padding oranlaması için).
  /// Tam sidebar genişliğinde (220) → 1.0, minimum (170) → ~0.77.
  static double sidebarScale(BuildContext context) {
    if (isCompactSidebar(context)) return 0.6;
    return sidebarWidth(context) / 220;
  }

  /// Ekran genişliğine göre grid sütun sayısı.
  /// Kompakt (telefon yatay): 4-5, Tablet/Desktop: 6+
  static int gridColumnCount(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 1400) return 8;
    if (width >= 1200) return 7;
    if (width >= compactSidebarBreakpoint) return 6;
    if (width >= tabletBreakpoint) return 5;
    if (width >= mobileBreakpoint) return 4;
    return 3;
  }
}
