import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/oturum_model.dart';
import '../../data/repositories/oturum_repository.dart';
import '../services/ses_servisi.dart';
import '../services/sure_hesaplama_servisi.dart';

/// Süre dolan oturumun bildirim verisi.
class SureBitenBildirim {
  final String oturumId;
  final String masaId;
  final int planliSureDk;
  final int kolSayisi;
  final List<KolSegment> kolGecmisi;
  final Duration efektifSure;
  final DateTime oturumBaslangic;

  const SureBitenBildirim({
    required this.oturumId,
    required this.masaId,
    required this.planliSureDk,
    this.kolSayisi = 2,
    this.kolGecmisi = const [],
    required this.efektifSure,
    required this.oturumBaslangic,
  });
}

/// Oturum (session) state yönetimi.
class OturumProvider extends ChangeNotifier {
  final OturumRepository _repository;
  final Uuid _uuid = const Uuid();

  List<OturumModel> _aktifOturumlar = [];
  bool _yukleniyor = false;
  String? _hata;

  /// Süre dolan oturumların bildirimleri.
  final List<SureBitenBildirim> _sureBitenBildirimler = [];

  /// 5 dakika kala uyarı sesi çalınmış oturum ID'leri.
  final Set<String> _uyariSesiCalinmis = {};

  /// Re-entrant async çağrıları engellemek için bayrak.
  bool _kontrolEdiliyor = false;

  /// Her saniye aktif oturumları güncellemek için zamanlayıcı.
  Timer? _sayacTimer;

  /// dispose() çağrıldıktan sonra async callback'lerin notifyListeners yapmasını engeller.
  bool _disposed = false;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  OturumProvider({OturumRepository? repository})
    : _repository = repository ?? OturumRepository();

  /// Tüm lokal state'i sıfırla (hesap değişiminde çağrılır).
  void temizle() {
    _sayacTimer?.cancel();
    _sayacTimer = null;
    _aktifOturumlar = [];
    _sureBitenBildirimler.clear();
    _uyariSesiCalinmis.clear();
    _yukleniyor = false;
    _hata = null;
    _kontrolEdiliyor = false;
    notifyListeners();
  }

  // ── Getter'lar ──
  List<OturumModel> get aktifOturumlar => _aktifOturumlar;
  bool get yukleniyor => _yukleniyor;
  String? get hata => _hata;
  List<SureBitenBildirim> get sureBitenBildirimler =>
      List.unmodifiable(_sureBitenBildirimler);

  /// Dakika başı ücreti güncelle (UI'dan çağrılır) — şu an kullanılmıyor.
  // ignore: avoid_unused_parameters
  void dakikaBasiUcretAyarla(double ucret) {}

  /// Ücret resolver'ını set et — şu an kullanılmıyor.
  // ignore: avoid_unused_parameters
  void ucretResolverAyarla(
    double Function(String masaId, int kolSayisi) resolver,
  ) {}

  /// Kol ekstra resolver'ını set et.
  /// Ekstra ücret sidebar tarafında hesaplandığı için provider'da kullanılmıyor.
  // ignore: avoid_unused_parameters
  void kolEkstraResolverAyarla(double Function(int kolSayisi) _) {}

  /// Bildirimi görüldü olarak işaretle ve listeden kaldır.
  void bildirimGoruldu(String oturumId) {
    _sureBitenBildirimler.removeWhere((b) => b.oturumId == oturumId);
  }

  /// Belirli bir masanın aktif oturumunu bul.
  OturumModel? masaninOturumu(String masaId) {
    try {
      return _aktifOturumlar.firstWhere((o) => o.masaId == masaId);
    } catch (_) {
      return null;
    }
  }

  // ── Veri Yükle ──

  /// Aktif oturumları Supabase'den çek.
  Future<void> aktifOturumlariYukle() async {
    _yukleniyor = true;
    _hata = null;
    notifyListeners();

    try {
      _aktifOturumlar = await _repository.aktifOturumlariGetir();
      _sayacBaslat();
    } catch (e) {
      _hata = 'Oturumlar yüklenirken hata: $e';
    }

    _yukleniyor = false;
    notifyListeners();
  }

