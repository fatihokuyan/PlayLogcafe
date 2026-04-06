import 'dart:convert';

/// Kol geçmişi rapor kaydı — her segment kaç kol ile ne zaman başladığını tutar.
class KolGecmisiKayit {
  final int kolSayisi;
  final DateTime baslangic;

  const KolGecmisiKayit({required this.kolSayisi, required this.baslangic});

  factory KolGecmisiKayit.fromJson(Map<String, dynamic> json) {
    return KolGecmisiKayit(
      kolSayisi: json['kol'] as int,
      baslangic: DateTime.parse(json['baslangic'] as String).toLocal(),
    );
  }

  Map<String, dynamic> toJson() => {
    'kol': kolSayisi,
    'baslangic': baslangic.toUtc().toIso8601String(),
  };
}

/// Ödeme yöntemi enum.
enum OdemeYontemi {
  nakit,
  kart,
  parcali; // Parçalı ödeme (nakit + kart)

  String get label => switch (this) {
    OdemeYontemi.nakit => 'Nakit',
    OdemeYontemi.kart => 'Kart',
    OdemeYontemi.parcali => 'Parçalı',
  };

  static OdemeYontemi fromString(String value) {
    switch (value) {
      case 'kart':
        return OdemeYontemi.kart;
      case 'parcali':
        return OdemeYontemi.parcali;
      default:
        return OdemeYontemi.nakit;
    }
  }
}

/// Oturum kapandıktan sonra oluşturulan rapor kaydı.
/// Supabase "raporlar" tablosuna yazılır.
class RaporModel {
  final String id;
  final String? oturumId;
  final String? masaId;
  final String masaAd;
  final String konsolTipi;
  final DateTime baslangic;
  final DateTime bitis;
  final int oynananDk; // Efektif oynanan dakika (dondurma hariç)
  final int kolSayisi;
  final double konsolUcreti; // Zaman ücreti
  final double kolEkstraUcreti;
  final double siparisUcreti; // Kafeterya toplamı
  final double toplamTutar; // konsolUcreti + kolEkstra + siparis
  final OdemeYontemi odemeYontemi;
  final double nakitTutar;
  final double kartTutar;
  final DateTime olusturulmaTarihi;
  final String aciklama;

  /// Kol sayısı değişim geçmişi (JSON olarak saklanır).
  final List<KolGecmisiKayit> kolGecmisi;

  /// Direkt satış mı? (masaId null ise direkt satıştır)
  bool get isDirektSatis => masaId == null;

  const RaporModel({
    required this.id,
    this.oturumId,
    this.masaId,
    required this.masaAd,
    required this.konsolTipi,
    required this.baslangic,
    required this.bitis,
    required this.oynananDk,
    this.kolSayisi = 2,
    required this.konsolUcreti,
    this.kolEkstraUcreti = 0,
    this.siparisUcreti = 0,
    required this.toplamTutar,
    this.odemeYontemi = OdemeYontemi.nakit,
    this.nakitTutar = 0,
    this.kartTutar = 0,
    DateTime? olusturulmaTarihi,
    this.kolGecmisi = const [],
    this.aciklama = '',
  }) : olusturulmaTarihi = olusturulmaTarihi ?? baslangic;

