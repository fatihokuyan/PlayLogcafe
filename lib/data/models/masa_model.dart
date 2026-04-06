/// Masa/konsol durumunu temsil eden enum.
enum MasaDurum {
  bos,
  dolu,
  rezerve,
  dondurulmus;

  /// Supabase'den gelen string → enum
  static MasaDurum fromString(String value) {
    switch (value) {
      case 'dolu':
        return MasaDurum.dolu;
      case 'rezerve':
        return MasaDurum.rezerve;
      case 'dondurulmus':
        return MasaDurum.dondurulmus;
      default:
        return MasaDurum.bos;
    }
  }
}

/// PlayStation masası / konsol modeli.
class MasaModel {
  final String id;
  final String ad;
  final String konsolTipi; // 'PS4' veya 'PS5'
  final MasaDurum durum;
  final DateTime createdAt;

  const MasaModel({
    required this.id,
    required this.ad,
    required this.konsolTipi,
    this.durum = MasaDurum.bos,
    required this.createdAt,
  });

  /// Supabase JSON → MasaModel
  factory MasaModel.fromJson(Map<String, dynamic> json) {
    return MasaModel(
      id: json['id'] as String,
      ad: json['ad'] as String,
      konsolTipi: json['konsol_tipi'] as String,
      durum: MasaDurum.fromString(json['durum'] as String? ?? 'bos'),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// MasaModel → Supabase JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ad': ad,
      'konsol_tipi': konsolTipi,
      'durum': durum.name,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Insert için (id ve created_at Supabase tarafından atanır)
  Map<String, dynamic> toInsertJson() {
    return {'id': id, 'ad': ad, 'konsol_tipi': konsolTipi, 'durum': durum.name};
  }

  MasaModel copyWith({
    String? id,
    String? ad,
    String? konsolTipi,
    MasaDurum? durum,
    DateTime? createdAt,
  }) {
    return MasaModel(
      id: id ?? this.id,
      ad: ad ?? this.ad,
      konsolTipi: konsolTipi ?? this.konsolTipi,
      durum: durum ?? this.durum,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() => 'Masa($ad, $konsolTipi, $durum)';
}