  // ── Oturum Başlat ──

  /// Yeni oturum başlat.
  Future<bool> oturumBaslat({
    required String masaId,
    required OturumMod mod,
    int? sureDk,
    int kolSayisi = 2,
    double? butce,
  }) async {
    try {
      final simdi = DateTime.now();
      final oturum = OturumModel(
        id: _uuid.v4(),
        masaId: masaId,
        baslangic: simdi,
        mod: mod,
        sureDk: sureDk,
        tutar: 0,
        durum: OturumDurum.aktif,
        kolSayisi: kolSayisi,
        kolGecmisi: [KolSegment(kolSayisi: kolSayisi, baslangic: simdi)],
        butce: butce,
      );
      final eklenen = await _repository.oturumBaslat(oturum);
      // Aynı masaId için zaten optimistic oturum varsa yerine koy (çift kayıt önleme)
      final varIndex = _aktifOturumlar.indexWhere((o) => o.masaId == masaId);
      if (varIndex != -1) {
        _aktifOturumlar[varIndex] = eklenen;
      } else {
        _aktifOturumlar.add(eklenen);
      }
      _sayacBaslat();
      notifyListeners();
      return true;
    } catch (e) {
      _hata = 'Oturum başlatılırken hata: $e';
      notifyListeners();
      return false;
    }
  }

  // ── Oturum Sonlandır ──

  /// Oturumu sonlandır ve ücreti hesapla.
  Future<double> oturumSonlandir(
    String oturumId,
    double dakikaBasiUcret,
  ) async {
    try {
      final oturum = _aktifOturumlar.firstWhere((o) => o.id == oturumId);
      // gecenSure zaten dondurulma süresini çıkarır
      final efektifDk = oturum.gecenSure.inMinutes;
      final tutar = SureHesaplamaServisi.ucretHesapla(
        baslangic: DateTime.now().subtract(Duration(minutes: efektifDk)),
        bitis: DateTime.now(),
        mod: oturum.mod,
        planliSureDk: oturum.mod == OturumMod.sureli ? oturum.sureDk : null,
        dakikaBasiUcret: dakikaBasiUcret,
      );

      await _repository.oturumSonlandir(oturumId, tutar);
      _aktifOturumlar.removeWhere((o) => o.id == oturumId);
      _uyariSesiCalinmis.remove(oturumId);

      if (_aktifOturumlar.isEmpty) _sayacDurdur();
      notifyListeners();
      return tutar;
    } catch (e) {
      _hata = 'Oturum sonlandırılırken hata: $e';
      notifyListeners();
      return 0;
    }
  }

  /// Oturumu önceden hesaplanmış tutarla sonlandır (dinamik kol hesabı dışarıda yapılır).
  Future<bool> oturumSonlandirTutarli(String oturumId, double tutar) async {
    try {
      await _repository.oturumSonlandir(oturumId, tutar);
      _aktifOturumlar.removeWhere((o) => o.id == oturumId);
      _uyariSesiCalinmis.remove(oturumId);
      if (_aktifOturumlar.isEmpty) _sayacDurdur();
      notifyListeners();
      return true;
    } catch (e) {
      _hata = 'Oturum sonlandırılırken hata: $e';
      notifyListeners();
      return false;
    }
  }

  /// Oturumu SADECE lokal listeden kaldır — DB'ye yazmaz.
  /// Optimistic UI için kullanılır; hemen ardından gerçek DB çağrısı yapılmalıdır.
  void oturumSonlandirLokalde(String oturumId) {
    _aktifOturumlar.removeWhere((o) => o.id == oturumId);
    _uyariSesiCalinmis.remove(oturumId);
    if (_aktifOturumlar.isEmpty) _sayacDurdur();
    notifyListeners();
  }

