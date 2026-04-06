import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/rapor_model.dart';
import '../../../data/models/siparis_kalemi_model.dart';
import '../../../logic/providers/rapor_provider.dart';
import 'rapor_ekrani.dart'
    show adminSifreKontrol, raporDuzenleDiyalogu, raporSilDiyalogu;

/// Rapor detay dialogu — ücret kırılımı, sipariş kalemleri, ödeme bilgisi.
class RaporDetayEkrani extends StatelessWidget {
  final RaporModel rapor;
  const RaporDetayEkrani({super.key, required this.rapor});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 600),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text('${rapor.masaAd} — Detay'),
            centerTitle: true,
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                icon: const Icon(Icons.edit, size: 20),
                tooltip: 'Düzenle',
                onPressed: () async {
                  final ok = await adminSifreKontrol(context);
                  if (ok && context.mounted) {
                    Navigator.of(context).pop();
                    if (context.mounted) {
                      raporDuzenleDiyalogu(context, rapor);
                    }
                  }
                },
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete,
                  size: 20,
                  color: AppColors.error,
                ),
                tooltip: 'Sil',
                onPressed: () async {
                  final ok = await adminSifreKontrol(context);
                  if (ok && context.mounted) {
                    Navigator.of(context).pop();
                    if (context.mounted) {
                      raporSilDiyalogu(context, rapor);
                    }
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Direkt satış rozeti ──
                if (rapor.isDirektSatis) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.point_of_sale,
                          size: 16,
                          color: Colors.orange,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Direkt Satış',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  _BilgiSatiri(
                    'Tarih',
                    '${Formatters.tarih(rapor.baslangic)}  ${Formatters.saat(rapor.baslangic)}',
                  ),
                ] else ...[
                  // ── Genel bilgi (konsol oturumu) ──
                  _BilgiSatiri('Konsol Tipi', rapor.konsolTipi),
                  _BilgiSatiri('Başlangıç', Formatters.saat(rapor.baslangic)),
                  _BilgiSatiri('Bitiş', Formatters.saat(rapor.bitis)),
                  _BilgiSatiri('Oynanan Süre', '${rapor.oynananDk} dk'),
                  _BilgiSatiri('Kol Sayısı', '${rapor.kolSayisi}'),

                  // ── Kol Geçmişi ──
                  if (rapor.kolGecmisi.length > 1) ...[
                    const Divider(height: 24),
                    const Text(
                      'Kol Değişim Geçmişi',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _KolGecmisiTablosu(rapor: rapor),
                  ],
                ],
                const Divider(height: 24),

                // ── Ücret kırılımı ──
                const Text(
                  'Ücret Kırılımı',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 8),
                if (!rapor.isDirektSatis) ...[
                  _UcretSatiri('Konsol Ücreti', rapor.konsolUcreti),
                  if (rapor.kolEkstraUcreti > 0)
                    _UcretSatiri(
                      'Kol Ekstra (${rapor.kolSayisi} kol)',
                      rapor.kolEkstraUcreti,
                    ),
                ],
                if (rapor.siparisUcreti > 0)
                  _UcretSatiri('Kafeterya', rapor.siparisUcreti),
                const Divider(height: 16),
                _UcretSatiri('TOPLAM', rapor.toplamTutar, bold: true),
                const SizedBox(height: 16),

                // ── Ödeme bilgisi ──
                const Text(
                  'Ödeme Bilgisi',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 8),
                _OdemeChip(rapor: rapor),
                if (rapor.odemeYontemi == OdemeYontemi.parcali) ...[
                  const SizedBox(height: 4),
                  _UcretSatiri('Nakit', rapor.nakitTutar),
                  _UcretSatiri('Kart', rapor.kartTutar),
                ],
                const SizedBox(height: 16),

                // ── Sipariş kalemleri ──
                const Text(
                  'Sipariş Kalemleri',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 8),
                _SiparisListesi(oturumId: rapor.oturumId),

                if (rapor.aciklama.isNotEmpty) ...[
                  const Divider(height: 24),
                  const Text(
                    'Açıklama / Not',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    rapor.aciklama,
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: AppColors.textS(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BilgiSatiri extends StatelessWidget {
  final String etiket;
  final String deger;
  const _BilgiSatiri(this.etiket, this.deger);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(etiket, style: TextStyle(color: AppColors.textS(context))),
          Text(deger, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _UcretSatiri extends StatelessWidget {
  final String etiket;
  final double tutar;
  final bool bold;
  const _UcretSatiri(this.etiket, this.tutar, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            etiket,
            style: bold
                ? const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                : TextStyle(color: AppColors.textS(context)),
          ),
          Text(
            Formatters.para(tutar),
            style: bold
                ? TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.vurguMavi(context),
                  )
                : const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _OdemeChip extends StatelessWidget {
  final RaporModel rapor;
  const _OdemeChip({required this.rapor});

  @override
  Widget build(BuildContext context) {
    final (icon, renk, metin) = switch (rapor.odemeYontemi) {
      OdemeYontemi.nakit => (Icons.money, Colors.green, 'Nakit'),
      OdemeYontemi.kart => (Icons.credit_card, AppColors.mavi(context), 'Kart'),
      OdemeYontemi.parcali => (Icons.call_split, Colors.orange, 'Parçalı'),
    };
    return Chip(
      avatar: Icon(icon, color: renk, size: 18),
      label: Text(metin, style: TextStyle(color: renk)),
      backgroundColor: renk.withValues(alpha: 0.1),
      side: BorderSide.none,
    );
  }
}

/// Sipariş kalemlerini asenkron yükler.
class _SiparisListesi extends StatefulWidget {
  final String? oturumId;
  const _SiparisListesi({required this.oturumId});

  @override
  State<_SiparisListesi> createState() => _SiparisListesiState();
}

class _SiparisListesiState extends State<_SiparisListesi> {
  List<SiparisKalemiModel>? _kalemler;
  bool _yukleniyor = true;

  @override
  void initState() {
    super.initState();
    if (widget.oturumId != null) {
      _yukle();
    } else {
      _yukleniyor = false;
    }
  }

  Future<void> _yukle() async {
    final raporProvider = context.read<RaporProvider>();
    final liste = await raporProvider.raporSiparisleri(widget.oturumId);
    if (mounted) {
      setState(() {
        _kalemler = liste;
        _yukleniyor = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_yukleniyor) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_kalemler == null || _kalemler!.isEmpty) {
      return Text(
        'Sipariş yok.',
        style: TextStyle(color: AppColors.textS(context)),
      );
    }
    return Column(
      children: _kalemler!
          .map(
            (k) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${k.urunAd} x${k.adet}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  Text(
                    Formatters.para(k.toplamTutar),
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

/// Kol değişim geçmişi tablosu — her segment kaç kol, ne zaman, kaç dakika.
class _KolGecmisiTablosu extends StatelessWidget {
  final RaporModel rapor;
  const _KolGecmisiTablosu({required this.rapor});

  @override
  Widget build(BuildContext context) {
    final gecmis = rapor.kolGecmisi;
    if (gecmis.isEmpty) return const SizedBox.shrink();

    // Her segmentin süresini hesapla
    final satirlar = <_KolSegmentSatir>[];
    for (int i = 0; i < gecmis.length; i++) {
      final segment = gecmis[i];
      final sonrakiBaslangic = i + 1 < gecmis.length
          ? gecmis[i + 1].baslangic
          : rapor.bitis;
      final sure = sonrakiBaslangic.difference(segment.baslangic);
      final sureDk = sure.inMinutes;
      satirlar.add(
        _KolSegmentSatir(
          kolSayisi: segment.kolSayisi,
          baslangic: segment.baslangic,
          sureDk: sureDk,
        ),
      );
    }

    return Column(
      children: satirlar.map((s) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              // Kol ikonu + sayı
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.isDark(context)
                      ? AppColors.accent.withValues(alpha: 0.10)
                      : AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.sports_esports,
                      size: 14,
                      color: AppColors.vurguMavi(context),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${s.kolSayisi} kol',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppColors.vurguMavi(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Saat bilgisi
              Text(
                Formatters.saat(s.baslangic),
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textS(context),
                ),
              ),
              const Spacer(),
              // Süre
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${s.sureDk} dk',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _KolSegmentSatir {
  final int kolSayisi;
  final DateTime baslangic;
  final int sureDk;
  const _KolSegmentSatir({
    required this.kolSayisi,
    required this.baslangic,
    required this.sureDk,
  });
}
