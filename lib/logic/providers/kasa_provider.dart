import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/daily_report_model.dart';
import '../../data/models/muhasebe_model.dart';
import '../../data/repositories/daily_report_repository.dart';
import '../../data/repositories/rapor_repository.dart';
import '../../data/repositories/muhasebe_repository.dart';

/// Üst panel filtre seçenekleri.
enum OzetFiltresi {
  seciliAy('Seçili Ay'),
  son3Ay('Son 3 Ay'),
  yillik('Yıllık'),
  tumZamanlar('Tüm Zamanlar');

  final String etiket;
  const OzetFiltresi(this.etiket);
}

/// Kasa Takibi / Muhasebe state yönetimi.
///
/// Aylık bazda günlük raporları yönetir.
/// Raporlar ve giderler tablosundan otonom veriler çeker,
/// kullanıcının manuel override'larını destekler.
class KasaProvider extends ChangeNotifier {
  final DailyReportRepository _dailyRepo;
  final RaporRepository _raporRepo;
  final MuhasebeRepository _muhasebeRepo;

  /// Seçilen ay/yıl.
  int _secilenYil = DateTime.now().year;
  int _secilenAy = DateTime.now().month;

  /// Ayarlardan gelen günlük sıfırlama saat/dakika bilgisi.
  int _sifirlaSaat = 0;
  int _sifirlaDakika = 0;

  /// O aya ait tüm günlük kayıtlar (1..sonGün).
  List<DailyReportModel> _gunlukKayitlar = [];

  /// O aya ait gider kayıtları (muhasebe tablosundan).
  List<MuhasebeModel> _giderKayitlari = [];

  /// Günlük nakit/kart gider haritaları.
  Map<String, double> _gunlukNakitGider = {};
  Map<String, double> _gunlukKartGider = {};

  /// Önceki aydan devreden bakiye.
  double _oncekiAyBakiyesi = 0;

  /// Üst panel filtresi.
  OzetFiltresi _ozetFiltresi = OzetFiltresi.seciliAy;

  /// Yıllık filtre için seçilen yıl.
  int _filtreYili = DateTime.now().year;

  /// Filtrelenmiş özet verileri (filtre değiştiğinde hesaplanır).
  double _filtreNakitGelir = 0;
  double _filtreKartGelir = 0;
  double _filtreNakitGider = 0;
  double _filtreKartGider = 0;

  bool _yukleniyor = false;
  String? _hata;

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  KasaProvider({
    DailyReportRepository? dailyRepo,
    RaporRepository? raporRepo,
    MuhasebeRepository? muhasebeRepo,
  }) : _dailyRepo = dailyRepo ?? DailyReportRepository(),
       _raporRepo = raporRepo ?? RaporRepository(),
       _muhasebeRepo = muhasebeRepo ?? MuhasebeRepository();

  // ── Getter'lar ──

  int get secilenYil => _secilenYil;
  int get secilenAy => _secilenAy;
  List<DailyReportModel> get gunlukKayitlar => _gunlukKayitlar;
  List<MuhasebeModel> get giderKayitlari => _giderKayitlari;
  bool get yukleniyor => _yukleniyor;
  String? get hata => _hata;

  /// Belirli bir gün için nakit gider tutarı.
  double nakitGiderForDate(DateTime dt) => _gunlukNakitGider[_dateKey(dt)] ?? 0;

  /// Belirli bir gün için kart gider tutarı.
  double kartGiderForDate(DateTime dt) => _gunlukKartGider[_dateKey(dt)] ?? 0;

  /// Ayın son günü.
  int get ayinSonGunu => DateTime(_secilenYil, _secilenAy + 1, 0).day;

  // ── Ay toplam hesapları ──

  double get aylikToplamNakit =>
      _gunlukKayitlar.fold<double>(0, (t, r) => t + r.nakitGelir);

  double get aylikToplamPos =>
      _gunlukKayitlar.fold<double>(0, (t, r) => t + r.posGelir);

  double get aylikToplamGider =>
      _gunlukKayitlar.fold<double>(0, (t, r) => t + r.gider);