  /// Oturumu SADECE lokal listeye ekle — DB'ye yazmaz.
  /// Optimistic UI için kullanılır. Sidebar anında aktif oturum moduna geçer.
  /// Aynı masaId için zaten oturum varsa eklenmez (dup önleme).
  void oturumBaslatLokalde(OturumModel oturum) {
    if (_aktifOturumlar.any((o) => o.masaId == oturum.masaId)) return;
    _aktifOturumlar.add(oturum);
    _sayacBaslat();
    notifyListeners();
  }

  // ── Oturum İptal ──

  /// Oturumu iptal et (ücret alınmaz).
  Future<bool> oturumIptalEt(String oturumId) async {
    try {
      await _repository.oturumIptalEt(oturumId);
      _aktifOturumlar.removeWhere((o) => o.id == oturumId);
      _uyariSesiCalinmis.remove(oturumId);

      if (_aktifOturumlar.isEmpty) _sayacDurdur();
      notifyListeners();
      return true;
    } catch (e) {
      _hata = 'Oturum iptal edilirken hata: $e';
      notifyListeners();
      return false;
    }
  }

  // ── Oturum Yeniden Başlat ──

  /// Mevcut oturumu sıfırlayıp yeni parametrelerle yeniden başlat.
  /// Oturum silinmez, ID korunur; sadece zamanlama/ücret alanları sıfırlanır.
  /// Eski ücretin siparişe aktarılması bu metot dışında (UI katmanında) yapılır.
  Future<bool> oturumYenidenBaslat(
    String oturumId, {
    required OturumMod yeniMod,
    int? yeniSureDk,
    int yeniKolSayisi = 2,
  }) async {
    try {
      final index = _aktifOturumlar.indexWhere((o) => o.id == oturumId);
      if (index == -1) return false;

      final simdi = DateTime.now();
      final sifirlanan = _aktifOturumlar[index].copyWith(
        baslangic: simdi,
        bitis: null,
        mod: yeniMod,
        sureDk: yeniMod == OturumMod.sureli ? yeniSureDk : null,
        sureDkNull: yeniMod == OturumMod.suresiz,
        kolSayisi: yeniKolSayisi,
        kolGecmisi: [KolSegment(kolSayisi: yeniKolSayisi, baslangic: simdi)],
        tutar: 0,
        durum: OturumDurum.aktif,
        dondurmaAniNull: true,
        toplamDondurulmaSuresiSn: 0,
      );
      await _repository.oturumGuncelle(sifirlanan);
      _aktifOturumlar[index] = sifirlanan;
      _sayacBaslat();
      notifyListeners();
      return true;
    } catch (e) {
      _hata = 'Oturum yeniden başlatılırken hata: $e';
      notifyListeners();
      return false;
    }
  }

  // ── Masa Taşı ──

  /// Oturumu başka bir masaya taşı.
  /// Zamanlama sıfırlanır (eski ücret önceden siparişe aktarılmalı).
  /// Kalan süre korunur (süreli mod için).
  Future<bool> masaTasi(
    String oturumId,
    String yeniMasaId, {
    int? kalanSureDk,
    required int kolSayisi,
  }) async {
    try {
      final index = _aktifOturumlar.indexWhere((o) => o.id == oturumId);
      if (index == -1) return false;
      final oturum = _aktifOturumlar[index];

      // Dondurulmuş oturum taşınamaz
      if (oturum.isDondurulmus) return false;

      final simdi = DateTime.now();
      final tasinan = oturum.copyWith(
        masaId: yeniMasaId,
        baslangic: simdi,
        bitis: null,
        mod: oturum.mod,
        sureDk: oturum.mod == OturumMod.sureli ? kalanSureDk : null,
        sureDkNull: oturum.mod == OturumMod.suresiz,
        kolSayisi: kolSayisi,
        kolGecmisi: [KolSegment(kolSayisi: kolSayisi, baslangic: simdi)],
        tutar: 0,
        durum: OturumDurum.aktif,
        dondurmaAniNull: true,
        toplamDondurulmaSuresiSn: 0,
      );

      await _repository.oturumGuncelle(tasinan);
      _aktifOturumlar[index] = tasinan;
      _sayacBaslat();
      notifyListeners();
      return true;
    } catch (e) {
      _hata = 'Masa taşınırken hata: $e';
      notifyListeners();
      return false;
    }
  }

