import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/muhasebe_model.dart';
import '../../data/repositories/muhasebe_repository.dart';

/// Muhasebe (gelir-gider) state yönetimi.
class MuhasebeProvider extends ChangeNotifier {
  final MuhasebeRepository _repo = MuhasebeRepository();

  List<MuhasebeModel> _kayitlar = [];
  bool _yukleniyor = false;
  int _secilenYil = DateTime.now().year;
  int _secilenAy = DateTime.now().month;

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
    _kayitlar = [];
    _yukleniyor = false;
    _secilenYil = DateTime.now().year;
    _secilenAy = DateTime.now().month;
    notifyListeners();
  }

  // ── Getter'lar ──

  List<MuhasebeModel> get kayitlar => _kayitlar;
  bool get yukleniyor => _yukleniyor;
  int get secilenYil => _secilenYil;
  int get secilenAy => _secilenAy;

  List<MuhasebeModel> get gelirler =>
      _kayitlar.where((k) => k.isGelir).toList();

  List<MuhasebeModel> get giderler =>
      _kayitlar.where((k) => k.isGider).toList();

  double get toplamGelir => gelirler.fold<double>(0, (t, k) => t + k.tutar);

  double get toplamGider => giderler.fold<double>(0, (t, k) => t + k.tutar);

  double get netKar => toplamGelir - toplamGider;

  // ── Ay/Yıl seçici ──

  void ayDegistir(int yil, int ay) {
    _secilenYil = yil;
    _secilenAy = ay;
    aylikKayitlariYukle();
  }

  void oncekiAy() {
    if (_secilenAy == 1) {
      _secilenAy = 12;
      _secilenYil--;
    } else {
      _secilenAy--;
    }
    aylikKayitlariYukle();
  }

  void sonrakiAy() {
    if (_secilenAy == 12) {
      _secilenAy = 1;
      _secilenYil++;
    } else {
      _secilenAy++;
    }
    aylikKayitlariYukle();
  }

  // ── Veri yükleme ──

  Future<void> aylikKayitlariYukle() async {
    _yukleniyor = true;
    notifyListeners();

    try {
      _kayitlar = await _repo.aylikKayitlar(_secilenYil, _secilenAy);
    } catch (e) {
      debugPrint('Muhasebe yükleme hatası: $e');
    }

    _yukleniyor = false;
    notifyListeners();
  }

  // ── CRUD ──

  Future<bool> kayitEkle({
    required MuhasebeTur tur,
    required String aciklama,
    required double tutar,
    DateTime? tarih,
  }) async {
    try {
      final yeniKayit = MuhasebeModel(
        id: const Uuid().v4(),
        tur: tur,
        aciklama: aciklama,
        tutar: tutar,
        tarih: tarih ?? DateTime.now(),
      );
      final kaydedilen = await _repo.kayitEkle(yeniKayit);
      _kayitlar.insert(0, kaydedilen);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Kayıt ekleme hatası: $e');
      return false;
    }
  }

  Future<bool> kayitGuncelle(MuhasebeModel kayit) async {
    try {
      final guncellenen = await _repo.kayitGuncelle(kayit);
      final index = _kayitlar.indexWhere((k) => k.id == kayit.id);
      if (index != -1) {
        _kayitlar[index] = guncellenen;
        notifyListeners();
      }
      return true;
    } catch (e) {
      debugPrint('Kayıt güncelleme hatası: $e');
      return false;
    }
  }

  Future<bool> kayitSil(String id) async {
    try {
      await _repo.kayitSil(id);
      _kayitlar.removeWhere((k) => k.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Kayıt silme hatası: $e');
      return false;
    }
  }
}
