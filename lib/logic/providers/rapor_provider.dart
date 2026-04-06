import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/rapor_model.dart';
import '../../data/models/siparis_kalemi_model.dart';
import '../../data/repositories/rapor_repository.dart';
import '../../data/repositories/satis_repository.dart';

enum RaporSiralama {
  zamanAzalan,
  zamanArtan,
  tutarAzalan,
  tutarArtan,
}

/// Raporlama state yönetimi — filtreleme, listeleme, detay.
class RaporProvider extends ChangeNotifier {
  final RaporRepository _raporRepo;
  final SatisRepository _satisRepo;

  List<RaporModel> _raporlar = [];
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

  // Filtreler
  DateTime _filtreBas = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
    0,
    0,
  );
  DateTime _filtreSon = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
    23,
    59,
    59,
  );
  String? _filtreMasaId;
  OdemeYontemi? _filtreOdeme;
  RaporSiralama _siralama = RaporSiralama.zamanAzalan;

  RaporProvider({
    RaporRepository? raporRepository,
    SatisRepository? satisRepository,
  }) : _raporRepo = raporRepository ?? RaporRepository(),
       _satisRepo = satisRepository ?? SatisRepository() {
    // Uygulama açıldığında varsa bekleyen kayıtları gönder
    kuyruguIsle();
  }

  static const String _kuyrukAnahtari = 'bekleyen_raporlar_kuyrugu';
  bool _kuyrukIsleniyor = false;

  /// Tüm lokal state'i sıfırla (hesap değişiminde çağrılır).
  void temizle() {
    _raporlar = [];
    _yukleniyor = false;
    _hata = null;
    _filtreMasaId = null;
    _filtreOdeme = null;
    final now = DateTime.now();
    _filtreBas = DateTime(now.year, now.month, now.day, 0, 0);
    _filtreSon = DateTime(now.year, now.month, now.day, 23, 59, 59);
    notifyListeners();
  }

  List<RaporModel> get raporlar => _raporlar;
  bool get yukleniyor => _yukleniyor;
  String? get hata => _hata;
  DateTime get filtreBas => _filtreBas;
  DateTime get filtreSon => _filtreSon;
  String? get filtreMasaId => _filtreMasaId;
  OdemeYontemi? get filtreOdeme => _filtreOdeme;
  RaporSiralama get siralama => _siralama;

  /// Mevcut filtre bugünün periyoduna mı ait?
  bool get bugunMu {
    final simdi = DateTime.now();
    return simdi.isAfter(_filtreBas) && simdi.isBefore(_filtreSon);
  }

  /// Mevcut filtre dünkü periyoda mı ait?
  bool get dunMu {
    final simdi = DateTime.now();
    return _filtreSon.isBefore(simdi) &&
        _filtreBas.isAfter(simdi.subtract(const Duration(hours: 48)));
  }

  /// Filtrelenmiş raporlar.
  List<RaporModel> get filtrelenmisRaporlar {
    var liste = List<RaporModel>.from(_raporlar);
    if (_filtreMasaId != null && _filtreMasaId!.isNotEmpty) {
      liste = liste.where((r) => r.masaId == _filtreMasaId).toList();
    }
    if (_filtreOdeme != null) {
      liste = liste.where((r) => r.odemeYontemi == _filtreOdeme).toList();
    }
    
    liste.sort((a, b) {
      switch (_siralama) {
        case RaporSiralama.zamanAzalan:
          return b.bitis.compareTo(a.bitis);
        case RaporSiralama.zamanArtan:
          return a.baslangic.compareTo(b.baslangic);
        case RaporSiralama.tutarAzalan:
          return b.toplamTutar.compareTo(a.toplamTutar);
        case RaporSiralama.tutarArtan:
          return a.toplamTutar.compareTo(b.toplamTutar);
      }
    });
    
    return liste;
  }

  // ── Toplam istatistikler ──
  double get toplamTutar =>
      filtrelenmisRaporlar.fold<double>(0, (t, r) => t + r.toplamTutar);
  double get toplamNakit =>
      filtrelenmisRaporlar.fold<double>(0, (t, r) => t + r.nakitTutar);
  double get toplamKart =>
      filtrelenmisRaporlar.fold<double>(0, (t, r) => t + r.kartTutar);

  // ── Filtre setters ──
  void tarihFiltresiAyarla(DateTime bas, DateTime son) {
    _filtreBas = bas;
    _filtreSon = son;
    raporlariYukle();
  }

  /// Bugünün periyodunu hesapla ve filtreyi sıfırla.
  /// Periyot: son geçen sıfırlama saatinden bir sonraki sıfırlama saatine kadar.
  void gunlukFiltreyiSifirla({
    int sifirlSaat = 0,
    int sifirlDak = 0,
  }) {
    final simdi = DateTime.now();
    final simdiDk = simdi.hour * 60 + simdi.minute;
    final resetDk = sifirlSaat * 60 + sifirlDak;

    // Bugünün sıfırlama noktası
    DateTime periodBas = DateTime(
      simdi.year,
      simdi.month,
      simdi.day,
      sifirlSaat,
      sifirlDak,
    );
    // Eğer şu an sıfırlama saatinden önceyse, bir önceki günün periyodu
    if (simdiDk < resetDk) {
      periodBas = periodBas.subtract(const Duration(days: 1));
    }

    _filtreBas = periodBas;
    _filtreSon = periodBas
        .add(const Duration(days: 1))
        .subtract(const Duration(seconds: 1));
    _filtreMasaId = null;
    _filtreOdeme = null;
    raporlariYukle();
  }

  /// Dünkü periyoda göre filtreyi ayarla.
  void dunFiltreyiAyarla({
    int sifirlSaat = 0,
    int sifirlDak = 0,
  }) {
    final simdi = DateTime.now();
    final simdiDk = simdi.hour * 60 + simdi.minute;
    final resetDk = sifirlSaat * 60 + sifirlDak;

    // Bugünün periyod başlangıcını bul
    DateTime bugunPeriodBas = DateTime(
      simdi.year,
      simdi.month,
      simdi.day,
      sifirlSaat,
      sifirlDak,
    );
    if (simdiDk < resetDk) {
      bugunPeriodBas = bugunPeriodBas.subtract(const Duration(days: 1));
    }

    // Dünkü periyot = bugünün periyodundan 24 saat önce
    final dunkuPeriodBas = bugunPeriodBas.subtract(const Duration(days: 1));

    _filtreBas = dunkuPeriodBas;
    _filtreSon = bugunPeriodBas.subtract(const Duration(seconds: 1));
    _filtreMasaId = null;
    _filtreOdeme = null;
    raporlariYukle();
  }

  void masaFiltresiAyarla(String? masaId) {
    _filtreMasaId = masaId;
    notifyListeners();
  }

  void odemeFiltresiAyarla(OdemeYontemi? yontem) {
    _filtreOdeme = yontem;
    notifyListeners();
  }

  void siralamaAyarla(RaporSiralama sir) {
    _siralama = sir;
    notifyListeners();
  }

  void filtreleriTemizle() {
    _filtreMasaId = null;
    _filtreOdeme = null;
    final bugun = DateTime.now();
    _filtreBas = DateTime(bugun.year, bugun.month, bugun.day, 0, 0);
    _filtreSon = DateTime(bugun.year, bugun.month, bugun.day, 23, 59, 59);
    raporlariYukle();
  }

  // ── Veri yükleme ──
  Future<void> raporlariYukle() async {
    _yukleniyor = true;
    _hata = null;
    notifyListeners();

    try {
      _raporlar = await _raporRepo.tarihAraligiRaporlari(
        _filtreBas,
        _filtreSon,
      );
    } catch (e) {
      _hata = 'Raporlar yüklenirken hata: $e';
    }

    _yukleniyor = false;
    notifyListeners();
  }

  /// Yeni rapor kaydet (oturum kapandığında çağrılır).
  Future<RaporModel?> raporOlustur({
    String? oturumId,
    String? masaId,
    required String masaAd,
    required String konsolTipi,
    required DateTime baslangic,
    required DateTime bitis,
    required int oynananDk,
    required int kolSayisi,
    required double konsolUcreti,
    required double kolEkstraUcreti,
    required double siparisUcreti,
    required double toplamTutar,
    required OdemeYontemi odemeYontemi,
    required double nakitTutar,
    required double kartTutar,
    List<KolGecmisiKayit> kolGecmisi = const [],
    String aciklama = '',
  }) async {
    final rapor = RaporModel(
      id: const Uuid().v4(),
      oturumId: oturumId,
      masaId: masaId,
      masaAd: masaAd,
      konsolTipi: konsolTipi,
      baslangic: baslangic,
      bitis: bitis,
      oynananDk: oynananDk,
      kolSayisi: kolSayisi,
      konsolUcreti: konsolUcreti,
      kolEkstraUcreti: kolEkstraUcreti,
      siparisUcreti: siparisUcreti,
      toplamTutar: toplamTutar,
      odemeYontemi: odemeYontemi,
      nakitTutar: nakitTutar,
      kartTutar: kartTutar,
      olusturulmaTarihi: DateTime.now(),
      kolGecmisi: kolGecmisi,
      aciklama: aciklama,
    );

    try {
      final kaydedilen = await _raporRepo.raporOlustur(rapor);
      _raporlar.insert(0, kaydedilen);
      notifyListeners();
      
      // Başarılı gönderim sonrası varsa kuyruğu da temizlemeye çalış
      kuyruguIsle();
      
      return kaydedilen;
    } catch (e) {
      _hata = 'Rapor veritabanına yazılamadı, yerel kuyruğa eklendi: $e';
      debugPrint('CRITICAL: Rapor hatası! Kuyruğa ekleniyor. Hata: $e');
      
      // Veritabanı hatası durumunda yerel kuyruğa ekle (Kritik veri kaybı önleme)
      await _kuyrugaEkle(rapor);
      
      notifyListeners();
      return null;
    }
  }

  /// Veritabanına yazılamayan raporu yerel hafızaya kaydet.
  Future<void> _kuyrugaEkle(RaporModel rapor) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final kuyrukJson = prefs.getStringList(_kuyrukAnahtari) ?? [];
      kuyrukJson.add(jsonEncode(rapor.toJson()));
      await prefs.setStringList(_kuyrukAnahtari, kuyrukJson);
    } catch (e) {
      debugPrint('Kuyruğa eklerken hata: $e');
    }
  }

  /// Yerel hafızadaki bekleyen raporları veritabanına göndermeyi dene.
  Future<void> kuyruguIsle() async {
    if (_kuyrukIsleniyor) return;
    _kuyrukIsleniyor = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final kuyrukJson = prefs.getStringList(_kuyrukAnahtari) ?? [];
      if (kuyrukJson.isEmpty) {
        _kuyrukIsleniyor = false;
        return;
      }

      debugPrint('Kuyrukta ${kuyrukJson.length} bekleyen rapor var. İşleniyor...');
      
      final basariliIds = <String>[];
      final yeniKuyruk = List<String>.from(kuyrukJson);

      for (final jsonStr in kuyrukJson) {
        try {
          final map = jsonDecode(jsonStr) as Map<String, dynamic>;
          final rapor = RaporModel.fromJson(map);
          
          await _raporRepo.raporOlustur(rapor);
          basariliIds.add(rapor.id);
          yeniKuyruk.remove(jsonStr);
          debugPrint('Bekleyen rapor başarıyla gönderildi: ${rapor.id}');
        } catch (e) {
          debugPrint('Kuyruktaki bir rapor gönderilemedi: $e');
          // Bir tanesi bile hata verirse (internet yoksa vb.) diğerlerini zorlamayalım
          break;
        }
      }

      await prefs.setStringList(_kuyrukAnahtari, yeniKuyruk);
      
      // Eğer bir şeyler gönderildiyse listeyi yenile
      if (basariliIds.isNotEmpty && bugunMu) {
        raporlariYukle();
      }
    } catch (e) {
      debugPrint('Kuyruk işlenirken hata: $e');
    } finally {
      _kuyrukIsleniyor = false;
    }
  }

  /// Rapor güncelle (düzenleme için).
  Future<bool> raporGuncelle(RaporModel rapor) async {
    try {
      final guncellenen = await _raporRepo.raporGuncelle(rapor);
      final index = _raporlar.indexWhere((r) => r.id == rapor.id);
      if (index >= 0) {
        _raporlar[index] = guncellenen;
      }
      notifyListeners();
      return true;
    } catch (e) {
      _hata = 'Rapor güncellenirken hata: $e';
      notifyListeners();
      return false;
    }
  }

  /// Rapor sil.
  Future<bool> raporSil(String id) async {
    try {
      await _raporRepo.raporSil(id);
      _raporlar.removeWhere((r) => r.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _hata = 'Rapor silinirken hata: $e';
      notifyListeners();
      return false;
    }
  }

  // ── Toplu Silme ──

  /// Tarih aralığındaki raporları toplu sil.
  Future<int> tarihAraligiTopluSil(DateTime bas, DateTime son) async {
    try {
      final adet = await _raporRepo.tarihAraligiTopluSil(bas, son);
      await raporlariYukle();
      return adet;
    } catch (e) {
      _hata = 'Toplu silme hatası: $e';
      notifyListeners();
      return 0;
    }
  }

  /// Tarih + saat aralığındaki raporları toplu sil.
  Future<int> saatAraligiTopluSil({
    required DateTime tarihBas,
    required DateTime tarihSon,
    required int saatBasDak,
    required int saatSonDak,
  }) async {
    try {
      final adet = await _raporRepo.saatAraligiTopluSil(
        tarihBas: tarihBas,
        tarihSon: tarihSon,
        saatBasDak: saatBasDak,
        saatSonDak: saatSonDak,
      );
      await raporlariYukle();
      return adet;
    } catch (e) {
      _hata = 'Toplu silme hatası: $e';
      notifyListeners();
      return 0;
    }
  }

  /// Seçili ID'lere göre raporları toplu sil.
  Future<void> secilenlerinSil(List<String> idler) async {
    _yukleniyor = true;
    notifyListeners();
    try {
      for (final id in idler) {
        await _raporRepo.raporSil(id);
        _raporlar.removeWhere((r) => r.id == id);
      }
    } catch (e) {
      _hata = 'Toplu silme hatası: $e';
    }
    _yukleniyor = false;
    notifyListeners();
  }

  /// Tüm raporları sil.
  Future<int> tumRaporlariSil() async {
    try {
      final adet = await _raporRepo.tumunuSil();
      await raporlariYukle();
      return adet;
    } catch (e) {
      _hata = 'Toplu silme hatası: $e';
      notifyListeners();
      return 0;
    }
  }

  /// Seçili masanın tüm raporlarını sil.
  Future<int> masaKayitlariniTopluSil(String masaId) async {
    try {
      final adet = await _raporRepo.masaKayitlariniTopluSil(masaId);
      await raporlariYukle();
      return adet;
    } catch (e) {
      _hata = 'Toplu silme hatası: $e';
      notifyListeners();
      return 0;
    }
  }

  /// Rapor detayı: oturumun sipariş kalemleri.
  Future<List<SiparisKalemiModel>> raporSiparisleri(String? oturumId) async {
    if (oturumId == null) return [];
    try {
      final satislar = await _satisRepo.oturumSatislari(oturumId);
      return satislar
          .map(
            (s) => SiparisKalemiModel(
              urunAd: s.urunAd,
              adet: s.adet,
              birimFiyat: s.birimFiyat,
              toplamTutar: s.toplamTutar,
            ),
          )
          .toList();
    } catch (e) {
      return [];
    }
  }
}
