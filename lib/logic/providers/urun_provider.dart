import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/urun_model.dart';
import '../../data/repositories/urun_repository.dart';

/// Ürün/stok state yönetimi.
class UrunProvider extends ChangeNotifier {
  final UrunRepository _repository;
  final Uuid _uuid = const Uuid();

  List<UrunModel> _urunler = [];
  bool _yukleniyor = false;
  String? _hata;

  UrunProvider({UrunRepository? repository})
    : _repository = repository ?? UrunRepository();

  bool _disposed = false;
  StreamSubscription? _realtimeSub;

  @override
  void dispose() {
    _disposed = true;
    _realtimeSub?.cancel();
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  /// Tüm lokal state'i sıfırla (hesap değişiminde çağrılır).
  void temizle() {
    _realtimeSub?.cancel();
    _realtimeSub = null;
    _urunler = [];
    _yukleniyor = false;
    _hata = null;
    notifyListeners();
  }

  // ── Getter'lar ──
  List<UrunModel> get urunler => _urunler;
  bool get yukleniyor => _yukleniyor;
  String? get hata => _hata;

  /// Kategoriye göre filtrelenmiş ürünler.
  List<UrunModel> kategoriyeGore(String kategori) =>
      _urunler.where((u) => u.kategori == kategori).toList();

  /// Stoku kritik seviyede olan ürünler.
  /// [esik] değeri AyarlarProvider'dan alınmalıdır (varsayılan: 5).
  List<UrunModel> kritikStokUrunleriHesapla([int esik = 5]) =>
      _urunler.where((u) => u.stokKritikMi(esik)).toList();

  /// Geriye uyumluluk — varsayılan eşikle kritik ürünler.
  List<UrunModel> get kritikStokUrunleri => kritikStokUrunleriHesapla();

  /// Stoku biten ürünler.
  List<UrunModel> get stokuBitenUrunler =>
      _urunler.where((u) => u.stokBittiMi).toList();

  // ── Veri Yükle ──

  /// Tüm ürünleri Supabase'den çek.
  Future<void> urunleriYukle() async {
    _yukleniyor = true;
    _hata = null;
    notifyListeners();

    try {
      _urunler = await _repository.tumUrunleriGetir();
    } catch (e) {
      _hata = 'Ürünler yüklenirken hata: $e';
    }

    _yukleniyor = false;
    notifyListeners();
  }

  /// Realtime dinlemeyi başlat.
  void realtimeDinle() {
    _realtimeSub?.cancel();
    _realtimeSub = _repository.urunleriDinle().listen((data) {
      _urunler = data.map((json) => UrunModel.fromJson(json)).toList();
      notifyListeners();
    });
  }

  // ── CRUD ──

  /// Yeni ürün ekle.
  Future<bool> urunEkle({
    required String ad,
    required String kategori,
    required double fiyat,
    int stokMiktari = 0,
  }) async {
    try {
      final yeniUrun = UrunModel(
        id: _uuid.v4(),
        ad: ad,
        kategori: kategori,
        fiyat: fiyat,
        stokMiktari: stokMiktari,
      );
      final eklenen = await _repository.urunEkle(yeniUrun);
      _urunler.add(eklenen);
      notifyListeners();
      return true;
    } catch (e) {
      _hata = 'Ürün eklenirken hata: $e';
      notifyListeners();
      return false;
    }
  }

  /// Ürün güncelle.
  Future<bool> urunGuncelle(UrunModel urun) async {
    try {
      final guncellenen = await _repository.urunGuncelle(urun);
      final index = _urunler.indexWhere((u) => u.id == urun.id);
      if (index != -1) {
        _urunler[index] = guncellenen;
        notifyListeners();
      }
      return true;
    } catch (e) {
      _hata = 'Ürün güncellenirken hata: $e';
      notifyListeners();
      return false;
    }
  }

  /// Ürün sil.
  Future<bool> urunSil(String id) async {
    try {
      await _repository.urunSil(id);
      _urunler.removeWhere((u) => u.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _hata = 'Ürün silinirken hata: $e';
      notifyListeners();
      return false;
    }
  }

  /// Stok azalt (satış sonrası).
  Future<void> stokAzalt(String urunId, int miktar) async {
    try {
      await _repository.stokAzalt(urunId, miktar);
      final index = _urunler.indexWhere((u) => u.id == urunId);
      if (index != -1) {
        final mevcutStok = _urunler[index].stokMiktari;
        _urunler[index] = _urunler[index].copyWith(
          stokMiktari: (mevcutStok - miktar).clamp(0, 999999),
        );
        notifyListeners();
      }
    } catch (e) {
      _hata = 'Stok azaltılırken hata: $e';
      notifyListeners();
    }
  }

  /// Stok artır (stok girişi).
  Future<void> stokArtir(String urunId, int miktar) async {
    try {
      await _repository.stokArtir(urunId, miktar);
      final index = _urunler.indexWhere((u) => u.id == urunId);
      if (index != -1) {
        _urunler[index] = _urunler[index].copyWith(
          stokMiktari: _urunler[index].stokMiktari + miktar,
        );
        notifyListeners();
      }
    } catch (e) {
      _hata = 'Stok artırılırken hata: $e';
      notifyListeners();
    }
  }
}
