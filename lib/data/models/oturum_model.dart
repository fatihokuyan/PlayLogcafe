/// Oturum modunu temsil eden enum.
enum OturumMod {
  sureli,
  suresiz;

  static OturumMod fromString(String value) {
    switch (value) {
      case 'suresiz':
        return OturumMod.suresiz;
      default:
        return OturumMod.sureli;
    }
  }
}

/// Oturum durumunu temsil eden enum.
enum OturumDurum {
  aktif,
  dondurulmus,
  tamamlandi,
  iptal;

  static OturumDurum fromString(String value) {
    switch (value) {
      case 'tamamlandi':
        return OturumDurum.tamamlandi;
      case 'iptal':
        return OturumDurum.iptal;
      case 'dondurulmus':
        return OturumDurum.dondurulmus;
      default:
        return OturumDurum.aktif;
    }
  }
}

/// Kol sayısı değişim segmenti.
/// Her segment, belirli bir zamandan itibaren geçerli olan kol sayısını tutar.
class KolSegment {
  final int kolSayisi;
  final DateTime baslangic;

  const KolSegment({required this.kolSayisi, required this.baslangic});

  factory KolSegment.fromJson(Map<String, dynamic> json) {
    return KolSegment(
      kolSayisi: json['kol'] as int,
      baslangic: DateTime.parse(json['baslangic'] as String).toLocal(),
    );
  }

  Map<String, dynamic> toJson() => {
    'kol': kolSayisi,
    'baslangic': baslangic.toUtc().toIso8601String(),
  };
}

/// Bir masadaki oyun oturumunu temsil eden model.
class OturumModel {
  final String id;
  final String masaId;
  final DateTime baslangic;
  final DateTime? bitis;
  final OturumMod mod;
  final int? sureDk;
  final double tutar;
  final OturumDurum durum;
  final int kolSayisi;

  /// Kol sayısı değişim geçmişi (dinamik ücretlendirme için)
  final List<KolSegment> kolGecmisi;

  /// Dondurma başlangıç anı (null ise şu an dondurulmuş değil)
  final DateTime? dondurmaAni;

  /// Toplam dondurulma süresi (saniye cinsinden)
  final int toplamDondurulmaSuresiSn;

  /// Bütçe (₺ ile başlatma). null → normal oturum, değer → bütçeli oturum.
  final double? butce;

  const OturumModel({
    required this.id,
    required this.masaId,
    required this.baslangic,
    this.bitis,
    required this.mod,
    this.sureDk,
    this.tutar = 0,
    this.durum = OturumDurum.aktif,
    this.kolSayisi = 2,
    this.kolGecmisi = const [],
    this.dondurmaAni,
    this.toplamDondurulmaSuresiSn = 0,
    this.butce,
  });

  /// Supabase JSON → OturumModel
  factory OturumModel.fromJson(Map<String, dynamic> json) {
    return OturumModel(
      id: json['id'] as String,
      masaId: json['masa_id'] as String,
      baslangic: DateTime.parse(json['baslangic'] as String).toLocal(),
      bitis: json['bitis'] != null
          ? DateTime.parse(json['bitis'] as String).toLocal()
          : null,
      mod: OturumMod.fromString(json['mod'] as String? ?? 'sureli'),
      sureDk: json['sure_dk'] as int?,
      tutar: (json['tutar'] as num?)?.toDouble() ?? 0,
      durum: OturumDurum.fromString(json['durum'] as String? ?? 'aktif'),
      kolSayisi: (json['kol_sayisi'] as int?) ?? 1,
      kolGecmisi: _kolGecmisiParse(json['kol_gecmisi']),
      dondurmaAni: json['dondurma_ani'] != null
          ? DateTime.parse(json['dondurma_ani'] as String).toLocal()
          : null,
      toplamDondurulmaSuresiSn:
          (json['toplam_dondurulma_suresi_sn'] as int?) ?? 0,
      butce: (json['butce'] as num?)?.toDouble(),
    );
  }

  /// OturumModel → Supabase JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'masa_id': masaId,
      'baslangic': baslangic.toUtc().toIso8601String(),
      'bitis': bitis?.toUtc().toIso8601String(),
      'mod': mod.name,
      'sure_dk': sureDk,
      'tutar': tutar,
      'durum': durum.name,
      'kol_sayisi': kolSayisi,
      'kol_gecmisi': kolGecmisi.map((s) => s.toJson()).toList(),
      'dondurma_ani': dondurmaAni?.toUtc().toIso8601String(),
      'toplam_dondurulma_suresi_sn': toplamDondurulmaSuresiSn,
      'butce': butce,
    };
  }

  /// Oturum başlatma için insert JSON
  Map<String, dynamic> toInsertJson() {
    return {
      'id': id,
      'masa_id': masaId,
      'baslangic': baslangic.toUtc().toIso8601String(),
      'mod': mod.name,
      'sure_dk': sureDk,
      'tutar': tutar,
      'durum': durum.name,
      'kol_sayisi': kolSayisi,
      'kol_gecmisi': kolGecmisi.map((s) => s.toJson()).toList(),
      'butce': butce,
    };
  }

  /// JSON parse helper
  static List<KolSegment> _kolGecmisiParse(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) {
      return raw
          .map((e) => KolSegment.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// Oturum aktif mi?
  bool get isAktif => durum == OturumDurum.aktif;
  bool get isDondurulmus => durum == OturumDurum.dondurulmus;

  /// Gerçek oynanan süre (dondurma süresi çıkarılmış)
  Duration get gecenSure {
    final son = bitis ?? DateTime.now();
    final toplam = son.difference(baslangic);
    var donSn = toplamDondurulmaSuresiSn;
    // Eğer şu an dondurulmuşsa, devam eden dondurma süresini de ekle
    if (isDondurulmus && dondurmaAni != null) {
      donSn += DateTime.now().difference(dondurmaAni!).inSeconds;
    }
    final oynanan = toplam - Duration(seconds: donSn);
    return oynanan.isNegative ? Duration.zero : oynanan;
  }

  OturumModel copyWith({
    String? id,
    String? masaId,
    DateTime? baslangic,
    DateTime? bitis,
    OturumMod? mod,
    int? sureDk,
    bool sureDkNull = false,
    double? tutar,
    OturumDurum? durum,
    int? kolSayisi,
    List<KolSegment>? kolGecmisi,
    DateTime? dondurmaAni,
    bool dondurmaAniNull = false,
    int? toplamDondurulmaSuresiSn,
    double? butce,
    bool butceNull = false,
  }) {
    return OturumModel(
      id: id ?? this.id,
      masaId: masaId ?? this.masaId,
      baslangic: baslangic ?? this.baslangic,
      bitis: bitis ?? this.bitis,
      mod: mod ?? this.mod,
      sureDk: sureDkNull ? null : (sureDk ?? this.sureDk),
      tutar: tutar ?? this.tutar,
      durum: durum ?? this.durum,
      kolSayisi: kolSayisi ?? this.kolSayisi,
      kolGecmisi: kolGecmisi ?? this.kolGecmisi,
      dondurmaAni: dondurmaAniNull ? null : (dondurmaAni ?? this.dondurmaAni),
      toplamDondurulmaSuresiSn:
          toplamDondurulmaSuresiSn ?? this.toplamDondurulmaSuresiSn,
      butce: butceNull ? null : (butce ?? this.butce),
    );
  }

  @override
  String toString() => 'Oturum(masa: $masaId, mod: $mod, durum: $durum)';
}
