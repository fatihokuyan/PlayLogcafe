import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

/// Süreli masa ses bildirimleri servisi.
/// Windows'ta kernel32.dll Beep() API'si ayrı bir izolat'ta çağrılır.
class SesServisi {
  SesServisi._();
  static final SesServisi _instance = SesServisi._();
  static SesServisi get instance => _instance;

  /// Ses bildirimleri aktif mi? (Ayarlardan kapatılabilir)
  bool aktif = true;

  // 5dk uyarı: çift çıkan bip (880 Hz → 1047 Hz)
  static const List<(int, int)> _uyariPattern = [
    (880, 150),
    (0, 100),
    (1047, 200),
  ];

  // Süre doldu: 3'lü alçalan bip × 2 tekrar
  static const List<(int, int)> _alarmPattern = [
    (1200, 200), (0, 80),
    (900, 200),  (0, 80),
    (600, 250),  (0, 150),
    (1200, 200), (0, 80),
    (900, 200),  (0, 80),
    (600, 350),
  ];

  /// 5 dakika kala uyarı sesi çal.
  void uyariSesiCal() {
    if (!aktif || !Platform.isWindows) return;
    Isolate.run(() => _oynat(_uyariPattern));
  }

  /// Süre doldu alarm sesi çal.
  void alarmSesiCal() {
    if (!aktif || !Platform.isWindows) return;
    Isolate.run(() => _oynat(_alarmPattern));
  }

  /// Ayrı izolat'ta çalışır — UI thread'i bloke etmez.
  static void _oynat(List<(int, int)> pattern) {
    final kernel32 = DynamicLibrary.open('kernel32.dll');
    final beepFn = kernel32.lookupFunction<
        Int32 Function(Uint32, Uint32),
        int Function(int, int)>('Beep');
    final sleepFn = kernel32.lookupFunction<
        Void Function(Uint32),
        void Function(int)>('Sleep');

    for (final (freq, ms) in pattern) {
      if (freq == 0) {
        sleepFn(ms);
      } else {
        beepFn(freq, ms);
      }
    }
  }

  void dispose() {}
}
