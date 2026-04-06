import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/rapor_model.dart';
import '../../data/models/urun_model.dart';
import '../../logic/providers/urun_provider.dart';
import '../../logic/providers/satis_provider.dart';
import '../../logic/providers/rapor_provider.dart';
import '../../logic/services/stok_servisi.dart';

/// Kafeterya ekranından oturum açmadan doğrudan satış yapma dialogu.
/// Satış kaydı + rapor kaydı oluşturur.
/// Fire-and-Forget: Dialog hemen kapanır, kayıt arka planda yapılır.
class DirektSatisDialogu extends StatefulWidget {
  const DirektSatisDialogu({super.key});

  /// Dialogu açan yardımcı metot.
  static Future<void> goster(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const DirektSatisDialogu(),
    );
  }

  @override
  State<DirektSatisDialogu> createState() => _DirektSatisDialoguState();
}

class _DirektSatisDialoguState extends State<DirektSatisDialogu> {
  final Map<String, int> _sepet = {}; // urunId → adet
  OdemeYontemi _odemeYontemi = OdemeYontemi.nakit;
  double _nakitTutar = 0;
  double _kartTutar = 0;
  final TextEditingController _nakitController = TextEditingController();
  final TextEditingController _kartController = TextEditingController();

  @override
  void dispose() {
    _nakitController.dispose();
    _kartController.dispose();
    super.dispose();
  }

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
    final toplam = _toplamTutar(urunler);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.point_of_sale, color: AppColors.vurguMavi(context)),
          const SizedBox(width: 8),
          const Text('Direkt Satış'),
        ],
      ),
      content: SizedBox(
        width: 440,
        height: 520,
        child: urunler.isEmpty
            ? const Center(child: Text('Henüz ürün bulunmuyor.'))
            : Column(
                children: [
                  // ── Ürün listesi ──
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

                  // ── Sepet özeti + ödeme yöntemi ──
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
                          Formatters.para(toplam),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.vurguMavi(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // ── Ödeme Yöntemi ──
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Ödeme Yöntemi',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SegmentedButton<OdemeYontemi>(
                      segments: const [
                        ButtonSegment(
                          value: OdemeYontemi.nakit,
                          label: Text('Nakit'),
                          icon: Icon(Icons.money, size: 16),
                        ),
                        ButtonSegment(
                          value: OdemeYontemi.kart,
                          label: Text('Kart'),
                          icon: Icon(Icons.credit_card, size: 16),
                        ),
                        ButtonSegment(
                          value: OdemeYontemi.parcali,
                          label: Text('Parçalı'),
                          icon: Icon(Icons.call_split, size: 16),
                        ),
                      ],
                      selected: {_odemeYontemi},
                      onSelectionChanged: (sel) {
                        setState(() {
                          _odemeYontemi = sel.first;
                          if (_odemeYontemi != OdemeYontemi.parcali) {
                            _nakitTutar = 0;
                            _kartTutar = 0;
                            _nakitController.text = '';
                            _kartController.text = '';
                          } else {
                            _nakitController.text = '';
                            _kartController.text = '';
                          }
                        });
                      },
                    ),

                    // ── Parçalı detay ──
                    if (_odemeYontemi == OdemeYontemi.parcali) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _nakitController,
                              decoration: const InputDecoration(
                                labelText: 'Nakit',
                                prefixText: '₺',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                              ],
                              onChanged: (v) {
                                final val = double.tryParse(v.replaceAll(',', '.')) ?? 0;
                                setState(() {
                                  _nakitTutar = val;
                                  final kalan = toplam - val;
                                  if (kalan >= 0) {
                                    _kartTutar = kalan;
                                    _kartController.text = kalan.toStringAsFixed(2);
                                  }
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _kartController,
                              decoration: const InputDecoration(
                                labelText: 'Kart',
                                prefixText: '₺',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                              ],
                              onChanged: (v) {
                                final val = double.tryParse(v.replaceAll(',', '.')) ?? 0;
                                setState(() {
                                  _kartTutar = val;
                                  final kalan = toplam - val;
                                  if (kalan >= 0) {
                                    _nakitTutar = kalan;
                                    _nakitController.text = kalan.toStringAsFixed(2);
                                  }
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
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
          onPressed: _sepet.isEmpty ? null : () => _satisiOnayla(urunler),
          child: const Text('Satışı Tamamla'),
        ),
      ],
    );
  }

  /// Fire-and-Forget: Dialog hemen kapanır, kayıt arka planda yapılır.
  void _satisiOnayla(List<UrunModel> urunler) {
    // Provider referanslarını dialog kapanmadan önce yakala
    final satisProvider = context.read<SatisProvider>();
    final urunProvider = context.read<UrunProvider>();
    final raporProvider = context.read<RaporProvider>();

    // Anlık snapshot'ları al
    final sepetSnapshot = Map<String, int>.from(_sepet);
    final urunlerSnapshot = List<UrunModel>.from(urunler);

    // 1) Dialog'u HEMEN kapat — UI anında serbest kalır
    Navigator.of(context).pop();

    // 2) Arka planda fire-and-forget ile kaydet
    satisProvider.direktSatisKaydet(
      sepet: sepetSnapshot,
      urunler: urunlerSnapshot,
      odemeYontemi: _odemeYontemi,
      nakitTutar: _nakitTutar,
      kartTutar: _kartTutar,
      urunProvider: urunProvider,
      raporProvider: raporProvider,
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
