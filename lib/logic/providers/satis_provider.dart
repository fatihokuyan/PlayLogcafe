import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../app.dart';
import '../../data/models/rapor_model.dart';
import '../../data/models/satis_model.dart';
import '../../data/models/urun_model.dart';
import '../../data/repositories/satis_repository.dart';
import '../providers/rapor_provider.dart';
import '../providers/urun_provider.dart';

/// Satış state yönetimi.
class SatisProvider extends ChangeNotifier {
  final SatisRepository _repository;
  final Uuid _uuid = const Uuid();

  List<SatisModel> _bugunSatislar = [];
  bool _yukleniyor = false;
  String? _hata;

  SatisProvider({SatisRepository? repository})
    : _repository = repository ?? SatisRepository();

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

  /// Tüm lokal state'i sıfırla (hesap değişiminde çağrılır).
  void temizle() {
    _bugunSatislar = [];
    _yukleniyor = false;
    _hata = null;
    notifyListeners();
  }

  // ── Getter'lar ──
  List<SatisModel> get bugunSatislar => _bugunSatislar;
  bool get yukleniyor => _yukleniyor;
  String? get hata => _hata;

  /// Bugünkü toplam satış tutarı.
  double get bugunToplamTutar =>
      _bugunSatislar.fold<double>(0, (toplam, s) => toplam + s.toplamTutar);

  /// Belirli bir oturumun satışları.
  List<SatisModel> oturumSatislari(String oturumId) =>
      _bugunSatislar.where((s) => s.oturumId == oturumId).toList();

  // ── Yardımcı: Global SnackBar ──

