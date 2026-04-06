/// Muhasebe işlem türü.
enum MuhasebeTur {
  gelir,
  gider;

  static MuhasebeTur fromString(String value) {
    switch (value) {
      case 'gider':
        return MuhasebeTur.gider;
      default:
        return MuhasebeTur.gelir;
    }
  }
}

/// Ödeme yöntemi.
enum OdemeYontemi {
  nakit,
  kart;

  static OdemeYontemi fromString(String value) {
    switch (value) {
      case 'kart':
        return OdemeYontemi.kart;
      default:
        return OdemeYontemi.nakit;
    }
  }

  String get etiket => this == nakit ? 'Nakit' : 'Kart';
}

/// Gelir-gider kaydı modeli.
class MuhasebeModel {
  final String id;
  final MuhasebeTur tur;
  final String aciklama;
  final double tutar;
  final DateTime tarih;
  final OdemeYontemi odemeYontemi;

  const MuhasebeModel({
    required this.id,
    required this.tur,
    required this.aciklama,
    required this.tutar,
    required this.tarih,
    this.odemeYontemi = OdemeYontemi.nakit,
  });

  /// Supabase JSON → MuhasebeModel
  factory MuhasebeModel.fromJson(Map<String, dynamic> json) {
    return MuhasebeModel(
      id: json['id'] as String,
      tur: MuhasebeTur.fromString(json['tur'] as String? ?? 'gelir'),
      aciklama: json['aciklama'] as String? ?? '',
      tutar: (json['tutar'] as num).toDouble(),
      tarih: DateTime.parse(json['tarih'] as String),
      odemeYontemi: OdemeYontemi.fromString(
        json['odeme_yontemi'] as String? ?? 'nakit',
      ),
    );
  }

  /// MuhasebeModel → Supabase JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tur': tur.name,
      'aciklama': aciklama,
      'tutar': tutar,
      'tarih': tarih.toIso8601String(),
      'odeme_yontemi': odemeYontemi.name,
    };
  }

  /// Gelir mi?
  bool get isGelir => tur == MuhasebeTur.gelir;

  /// Gider mi?
  bool get isGider => tur == MuhasebeTur.gider;

  /// Nakit gider mi?
  bool get isNakitGider => isGider && odemeYontemi == OdemeYontemi.nakit;

  /// Kart gider mi?
  bool get isKartGider => isGider && odemeYontemi == OdemeYontemi.kart;

  MuhasebeModel copyWith({
    String? id,
    MuhasebeTur? tur,
    String? aciklama,
    double? tutar,
    DateTime? tarih,
    OdemeYontemi? odemeYontemi,
  }) {
    return MuhasebeModel(
      id: id ?? this.id,
      tur: tur ?? this.tur,
      aciklama: aciklama ?? this.aciklama,
      tutar: tutar ?? this.tutar,
      tarih: tarih ?? this.tarih,
      odemeYontemi: odemeYontemi ?? this.odemeYontemi,
    );
  }

  @override
  String toString() => 'Muhasebe($tur/$odemeYontemi: $aciklama, ₺$tutar)';
}
