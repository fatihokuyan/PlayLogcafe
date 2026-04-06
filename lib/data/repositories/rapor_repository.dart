import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/rapor_model.dart';

/// Supabase "raporlar" tablosu CRUD.
class RaporRepository {
  final SupabaseClient _client;

  RaporRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  static const String _tablo = 'raporlar';

  String get _userId => _client.auth.currentUser!.id;

  /// Rapor oluştur (oturum kapanınca çağrılır).
  Future<RaporModel> raporOlustur(RaporModel rapor) async {
    final userId = _client.auth.currentUser!.id;
    try {
      final json = rapor.toJson()..['user_id'] = userId;
      final response = await _client
          .from(_tablo)
          .insert(json)
          .select()
          .single();
      return RaporModel.fromJson(response);
    } catch (e) {
      // Yeni sütunlar yoksa basit versiyon dene
      final json = rapor.toJson();
      json.remove('kol_ekstra_ucreti');
      json.remove('oynanan_dk');
      json.remove('kol_sayisi');
      json.remove('konsol_tipi');
      json.remove('kol_gecmisi');
      json['user_id'] = userId;
      final response = await _client
          .from(_tablo)
          .insert(json)
          .select()
          .single();
      return RaporModel.fromJson(response);
    }
  }

  /// Tarih aralığına göre raporlar.
  Future<List<RaporModel>> tarihAraligiRaporlari(
    DateTime baslangic,
    DateTime bitis,
  ) async {
    final response = await _client
        .from(_tablo)
        .select()
        .eq('user_id', _userId)
        .gte('baslangic', baslangic.toUtc().toIso8601String())
        .lte('baslangic', bitis.toUtc().toIso8601String())
        .order('baslangic', ascending: false);
    return response.map((json) => RaporModel.fromJson(json)).toList();
  }

  /// Belirli masanın raporları.
  Future<List<RaporModel>> masaRaporlari(
    String masaId, {
    DateTime? baslangic,
    DateTime? bitis,
  }) async {
    var query = _client.from(_tablo).select().eq('user_id', _userId).eq('masa_id', masaId);
    if (baslangic != null) {
      query = query.gte(
        'olusturulma_tarihi',
        baslangic.toUtc().toIso8601String(),
      );
    }
    if (bitis != null) {
      query = query.lte('olusturulma_tarihi', bitis.toUtc().toIso8601String());
    }
    final response = await query.order('olusturulma_tarihi', ascending: false);
    return response.map((json) => RaporModel.fromJson(json)).toList();
  }

  /// Ödeme yöntemine göre raporlar.
  Future<List<RaporModel>> odemeYontemiRaporlari(
    OdemeYontemi yontem, {
    DateTime? baslangic,
    DateTime? bitis,
  }) async {
    var query = _client.from(_tablo).select().eq('user_id', _userId).eq('odeme_yontemi', yontem.name);
    if (baslangic != null) {
      query = query.gte(
        'olusturulma_tarihi',
        baslangic.toUtc().toIso8601String(),
      );
    }
    if (bitis != null) {
      query = query.lte('olusturulma_tarihi', bitis.toUtc().toIso8601String());
    }
    final response = await query.order('olusturulma_tarihi', ascending: false);
    return response.map((json) => RaporModel.fromJson(json)).toList();
  }

  /// Bugünün raporları.
  Future<List<RaporModel>> bugunRaporlari() async {
    final bugun = DateTime.now();
    final baslangic = DateTime(bugun.year, bugun.month, bugun.day);
    final bitis = baslangic.add(const Duration(days: 1));
    return tarihAraligiRaporlari(baslangic, bitis);
  }

  /// Tek rapor getir.
  Future<RaporModel?> raporGetir(String id) async {
    final response = await _client
        .from(_tablo)
        .select()
        .eq('id', id)
        .eq('user_id', _userId)
        .maybeSingle();
    if (response == null) return null;
    return RaporModel.fromJson(response);
  }

  // ── Toplu Silme ──

  /// Tarih aralığındaki tüm raporları sil. Silinen adet döner.
  Future<int> tarihAraligiTopluSil(DateTime bas, DateTime son) async {
    final response = await _client
        .from(_tablo)
        .select('id')
        .eq('user_id', _userId)
        .gte('olusturulma_tarihi', bas.toUtc().toIso8601String())
        .lte('olusturulma_tarihi', son.toUtc().toIso8601String());
    if (response.isEmpty) return 0;
    final ids = response.map<String>((r) => r['id'] as String).toList();
    await _client.from(_tablo).delete().inFilter('id', ids);
    return ids.length;
  }

  /// Tarih aralığı + saat dilimindeki raporları sil. Silinen adet döner.
  Future<int> saatAraligiTopluSil({
    required DateTime tarihBas,
    required DateTime tarihSon,
    required int saatBasDak,
    required int saatSonDak,
  }) async {
    final response = await _client
        .from(_tablo)
        .select()
        .eq('user_id', _userId)
        .gte('olusturulma_tarihi', tarihBas.toUtc().toIso8601String())
        .lte('olusturulma_tarihi', tarihSon.toUtc().toIso8601String());
    final ids = response
        .where((r) {
          final tarih = DateTime.parse(
            r['olusturulma_tarihi'] as String,
          ).toLocal();
          final dk = tarih.hour * 60 + tarih.minute;
          return dk >= saatBasDak && dk <= saatSonDak;
        })
        .map<String>((r) => r['id'] as String)
        .toList();
    if (ids.isEmpty) return 0;
    await _client.from(_tablo).delete().inFilter('id', ids);
    return ids.length;
  }

  /// Tüm raporları sil. Silinen adet döner.
  Future<int> tumunuSil() async {
    final response = await _client.from(_tablo).select('id').eq('user_id', _userId);
    if (response.isEmpty) return 0;
    final ids = response.map<String>((r) => r['id'] as String).toList();
    await _client.from(_tablo).delete().inFilter('id', ids);
    return ids.length;
  }

  /// Bir masanın kaydedilmiş raporu var mı kontrol et.
  Future<bool> masaRaporuVarMi(String masaId) async {
    final response = await _client
        .from(_tablo)
        .select('id')
        .eq('user_id', _userId)
        .eq('masa_id', masaId)
        .limit(1);
    return response.isNotEmpty;
  }

  /// Bir masaya ait tüm raporları sil (masa silinmeden önce çağrılır).
  Future<void> masaRaporlariniSil(String masaId) async {
    await _client.from(_tablo).delete().eq('user_id', _userId).eq('masa_id', masaId);
  }

  /// Bir masanın tüm raporlarını toplu sil, silinen adet döner.
  Future<int> masaKayitlariniTopluSil(String masaId) async {
    final response = await _client
        .from(_tablo)
        .select('id')
        .eq('user_id', _userId)
        .eq('masa_id', masaId);
    if (response.isEmpty) return 0;
    await _client.from(_tablo).delete().eq('masa_id', masaId);
    return response.length;
  }

  /// Rapor sil.
  Future<void> raporSil(String id) async {
    await _client.from(_tablo).delete().eq('id', id);
  }

  /// Rapor güncelle.
  Future<RaporModel> raporGuncelle(RaporModel rapor) async {
    final response = await _client
        .from(_tablo)
        .update(rapor.toJson())
        .eq('id', rapor.id)
        .select()
        .single();
    return RaporModel.fromJson(response);
  }
}