  /// Sadece masaId'yi değiştirir — zamanlama, ücret, kol geçmişi korunur.
  /// Aynı konsol tipi geçişlerinde kullanılır.
  Future<bool> masaIdDegistir(String oturumId, String yeniMasaId) async {
    try {
      final index = _aktifOturumlar.indexWhere((o) => o.id == oturumId);
      if (index == -1) return false;
      final oturum = _aktifOturumlar[index];

      if (oturum.isDondurulmus) return false;

      final guncellenen = oturum.copyWith(masaId: yeniMasaId);
      await _repository.oturumGuncelle(guncellenen);
      _aktifOturumlar[index] = guncellenen;
      notifyListeners();
      return true;
    } catch (e) {
      _hata = 'Masa ID değiştirirken hata: $e';
      notifyListeners();
      return false;
    }
  }

  // ── Başlangıç Saati Güncelle ──

  /// Aktif oturumun başlangıç saatini güncelle.
  /// Aktif oturumun başlangıç saatini güncelle.
  /// Önemli: kolGecmisi[0].baslangic da güncellenir; çünkü segment
  /// hesaplaması ilk segmentin wall-clock süresini buradan alır.
  Future<bool> baslangicGuncelle(
    String oturumId,
    DateTime yeniBaslangic,
  ) async {
    try {
      final index = _aktifOturumlar.indexWhere((o) => o.id == oturumId);
      if (index == -1) return false;
      final oturum = _aktifOturumlar[index];

      // İlk segmentin başlangıcını da taşı — daha sonraki segmentler sabit kalır
      final yeniKolGecmisi = oturum.kolGecmisi.isNotEmpty
          ? [
              KolSegment(
                kolSayisi: oturum.kolGecmisi.first.kolSayisi,
                baslangic: yeniBaslangic,
              ),
              ...oturum.kolGecmisi.skip(1),
            ]
          : oturum.kolGecmisi;

      final guncellenen = oturum.copyWith(
        baslangic: yeniBaslangic,
        kolGecmisi: yeniKolGecmisi,
      );
      await _repository.oturumGuncelle(guncellenen);
      _aktifOturumlar[index] = guncellenen;
      notifyListeners();
      return true;
    } catch (e) {
      _hata = 'Başlangıç saati güncellenirken hata: $e';
      notifyListeners();
      return false;
    }
  }

  // ── Kol Sayısı Değiştir ──

