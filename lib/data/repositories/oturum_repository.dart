import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/oturum_model.dart';

/// Supabase "oturumlar" tablosu CRUD operasyonları.
class OturumRepository {
  final SupabaseClient _client;

  OturumRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  static const String _tablo = 'oturumlar';

  String get _userId => _client.auth.currentUser!.id;

  // ── READ ──

  /// Tüm aktif ve dondurulmuş oturumları getir.
  Future<List<OturumModel>> aktifOturumlariGetir() async {
    final response = await _client
        .from(_tablo)
        .select()
        .eq('user_id', _userId)
        .inFilter('durum', ['aktif', 'dondurulmus'])
        .order('baslangic', ascending: false);
    return response.map((json) => OturumModel.fromJson(json)).toList();
  }

  /// Belirli bir masanın aktif oturumunu getir.
  Future<OturumModel?> masaninAktifOturumu(String masaId) async {
    final response = await _client
        .from(_tablo)
        .select()
        .eq('masa_id', masaId)
        .eq('user_id', _userId)
        .eq('durum', 'aktif')
        .maybeSingle();
    if (response == null) return null;
    return OturumModel.fromJson(response);
  }

  /// Belirli tarih aralığındaki oturumları getir.
  Future<List<OturumModel>> tarihAraligiOturumlari(
    DateTime baslangic,
    DateTime bitis,
  ) async {
    final response = await _client
        .from(_tablo)
        .select()
        .eq('user_id', _userId)
        .gte('baslangic', baslangic.toIso8601String())
        .lte('baslangic', bitis.toIso8601String())
        .order('baslangic', ascending: false);
    return response.map((json) => OturumModel.fromJson(json)).toList();
  }

  // ── CREATE ──

  /// Yeni oturum başlat.
  Future<OturumModel> oturumBaslat(OturumModel oturum) async {
    final userId = _client.auth.currentUser!.id;
    try {
      final json = oturum.toInsertJson()..['user_id'] = userId;
      final response = await _client
          .from(_tablo)
          .insert(json)
          .select()
          .single();
      return OturumModel.fromJson(response);
    } catch (_) {
      // kol_sayisi kolonu henüz yoksa, o alan olmadan dene
      final json = oturum.toInsertJson()
        ..remove('kol_sayisi')
        ..['user_id'] = userId;
      final response = await _client
          .from(_tablo)
          .insert(json)
          .select()
          .single();
      return OturumModel.fromJson(response);
    }
  }

  // ── UPDATE ──

  /// Oturumu güncelle (süre, tutar, durum vb.).
  Future<OturumModel> oturumGuncelle(OturumModel oturum) async {
    final response = await _client
        .from(_tablo)
        .update(oturum.toJson())
        .eq('id', oturum.id)
        .select()
        .single();
    return OturumModel.fromJson(response);
  }

  /// Oturumu sonlandır.
  Future<OturumModel> oturumSonlandir(String oturumId, double tutar) async {
    final response = await _client
        .from(_tablo)
        .update({
          'bitis': DateTime.now().toUtc().toIso8601String(),
          'tutar': tutar,
          'durum': OturumDurum.tamamlandi.name,
        })
        .eq('id', oturumId)
        .select()
        .single();
    return OturumModel.fromJson(response);
  }

  /// Oturumu iptal et.
  Future<void> oturumIptalEt(String oturumId) async {
    await _client
        .from(_tablo)
        .update({
          'bitis': DateTime.now().toUtc().toIso8601String(),
          'durum': OturumDurum.iptal.name,
        })
        .eq('id', oturumId);
  }

  // ── DELETE ──

  /// Oturum sil (gerekirse).
  Future<void> oturumSil(String id) async {
    await _client.from(_tablo).delete().eq('id', id);
  }

  /// Belirli bir masaya ait tüm oturumları sil (masa silinmeden önce cascade).
  Future<void> masaOturumlariniSil(String masaId) async {
    await _client.from(_tablo).delete().eq('masa_id', masaId);
  }

  // ── REALTIME ──

  /// Oturumlar tablosundaki değişiklikleri dinle.
  Stream<List<Map<String, dynamic>>> oturumlariDinle() {
    return _client
        .from(_tablo)
        .stream(primaryKey: ['id'])
        .eq('user_id', _userId)
        .order('baslangic', ascending: false);
  }
}