  /// rootScaffoldMessengerKey üzerinden toast bildirim göster.
  void _toast(String mesaj) {
    rootScaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(mesaj)),
    );
  }

  // ── Veri Yükle ──

  /// Bugünün satışlarını yükle.
  Future<void> bugunSatislariYukle() async {
    _yukleniyor = true;
    _hata = null;
    notifyListeners();

    try {
      _bugunSatislar = await _repository.bugunSatislari();
    } catch (e) {
      _hata = 'Satışlar yüklenirken hata: $e';
    }

    _yukleniyor = false;
    notifyListeners();
  }

  // ── Satış Ekle ──

  /// Yeni satış kaydet (Smart Order Merging).
  Future<bool> satisEkle({
    String? oturumId,
    String? urunId,
    required String urunAd,
    required int adet,
    required double birimFiyat,
  }) async {
    // Aynı oturumda aynı ürün (adı veya id'si üzerinden) daha önce eklenmiş mi kontrol et
    if (oturumId != null) {
      final existingIndex = _bugunSatislar.indexWhere((s) {
        final bool ayniUrun = (urunId != null && s.urunId != null)
            ? s.urunId == urunId
            : s.urunAd == urunAd;
        return s.oturumId == oturumId && ayniUrun && s.birimFiyat == birimFiyat;
      });

      if (existingIndex != -1) {
        // Ürün zaten var, adedi güncelle
        final existing = _bugunSatislar[existingIndex];
        return await satisAdetGuncelle(existing.id, existing.adet + adet);
      }
    }

    // Ürün yoksa yeni kayıt oluştur
    final satis = SatisModel(
      id: _uuid.v4(),
      oturumId: oturumId,
      urunId: urunId,
      urunAd: urunAd,
      adet: adet,
      birimFiyat: birimFiyat,
      toplamTutar: adet * birimFiyat,
      tarih: DateTime.now(),
    );

    // Önce yerel listeye ekle (UI hemen güncellenir)
    _bugunSatislar.insert(0, satis);
    notifyListeners();

    // Sonra Supabase'e kaydet
    try {
      final eklenen = await _repository.satisEkle(satis);
      // Supabase dönüşü ile yerel kaydı değiştir
      final index = _bugunSatislar.indexWhere((s) => s.id == satis.id);
      if (index != -1) {
        _bugunSatislar[index] = eklenen;
        notifyListeners();
      }
      return true;
    } catch (e) {
      // Supabase başarısız olsa bile yerel kayıt kalır
      // (örn. urun_id FK constraint — sanal kalem)
      debugPrint('Satış Supabase kaydı başarısız (yerel kayıt korundu): $e');
      return true;
    }
  }

  // ── Fire-and-Forget: Sipariş Toplu Ekle ──

  /// Sipariş dialogundan gelen sepeti arka planda kaydeder.
  /// Dialog zaten kapatılmış olmalı — sonucu toast ile bildirir.
  ///
  /// [sepet] `Map<urunId, adet>` — ürün snapshot'ı.
  /// [urunler] Mevcut ürün listesinin anlık kopyası.
  /// [oturumId] İlişkili oturum ID'si (null olabilir).
  void siparisTopluEkle({
    required Map<String, int> sepet,
    required List<UrunModel> urunler,
    required String? oturumId,
    required UrunProvider urunProvider,
  }) {
    // Async işlemi unawaited başlat — BuildContext bağımlılığı yok
    _siparisTopluEkleAsync(
      sepet: sepet,
      urunler: urunler,
      oturumId: oturumId,
      urunProvider: urunProvider,
    );
  }

  Future<void> _siparisTopluEkleAsync({
    required Map<String, int> sepet,
    required List<UrunModel> urunler,
    required String? oturumId,
    required UrunProvider urunProvider,
  }) async {
    try {
      for (final entry in sepet.entries) {
        final urun = urunler.firstWhere((u) => u.id == entry.key);
        await satisEkle(
          oturumId: oturumId,
          urunId: urun.id,
          urunAd: urun.ad,
          adet: entry.value,
          birimFiyat: urun.fiyat,
        );
        await urunProvider.stokAzalt(urun.id, entry.value);
      }
      _toast('Sipariş kaydedildi!');
    } catch (e) {
      debugPrint('Sipariş toplu ekleme hatası: $e');
      _toast('Sipariş kaydedilirken hata: $e');
    }
  }

  // ── Fire-and-Forget: Direkt Satış Kaydet ──

  /// Direkt satış dialogundan gelen sepeti arka planda kaydeder.
  /// Dialog zaten kapatılmış olmalı — sonucu toast ile bildirir.
  void direktSatisKaydet({
    required Map<String, int> sepet,
    required List<UrunModel> urunler,
    required OdemeYontemi odemeYontemi,
    required double nakitTutar,
    required double kartTutar,
    required UrunProvider urunProvider,
    required RaporProvider raporProvider,
  }) {
    _direktSatisKaydetAsync(
      sepet: sepet,
      urunler: urunler,
      odemeYontemi: odemeYontemi,
      nakitTutar: nakitTutar,
      kartTutar: kartTutar,
      urunProvider: urunProvider,
      raporProvider: raporProvider,
    );
  }

  Future<void> _direktSatisKaydetAsync({
    required Map<String, int> sepet,
    required List<UrunModel> urunler,
    required OdemeYontemi odemeYontemi,
    required double nakitTutar,
    required double kartTutar,
    required UrunProvider urunProvider,
    required RaporProvider raporProvider,
  }) async {
    try {
      double toplam = 0;
      for (final entry in sepet.entries) {
        final urun = urunler.firstWhere((u) => u.id == entry.key);
        toplam += urun.fiyat * entry.value;
      }

      final simdi = DateTime.now();

      // Ödeme tutarlarını belirle
      double hesaplananNakit = nakitTutar;
      double hesaplananKart = kartTutar;
      switch (odemeYontemi) {
        case OdemeYontemi.nakit:
          hesaplananNakit = toplam;
          hesaplananKart = 0;
          break;
        case OdemeYontemi.kart:
          hesaplananNakit = 0;
          hesaplananKart = toplam;
          break;
        case OdemeYontemi.parcali:
          // nakitTutar ve kartTutar zaten geldi
          break;
      }

      // ── Satış kayıtlarını oluştur ──
      for (final entry in sepet.entries) {
        final urun = urunler.firstWhere((u) => u.id == entry.key);
        await satisEkle(
          oturumId: null,
          urunId: urun.id,
          urunAd: urun.ad,
          adet: entry.value,
          birimFiyat: urun.fiyat,
        );
        await urunProvider.stokAzalt(urun.id, entry.value);
      }

      // ── Rapor kaydı oluştur ──
      await raporProvider.raporOlustur(
        oturumId: null,
        masaId: null,
        masaAd: 'Direkt Satış',
        konsolTipi: '-',
        baslangic: simdi,
        bitis: simdi,
        oynananDk: 0,
        kolSayisi: 0,
        konsolUcreti: 0,
        kolEkstraUcreti: 0,
        siparisUcreti: toplam,
        toplamTutar: toplam,
        odemeYontemi: odemeYontemi,
        nakitTutar: hesaplananNakit,
        kartTutar: hesaplananKart,
      );

      _toast('Direkt satış kaydedildi!');
    } catch (e) {
      debugPrint('Direkt satış kaydetme hatası: $e');
      _toast('Satış kaydedilirken hata: $e');
    }
  }

  // ── Eski Konsol Ücreti Aktarma ──

  /// Mevcut konsol ücretini sipariş listesine "Eski Konsol Ücreti" olarak ekle.
  /// Detay bilgisi (kol sayısı, oynanan süre) sipariş adında yer alır.
  Future<bool> eskiKonsolUcretiEkle({
    required String oturumId,
    required double konsolUcreti,
    required double kolEkstraUcreti,
    required String kolMetni,
    required int oynananDk,
    required DateTime baslangic,
  }) async {
    final toplam = konsolUcreti + kolEkstraUcreti;
    if (toplam <= 0) return true; // 0 ₺ ise eklemeye gerek yok

    final saat =
        '${baslangic.hour.toString().padLeft(2, '0')}:${baslangic.minute.toString().padLeft(2, '0')}';
    final detay =
        'Eski Konsol Ücreti ($kolMetni, $oynananDk dk, başlangıç $saat)';
    return satisEkle(
      oturumId: oturumId,
      urunId: null,
      urunAd: detay,
      adet: 1,
      birimFiyat: toplam,
    );
  }

  /// Satış adetini güncelle (artır/azalt).
  Future<bool> satisAdetGuncelle(String id, int yeniAdet) async {
    try {
      final index = _bugunSatislar.indexWhere((s) => s.id == id);
      if (index == -1) return false;
      final satis = _bugunSatislar[index];

      if (yeniAdet <= 0) {
        // Adet 0 veya altındaysa sil
        return await satisSil(id);
      }

      final guncellenen = satis.copyWith(
        adet: yeniAdet,
        toplamTutar: yeniAdet * satis.birimFiyat,
      );
      final sonuc = await _repository.satisGuncelle(guncellenen);
      _bugunSatislar[index] = sonuc;
      notifyListeners();
      return true;
    } catch (e) {
      _hata = 'Satış güncellenirken hata: $e';
      notifyListeners();
      return false;
    }
  }

  /// Satış sil.
  Future<bool> satisSil(String id) async {
    try {
      await _repository.satisSil(id);
      _bugunSatislar.removeWhere((s) => s.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _hata = 'Satış silinirken hata: $e';
      notifyListeners();
      return false;
    }
  }

  /// Tarih aralığı satışlarını getir (raporlama için).
  Future<List<SatisModel>> tarihAraligiSatislari(
    DateTime baslangic,
    DateTime bitis,
  ) async {
    try {
      return await _repository.tarihAraligiSatislari(baslangic, bitis);
    } catch (e) {
      _hata = 'Satışlar getirilirken hata: $e';
      notifyListeners();
      return [];
    }
  }

  /// Tüm siparişleri başka bir oturuma aktar (Masa birleştirme / dolu masaya taşıma)
  Future<bool> satisOturumaAktar(String kaynakOturumId, String hedefOturumId) async {
    try {
      final aktarilacaklar = _bugunSatislar.where((s) => s.oturumId == kaynakOturumId).toList();
      for (final satis in aktarilacaklar) {
        final guncellenen = satis.copyWith(oturumId: hedefOturumId);
        final sonuc = await _repository.satisGuncelle(guncellenen);
        final index = _bugunSatislar.indexWhere((s) => s.id == satis.id);
        if (index != -1) {
          _bugunSatislar[index] = sonuc;
        }
      }
      notifyListeners();
      return true;
    } catch (e) {
      _hata = 'Satışlar aktarılırken hata: $e';
      notifyListeners();
      return false;
    }
  }
}
