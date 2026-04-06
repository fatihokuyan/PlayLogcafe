/// Kafeterya ürün modeli.
class UrunModel {
  final String id;
  final String ad;
  final String kategori; // İçecek, Atıştırmalık, Yiyecek, Diğer
  final double fiyat;
  final int stokMiktari;

  const UrunModel({
    required this.id,
    required this.ad,
    required this.kategori,
    required this.fiyat,
    this.stokMiktari = 0,
  });

  /// Supabase JSON → UrunModel
  factory UrunModel.fromJson(Map<String, dynamic> json) {
    return UrunModel(
      id: json['id'] as String,
      ad: json['ad'] as String,
      kategori: json['kategori'] as String,
      fiyat: (json['fiyat'] as num).toDouble(),
      stokMiktari: json['stok_miktari'] as int? ?? 0,
    );
  }

  /// UrunModel → Supabase JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ad': ad,
      'kategori': kategori,
      'fiyat': fiyat,
      'stok_miktari': stokMiktari,
    };
  }

  /// Stok kritik seviyede mi?
  bool stokKritikMi(int esik) => stokMiktari <= esik;

  /// Stok sıfır mı?
  bool get stokBittiMi => stokMiktari <= 0;

  UrunModel copyWith({
    String? id,
    String? ad,
    String? kategori,
    double? fiyat,
    int? stokMiktari,
  }) {
    return UrunModel(
      id: id ?? this.id,
      ad: ad ?? this.ad,
      kategori: kategori ?? this.kategori,
      fiyat: fiyat ?? this.fiyat,
      stokMiktari: stokMiktari ?? this.stokMiktari,
    );
  }

  @override
  String toString() => 'Urun($ad, $kategori, ₺$fiyat, stok: $stokMiktari)';
}
