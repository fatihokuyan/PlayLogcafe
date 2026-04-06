import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/satis_model.dart';

/// Supabase "satislar" tablosu CRUD operasyonları.
class SatisRepository {
  final SupabaseClient _client;

  SatisRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  static const String _tablo = 'satislar';

  String get _userId => _client.auth.currentUser!.id;

  // ── READ ──

  /// Belirli bir oturumun satışlarını getir.
  Future<List<SatisModel>> oturumSatislari(String oturumId) async {
    final response = await _client
        .from(_tablo)
        .select()
        .eq('user_id', _userId)
        .eq('oturum_id', oturumId)
        .order('tarih', ascending: false);
    return response.map((json) => SatisModel.fromJson(json)).toList();
  }

  /// Tarih aralığındaki tüm satışları getir.
  Future<List<SatisModel>> tarihAraligiSatislari(
    DateTime baslangic,
    DateTime bitis,
  ) async {
    final response = await _client
        .from(_tablo)
        .select()
        .eq('user_id', _userId)
        .gte('tarih', baslangic.toIso8601String())
        .lte('tarih', bitis.toIso8601String())
        .order('tarih', ascending: false);
    return response.map((json) => SatisModel.fromJson(json)).toList();
  }

  /// Bugünün satışlarını getir.
  Future<List<SatisModel>> bugunSatislari() async {
    final bugun = DateTime.now();
    final baslangic = DateTime(bugun.year, bugun.month, bugun.day);
    final bitis = baslangic.add(const Duration(days: 1));
    return tarihAraligiSatislari(baslangic, bitis);
  }

  // ── CREATE ──

  /// Yeni satış kaydet.
  Future<SatisModel> satisEkle(SatisModel satis) async {
    final userId = _client.auth.currentUser!.id;
    try {
      final json = satis.toJson()..['user_id'] = userId;
      final response = await _client
          .from(_tablo)
          .insert(json)
          .select()
          .single();
      return SatisModel.fromJson(response);
    } catch (_) {
      // urun_id FK veya NOT NULL constraint hatası olabilir — urun_id olmadan dene
      try {
        final json = satis.toJson()
          ..remove('urun_id')
          ..['user_id'] = userId;
        final response = await _client
            .from(_tablo)
            .insert(json)
            .select()
            .single();
        return SatisModel.fromJson(response);
      } catch (_) {
        rethrow;
      }
    }
  }

  // ── UPDATE ──

  /// Satış güncelle.
  Future<SatisModel> satisGuncelle(SatisModel satis) async {
    final response = await _client
        .from(_tablo)
        .update(satis.toJson())
        .eq('id', satis.id)
        .select()
        .single();
    return SatisModel.fromJson(response);
  }

  // ── DELETE ──

  /// Satış sil.
  Future<void> satisSil(String id) async {
    await _client.from(_tablo).delete().eq('id', id);
  }

  // ── REALTIME ──

  /// Satışlar tablosundaki değişiklikleri dinle.
  Stream<List<Map<String, dynamic>>> satislariDinle() {
    return _client
        .from(_tablo)
        .stream(primaryKey: ['id'])
        .eq('user_id', _userId)
        .order('tarih', ascending: false);
  }
}
