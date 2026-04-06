import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/daily_report_model.dart';

/// Supabase "daily_reports" tablosu CRUD operasyonları.
class DailyReportRepository {
  final SupabaseClient _client;

  DailyReportRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  static const String _tablo = 'daily_reports';

  String get _userId => _client.auth.currentUser!.id;

  // ── READ ──

  /// Aylık kayıtları getir (sıralı).
  Future<List<DailyReportModel>> aylikKayitlar(int yil, int ay) async {
    final baslangic = DateTime(yil, ay, 1);
    final bitis = DateTime(yil, ay + 1, 0); // Ayın son günü
    final response = await _client
        .from(_tablo)
        .select()
        .eq('user_id', _userId)
        .gte('tarih', _dateOnly(baslangic))
        .lte('tarih', _dateOnly(bitis))
        .order('tarih', ascending: true);
    return response.map((json) => DailyReportModel.fromJson(json)).toList();
  }

  /// Tek günlük kaydı getir.
  Future<DailyReportModel?> gunlukKayit(DateTime tarih) async {
    final response = await _client
        .from(_tablo)
        .select()
        .eq('user_id', _userId)
        .eq('tarih', _dateOnly(tarih))
        .maybeSingle();
    if (response == null) return null;
    return DailyReportModel.fromJson(response);
  }

  /// Tarih aralığı kayıtları.
  Future<List<DailyReportModel>> tarihAraligiKayitlar(
    DateTime baslangic,
    DateTime bitis,
  ) async {
    final response = await _client
        .from(_tablo)
        .select()
        .eq('user_id', _userId)
        .gte('tarih', _dateOnly(baslangic))
        .lte('tarih', _dateOnly(bitis))
        .order('tarih', ascending: true);
    return response.map((json) => DailyReportModel.fromJson(json)).toList();
  }

  // ── UPSERT ──

  /// Günlük kaydı oluştur veya güncelle (tarih bazlı upsert).
  Future<DailyReportModel?> kayitUpsert(DailyReportModel kayit) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    final json = kayit.toUpsertJson()
      ..['user_id'] = userId;
    final response = await _client
        .from(_tablo)
        .upsert(json, onConflict: 'tarih,user_id')
        .select()
        .single();
    return DailyReportModel.fromJson(response);
  }

  /// Birden fazla günlük kaydı toplu upsert.
  Future<void> topluUpsert(List<DailyReportModel> kayitlar) async {
    if (kayitlar.isEmpty) return;
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    final jsonList = kayitlar
        .map((k) => k.toUpsertJson()..['user_id'] = userId)
        .toList();
    await _client.from(_tablo).upsert(jsonList, onConflict: 'tarih,user_id');
  }

  // ── UPDATE (tek alan) ──

  /// Manuel nakit değeri güncelle (null = override kaldır).
  Future<void> manualCashGuncelle(DateTime tarih, double? deger) async {
    await _client
        .from(_tablo)
        .update({'manual_cash': deger})
        .eq('user_id', _userId)
        .eq('tarih', _dateOnly(tarih));
  }

  /// Manuel POS değeri güncelle.
  Future<void> manualPosGuncelle(DateTime tarih, double? deger) async {
    await _client
        .from(_tablo)
        .update({'manual_pos': deger})
        .eq('user_id', _userId)
        .eq('tarih', _dateOnly(tarih));
  }

  /// Manuel gider değeri güncelle.
  Future<void> manualExpenseGuncelle(DateTime tarih, double? deger) async {
    await _client
        .from(_tablo)
        .update({'manual_expense': deger})
        .eq('user_id', _userId)
        .eq('tarih', _dateOnly(tarih));
  }

  /// Devreden bakiye güncelle.
  Future<void> devredenBakiyeGuncelle(DateTime tarih, double bakiye) async {
    await _client
        .from(_tablo)
        .update({'devreden_bakiye': bakiye})
        .eq('user_id', _userId)
        .eq('tarih', _dateOnly(tarih));
  }

  /// Not güncelle.
  Future<void> notGuncelle(DateTime tarih, String? not_) async {
    await _client
        .from(_tablo)
        .update({'notlar': not_})
        .eq('user_id', _userId)
        .eq('tarih', _dateOnly(tarih));
  }

  // ── DELETE ──

  /// Tek kaydı sil.
  Future<void> kayitSil(String id) async {
    await _client.from(_tablo).delete().eq('id', id);
  }

  // ── YARDIMCILAR ──

  /// Tarih → 'YYYY-MM-DD' string.
  static String _dateOnly(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}
