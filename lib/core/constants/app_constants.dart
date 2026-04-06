/// Uygulama genelinde kullanılan sabit değerler.
///
/// NOT: Kullanıcının değiştirebileceği ayarlar artık
/// [AyarlarProvider] tarafından SharedPreferences ile yönetiliyor.
/// Bu dosya yalnızca değişmeyen teknik sabitleri barındırır.
class AppConstants {
  AppConstants._();

  // ── Uygulama bilgileri ──
  static const String appName = 'PS Salon Yönetim';
  static const String appVersion = '2.0.0';

  // ── Teknik sabitler ──
  /// Süresiz modda canlı sayaç güncelleme aralığı (saniye).
  static const int sayacGuncellemeAraligi = 1;

  /// Supabase realtime kanalları için prefix.
  static const String realtimePrefix = 'ps_salon';
}