  /// Aktif oturumun kol sayısını değiştir (dinamik ücretlendirme).
  /// Yeni segment eklenir, eski segmentler korunur.
  /// Bütçeli oturumlarda dilimli hesaplama uygulanır:
  /// geçen süre dilime yuvarlanır, fazla dk yeni segmente taşınır,
  /// kalan bütçe yeni tarifeden dakikaya çevrilir.
  /// [dakikaBasiUcretResolver]: (kolSayisi) => dk başı ücret
  /// [periyotDk]: ücretlendirme dilimi (ör: 15 dk)
  Future<bool> kolSayisiDegistir(
    String oturumId,
    int yeniKolSayisi, {
    double Function(int kolSayisi)? dakikaBasiUcretResolver,
    int periyotDk = 15,
  }) async {
    try {
      final index = _aktifOturumlar.indexWhere((o) => o.id == oturumId);
      if (index == -1) return false;
      final oturum = _aktifOturumlar[index];

      // Zaten aynı sayıdaysa değişiklik yapma
      if (oturum.kolSayisi == yeniKolSayisi) return true;

      // Yeni segment ekle
      final yeniGecmis = List<KolSegment>.from(oturum.kolGecmisi)
        ..add(KolSegment(kolSayisi: yeniKolSayisi, baslangic: DateTime.now()));

      int? yeniSureDk = oturum.sureDk;

      // Bütçeli oturumlarda süreyi yeniden hesapla (segment bazlı dilimli)
      if (oturum.butce != null &&
          oturum.butce! > 0 &&
          oturum.mod == OturumMod.sureli &&
          dakikaBasiUcretResolver != null) {
        final gecenDk = oturum.gecenSure.inMinutes;

        // Tüm segmentleri dilimli hesapla (harcanan + fazla dk)
        // Bütçeli oturumlarda periyot her zaman 1 dk (dinamik bakiye dönüşümü)
        final sonuc = SureHesaplamaServisi.butceHarcamaHesapla(
          kolGecmisi: oturum.kolGecmisi,
          efektifSure: oturum.gecenSure,
          dakikaBasiUcretResolver: dakikaBasiUcretResolver,
          fallbackKolSayisi: oturum.kolSayisi,
          periyotDk: 1,
        );

        // Kalan bütçeyi yeni tarifeden dakikaya çevir
        final kalanButce = (oturum.butce! - sonuc.harcananTutar).clamp(
          0.0,
          oturum.butce!,
        );
        final yeniDkBasiUcret = dakikaBasiUcretResolver(yeniKolSayisi);
        final butcedenKalanDk = yeniDkBasiUcret > 0
            ? (kalanButce / yeniDkBasiUcret).floor()
            : 0;

        // Toplam kalan = bütçeden kalan + dilim fazlası
        final toplamKalanDk = butcedenKalanDk + sonuc.kalanFazlaDk;

        yeniSureDk = gecenDk + toplamKalanDk;
        // Minimum: geçen süreden en az 1 dk fazla
        if (yeniSureDk <= gecenDk) yeniSureDk = gecenDk + 1;
      }

      final guncellenen = oturum.copyWith(
        kolSayisi: yeniKolSayisi,
        kolGecmisi: yeniGecmis,
        sureDk: yeniSureDk,
      );
      await _repository.oturumGuncelle(guncellenen);
      _aktifOturumlar[index] = guncellenen;
      // Süre değiştiği için uyarı sesini sıfırla
      _uyariSesiCalinmis.remove(oturumId);
      notifyListeners();
      return true;
    } catch (e) {
      _hata = 'Kol sayısı değiştirilirken hata: $e';
      notifyListeners();
      return false;
    }
  }

  // ── Masa Dondurma ──

  /// Oturumu dondur (süre ve ücret işlemeyi durdur).
  Future<bool> oturumDondur(String oturumId) async {
    try {
      final index = _aktifOturumlar.indexWhere((o) => o.id == oturumId);
      if (index == -1) return false;
      final oturum = _aktifOturumlar[index];
      if (oturum.durum != OturumDurum.aktif) return false;

      final dondurulan = oturum.copyWith(
        durum: OturumDurum.dondurulmus,
        dondurmaAni: DateTime.now(),
      );
      await _repository.oturumGuncelle(dondurulan);
      _aktifOturumlar[index] = dondurulan;
      notifyListeners();
      return true;
    } catch (e) {
      _hata = 'Oturum dondurulurken hata: $e';
      notifyListeners();
      return false;
    }
  }

  /// Dondurulmuş oturumu devam ettir.
  Future<bool> oturumDevamEt(String oturumId) async {
    try {
      final index = _aktifOturumlar.indexWhere((o) => o.id == oturumId);
      if (index == -1) return false;
      final oturum = _aktifOturumlar[index];
      if (oturum.durum != OturumDurum.dondurulmus) return false;

      // Dondurma süresini hesapla ve toplam süreye ekle
      int dondurmaSn = 0;
      if (oturum.dondurmaAni != null) {
        dondurmaSn = DateTime.now().difference(oturum.dondurmaAni!).inSeconds;
      }
      final devamEden = oturum.copyWith(
        durum: OturumDurum.aktif,
        dondurmaAniNull: true,
        toplamDondurulmaSuresiSn: oturum.toplamDondurulmaSuresiSn + dondurmaSn,
      );
      await _repository.oturumGuncelle(devamEden);
      _aktifOturumlar[index] = devamEden;
      _sayacBaslat();
      notifyListeners();
      return true;
    } catch (e) {
      _hata = 'Oturum devam ettirilirken hata: $e';
      notifyListeners();
      return false;
    }
  }