  factory RaporModel.fromJson(Map<String, dynamic> json) {
    return RaporModel(
      id: json['id'] as String,
      oturumId: json['oturum_id'] as String?,
      masaId: json['masa_id'] as String?,
      masaAd: json['masa_ad'] as String? ?? '',
      konsolTipi: json['konsol_tipi'] as String? ?? 'PS5',
      baslangic: DateTime.parse(json['baslangic'] as String).toLocal(),
      bitis: DateTime.parse(json['bitis'] as String).toLocal(),
      oynananDk: (json['oynanan_dk'] as int?) ?? 0,
      kolSayisi: (json['kol_sayisi'] as int?) ?? 2,
      konsolUcreti: (json['konsol_ucreti'] as num?)?.toDouble() ?? 0,
      kolEkstraUcreti: (json['kol_ekstra_ucreti'] as num?)?.toDouble() ?? 0,
      siparisUcreti: (json['siparis_ucreti'] as num?)?.toDouble() ?? 0,
      toplamTutar: (json['toplam_tutar'] as num?)?.toDouble() ?? 0,
      odemeYontemi: OdemeYontemi.fromString(
        json['odeme_yontemi'] as String? ?? 'nakit',
      ),
      nakitTutar: (json['nakit_tutar'] as num?)?.toDouble() ?? 0,
      kartTutar: (json['kart_tutar'] as num?)?.toDouble() ?? 0,
      olusturulmaTarihi: json['olusturulma_tarihi'] != null
          ? DateTime.parse(json['olusturulma_tarihi'] as String).toLocal()
          : null,
      kolGecmisi: _kolGecmisiParse(json['kol_gecmisi']),
      aciklama: json['aciklama'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'oturum_id': oturumId,
      'masa_id': masaId,
      'masa_ad': masaAd,
      'konsol_tipi': konsolTipi,
      'baslangic': baslangic.toUtc().toIso8601String(),
      'bitis': bitis.toUtc().toIso8601String(),
      'oynanan_dk': oynananDk,
      'kol_sayisi': kolSayisi,
      'konsol_ucreti': konsolUcreti,
      'kol_ekstra_ucreti': kolEkstraUcreti,
      'siparis_ucreti': siparisUcreti,
      'toplam_tutar': toplamTutar,
      'odeme_yontemi': odemeYontemi.name,
      'nakit_tutar': nakitTutar,
      'kart_tutar': kartTutar,
      'olusturulma_tarihi': olusturulmaTarihi.toUtc().toIso8601String(),
      'aciklama': aciklama,
      if (kolGecmisi.isNotEmpty)
        'kol_gecmisi': jsonEncode(kolGecmisi.map((k) => k.toJson()).toList()),
    };
  }

  String get odemeMetni {
    switch (odemeYontemi) {
      case OdemeYontemi.nakit:
        return 'Nakit';
      case OdemeYontemi.kart:
        return 'Kart';
      case OdemeYontemi.parcali:
        return 'Parçalı';
    }
  }

  RaporModel copyWith({
    String? id,
    String? oturumId,
    String? masaId,
    String? masaAd,
    String? konsolTipi,
    DateTime? baslangic,
    DateTime? bitis,
    int? oynananDk,
    int? kolSayisi,
    double? konsolUcreti,
    double? kolEkstraUcreti,
    double? siparisUcreti,
    double? toplamTutar,
    OdemeYontemi? odemeYontemi,
    double? nakitTutar,
    double? kartTutar,
    DateTime? olusturulmaTarihi,
    List<KolGecmisiKayit>? kolGecmisi,
    String? aciklama,
  }) {
    return RaporModel(
      id: id ?? this.id,
      oturumId: oturumId ?? this.oturumId,
      masaId: masaId ?? this.masaId,
      masaAd: masaAd ?? this.masaAd,
      konsolTipi: konsolTipi ?? this.konsolTipi,
      baslangic: baslangic ?? this.baslangic,
      bitis: bitis ?? this.bitis,
      oynananDk: oynananDk ?? this.oynananDk,
      kolSayisi: kolSayisi ?? this.kolSayisi,
      konsolUcreti: konsolUcreti ?? this.konsolUcreti,
      kolEkstraUcreti: kolEkstraUcreti ?? this.kolEkstraUcreti,
      siparisUcreti: siparisUcreti ?? this.siparisUcreti,
      toplamTutar: toplamTutar ?? this.toplamTutar,
      odemeYontemi: odemeYontemi ?? this.odemeYontemi,
      nakitTutar: nakitTutar ?? this.nakitTutar,
      kartTutar: kartTutar ?? this.kartTutar,
      olusturulmaTarihi: olusturulmaTarihi ?? this.olusturulmaTarihi,
      kolGecmisi: kolGecmisi ?? this.kolGecmisi,
      aciklama: aciklama ?? this.aciklama,
    );
  }

  @override
  String toString() =>
      'Rapor($masaAd, $odemeMetni, ₺${toplamTutar.toStringAsFixed(2)})';
}

/// kol_gecmisi JSON string → `List<KolGecmisiKayit>` parse helper.
List<KolGecmisiKayit> _kolGecmisiParse(dynamic value) {
  if (value == null) return [];
  try {
    final List<dynamic> liste;
    if (value is String) {
      liste = jsonDecode(value) as List<dynamic>;
    } else if (value is List) {
      liste = value;
    } else {
      return [];
    }
    return liste
        .map((e) => KolGecmisiKayit.fromJson(e as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return [];
  }
}
