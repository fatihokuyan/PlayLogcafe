/// Bir oturum sırasında yapılan kafeterya satışı modeli.
class SatisModel {
  final String id;
  final String? oturumId; // Hangi oturuma bağlı (nullable — oturum dışı satış)
  final String? urunId; // Hangi ürünle ilgili (nullable — sanal kalem)
  final String urunAd; // Denormalize: raporlama kolaylığı için
  final int adet;
  final double birimFiyat;
  final double toplamTutar;
  final DateTime tarih;

  const SatisModel({
    required this.id,
    this.oturumId,
    required this.urunId,
    required this.urunAd,
    required this.adet,
    required this.birimFiyat,
    required this.toplamTutar,
    required this.tarih,
  });

  /// Supabase JSON → SatisModel
  factory SatisModel.fromJson(Map<String, dynamic> json) {
    return SatisModel(
      id: json['id'] as String,
      oturumId: json['oturum_id'] as String?,
      urunId: json['urun_id'] as String?,
      urunAd: json['urun_ad'] as String? ?? '',
      adet: json['adet'] as int,
      birimFiyat: (json['birim_fiyat'] as num).toDouble(),
      toplamTutar: (json['toplam_tutar'] as num).toDouble(),
      tarih: DateTime.parse(json['tarih'] as String),
    );
  }

  /// SatisModel → Supabase JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'oturum_id': oturumId,
      if (urunId != null) 'urun_id': urunId,
      'urun_ad': urunAd,
      'adet': adet,
      'birim_fiyat': birimFiyat,
      'toplam_tutar': toplamTutar,
      'tarih': tarih.toIso8601String(),
    };
  }

  SatisModel copyWith({
    String? id,
    String? oturumId,
    String? urunId,
    String? urunAd,
    int? adet,
    double? birimFiyat,
    double? toplamTutar,
    DateTime? tarih,
  }) {
    return SatisModel(
      id: id ?? this.id,
      oturumId: oturumId ?? this.oturumId,
      urunId: urunId ?? this.urunId,
      urunAd: urunAd ?? this.urunAd,
      adet: adet ?? this.adet,
      birimFiyat: birimFiyat ?? this.birimFiyat,
      toplamTutar: toplamTutar ?? this.toplamTutar,
      tarih: tarih ?? this.tarih,
    );
  }

  @override
  String toString() => 'Satis($urunAd x$adet = ₺$toplamTutar)';
}