  double get aylikToplamNakitGider => _giderKayitlari
      .where((k) => k.odemeYontemi == OdemeYontemi.nakit)
      .fold<double>(0, (t, k) => t + k.tutar);

  double get aylikToplamKartGider => _giderKayitlari
      .where((k) => k.odemeYontemi == OdemeYontemi.kart)
      .fold<double>(0, (t, k) => t + k.tutar);

  double get aylikToplamGelir => aylikToplamNakit + aylikToplamPos;

  /// Toplam ciro = nakit gelir + kart gelir (tüm satırların toplamı).
  double get toplamCiro => aylikToplamGelir;

  /// Net kazanç = Toplam Ciro - (Nakit Gider + Kart Gider).
  double get aylikNetKar =>
      toplamCiro - (aylikToplamNakitGider + aylikToplamKartGider);

  /// Önceki aydan devreden bakiye (tabloda ilk satır olarak gösterilir).
  double get oncekiAyBakiyesi => _oncekiAyBakiyesi;

  // ── Filtre ──

  OzetFiltresi get ozetFiltresi => _ozetFiltresi;
  int get filtreYili => _filtreYili;

  double get filtreNakitGelir => _ozetFiltresi == OzetFiltresi.seciliAy
      ? aylikToplamNakit
      : _filtreNakitGelir;
  double get filtreKartGelir => _ozetFiltresi == OzetFiltresi.seciliAy
      ? aylikToplamPos
      : _filtreKartGelir;
  double get filtreNakitGider => _ozetFiltresi == OzetFiltresi.seciliAy
      ? aylikToplamNakitGider
      : _filtreNakitGider;
  double get filtreKartGider => _ozetFiltresi == OzetFiltresi.seciliAy
      ? aylikToplamKartGider
      : _filtreKartGider;
  double get filtreToplamCiro => filtreNakitGelir + filtreKartGelir;
  double get filtreNetKazanc =>
      filtreToplamCiro - (filtreNakitGider + filtreKartGider);

  /// Filtre değiştir ve özet verilerini yeniden hesapla.
  Future<void> ozetFiltresiDegistir(OzetFiltresi yeniFiltre) async {
    _ozetFiltresi = yeniFiltre;
    notifyListeners();

    if (yeniFiltre == OzetFiltresi.seciliAy) {
      // Zaten aylik getter'lar kullanılıyor, ek veri çekmeye gerek yok.
      return;
    }

    try {
      final simdi = DateTime.now();
      late DateTime baslangic;
      late DateTime bitis;

      switch (yeniFiltre) {
        case OzetFiltresi.son3Ay:
          // Seçilen aydan geriye 3 ay
          int bAy = _secilenAy - 2;
          int bYil = _secilenYil;
          while (bAy <= 0) {
            bAy += 12;
            bYil--;
          }
          baslangic = DateTime(bYil, bAy, 1, _sifirlaSaat, _sifirlaDakika);
          final nextSonAyDt = DateTime(_secilenYil, _secilenAy + 1, 1, _sifirlaSaat, _sifirlaDakika);
          bitis = nextSonAyDt.subtract(const Duration(seconds: 1));
          break;
        case OzetFiltresi.yillik:
          baslangic = DateTime(_filtreYili, 1, 1, _sifirlaSaat, _sifirlaDakika);
          final nextYilDt = DateTime(_filtreYili + 1, 1, 1, _sifirlaSaat, _sifirlaDakika);
          bitis = nextYilDt.subtract(const Duration(seconds: 1));
          break;
        case OzetFiltresi.tumZamanlar:
          baslangic = DateTime(2020, 1, 1);
          final simdiNextDay = DateTime(simdi.year, simdi.month, simdi.day + 1, _sifirlaSaat, _sifirlaDakika);
          bitis = simdiNextDay.subtract(const Duration(seconds: 1));
          break;
        case OzetFiltresi.seciliAy:
          return; // Yukarıda zaten handle edildi
      }

      // Gelir verilerini çek
      final raporlar = await _raporRepo.tarihAraligiRaporlari(baslangic, bitis);
      double nakitGelir = 0, kartGelir = 0;
      for (final r in raporlar) {
        nakitGelir += r.nakitTutar;
        kartGelir += r.kartTutar;
      }

      // Gider verilerini çek
      final giderler = await _muhasebeRepo.giderleriGetir(baslangic, bitis);
      double nakitGider = 0, kartGider = 0;
      for (final g in giderler) {
        if (g.odemeYontemi == OdemeYontemi.nakit) {
          nakitGider += g.tutar;
        } else {
          kartGider += g.tutar;
        }
      }

      _filtreNakitGelir = nakitGelir;
      _filtreKartGelir = kartGelir;
      _filtreNakitGider = nakitGider;
      _filtreKartGider = kartGider;
      notifyListeners();
    } catch (e) {
      debugPrint('Filtre verileri yüklenirken hata: $e');
    }
  }

