import 'package:intl/intl.dart';

/// Tarih, saat ve para formatlama yardımcıları.
class Formatters {
  Formatters._();

  // ── Para ──
  /// 25.0 → "₺25,00"
  /// [sembol] parametresi ile para birimi özelleştirilebilir.
  static String para(double tutar, [String sembol = '₺']) {
    final formatter = NumberFormat.currency(
      locale: 'tr_TR',
      symbol: sembol,
      decimalDigits: 2,
    );
    return formatter.format(tutar);
  }

  // ── Tarih ──
  /// DateTime → "14 Şub 2026"
  static String tarih(DateTime dt) {
    return DateFormat('dd MMM yyyy', 'tr_TR').format(dt);
  }

  /// DateTime → "14.02.2026"
  static String tarihKisa(DateTime dt) {
    return DateFormat('dd.MM.yyyy').format(dt);
  }

  // ── Saat ──
  /// DateTime → "14:30"
  static String saat(DateTime dt) {
    return DateFormat('HH:mm').format(dt);
  }

  /// DateTime → "14:30:05"
  static String saatSaniye(DateTime dt) {
    return DateFormat('HH:mm:ss').format(dt);
  }

  // ── Süre ──
  /// 125 dakika → "2s 05dk"
  static String sure(int dakika) {
    final saat = dakika ~/ 60;
    final dk = dakika % 60;
    if (saat > 0) {
      return '${saat}s ${dk.toString().padLeft(2, '0')}dk';
    }
    return '${dk}dk';
  }

  /// Duration → "02:05:30"
  static String sureDuration(Duration duration) {
    final d = duration.isNegative ? Duration.zero : duration;
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
}
