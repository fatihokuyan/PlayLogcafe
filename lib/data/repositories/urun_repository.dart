import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/urun_model.dart';

/// Supabase "urunler" tablosu CRUD operasyonları.
class UrunRepository {
  final SupabaseClient _client;

  UrunRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  static const String _tablo = 'urunler';

  String get _userId => _client.auth.currentUser!.id;

  // ── READ ──

  /// Tüm ürünleri getir.
  Future<List<UrunModel>> tumUrunleriGetir() async {
    final response = await _client
        .from(_tablo)
        .select()
        .eq('user_id', _userId)
        .order('ad', ascending: true);
    return response.map((json) => UrunModel.fromJson(json)).toList();
  }

  /// Kategoriye göre ürünleri getir.
  Future<List<UrunModel>> kategoriyeGoreGetir(String kategori) async {
    final response = await _client
        .from(_tablo)
        .select()
        .eq('user_id', _userId)
        .eq('kategori', kategori)
        .order('ad', ascending: true);
    return response.map((json) => UrunModel.fromJson(json)).toList();
  }

  /// Tek ürün getir (id ile).
  Future<UrunModel?> urunGetir(String id) async {
    final response = await _client
        .from(_tablo)
        .select()
        .eq('id', id)
        .eq('user_id', _userId)
        .maybeSingle();
    if (response == null) return null;
    return UrunModel.fromJson(response);
  }

  /// Stoku kritik seviyede olan ürünler.
  Future<List<UrunModel>> kritikStokUrunleri(int esik) async {
    final response = await _client
        .from(_tablo)
        .select()
        .eq('user_id', _userId)
        .lte('stok_miktari', esik)
        .order('stok_miktari', ascending: true);
    return response.map((json) => UrunModel.fromJson(json)).toList();
  }

  // ── CREATE ──

  /// Yeni ürün ekle.
  Future<UrunModel> urunEkle(UrunModel urun) async {
    final json = urun.toJson()..['user_id'] = _client.auth.currentUser!.id;
    final response = await _client
        .from(_tablo)
        .insert(json)
        .select()
        .single();
    return UrunModel.fromJson(response);
  }

  // ── UPDATE ──

  /// Ürün bilgilerini güncelle.
  Future<UrunModel> urunGuncelle(UrunModel urun) async {
    final response = await _client
        .from(_tablo)
        .update(urun.toJson())
        .eq('id', urun.id)
        .select()
        .single();
    return UrunModel.fromJson(response);
  }

  /// Stok miktarını azalt (satış sonrası).
  Future<void> stokAzalt(String urunId, int miktar) async {
    // Mevcut stoku al, sonra güncelle
    final urun = await urunGetir(urunId);
    if (urun == null) return;
    final yeniStok = (urun.stokMiktari - miktar).clamp(0, 999999);
    await _client
        .from(_tablo)
        .update({'stok_miktari': yeniStok})
        .eq('id', urunId);
  }

  /// Stok miktarını artır (stok girişi).
  Future<void> stokArtir(String urunId, int miktar) async {
    final urun = await urunGetir(urunId);
    if (urun == null) return;
    final yeniStok = urun.stokMiktari + miktar;
    await _client
        .from(_tablo)
        .update({'stok_miktari': yeniStok})
        .eq('id', urunId);
  }

  // ── DELETE ──

  /// Ürün sil.
  Future<void> urunSil(String id) async {
    await _client.from(_tablo).delete().eq('id', id);
  }

  // ── REALTIME ──

  /// Ürünler tablosundaki değişiklikleri dinle.
  Stream<List<Map<String, dynamic>>> urunleriDinle() {
    return _client
        .from(_tablo)
        .stream(primaryKey: ['id'])
        .eq('user_id', _userId)
        .order('ad', ascending: true);
  }
}
