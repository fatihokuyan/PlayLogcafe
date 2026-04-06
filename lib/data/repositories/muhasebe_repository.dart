import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/muhasebe_model.dart';

/// Supabase "muhasebe" tablosu CRUD operasyonları.
class MuhasebeRepository {
  final SupabaseClient _client;

  MuhasebeRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  static const String _tablo = 'muhasebe';

  String get _userId => _client.auth.currentUser!.id;

  // ── READ ──

  /// Tüm muhasebe kayıtlarını getir.
  Future<List<MuhasebeModel>> tumKayitlariGetir() async {
    final response = await _client
        .from(_tablo)
        .select()
        .eq('user_id', _userId)
        .order('tarih', ascending: false);
    return response.map((json) => MuhasebeModel.fromJson(json)).toList();
  }

  /// Belirli ay/yılın kayıtlarını getir.
  Future<List<MuhasebeModel>> aylikKayitlar(int yil, int ay) async {
    final baslangic = DateTime(yil, ay, 1);
    final bitis = DateTime(yil, ay + 1, 1);
    final response = await _client
        .from(_tablo)
        .select()
        .eq('user_id', _userId)
        .gte('tarih', baslangic.toIso8601String())
        .lt('tarih', bitis.toIso8601String())
        .order('tarih', ascending: false);
    return response.map((json) => MuhasebeModel.fromJson(json)).toList();
  }

  /// Belirli tarih aralığındaki tüm kayıtları getir (saat dahil).
  Future<List<MuhasebeModel>> tarihAraligiKayitlar(
    DateTime baslangic,
    DateTime bitis,
  ) async {
    final response = await _client
        .from(_tablo)
        .select()
        .eq('user_id', _userId)
        .gte('tarih', baslangic.toIso8601String())
        .lt('tarih', bitis.toIso8601String())
        .order('tarih', ascending: false);
    return response.map((json) => MuhasebeModel.fromJson(json)).toList();
  }

  /// Sadece gelirleri getir (tarih aralığı).
  Future<List<MuhasebeModel>> gelirleriGetir(
    DateTime baslangic,
    DateTime bitis,
  ) async {
    final response = await _client
        .from(_tablo)
        .select()
        .eq('user_id', _userId)
        .eq('tur', 'gelir')
        .gte('tarih', baslangic.toIso8601String())
        .lte('tarih', bitis.toIso8601String())
        .order('tarih', ascending: false);
    return response.map((json) => MuhasebeModel.fromJson(json)).toList();
  }

  /// Sadece giderleri getir (tarih aralığı).
  Future<List<MuhasebeModel>> giderleriGetir(
    DateTime baslangic,
    DateTime bitis,
  ) async {
    final response = await _client
        .from(_tablo)
        .select()
        .eq('user_id', _userId)
        .eq('tur', 'gider')
        .gte('tarih', baslangic.toIso8601String())
        .lte('tarih', bitis.toIso8601String())
        .order('tarih', ascending: false);
    return response.map((json) => MuhasebeModel.fromJson(json)).toList();
  }

  // ── CREATE ──

  /// Yeni muhasebe kaydı ekle.
  Future<MuhasebeModel> kayitEkle(MuhasebeModel kayit) async {
    final json = kayit.toJson()..['user_id'] = _client.auth.currentUser!.id;
    final response = await _client
        .from(_tablo)
        .insert(json)
        .select()
        .single();
    return MuhasebeModel.fromJson(response);
  }

  // ── UPDATE ──

  /// Muhasebe kaydını güncelle.
  Future<MuhasebeModel> kayitGuncelle(MuhasebeModel kayit) async {
    final response = await _client
        .from(_tablo)
        .update(kayit.toJson())
        .eq('id', kayit.id)
        .select()
        .single();
    return MuhasebeModel.fromJson(response);
  }

  // ── DELETE ──

  /// Muhasebe kaydını sil.
  Future<void> kayitSil(String id) async {
    await _client.from(_tablo).delete().eq('id', id);
  }

  // ── AGGREGATE ──

  /// Aylık toplam gelir.
  Future<double> aylikToplamGelir(int yil, int ay) async {
    final kayitlar = await aylikKayitlar(yil, ay);
    return kayitlar
        .where((k) => k.isGelir)
        .fold<double>(0, (toplam, k) => toplam + k.tutar);
  }

  /// Aylık toplam gider.
  Future<double> aylikToplamGider(int yil, int ay) async {
    final kayitlar = await aylikKayitlar(yil, ay);
    return kayitlar
        .where((k) => k.isGider)
        .fold<double>(0, (toplam, k) => toplam + k.tutar);
  }

  /// Aylık net kâr (gelir - gider).
  Future<double> aylikNetKar(int yil, int ay) async {
    final gelir = await aylikToplamGelir(yil, ay);
    final gider = await aylikToplamGider(yil, ay);
    return gelir - gider;
  }

  // ── REALTIME ──

  /// Muhasebe tablosundaki değişiklikleri dinle.
  Stream<List<Map<String, dynamic>>> kayitlariDinle() {
    return _client
        .from(_tablo)
        .stream(primaryKey: ['id'])
        .order('tarih', ascending: false);
  }
}
