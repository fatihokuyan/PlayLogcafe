/// Bir rapora ait sipariş kalemi.
/// Rapor detay sayfasında listelemek için kullanılır.
class SiparisKalemiModel {
  final String urunAd;
  final int adet;
  final double birimFiyat;
  final double toplamTutar;

  const SiparisKalemiModel({
    required this.urunAd,
    required this.adet,
    required this.birimFiyat,
    required this.toplamTutar,
  });

  factory SiparisKalemiModel.fromSatisJson(Map<String, dynamic> json) {
    return SiparisKalemiModel(
      urunAd: json['urun_ad'] as String? ?? '',
      adet: json['adet'] as int,
      birimFiyat: (json['birim_fiyat'] as num).toDouble(),
      toplamTutar: (json['toplam_tutar'] as num).toDouble(),
    );
  }

  @override
  String toString() => '$urunAd x$adet = ₺${toplamTutar.toStringAsFixed(2)}';
}