  /// Yıllık filtre yılını değiştir ve verileri yeniden çek.
  Future<void> filtreYiliniDegistir(int yil) async {
    _filtreYili = yil;
    if (_ozetFiltresi == OzetFiltresi.yillik) {
      await ozetFiltresiDegistir(OzetFiltresi.yillik);
    }
  }

  // ── Ay seçici ──

  void ayDegistir(int yil, int ay) {
    _secilenYil = yil;
    _secilenAy = ay;
    _ozetFiltresi = OzetFiltresi.seciliAy;
    ayiYukle();
  }

  void oncekiAy() {
    if (_secilenAy == 1) {
      _secilenAy = 12;
      _secilenYil--;
    } else {
      _secilenAy--;
    }
    ayiYukle();
  }

  void sonrakiAy() {
    if (_secilenAy == 12) {
      _secilenAy = 1;
      _secilenYil++;
    } else {
      _secilenAy++;
    }
    ayiYukle();
  }

  // ── Veri yükleme ──

  /// Ayın tüm verilerini yükle:
  /// 1. daily_reports tablosundan mevcut kayıtlar
  /// 2. raporlar tablosundan günlük nakit/POS toplamları
  /// 3. muhasebe tablosundan günlük gider toplamları
  /// 4. Devreden bakiye hesapla
  Future<void> ayiYukle() async {
    _yukleniyor = true;
    _hata = null;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = Supabase.instance.client.auth.currentUser!.id;
      _sifirlaSaat = prefs.getInt('${userId}_mesai_bas_saat') ?? 0;
      _sifirlaDakika = prefs.getInt('${userId}_mesai_bas_dakika') ?? 0;

      final sonGun = ayinSonGunu;
      final ayBaslangic = DateTime(_secilenYil, _secilenAy, 1, _sifirlaSaat, _sifirlaDakika);
      
      final dtBitis = DateTime(_secilenYil, _secilenAy + 1, 1, _sifirlaSaat, _sifirlaDakika);
      final ayBitis = dtBitis.subtract(const Duration(seconds: 1));

      // Tüm sorguları paralel başlat → yükleme süresi kısalır
      final dailyFuture = _dailyRepo.aylikKayitlar(_secilenYil, _secilenAy);
      final raporFuture = _raporRepo.tarihAraligiRaporlari(ayBaslangic, ayBitis);
      final muhasebeFuture = _muhasebeRepo.tarihAraligiKayitlar(ayBaslangic, ayBitis);
      final bakiyeFuture = _oncekiAySonBakiye(_secilenYil, _secilenAy);

      final mevcutKayitlar = await dailyFuture;
      final raporlar = await raporFuture;
      final muhasebeKayitlar = await muhasebeFuture;
      final oncekiBakiye = await bakiyeFuture;

      final mevcutMap = <String, DailyReportModel>{};
      for (final k in mevcutKayitlar) {
        mevcutMap[_dateKey(k.tarih)] = k;
      }

      final nakitMap = <String, double>{};
      final posMap = <String, double>{};
      for (final rapor in raporlar) {
        final key = _shiftliDateKey(rapor.baslangic);
        nakitMap[key] = (nakitMap[key] ?? 0) + rapor.nakitTutar;
        posMap[key] = (posMap[key] ?? 0) + rapor.kartTutar;
      }

      final giderMap = <String, double>{};
      final nakitGiderMap = <String, double>{};
      final kartGiderMap = <String, double>{};
      final giderListesi = <MuhasebeModel>[];
      for (final kayit in muhasebeKayitlar) {
        if (kayit.isGider) {
          final key = _shiftliDateKey(kayit.tarih);
          giderMap[key] = (giderMap[key] ?? 0) + kayit.tutar;
          if (kayit.odemeYontemi == OdemeYontemi.nakit) {
            nakitGiderMap[key] = (nakitGiderMap[key] ?? 0) + kayit.tutar;
          } else {
            kartGiderMap[key] = (kartGiderMap[key] ?? 0) + kayit.tutar;
          }
          giderListesi.add(kayit);
        }
      }
      _giderKayitlari = giderListesi;
      _gunlukNakitGider = nakitGiderMap;
      _gunlukKartGider = kartGiderMap;
      _oncekiAyBakiyesi = oncekiBakiye;

      // 5. Ayın her günü için kayıt oluştur
      final bugun = DateTime.now();
      final kayitlar = <DailyReportModel>[];
      double devredenBakiye = oncekiBakiye;

      for (int gun = 1; gun <= sonGun; gun++) {
        final tarih = DateTime(_secilenYil, _secilenAy, gun);
        final key = _dateKey(tarih);
        final mevcut = mevcutMap[key];

        final autoCash = nakitMap[key] ?? 0;
        final autoPos = posMap[key] ?? 0;
        final autoExpense = giderMap[key] ?? 0;

        // Mevcut kayıttaki manuel değerleri koru
        final manualCash = mevcut?.manualCash;
        final manualPos = mevcut?.manualPos;
        final manualExpense = mevcut?.manualExpense;
        final notlar = mevcut?.notlar;

        // Efektif değerler
        final efektifNakit = manualCash ?? autoCash;
        final efektifNakitGider = nakitGiderMap[key] ?? 0;

        // Devreden bakiye = önceki bakiye + nakit gelir - nakit gider
        devredenBakiye = devredenBakiye + efektifNakit - efektifNakitGider;

        // Gelecekteki günler için (bugünden sonra) rapor gösterme
        final kayit = DailyReportModel(
          id: mevcut?.id ?? '',
          tarih: tarih,
          autoCash: autoCash,
          autoPos: autoPos,
          autoExpense: autoExpense,
          manualCash: manualCash,
          manualPos: manualPos,
          manualExpense: manualExpense,
          devredenBakiye: devredenBakiye,
          notlar: notlar,
          createdAt: mevcut?.createdAt ?? bugun,
          updatedAt: mevcut?.updatedAt ?? bugun,
        );

        kayitlar.add(kayit);
      }

      _gunlukKayitlar = kayitlar;

      // 6. Değişen kayıtları Supabase'e kaydet (bugüne kadar olan günler)
      final kaydedilecek = <DailyReportModel>[];
      for (final kayit in kayitlar) {
        if (!kayit.tarih.isAfter(
          DateTime(bugun.year, bugun.month, bugun.day),
        )) {
          kaydedilecek.add(kayit);
        }
      }
      if (kaydedilecek.isNotEmpty) {
        // Arka planda upsert, hata olsa bile UI'ı bozmayız
        _dailyRepo.topluUpsert(kaydedilecek).catchError((e) {
          debugPrint('Toplu upsert hatası: $e');
        });
      }
    } catch (e) {
      _hata = 'Kasa verileri yüklenirken hata: $e';
      debugPrint(_hata);
    }

