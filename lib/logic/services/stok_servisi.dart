import '../../data/models/urun_model.dart';

/// Stok yönetim servisi — stok düşme ve uyarı kontrolleri.
class StokServisi {
  StokServisi._();

  /// Ürünün stoku kritik seviyede mi?
  /// [esik] değeri AyarlarProvider'dan alınmalıdır.
  static bool stokKritikMi(UrunModel urun, [int esik = 5]) {
    return urun.stokKritikMi(esik);
  }

  /// Ürünün stoku satışa uygun mu?
  static bool satisaUygunMu(UrunModel urun, int istenenMiktar) {
    return urun.stokMiktari >= istenenMiktar;
  }

  /// Kritik stok uyarı mesajı oluştur.
  static String? uyariMesaji(UrunModel urun, [int esik = 5]) {
    if (urun.stokBittiMi) {
      return '${urun.ad} stokta kalmadı!';
    }
    if (stokKritikMi(urun, esik)) {
      return '${urun.ad} stoku kritik seviyede (${urun.stokMiktari} adet)';
    }
    return null;
  }

  /// Birden fazla ürün için kritik stok uyarıları.
  static List<String> topluUyarilar(List<UrunModel> urunler, [int esik = 5]) {
    return urunler
        .map((u) => uyariMesaji(u, esik))
        .where((msg) => msg != null)
        .cast<String>()
        .toList();
  }
}
