import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// SharedPreferences'a kullanıcı bazlı prefix ekleyen sarmalayıcı.
/// Farklı hesapların ayarları birbirini etkilemez.
class _UserPrefs {
  final SharedPreferences _prefs;
  final String _prefix;

  _UserPrefs(this._prefs, this._prefix);

  int? getInt(String key) => _prefs.getInt('${_prefix}_$key');
  double? getDouble(String key) => _prefs.getDouble('${_prefix}_$key');
  String? getString(String key) => _prefs.getString('${_prefix}_$key');
  List<String>? getStringList(String key) =>
      _prefs.getStringList('${_prefix}_$key');

  Future<bool> setInt(String key, int value) =>
      _prefs.setInt('${_prefix}_$key', value);
  Future<bool> setDouble(String key, double value) =>
      _prefs.setDouble('${_prefix}_$key', value);
  Future<bool> setString(String key, String value) =>
      _prefs.setString('${_prefix}_$key', value);
  Future<bool> setStringList(String key, List<String> value) =>
      _prefs.setStringList('${_prefix}_$key', value);

  Set<String> getKeys() =>
      _prefs.getKeys().where((k) => k.startsWith('${_prefix}_')).toSet();

  Future<void> clear() async {
    for (final key in getKeys()) {
      await _prefs.remove(key);
    }
  }

  Map<String, dynamic> getAll() {
    final map = <String, dynamic>{};
    for (final fullKey in getKeys()) {
      final shortKey = fullKey.replaceFirst('${_prefix}_', '');
      map[shortKey] = _prefs.get(fullKey);
    }
    return map;
  }

  Future<void> setAll(Map<String, dynamic> map) async {
    for (final entry in map.entries) {
      final key = entry.key;
      final val = entry.value;
      if (val is int) {
        await setInt(key, val);
      } else if (val is double) {
        await setDouble(key, val);
      } else if (val is num) {
        await setDouble(key, val.toDouble());
      } else if (val is String) {
        await setString(key, val);
      } else if (val is bool) {
        await _prefs.setBool('${_prefix}_$key', val);
      } else if (val is List) {
        await setStringList(key, val.map((e) => e.toString()).toList());
      }
    }
  }
}

/// Kullanıcının özelleştirebildiği tüm uygulama ayarları.
/// SharedPreferences ile kalıcı olarak saklanır.
class AyarlarProvider extends ChangeNotifier {
  final String userId;
  late _UserPrefs _prefs;
  bool _hazir = false;