    _yukleniyor = false;
    notifyListeners();
  }

  // ── Manuel Override ──

  /// Nakit gelir için manuel değer gir (null = override kaldır).
  Future<void> manuelNakitAyarla(DateTime tarih, double? deger) async {
    try {
      await _dailyRepo.manualCashGuncelle(tarih, deger);
      await ayiYukle(); // Devreden bakiyeleri yeniden hesapla
    } catch (e) {
      debugPrint('Manuel nakit güncelleme hatası: $e');
    }
  }

  /// POS gelir için manuel değer gir.
  Future<void> manuelPosAyarla(DateTime tarih, double? deger) async {
    try {
      await _dailyRepo.manualPosGuncelle(tarih, deger);
      await ayiYukle();
    } catch (e) {
      debugPrint('Manuel POS güncelleme hatası: $e');
    }
  }

  /// Gider için manuel değer gir.
  Future<void> manuelGiderAyarla(DateTime tarih, double? deger) async {
    try {
      await _dailyRepo.manualExpenseGuncelle(tarih, deger);
      await ayiYukle();
    } catch (e) {
      debugPrint('Manuel gider güncelleme hatası: $e');
    }
  }

  /// Not güncelle.
  Future<void> notGuncelle(DateTime tarih, String? not_) async {
    try {
      await _dailyRepo.notGuncelle(tarih, not_);
      final idx = _gunlukKayitlar.indexWhere(
        (k) => _dateKey(k.tarih) == _dateKey(tarih),
      );
      if (idx != -1) {
        _gunlukKayitlar[idx] = _gunlukKayitlar[idx].copyWith(
          notlar: () => not_,
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Not güncelleme hatası: $e');
    }
  }

  // ── Gider (Expense) CRUD ──

  /// Yeni gider kaydı ekle.
  Future<void> giderEkle({
    required String aciklama,
    required double tutar,
    required OdemeYontemi odemeYontemi,
    DateTime? tarih,
  }) async {
    try {
      final yeniKayit = MuhasebeModel(
        id: const Uuid().v4(),
        tur: MuhasebeTur.gider,
        aciklama: aciklama,
        tutar: tutar,
        tarih: tarih ?? DateTime.now(),
        odemeYontemi: odemeYontemi,
      );
      await _muhasebeRepo.kayitEkle(yeniKayit);
      await ayiYukle();
    } catch (e) {
      debugPrint('Gider ekleme hatası: $e');
    }
  }

  /// Gider kaydını güncelle.
  Future<void> giderGuncelle(MuhasebeModel kayit) async {
    try {
      await _muhasebeRepo.kayitGuncelle(kayit);
      await ayiYukle();
    } catch (e) {
      debugPrint('Gider güncelleme hatası: $e');
    }
  }

  /// Gider kaydını sil.
  Future<void> giderSil(String id) async {
    try {
      await _muhasebeRepo.kayitSil(id);
      await ayiYukle();
    } catch (e) {
      debugPrint('Gider silme hatası: $e');
    }
  }

  // ── Yardımcılar ──

  /// Önceki ayın son devreden bakiyesini getir.
  /// DB'de kayıt yoksa geriye doğru 12 aya kadar bakarak hesaplar.
  Future<double> _oncekiAySonBakiye(int yil, int ay) async {
    // Önceki ayı belirle
    int oy = ay - 1, oyil = yil;
    if (oy == 0) {
      oy = 12;
      oyil--;
    }

    // DB'de önceki ay kayıtları var mı?
    final oncekiKayitlar = await _dailyRepo.aylikKayitlar(oyil, oy);
    if (oncekiKayitlar.isNotEmpty) {
      return oncekiKayitlar.last.devredenBakiye;
    }

    // Kayıt yoksa geriye doğru kayıtlı bir ay bul (max 12 ay)
    double baslangicBakiye = 0;
    final bosAylar = <(int, int)>[(oyil, oy)];
    int sy = oyil, sm = oy;
    for (int i = 0; i < 12; i++) {
      sm--;
      if (sm == 0) {
        sm = 12;
        sy--;
      }
      final k = await _dailyRepo.aylikKayitlar(sy, sm);
      if (k.isNotEmpty) {
        baslangicBakiye = k.last.devredenBakiye;
        break;
      }
      bosAylar.insert(0, (sy, sm));
    }

    // Eksik ayları sırasıyla hesapla ve kaydet
    double bakiye = baslangicBakiye;
    for (final (by, bm) in bosAylar) {
      bakiye = await _ayBakiyeHesaplaVeKaydet(by, bm, bakiye);
    }
    return bakiye;
  }

  /// Tek bir ayın bakiye hesabını yap ve DB'ye kaydet.
  /// Dönen değer: ayın son gününün devreden bakiyesi.
  Future<double> _ayBakiyeHesaplaVeKaydet(
    int yil,
    int ay,
    double baslangicBakiye,
  ) async {
    final sonGun = DateTime(yil, ay + 1, 0).day;
    final ayBaslangic = DateTime(yil, ay, 1, _sifirlaSaat, _sifirlaDakika);
    final dtBitis = DateTime(yil, ay + 1, 1, _sifirlaSaat, _sifirlaDakika);
    final ayBitis = dtBitis.subtract(const Duration(seconds: 1));

    // Raporlardan nakit toplamları
    final raporlar = await _raporRepo.tarihAraligiRaporlari(
      ayBaslangic,
      ayBitis,
    );
    final nakitMap = <String, double>{};
    final posMap = <String, double>{};
    for (final r in raporlar) {
      final key = _shiftliDateKey(r.baslangic);
      nakitMap[key] = (nakitMap[key] ?? 0) + r.nakitTutar;
      posMap[key] = (posMap[key] ?? 0) + r.kartTutar;
    }

    // Nakit giderler
    final muhasebeKayitlar = await _muhasebeRepo.tarihAraligiKayitlar(ayBaslangic, ayBitis);
    final nakitGiderMap = <String, double>{};
    final giderMap = <String, double>{};
    for (final k in muhasebeKayitlar) {
      if (k.isGider) {
        final key = _shiftliDateKey(k.tarih);
        giderMap[key] = (giderMap[key] ?? 0) + k.tutar;
        if (k.odemeYontemi == OdemeYontemi.nakit) {
          nakitGiderMap[key] = (nakitGiderMap[key] ?? 0) + k.tutar;
        }
      }
    }

    // Günlük kayıtları oluştur
    final bugun = DateTime.now();
    final bugununTarihi = DateTime(bugun.year, bugun.month, bugun.day);
    double bakiye = baslangicBakiye;
    final kayitlar = <DailyReportModel>[];

    for (int gun = 1; gun <= sonGun; gun++) {
      final tarih = DateTime(yil, ay, gun);
      final key = _dateKey(tarih);
      final nakit = nakitMap[key] ?? 0;
      final pos = posMap[key] ?? 0;
      final gider = giderMap[key] ?? 0;
      final nakitGider = nakitGiderMap[key] ?? 0;

      bakiye = bakiye + nakit - nakitGider;

      kayitlar.add(
        DailyReportModel(
          id: '',
          tarih: tarih,
          autoCash: nakit,
          autoPos: pos,
          autoExpense: gider,
          devredenBakiye: bakiye,
          createdAt: bugun,
          updatedAt: bugun,
        ),
      );
    }

    // Geçmiş günleri DB'ye kaydet
    final kaydedilecek = kayitlar
        .where((k) => !k.tarih.isAfter(bugununTarihi))
        .toList();
    if (kaydedilecek.isNotEmpty) {
      await _dailyRepo.topluUpsert(kaydedilecek).catchError((e) {
        debugPrint('Önceki ay upsert hatası: $e');
      });
    }

    return bakiye;
  }

  String _dateKey(DateTime dt) {
    return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
  }

  String _shiftliDateKey(DateTime dt) {
    DateTime adjusted = dt;
    final simdiDk = dt.hour * 60 + dt.minute;
    final resetDk = _sifirlaSaat * 60 + _sifirlaDakika;

    // Eğer saat sıfırlama saatinden önceyse, bir önceki güne ait sayılır
    if (simdiDk < resetDk) {
      adjusted = dt.subtract(const Duration(days: 1));
    }

    return _dateKey(adjusted);
  }

  /// Gün adı (Türkçe kısa).
  static String gunAdi(int weekday) {
    const adlar = ['', 'Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
    return adlar[weekday];
  }

  static const ayAdlari = [
    '',
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık',
  ];
}