  // ── Mod Değiştir ──

  /// Oturum modunu değiştir (süresiz↔süreli).
  /// süresiz→süreli: sureDk parametresi toplam oturum süresini belirtir
  ///   (geçen süre dahil, ör: 30dk oynamış + 60dk seçildi → 30dk daha oynar).
  /// süreli→süresiz: sureDk yok sayılır, null olur.
  Future<bool> modDegistir(
    String oturumId,
    OturumMod yeniMod, {
    int? sureDk,
  }) async {
    try {
      final index = _aktifOturumlar.indexWhere((o) => o.id == oturumId);
      if (index == -1) return false;
      final oturum = _aktifOturumlar[index];

      if (oturum.mod == yeniMod) return true;

      final OturumModel guncellenen;
      if (yeniMod == OturumMod.suresiz) {
        // Süreli → Süresiz
        guncellenen = oturum.copyWith(mod: OturumMod.suresiz, sureDkNull: true);
      } else {
        // Süresiz → Süreli
        if (sureDk == null) return false;
        guncellenen = oturum.copyWith(mod: OturumMod.sureli, sureDk: sureDk);
      }

      await _repository.oturumGuncelle(guncellenen);
      _aktifOturumlar[index] = guncellenen;
      notifyListeners();
      return true;
    } catch (e) {
      _hata = 'Mod değiştirilirken hata: $e';
      notifyListeners();
      return false;
    }
  }

  // ── Süre Ayarla ──

  /// Süreli oturumun toplam süresini ayarla (pozitif = ekle, negatif = çıkar).
  Future<bool> sureAyarla(String oturumId, int ekstraDk) async {
    try {
      final index = _aktifOturumlar.indexWhere((o) => o.id == oturumId);
      if (index == -1) return false;
      final oturum = _aktifOturumlar[index];

      if (oturum.mod != OturumMod.sureli || oturum.sureDk == null) return false;

      final yeniSureDk = oturum.sureDk! + ekstraDk;
      // Minimum: geçen süreden büyük olmalı (en az 1dk kalsın)
      final gecenDk = oturum.gecenSure.inMinutes + 1;
      if (yeniSureDk < gecenDk) return false;

      final guncellenen = oturum.copyWith(sureDk: yeniSureDk);
      await _repository.oturumGuncelle(guncellenen);
      _aktifOturumlar[index] = guncellenen;
      // Süre uzatıldığında uyarı sesini sıfırla (yeniden çalabilsin)
      _uyariSesiCalinmis.remove(oturumId);
      notifyListeners();
      return true;
    } catch (e) {
      _hata = 'Süre ayarlanırken hata: $e';
      notifyListeners();
      return false;
    }
  }

  /// Bütçeli (Ücretli) oturumun toplam süresine ve bütçesine ekleme/çıkarma yapar.
  Future<bool> sureVeButceAyarla(String oturumId, int ekstraDk, double ekstraButce) async {
    try {
      final index = _aktifOturumlar.indexWhere((o) => o.id == oturumId);
      if (index == -1) return false;
      final oturum = _aktifOturumlar[index];

      if (oturum.mod != OturumMod.sureli || oturum.sureDk == null || oturum.butce == null) {
        return false;
      }

      final yeniSureDk = oturum.sureDk! + ekstraDk;
      // Minimum: geçen süreden büyük olmalı (en az 1dk kalsın)
      final gecenDk = oturum.gecenSure.inMinutes + 1;
      if (yeniSureDk < gecenDk) return false;

      final yeniButce = oturum.butce! + ekstraButce;
      if (yeniButce <= 0) return false;

      final guncellenen = oturum.copyWith(
        sureDk: yeniSureDk,
        butce: yeniButce,
      );
      await _repository.oturumGuncelle(guncellenen);
      _aktifOturumlar[index] = guncellenen;
      _uyariSesiCalinmis.remove(oturumId);
      notifyListeners();
      return true;
    } catch (e) {
      _hata = 'Süre ve bütçe ayarlanırken hata: $e';
      notifyListeners();
      return false;
    }
  }