  /// Aktif sayfa indeksi — tema rebuild'den etkilenmez.
  int seciliSayfaIndex = 0;

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) {
      super.notifyListeners();
    }
  }

  AyarlarProvider({required this.userId});

  // ── Varsayılan değerler ──
  static const double _varsayilanDakikaBasiUcret = 2.0;
  static const int _varsayilanSureDk = 60;
  static const int _varsayilanMinimumSureDk = 15;
  static const int _varsayilanKritikStokEsigi = 5;
  static const String _varsayilanParaBirimi = '₺';
  static const List<String> _varsayilanKonsolTipleri = ['PS4', 'PS5'];
  static const List<String> _varsayilanKategoriler = [
    'İçecek',
    'Atıştırmalık',
    'Yiyecek',
    'Diğer',
  ];

  // ── SharedPreferences key'leri ──
  static const String _keyDakikaBasiUcret = 'dakika_basi_ucret';
  static const String _keyVarsayilanSureDk = 'varsayilan_sure_dk';
  static const String _keyMinimumSureDk = 'minimum_sure_dk';
  static const String _keyKritikStokEsigi = 'kritik_stok_esigi';
  static const String _keyParaBirimi = 'para_birimi';
  static const String _keyKonsolTipleri = 'konsol_tipleri';
  static const String _keyKategoriler = 'urun_kategorileri';
  static const String _keyTemaModIndex = 'tema_mod';
  static const String _keyIsletmeAdi = 'isletme_adi';
  // Yeni ücretlendirme key'leri
  static const String _keyUcretBirimi = 'ucret_birimi'; // 'saat' | 'dakika'
  static const String _keyKolUcretModu =
      'kol_ucret_modu'; // 'tarife' | 'ekstra'
  static const String _keyKolBasinaEkstraUcret = 'kol_basina_ekstra_ucret';
  static const String _keyKonsolKolEkstraUcretleri =
      'konsol_kol_ekstra_ucretleri'; // JSON {konsolTipi: ucret}
  static const String _keyKonsolUcretleri =
      'konsol_ucretleri'; // JSON {konsolTipi: ucret}
  static const String _keyKonsolKolTarifeleri =
      'konsol_kol_tarifeleri'; // JSON {konsolTipi: {kolSayisi: ucret}}
  // Dilimli ücretlendirme key'leri
  static const String _keyGuncellemePeriyoduDk =
      'guncelleme_periyodu_dk'; // 1, 5, 10, 15, 30, 60
  static const String _keyIlkUcretsizDk =
      'ilk_ucretsiz_dk'; // 0+ (ilk X dk ücretsiz)
  // Admin şifre key'i
  static const String _keyAdminSifre = 'admin_sifre';
  // Günlük sıfırlama saati key'leri (eski mesai_bas_* alanları geri uyumlu kullanılıyor)
  static const String _keyGunlukSifirlamaSaat = 'mesai_bas_saat';
  static const String _keyGunlukSifirlamaDakika = 'mesai_bas_dakika';
  // UI Görünüm
  static const String _keyMuhasebeSekmesi = 'muhasebe_sekmesi_goster';
  static const String _keyRaporlarSekmesi = 'raporlar_sekmesi_goster';

  // ── Getter'lar ──

  bool get hazir => _hazir;

  /// Güncelleme (faturalandırma) periyodu: kaç dakikada bir dilim kesilir.
  /// Varsayılan 1 dk (gerçek zamanlı). Örn: 15 seçilirse 1-15 dk arası = 1 dilim ücreti.
  int get guncellemePeriyoduDk => _prefs.getInt(_keyGuncellemePeriyoduDk) ?? 1;

  /// İlk kaç dakika ücretsiz (0 = yok).
  int get ilkUcretsizDk => _prefs.getInt(_keyIlkUcretsizDk) ?? 0;

  /// Ücret birimi: 'saat' veya 'dakika'
  String get ucretBirimi => _prefs.getString(_keyUcretBirimi) ?? 'saat';

  /// Kol ücret modu: 'tarife' (saat ücreti değişir) veya 'ekstra' (tek seferlik ek ücret)
  String get kolUcretModu => _prefs.getString(_keyKolUcretModu) ?? 'tarife';

  /// Kol başına ekstra ücret — fallback (konsol bazlı tanım yoksa kullanılır)
  double get kolBasinaEkstraUcret =>
      _prefs.getDouble(_keyKolBasinaEkstraUcret) ?? 20.0;

  /// Konsol bazlı kol başına ekstra ücret haritası.
  /// Örnek: {'PS5': 50.0, 'PS4': 30.0}
  Map<String, double> get konsolKolEkstraUcretleri {
    final json = _prefs.getString(_keyKonsolKolEkstraUcretleri);
    if (json == null || json.isEmpty) return {};
    try {
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, (v as num).toDouble()));
    } catch (_) {
      return {};
    }
  }

  /// Konsol tipine göre kol başına ekstra ücret.
  /// Tanımlıysa konsol bazlı ücret döner, yoksa genel fallback.
  double konsolKolBasinaEkstraUcret(String konsolTipi) {
    final map = konsolKolEkstraUcretleri;
    if (map.containsKey(konsolTipi)) return map[konsolTipi]!;
    return kolBasinaEkstraUcret;
  }

  /// Eski dakika başı ücret (geriye uyumluluk / fallback)
  double get dakikaBasiUcret =>
      _prefs.getDouble(_keyDakikaBasiUcret) ?? _varsayilanDakikaBasiUcret;

  int get varsayilanSureDk =>
      _prefs.getInt(_keyVarsayilanSureDk) ?? _varsayilanSureDk;

  int get minimumSureDk =>
      _prefs.getInt(_keyMinimumSureDk) ?? _varsayilanMinimumSureDk;

  int get kritikStokEsigi =>
      _prefs.getInt(_keyKritikStokEsigi) ?? _varsayilanKritikStokEsigi;

  String get paraBirimi =>
      _prefs.getString(_keyParaBirimi) ?? _varsayilanParaBirimi;

  List<String> get konsolTipleri =>
      _prefs.getStringList(_keyKonsolTipleri) ?? _varsayilanKonsolTipleri;

  List<String> get urunKategorileri =>
      _prefs.getStringList(_keyKategoriler) ?? _varsayilanKategoriler;

  /// 0 = system, 1 = light, 2 = dark
  ThemeMode get temaMode {
    final index = _prefs.getInt(_keyTemaModIndex) ?? 1;
    return ThemeMode.values[index];
  }

  String get isletmeAdi => _prefs.getString(_keyIsletmeAdi) ?? 'PlayLog';

  bool get muhasebeSekmesiniGoster {
    if (!_hazir) return true;
    final val = _prefs.getInt(_keyMuhasebeSekmesi);
    if (val == null) return true;
    return val == 1;
  }

  bool get raporlarSekmesiniGoster {
    if (!_hazir) return true;
    final val = _prefs.getInt(_keyRaporlarSekmesi);
    if (val == null) return true;
    return val == 1;
  }

  // ── Konsol bazlı ücretler ──

  /// Her konsol tipinin temel ücreti (kullanıcının birimi cinsinden).
  /// Örnek: {'PS5': 140.0, 'PS4': 100.0}
  Map<String, double> get konsolUcretleri {
    final json = _prefs.getString(_keyKonsolUcretleri);
    if (json == null || json.isEmpty) return {};
    try {
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, (v as num).toDouble()));
    } catch (_) {
      return {};
    }
  }

  /// Her konsol tipinin kol bazlı tarifeleri.
  /// Örnek: {'PS5': {3: 160.0, 4: 180.0}, 'PS4': {3: 120.0}}
  Map<String, Map<int, double>> get konsolKolTarifeleri {
    final json = _prefs.getString(_keyKonsolKolTarifeleri);
    if (json == null || json.isEmpty) return {};
    try {
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      return decoded.map((konsol, kolMap) {
        final kolTarife = (kolMap as Map<String, dynamic>).map(
          (k, v) => MapEntry(int.parse(k), (v as num).toDouble()),
        );
        return MapEntry(konsol, kolTarife);
      });
    } catch (_) {
      return {};
    }
  }

  /// Belirli bir konsol tipinin tarifede tanımlı maksimum kol sayısı.
  /// Tanımlı tarife yoksa 8 döner.
  int maksimumKolSayisi(String konsolTipi) {
    final tarifeler = konsolKolTarifeleri;
    final konsolTarife = tarifeler[konsolTipi];
    if (konsolTarife != null && konsolTarife.isNotEmpty) {
      return konsolTarife.keys.reduce((a, b) => a > b ? a : b);
    }
    return 8; // Varsayılan üst sınır
  }

  /// Birim etiketi: '/saat' veya '/dk'
  String get birimEtiketi => ucretBirimi == 'saat' ? '/saat' : '/dk';

  /// Konsol tipinin temel ücreti (birim cinsinden).
  /// Tanımlı değilse: saat=140, dakika=2.33 fallback.
  double konsolTemelUcret(String konsolTipi) {
    final ucretler = konsolUcretleri;
    if (ucretler.containsKey(konsolTipi)) return ucretler[konsolTipi]!;
    // Fallback: eski dakikaBasiUcret'ten dönüştür
    return ucretBirimi == 'saat' ? dakikaBasiUcret * 60 : dakikaBasiUcret;
  }

  /// Konsol tipi + kol sayısı için ücret (birim cinsinden — display için).
  /// Tarife modunda kol tarifesi uygulanır, ekstra modunda temel ücret döner.
  double konsolKolUcret(String konsolTipi, int kolSayisi) {
    if (kolUcretModu == 'ekstra') {
      return konsolTemelUcret(konsolTipi); // Ekstra modda tarife değişmez
    }
    // Tarife modu: kol spesifik ücret bak
    final tarifeler = konsolKolTarifeleri;
    final konsolTarife = tarifeler[konsolTipi];
    if (konsolTarife != null && konsolTarife.containsKey(kolSayisi)) {
      return konsolTarife[kolSayisi]!;
    }
    return konsolTemelUcret(konsolTipi); // Varsayılan (2 kol) ücreti
  }

  /// Hesaplama için dakika başı ücret (her zaman per-minute döner).
  double konsolDakikaBasiUcretHesapla(String konsolTipi, int kolSayisi) {
    final birimUcret = konsolKolUcret(konsolTipi, kolSayisi);
    return ucretBirimi == 'saat' ? birimUcret / 60.0 : birimUcret;
  }

  /// Kol ekstra ücreti (tek seferlik — sadece 'ekstra' modunda > 0 döner).
  /// Konsol tipine göre farklı ekstra ücret uygulanır.
  double kolEkstraUcretHesapla(int kolSayisi, [String? konsolTipi]) {
    if (kolUcretModu != 'ekstra') return 0;
    final ekstra = (kolSayisi - 2).clamp(0, 99);
    final birimUcret = konsolTipi != null
        ? konsolKolBasinaEkstraUcret(konsolTipi)
        : kolBasinaEkstraUcret;
    return ekstra * birimUcret;
  }

  /// Ücret gösterim metni (display amaçlı)
  String ucretGosterimMetni(String konsolTipi, int kolSayisi) {
    final ucret = konsolKolUcret(konsolTipi, kolSayisi);
    final ekstra = kolEkstraUcretHesapla(kolSayisi, konsolTipi);
    final birim = birimEtiketi;
    if (ekstra > 0) {
      return '$paraBirimi${ucret.toStringAsFixed(0)}$birim + $paraBirimi${ekstra.toStringAsFixed(0)} kol';
    }
    return '$paraBirimi${ucret.toStringAsFixed(0)}$birim';
  }

  /// Bütçe tutarını dakikaya çevirir (konsol+kol tarifesine göre).
  /// Kol ekstra ücreti bütçeden düşülür, kalan süreye çevrilir.
  int butceyiDakikayaCevir(double butce, String konsolTipi, int kolSayisi) {
    final kolEkstra = kolEkstraUcretHesapla(kolSayisi, konsolTipi);
    final kalanButce = butce - kolEkstra;
    if (kalanButce <= 0) return 0;
    final dkBasiUcret = konsolDakikaBasiUcretHesapla(konsolTipi, kolSayisi);
    if (dkBasiUcret <= 0) return 0;
    return (kalanButce / dkBasiUcret).floor();
  }

  // ── Günlük sıfırlama saati ──

  /// Her gün raporların sıfırlandığı saat (saat kısmı). Varsayılan: 0 (00:00).
  int get gunlukSifirlamaSaat => _prefs.getInt(_keyGunlukSifirlamaSaat) ?? 0;

  /// Her gün raporların sıfırlandığı saat (dakika kısmı). Varsayılan: 0.
  int get gunlukSifirlamaDakika =>
      _prefs.getInt(_keyGunlukSifirlamaDakika) ?? 0;

  /// Günlük sıfırlama saati TimeOfDay olarak.
  TimeOfDay get gunlukSifirlamaTimeOfDay =>
      TimeOfDay(hour: gunlukSifirlamaSaat, minute: gunlukSifirlamaDakika);

  // ── Başlatma ──

  Future<void> baslat() async {
    final sp = await SharedPreferences.getInstance();
    _prefs = _UserPrefs(sp, userId);
    _hazir = true;
    notifyListeners();

    // Supabase ile çift yönlü eşitlemeyi başlat
    await _ayarlariEsitle();
  }

  // ── Supabase Senkronizasyonu ──

  Future<void> _ayarlariEsitle() async {
    try {
      final supabase = Supabase.instance.client;
      // Önce uzak sunucudan ayarları çekelim
      final response = await supabase
          .from('kullanici_ayarlari')
          .select('ayarlar')
          .eq('user_id', userId)
          .maybeSingle();

      if (response != null && response['ayarlar'] != null) {
        // Supabase'de var, yerel cihazı güncelle
        final remoteAyarlar = response['ayarlar'] as Map<String, dynamic>;
        await _prefs.setAll(remoteAyarlar);
        notifyListeners();
      } else {
        // Supabase'de yok (kullanıcının ilk girişi), yereldeki mevcut ayarları buluta gönder
        await _supabasiGuncelle();
      }
    } catch (e) {
      debugPrint('Ayarlar eşitlenirken hata oluştu: $e');
    }
  }

  Future<void> _supabasiGuncelle() async {
    if (!_hazir) return; // Henüz SharedPreferences hazır değilse
    try {
      final supabase = Supabase.instance.client;
      final localAyarlar = _prefs.getAll();

      await supabase.from('kullanici_ayarlari').upsert({
        'user_id': userId,
        'ayarlar': localAyarlar,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Ayarlar Supabase\'e kaydedilemedi: $e');
    }
  }

  // Ayarlar bir yerde her değiştiğinde Supabase'i de güncelleyecek merkezi metod
  void _ayarDegisti() {
    notifyListeners();
    _supabasiGuncelle();
  }

  // ── Setter'lar ──

  Future<void> ucretBirimiAyarla(String birim) async {
    await _prefs.setString(_keyUcretBirimi, birim);
    _ayarDegisti();
  }

  Future<void> kolUcretModuAyarla(String mod) async {
    await _prefs.setString(_keyKolUcretModu, mod);
    _ayarDegisti();
  }

  Future<void> kolBasinaEkstraUcretAyarla(double ucret) async {
    await _prefs.setDouble(_keyKolBasinaEkstraUcret, ucret);
    _ayarDegisti();
  }

  /// Konsol bazlı kol ekstra ücreti ayarla.
  Future<void> konsolKolEkstraUcretAyarla(
    String konsolTipi,
    double ucret,
  ) async {
    final map = Map<String, double>.from(konsolKolEkstraUcretleri);
    map[konsolTipi] = ucret;
    await _prefs.setString(_keyKonsolKolEkstraUcretleri, jsonEncode(map));
    _ayarDegisti();
  }

  Future<void> dakikaBasiUcretAyarla(double deger) async {
    await _prefs.setDouble(_keyDakikaBasiUcret, deger);
    _ayarDegisti();
  }

  Future<void> varsayilanSureDkAyarla(int deger) async {
    await _prefs.setInt(_keyVarsayilanSureDk, deger);
    _ayarDegisti();
  }

  Future<void> minimumSureDkAyarla(int deger) async {
    await _prefs.setInt(_keyMinimumSureDk, deger);
    _ayarDegisti();
  }

  Future<void> kritikStokEsigiAyarla(int deger) async {
    await _prefs.setInt(_keyKritikStokEsigi, deger);
    _ayarDegisti();
  }

  Future<void> paraBirimiAyarla(String deger) async {
    await _prefs.setString(_keyParaBirimi, deger);
    _ayarDegisti();
  }

  Future<void> temaModAyarla(ThemeMode mod) async {
    await _prefs.setInt(_keyTemaModIndex, mod.index);
    _ayarDegisti();
  }

  Future<void> isletmeAdiAyarla(String ad) async {
    await _prefs.setString(_keyIsletmeAdi, ad);
    _ayarDegisti();
  }

  Future<void> guncellemePeriyoduDkAyarla(int dk) async {
    await _prefs.setInt(_keyGuncellemePeriyoduDk, dk);
    _ayarDegisti();
  }

  Future<void> ilkUcretsizDkAyarla(int dk) async {
    await _prefs.setInt(_keyIlkUcretsizDk, dk);
    _ayarDegisti();
  }

  Future<void> muhasebeSekmesiniGosterAyarla(bool goster) async {
    await _prefs.setInt(_keyMuhasebeSekmesi, goster ? 1 : 0);
    _ayarDegisti();
  }

  Future<void> raporlarSekmesiniGosterAyarla(bool goster) async {
    await _prefs.setInt(_keyRaporlarSekmesi, goster ? 1 : 0);
    _ayarDegisti();
  }

  // ── Konsol ücret yönetimi ──

  /// Konsol tipi temel ücretini ayarla (birim cinsinden).
  Future<void> konsolUcretAyarla(String konsolTipi, double ucret) async {
    final map = Map<String, double>.from(konsolUcretleri);
    map[konsolTipi] = ucret;
    await _prefs.setString(_keyKonsolUcretleri, jsonEncode(map));
    _ayarDegisti();
  }

  /// Konsol tipi + kol sayısı için tarife ayarla.
  Future<void> konsolKolTarifesiAyarla(
    String konsolTipi,
    int kolSayisi,
    double ucret,
  ) async {
    final map = Map<String, Map<int, double>>.from(
      konsolKolTarifeleri.map((k, v) => MapEntry(k, Map<int, double>.from(v))),
    );
    map.putIfAbsent(konsolTipi, () => {});
    map[konsolTipi]![kolSayisi] = ucret;
    final json = jsonEncode(
      map.map(
        (k, v) => MapEntry(k, v.map((kk, vv) => MapEntry(kk.toString(), vv))),
      ),
    );
    await _prefs.setString(_keyKonsolKolTarifeleri, json);
    _ayarDegisti();
  }

  /// Konsol tipi + kol sayısı tarifesini sil.
  Future<void> konsolKolTarifesiSil(String konsolTipi, int kolSayisi) async {
    final map = Map<String, Map<int, double>>.from(
      konsolKolTarifeleri.map((k, v) => MapEntry(k, Map<int, double>.from(v))),
    );
    map[konsolTipi]?.remove(kolSayisi);
    if (map[konsolTipi]?.isEmpty ?? false) map.remove(konsolTipi);
    final json = jsonEncode(
      map.map(
        (k, v) => MapEntry(k, v.map((kk, vv) => MapEntry(kk.toString(), vv))),
      ),
    );
    await _prefs.setString(_keyKonsolKolTarifeleri, json);
    _ayarDegisti();
  }

  // ── Konsol tipleri yönetimi ──

  Future<void> konsolTipiEkle(String tip) async {
    final liste = List<String>.from(konsolTipleri);
    if (!liste.contains(tip)) {
      liste.add(tip);
      await _prefs.setStringList(_keyKonsolTipleri, liste);
      _ayarDegisti();
    }
  }

  Future<void> konsolTipiSil(String tip) async {
    final liste = List<String>.from(konsolTipleri);
    liste.remove(tip);
    if (liste.isNotEmpty) {
      await _prefs.setStringList(_keyKonsolTipleri, liste);
      _ayarDegisti();
    }
  }

  // ── Ürün kategorileri yönetimi ──

  Future<void> kategoriEkle(String kategori) async {
    final liste = List<String>.from(urunKategorileri);
    if (!liste.contains(kategori)) {
      liste.add(kategori);
      await _prefs.setStringList(_keyKategoriler, liste);
      _ayarDegisti();
    }
  }

  Future<void> kategoriSil(String kategori) async {
    final liste = List<String>.from(urunKategorileri);
    liste.remove(kategori);
    if (liste.isNotEmpty) {
      await _prefs.setStringList(_keyKategoriler, liste);
      _ayarDegisti();
    }
  }

  // ── Günlük sıfırlama saati setter ──

  /// Günlük rapor sıfırlama saatini ayarla.
  Future<void> gunlukSifirlamaAyarla(TimeOfDay saat) async {
    await _prefs.setInt(_keyGunlukSifirlamaSaat, saat.hour);
    await _prefs.setInt(_keyGunlukSifirlamaDakika, saat.minute);
    _ayarDegisti();
  }

  // ── Admin şifre yönetimi ──

  /// Admin şifresi (boş string = şifre ayarlanmamış).
  String get adminSifre => _prefs.getString(_keyAdminSifre) ?? '';

  /// Şifre aktif mi (ayarlanmış mı)?
  bool get sifreAktifMi => adminSifre.isNotEmpty;

  /// Şifre doğrula.
  bool sifreDogrula(String girilen) {
    if (!sifreAktifMi) return true; // Şifre yoksa her zaman doğru
    return girilen == adminSifre;
  }

  /// Admin şifresi ayarla (boş string = şifreyi kaldır).
  Future<void> adminSifreAyarla(String sifre) async {
    await _prefs.setString(_keyAdminSifre, sifre);
    _ayarDegisti();
  }

  // ── Fabrika ayarlarına dön ──

  Future<void> fabrikaAyarlarina() async {
    await _prefs.clear();
    _ayarDegisti();
  }
}
