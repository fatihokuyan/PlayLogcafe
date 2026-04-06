import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/urun_model.dart';
import '../../logic/providers/urun_provider.dart';
import '../../logic/providers/satis_provider.dart';
import '../../logic/services/stok_servisi.dart';

/// Masaya sipariş verme dialogu.
/// Ürün listesinden seçip, adet belirleyip satış kaydı oluşturur.
/// Fire-and-Forget: Dialog hemen kapanır, kayıt arka planda yapılır.
class SiparisDialogu extends StatefulWidget {
  final String? oturumId;

  const SiparisDialogu({super.key, this.oturumId});

  /// Dialogu açan yardımcı metot.
  static Future<void> goster(BuildContext context, {String? oturumId}) {
    return showDialog(
      context: context,
      builder: (_) => SiparisDialogu(oturumId: oturumId),
    );
  }

  @override
  State<SiparisDialogu> createState() => _SiparisDialoguState();
}

class _SiparisDialoguState extends State<SiparisDialogu> {
  final Map<String, int> _sepet = {}; // urunId → adet

  int _toplamAdet() =>
      _sepet.values.fold<int>(0, (toplam, adet) => toplam + adet);

  double _toplamTutar(List<UrunModel> urunler) {
    double toplam = 0;
    _sepet.forEach((urunId, adet) {
      final urun = urunler.firstWhere((u) => u.id == urunId);
      toplam += urun.fiyat * adet;
    });
    return toplam;
  }

  @override
  Widget build(BuildContext context) {
    final urunProvider = context.watch<UrunProvider>();
    final urunler = urunProvider.urunler;

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            color: AppColors.vurguMavi(context),
          ),
          const SizedBox(width: 8),
          const Text('Sipariş Ver'),
        ],
      ),
      content: SizedBox(
        width: 400,
        height: 400,
        child: urunler.isEmpty
            ? const Center(child: Text('Henüz ürün bulunmuyor.'))
            : Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      itemCount: urunler.length,
                      itemBuilder: (context, index) {
                        final urun = urunler[index];
                        final adet = _sepet[urun.id] ?? 0;
                        final stokYeterli = StokServisi.satisaUygunMu(
                          urun,
                          adet + 1,
                        );

                        return ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundColor: AppColors.vurguMavi(
                              context,
                            ).withValues(alpha: 0.1),
                            child: Icon(
                              _kategoriIkonu(urun.kategori),
                              size: 18,
                              color: AppColors.vurguMavi(context),
                            ),
                          ),
                          title: Text(
                            urun.ad,
                            style: const TextStyle(fontSize: 14),
                          ),
                          subtitle: Text(
                            '${Formatters.para(urun.fiyat)} · Stok: ${urun.stokMiktari}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.remove_circle_outline,
                                  size: 20,
                                ),
                                onPressed: adet > 0
                                    ? () => setState(() {
                                        if (adet <= 1) {
                                          _sepet.remove(urun.id);
                                        } else {
                                          _sepet[urun.id] = adet - 1;
                                        }
                                      })
                                    : null,
                              ),
                              SizedBox(
                                width: 24,
                                child: Text(
                                  '$adet',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.add_circle_outline,
                                  size: 20,
                                ),
                                onPressed: stokYeterli && !urun.stokBittiMi
                                    ? () => setState(() {
                                        _sepet[urun.id] = adet + 1;
                                      })
                                    : null,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  if (_sepet.isNotEmpty) ...[
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_toplamAdet()} ürün',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          Formatters.para(_toplamTutar(urunler)),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.vurguMavi(context),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('İptal'),
        ),
        FilledButton(
          onPressed: _sepet.isEmpty ? null : () => _siparisiOnayla(urunler),
          child: const Text('Onayla'),
        ),
      ],
    );
  }

  /// Fire-and-Forget: Dialog hemen kapanır, kayıt arka planda yapılır.
  void _siparisiOnayla(List<UrunModel> urunler) {
    // Provider referanslarını dialog kapanmadan önce yakala
    final satisProvider = context.read<SatisProvider>();
    final urunProvider = context.read<UrunProvider>();

    // Sepet ve ürün listesinin anlık kopyasını al
    final sepetSnapshot = Map<String, int>.from(_sepet);
    final urunlerSnapshot = List<UrunModel>.from(urunler);

    // 1) Dialog'u HEMEN kapat — UI anında serbest kalır
    Navigator.of(context).pop();

    // 2) Arka planda fire-and-forget ile kaydet
    satisProvider.siparisTopluEkle(
      sepet: sepetSnapshot,
      urunler: urunlerSnapshot,
      oturumId: widget.oturumId,
      urunProvider: urunProvider,
    );
  }

  IconData _kategoriIkonu(String kategori) {
    switch (kategori) {
      case 'İçecek':
        return Icons.local_drink;
      case 'Atıştırmalık':
        return Icons.cookie;
      case 'Yiyecek':
        return Icons.fastfood;
      default:
        return Icons.category;
    }
  }
}