  // ── Süre Dolan Kontrol ──

  /// Süreli oturumları kontrol et; 5dk kala uyarı, süresi dolanları dondur ve bildirim ekle.
  /// Oturum listeden çıkarılmaz — ödeme/uzatma kararı UI katmanında verilir.
  Future<void> _sureDolanlariKontrolEt() async {
    if (_kontrolEdiliyor) return;
    _kontrolEdiliyor = true;

    try {
      // ── 5 dakika kala uyarı sesi ──
      final sesServisi = SesServisi.instance;
      for (final o in _aktifOturumlar) {
        if (o.mod != OturumMod.sureli ||
            o.sureDk == null ||
            o.durum != OturumDurum.aktif) {
          continue;
        }
        final kalanSn = (o.sureDk! * 60) - o.gecenSure.inSeconds;
        // 5 dakika (300 sn) veya altına düştüyse ve henüz çalınmadıysa
        if (kalanSn <= 300 &&
            kalanSn > 0 &&
            !_uyariSesiCalinmis.contains(o.id)) {
          _uyariSesiCalinmis.add(o.id);
          sesServisi.uyariSesiCal();
        }
      }

      // Süresi dolan oturumları tespit et (sadece aktif olanlar, dondurulmuş atla)
      final dolanlar = _aktifOturumlar
          .where(
            (o) =>
                o.mod == OturumMod.sureli &&
                o.sureDk != null &&
                o.durum == OturumDurum.aktif &&
                o.gecenSure.inSeconds >= o.sureDk! * 60,
          )
          .toList();

      if (dolanlar.isEmpty) return;

      // Süre doldu alarm sesi çal
      sesServisi.alarmSesiCal();

      // Her birini dondur (süre sayacı durur, masa açık kalır, ödeme dialogu bekler)
      for (final oturum in dolanlar) {
        final idx = _aktifOturumlar.indexWhere((o) => o.id == oturum.id);
        if (idx == -1) continue;

        final dondurulan = oturum.copyWith(
          durum: OturumDurum.dondurulmus,
          dondurmaAni: DateTime.now(),
        );
        try {
          await _repository.oturumGuncelle(dondurulan);
          _aktifOturumlar[idx] = dondurulan;
        } catch (_) {}

        _sureBitenBildirimler.add(
          SureBitenBildirim(
            oturumId: oturum.id,
            masaId: oturum.masaId,
            planliSureDk: oturum.sureDk!,
            kolSayisi: oturum.kolSayisi,
            kolGecmisi: oturum.kolGecmisi,
            // gecenSure: dondurma anındaki efektif süre (artık artmaz)
            efektifSure: oturum.gecenSure,
            oturumBaslangic: oturum.baslangic,
          ),
        );
      }

      // Bildirimler eklendikten SONRA listener'ları tetikle
      notifyListeners();
    } finally {
      _kontrolEdiliyor = false;
    }
  }

  // ── Sayaç Yönetimi ──

  /// Her saniye UI'ı güncellemek ve süre dolan kontrolü için timer başlat.
  void _sayacBaslat() {
    _sayacTimer?.cancel();
    if (_aktifOturumlar.isNotEmpty) {
      _sayacTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_disposed) return;
        // Süre dolan kontrolü (async — kendi notifyListeners'ını çağırır)
        _sureDolanlariKontrolEt();
        // UI güncellemesi (fiyat hesaplamaları vb.)
        notifyListeners();
      });
    }
  }

  void _sayacDurdur() {
    _sayacTimer?.cancel();
    _sayacTimer = null;
  }

  @override
  void dispose() {
    _disposed = true;
    _sayacDurdur();
    super.dispose();
  }
}
