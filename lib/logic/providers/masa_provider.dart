import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/masa_model.dart';
import '../../data/repositories/masa_repository.dart';
import '../../data/repositories/oturum_repository.dart';
import '../../data/repositories/rapor_repository.dart';

/// Masa listesi state yönetimi.
class MasaProvider extends ChangeNotifier {
  final MasaRepository _repository;
  final OturumRepository _oturumRepository;
  final RaporRepository _raporRepository;
  final Uuid _uuid = const Uuid();

  List<MasaModel> _masalar = [];
  bool _yukleniyor = false;
  String? _hata;

  MasaProvider({
    MasaRepository? repository,
    OturumRepository? oturumRepository,
    RaporRepository? raporRepository,
  }) : _repository = repository ?? MasaRepository(),
       _oturumRepository = oturumRepository ?? OturumRepository(),
       _raporRepository = raporRepository ?? RaporRepository();

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
    _masalar = [];
    _yukleniyor = false;
    _hata = null;
    notifyListeners();
  }

  // ── Getter'lar ──
  List<MasaModel> get masalar => _masalar;
  bool get yukleniyor => _yukleniyor;
  String? get hata => _hata;

  int get toplamMasa => _masalar.length;
  int get bosMasaSayisi =>
      _masalar.where((m) => m.durum == MasaDurum.bos).length;
  int get doluMasaSayisi =>
      _masalar.where((m) => m.durum == MasaDurum.dolu).length;

  // ── Veri Yükle ──

  /// Masaları Supabase'den çek.
  Future<void> masalariYukle() async {
    _yukleniyor = true;
    _hata = null;
    notifyListeners();

    try {
      _masalar = await _repository.tumMasalariGetir();
    } catch (e) {
      _hata = 'Masalar yüklenirken hata: $e';
    }

    _yukleniyor = false;
    notifyListeners();
  }

  /// Realtime dinlemeyi başlat.
  void realtimeDinle() {
    _realtimeSub?.cancel();
    _realtimeSub = _repository.masalariDinle().listen((data) {
      _masalar = data.map((json) => MasaModel.fromJson(json)).toList();
      notifyListeners();
    });
  }

  // ── CRUD ──

  /// Yeni masa ekle.
  Future<bool> masaEkle({
    required String ad,
    required String konsolTipi,
  }) async {
    try {
      final yeniMasa = MasaModel(
        id: _uuid.v4(),
        ad: ad,
        konsolTipi: konsolTipi,
        durum: MasaDurum.bos,
        createdAt: DateTime.now(),
      );
      final eklenen = await _repository.masaEkle(yeniMasa);
      _masalar.add(eklenen);
      notifyListeners();
      return true;
    } catch (e) {
      _hata = 'Masa eklenirken hata: $e';
      notifyListeners();
      return false;
    }
  }

  /// Masa durumunu güncelle.
  Future<void> durumGuncelle(String masaId, MasaDurum yeniDurum) async {
    try {
      await _repository.durumGuncelle(masaId, yeniDurum);
      final index = _masalar.indexWhere((m) => m.id == masaId);
      if (index != -1) {
        _masalar[index] = _masalar[index].copyWith(durum: yeniDurum);
        notifyListeners();
      }
    } catch (e) {
      _hata = 'Durum güncellenirken hata: $e';
      notifyListeners();
    }
  }

  /// Masa durumunu SADECE lokal olarak güncelle — DB'ye yazmaz.
  /// Optimistic UI için kullanılır; hemen ardından `durumGuncelle` (DB) çağrılmalıdır.
  void durumGuncelleLokalde(String masaId, MasaDurum yeniDurum) {
    final index = _masalar.indexWhere((m) => m.id == masaId);
    if (index != -1) {
      _masalar[index] = _masalar[index].copyWith(durum: yeniDurum);
      notifyListeners();
    }
  }

  /// Masa sil (cascade: oturumlar → masa; raporlar varsa engelle).
  Future<bool> masaSil(String id) async {
    try {
      // Kayıtlı rapor varsa silmeye izin verme
      final raporVar = await _raporRepository.masaRaporuVarMi(id);
      if (raporVar) {
        _hata = 'Bu masaya ait kayıtlı raporlar olduğu için masa silinemedi.';
        notifyListeners();
        return false;
      }
      // Oturumları sil (oturumlar → masalar FK)
      await _oturumRepository.masaOturumlariniSil(id);
      // Masayı sil
      await _repository.masaSil(id);
      _masalar.removeWhere((m) => m.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _hata = 'Masa silinemedi. Lütfen tekrar deneyin.';
      notifyListeners();
      return false;
    }
  }

  /// Masa bilgilerini güncelle.
  Future<bool> masaBilgiGuncelle(MasaModel masa) async {
    try {
      final guncellenen = await _repository.masaGuncelle(masa);
      final index = _masalar.indexWhere((m) => m.id == masa.id);
      if (index != -1) {
        _masalar[index] = guncellenen;
        notifyListeners();
      }
      return true;
    } catch (e) {
      _hata = 'Masa güncellenirken hata: $e';
      notifyListeners();
      return false;
    }
  }
}
