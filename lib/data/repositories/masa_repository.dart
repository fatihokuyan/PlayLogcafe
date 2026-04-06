import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/masa_model.dart';

/// Supabase "masalar" tablosu CRUD operasyonları.
class MasaRepository {
  final SupabaseClient _client;

  MasaRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  static const String _tablo = 'masalar';

  String get _userId => _client.auth.currentUser!.id;

  // ── READ ──

  /// Tüm masaları getir.
  Future<List<MasaModel>> tumMasalariGetir() async {
    final response = await _client
        .from(_tablo)
        .select()
        .eq('user_id', _userId)
        .order('created_at', ascending: true);
    return response.map((json) => MasaModel.fromJson(json)).toList();
  }

  /// Tek masa getir (id ile).
  Future<MasaModel?> masaGetir(String id) async {
    final response = await _client
        .from(_tablo)
        .select()
        .eq('id', id)
        .eq('user_id', _userId)
        .maybeSingle();
    if (response == null) return null;
    return MasaModel.fromJson(response);
  }

  // ── CREATE ──

  /// Yeni masa ekle.
  Future<MasaModel> masaEkle(MasaModel masa) async {
    final json = masa.toInsertJson()
      ..['user_id'] = _client.auth.currentUser!.id;
    final response = await _client
        .from(_tablo)
        .insert(json)
        .select()
        .single();
    return MasaModel.fromJson(response);
  }

  // ── UPDATE ──

  /// Masa bilgilerini güncelle.
  Future<MasaModel> masaGuncelle(MasaModel masa) async {
    final response = await _client
        .from(_tablo)
        .update(masa.toJson())
        .eq('id', masa.id)
        .select()
        .single();
    return MasaModel.fromJson(response);
  }

  /// Masa durumunu güncelle (boş/dolu/rezerve).
  Future<void> durumGuncelle(String masaId, MasaDurum durum) async {
    await _client.from(_tablo).update({'durum': durum.name}).eq('id', masaId);
  }

  // ── DELETE ──

  /// Masa sil.
  Future<void> masaSil(String id) async {
    await _client.from(_tablo).delete().eq('id', id);
  }

  // ── REALTIME ──

  /// Masalar tablosundaki değişiklikleri dinle.
  Stream<List<Map<String, dynamic>>> masalariDinle() {
    return _client
        .from(_tablo)
        .stream(primaryKey: ['id'])
        .eq('user_id', _userId)
        .order('created_at', ascending: true);
  }
}
