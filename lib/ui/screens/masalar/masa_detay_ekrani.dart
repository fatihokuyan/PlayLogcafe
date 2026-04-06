import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/custom_snackbar.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/masa_model.dart';
import '../../../data/models/oturum_model.dart';
import '../../../data/models/rapor_model.dart';
import '../../../logic/providers/masa_provider.dart';
import '../../../logic/providers/oturum_provider.dart';
import '../../../logic/providers/satis_provider.dart';
import '../../../logic/providers/ayarlar_provider.dart';
import '../../../logic/providers/rapor_provider.dart';
import '../../../logic/services/sure_hesaplama_servisi.dart';
import '../../widgets/sure_sayaci.dart';
import '../../widgets/siparis_dialogu.dart';

/// Tek masa detay ekranı — oturum başlat/durdur, bilgi görüntüle.
class MasaDetayEkrani extends StatelessWidget {
  final MasaModel masa;

  const MasaDetayEkrani({super.key, required this.masa});

  @override
  Widget build(BuildContext context) {
    final oturumProvider = context.watch<OturumProvider>();
    final oturum = oturumProvider.masaninOturumu(masa.id);
    final masaProvider = context.watch<MasaProvider>();
    // Canlı masa durumunu al
    final canliMasa = masaProvider.masalar.firstWhere(
      (m) => m.id == masa.id,
      orElse: () => masa,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(canliMasa.ad),
        actions: [
          // Masa sil butonu (sadece boş masalar silinebilir)
          if (canliMasa.durum == MasaDurum.bos)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Masayı Sil',
              onPressed: () => _masaSilOnay(context, masaProvider),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Masa bilgi kartı ──
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(
                      Icons.sports_esports,
                      size: 48,
                      color: canliMasa.durum == MasaDurum.dolu
                          ? AppColors.masaDolu
                          : AppColors.masaBos,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      canliMasa.ad,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.vurguMavi(
                          context,
                        ).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        canliMasa.konsolTipi,
                        style: TextStyle(
                          color: AppColors.vurguMavi(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Aktif oturum bilgisi veya başlatma butonları ──
            if (oturum != null && oturum.isAktif) ...[
              _AktifOturumKarti(oturum: oturum, konsolTipi: masa.konsolTipi),
              const SizedBox(height: 12),
              // Kol Değiştir, Sipariş Ver
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: () => _kolDegistirDialogu(context, oturum),
                    icon: const Icon(Icons.sports_esports),
                    label: Text('Kol: ${oturum.kolSayisi}'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () =>
                        SiparisDialogu.goster(context, oturumId: oturum.id),
                    icon: const Icon(Icons.shopping_cart_outlined),
                    label: const Text('Sipariş Ver'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accentDark,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Dondur, Sonlandır & İptal butonları
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: () => _oturumDondur(context, oturum),
                    icon: const Icon(Icons.ac_unit),
                    label: const Text('Dondur'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.masaDondurulmus,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => _oturumSonlandir(context, oturum),
                    icon: const Icon(Icons.stop),
                    label: const Text('Sonlandır'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.masaDolu,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _oturumIptalEt(context, oturum),
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('İptal'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Siparişe Aktar & Yeniden Başlat
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _sipariseAktarVeYenidenBaslat(context, oturum),
                  icon: Icon(
                    Icons.restart_alt,
                    size: 16,
                    color: Colors.orange.shade700,
                  ),
                  label: Text(
                    'Siparişe Aktar & Yeniden Başlat',
                    style: TextStyle(color: Colors.orange.shade700),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: Colors.orange.withValues(alpha: 0.5),
                    ),
                    backgroundColor: Colors.orange.withValues(alpha: 0.06),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ] else if (oturum != null && oturum.isDondurulmus) ...[
              // ── Dondurulmuş oturum ──
              _AktifOturumKarti(oturum: oturum, konsolTipi: masa.konsolTipi),
              const SizedBox(height: 16),
              Card(
                color: AppColors.isDark(context)
                    ? AppColors.masaDondurulmus.withValues(alpha: 0.15)
                    : const Color(0xFF1565C0).withValues(alpha: 0.10),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.ac_unit,
                        color: AppColors.isDark(context)
                            ? AppColors.masaDondurulmus
                            : const Color(0xFF1565C0),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Oturum donduruldu — süre ve ücret işlemiyor',
                        style: TextStyle(
                          color: AppColors.isDark(context)
                              ? AppColors.masaDondurulmus
                              : const Color(0xFF0D47A1),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: () => _oturumDevamEt(context, oturum),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Devam Et'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.masaBos,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: () => _oturumSonlandir(context, oturum),
                    icon: const Icon(Icons.stop),
                    label: const Text('Sonlandır'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.masaDolu,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              Text(
                'Bu masa şu an boş. Oturum başlatın:',
                style: TextStyle(fontSize: 16, color: AppColors.textS(context)),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _oturumBaslatDialogu(context, OturumMod.sureli),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                        foregroundColor: AppColors.primary,
                        elevation: 0,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.timer, size: 40),
                          SizedBox(height: 12),
                          Text(
                            'Süreli Başlat',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _suresizOturumBaslatDialogu(context),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        backgroundColor: AppColors.accentDark.withValues(alpha: 0.15),
                        foregroundColor: AppColors.accentDark,
                        elevation: 0,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.all_inclusive, size: 40),
                          SizedBox(height: 12),
                          Text(
                            'Süresiz Başlat',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Süreli oturum başlatma dialogu ──
  void _oturumBaslatDialogu(BuildContext context, OturumMod mod) {
    final ayarlar = context.read<AyarlarProvider>();
    final controller = TextEditingController(
      text: ayarlar.varsayilanSureDk.toString(),
    );
    int seciliKolSayisi = 2;
    int sureDk = ayarlar.varsayilanSureDk;
    final maksKol = ayarlar.maksimumKolSayisi(masa.konsolTipi);

    // Quick-action buton değerleri (Süre Düzenleme diyaloğuyla aynı pattern)
    const List<int> hizliSureler = [60, 90, 120, 150, 180];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Süreli Oturum'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Hızlı süre seçimi (Süre Düzenleme ile birebir aynı layout) ──
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: hizliSureler.map((dk) {
                  final sec = sureDk == dk;
                  return ChoiceChip(
                    label: Text(
                      '$dk dk',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            sec ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    selected: sec,
                    onSelected: (_) {
                      setState(() {
                        sureDk = dk;
                        controller.text = dk.toString();
                      });
                    },
                    selectedColor: AppColors.primary.withValues(alpha: 0.18),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              // ── Manuel giriş alanı ──
              SizedBox(
                height: 40,
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  autofocus: true,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Süre (dakika)',
                    suffixText: 'dk',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onChanged: (v) {
                    final val = int.tryParse(v);
                    setState(() => sureDk = val ?? 0);
                  },
                ),
              ),
              const SizedBox(height: 16),
              // ── Kol sayısı seçici ──
              Row(
                children: [
                  const Icon(Icons.sports_esports, size: 20),
                  const SizedBox(width: 8),
                  const Text('Kol Sayısı:'),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: seciliKolSayisi > 2
                        ? () => setState(() => seciliKolSayisi--)
                        : null,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$seciliKolSayisi',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: seciliKolSayisi < maksKol
                        ? () => setState(() => seciliKolSayisi++)
                        : null,
                  ),
                ],
              ),
              // ── Ücret bilgisi ──
              Text(
                ayarlar.ucretGosterimMetni(masa.konsolTipi, seciliKolSayisi),
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textS(ctx),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('İptal'),
            ),
            FilledButton(
              onPressed: () {
                final girilmis = int.tryParse(controller.text.trim());
                final sonucDk = girilmis ?? sureDk;
                if (sonucDk < ayarlar.minimumSureDk) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Minimum süre ${ayarlar.minimumSureDk} dakikadır.',
                      ),
                    ),
                  );
                  return;
                }
                Navigator.of(ctx).pop();
                _oturumBaslat(context, mod, sonucDk, seciliKolSayisi);
              },
              child: const Text('Başlat'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Süresiz oturum başlatma dialogu (kol seçici) ──
  void _suresizOturumBaslatDialogu(BuildContext context) {
    final ayarlar = context.read<AyarlarProvider>();
    int seciliKolSayisi = 2;
    final maksKol = ayarlar.maksimumKolSayisi(masa.konsolTipi);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Süresiz Oturum'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Kol sayısı seçici
              Row(
                children: [
                  const Icon(Icons.sports_esports, size: 20),
                  const SizedBox(width: 8),
                  const Text('Kol Sayısı:'),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: seciliKolSayisi > 2
                        ? () => setState(() => seciliKolSayisi--)
                        : null,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$seciliKolSayisi',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: seciliKolSayisi < maksKol
                        ? () => setState(() => seciliKolSayisi++)
                        : null,
                  ),
                ],
              ),
              // Ücret bilgisi
              Text(
                ayarlar.ucretGosterimMetni(masa.konsolTipi, seciliKolSayisi),
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textS(ctx),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('İptal'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _oturumBaslat(
                  context,
                  OturumMod.suresiz,
                  null,
                  seciliKolSayisi,
                );
              },
              child: const Text('Başlat'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Oturum başlat ──
  Future<void> _oturumBaslat(
    BuildContext context,
    OturumMod mod,
    int? sureDk, [
    int kolSayisi = 2,
  ]) async {
    final oturumProvider = context.read<OturumProvider>();
    final masaProvider = context.read<MasaProvider>();

    final basarili = await oturumProvider.oturumBaslat(
      masaId: masa.id,
      mod: mod,
      sureDk: sureDk,
      kolSayisi: kolSayisi,
    );

    if (basarili) {
      await masaProvider.durumGuncelle(masa.id, MasaDurum.dolu);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Oturum başlatıldı!')));
      }
    }
  }

  // ── Kol sayısı değiştir ──
  void _kolDegistirDialogu(BuildContext context, OturumModel oturum) {
    int yeniKolSayisi = oturum.kolSayisi;
    final ayarlar = context.read<AyarlarProvider>();
    final maksKol = ayarlar.maksimumKolSayisi(masa.konsolTipi);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Kol Sayısını Değiştir'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Mevcut: ${oturum.kolSayisi} kol',
                style: TextStyle(color: AppColors.textS(ctx)),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, size: 32),
                    onPressed: yeniKolSayisi > 2
                        ? () => setState(() => yeniKolSayisi--)
                        : null,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$yeniKolSayisi',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, size: 32),
                    onPressed: yeniKolSayisi < maksKol
                        ? () => setState(() => yeniKolSayisi++)
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                ayarlar.ucretGosterimMetni(masa.konsolTipi, yeniKolSayisi),
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textS(ctx),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Not: Önceki süre eski kol sayısıyla,\nyeni süre yeni kol sayısıyla ücretlendirilir.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textS(ctx),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('İptal'),
            ),
            FilledButton(
              onPressed: yeniKolSayisi == oturum.kolSayisi
                  ? null
                  : () {
                      Navigator.of(ctx).pop();
                      _kolDegistir(context, oturum, yeniKolSayisi);
                    },
              child: const Text('Değiştir'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _kolDegistir(
    BuildContext context,
    OturumModel oturum,
    int yeniKol,
  ) async {
    final oturumProvider = context.read<OturumProvider>();
    final basarili = await oturumProvider.kolSayisiDegistir(oturum.id, yeniKol);
    if (basarili && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kol sayısı $yeniKol olarak güncellendi.')),
      );
    }
  }

  // ── Oturum dondur ──
  Future<void> _oturumDondur(BuildContext context, OturumModel oturum) async {
    final oturumProvider = context.read<OturumProvider>();
    final masaProvider = context.read<MasaProvider>();

    final basarili = await oturumProvider.oturumDondur(oturum.id);
    if (basarili) {
      await masaProvider.durumGuncelle(masa.id, MasaDurum.dondurulmus);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Oturum donduruldu — süre işlemiyor.')),
        );
      }
    }
  }

  // ── Oturum devam et ──
  Future<void> _oturumDevamEt(BuildContext context, OturumModel oturum) async {
    final oturumProvider = context.read<OturumProvider>();
    final masaProvider = context.read<MasaProvider>();

    final basarili = await oturumProvider.oturumDevamEt(oturum.id);
    if (basarili) {
      await masaProvider.durumGuncelle(masa.id, MasaDurum.dolu);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Oturum devam ediyor.')));
      }
    }
  }

  // ── Oturum sonlandır ──
  Future<void> _oturumSonlandir(
    BuildContext context,
    OturumModel oturum,
  ) async {
    final oturumProvider = context.read<OturumProvider>();
    final masaProvider = context.read<MasaProvider>();
    final satisProvider = context.read<SatisProvider>();
    final ayarlar = context.read<AyarlarProvider>();

    // Sipariş toplamı
    final siparisToplami = satisProvider
        .oturumSatislari(oturum.id)
        .fold<double>(0, (t, s) => t + s.toplamTutar);

    // Tahmini zaman ücreti (dinamik kol geçmişi ile)
    final tahminiZaman = SureHesaplamaServisi.dinamikKolUcretHesapla(
      kolGecmisi: oturum.kolGecmisi,
      efektifSure: oturum.gecenSure,
      mod: oturum.mod,
      planliSureDk: oturum.sureDk,
      dakikaBasiUcretResolver: (kol) =>
          ayarlar.konsolDakikaBasiUcretHesapla(masa.konsolTipi, kol),
      fallbackKolSayisi: oturum.kolSayisi,
      periyotDk: SureHesaplamaServisi.efektifPeriyot(oturum.butce, ayarlar.guncellemePeriyoduDk, oturum.mod),
      ilkUcretsizDk: ayarlar.ilkUcretsizDk,
    );
    final kolEkstra = ayarlar.kolEkstraUcretHesapla(
      oturum.kolSayisi,
      masa.konsolTipi,
    );
    final tahminiToplam = tahminiZaman + kolEkstra + siparisToplami;

    // Ödeme dialogunu göster
    if (!context.mounted) return;
    final odemeResult = await _odemeDialoguGoster(
      context,
      konsolUcreti: tahminiZaman,
      kolEkstraUcreti: kolEkstra,
      siparisUcreti: siparisToplami,
      toplamTutar: tahminiToplam,
      kolSayisi: oturum.kolSayisi,
      gecenSure: oturum.gecenSure,
    );

    if (odemeResult == null) return; // İptal edildi

    // Gerçek dinamik ücret hesapla
    final zamanUcreti = SureHesaplamaServisi.dinamikKolUcretHesapla(
      kolGecmisi: oturum.kolGecmisi,
      efektifSure: oturum.gecenSure,
      mod: oturum.mod,
      planliSureDk: oturum.sureDk,
      dakikaBasiUcretResolver: (kol) =>
          ayarlar.konsolDakikaBasiUcretHesapla(masa.konsolTipi, kol),
      fallbackKolSayisi: oturum.kolSayisi,
      periyotDk: SureHesaplamaServisi.efektifPeriyot(oturum.butce, ayarlar.guncellemePeriyoduDk, oturum.mod),
      ilkUcretsizDk: ayarlar.ilkUcretsizDk,
    );
    final genelToplam = zamanUcreti + kolEkstra + siparisToplami;

    // Provider'a sadece sonlandırma emri ver (tutar zaten hesaplandı)
    await oturumProvider.oturumSonlandirTutarli(oturum.id, zamanUcreti);

    await masaProvider.durumGuncelle(masa.id, MasaDurum.bos);

    // Rapor kaydet
    if (context.mounted) {
      final raporProvider = context.read<RaporProvider>();
      await raporProvider.raporOlustur(
        oturumId: oturum.id,
        masaId: masa.id,
        masaAd: masa.ad,
        konsolTipi: masa.konsolTipi,
        baslangic: oturum.baslangic,
        bitis: DateTime.now(),
        oynananDk: oturum.gecenSure.inMinutes,
        kolSayisi: oturum.kolSayisi,
        konsolUcreti: zamanUcreti,
        kolEkstraUcreti: kolEkstra,
        siparisUcreti: siparisToplami,
        toplamTutar: odemeResult.tahsilEdilenTutar,
        aciklama: (genelToplam - odemeResult.tahsilEdilenTutar).abs() > 0.01 
            ? 'Not: Toplam: ${Formatters.para(genelToplam)}, Tahsil Edilen: ${Formatters.para(odemeResult.tahsilEdilenTutar)}'
            : '',
        odemeYontemi: odemeResult.yontem,
        nakitTutar: odemeResult.nakitTutar,
        kartTutar: odemeResult.kartTutar,
        kolGecmisi: oturum.kolGecmisi
            .map(
              (s) => KolGecmisiKayit(
                kolSayisi: s.kolSayisi,
                baslangic: s.baslangic,
              ),
            )
            .toList(),
      );
    }

    if (context.mounted) {
      CustomSnackbar.showSuccess(
        context,
        'Oturum tamamlandı — ${Formatters.para(genelToplam)} (${odemeResult.yontem.label})',
      );
    }
  }

  /// Ödeme yöntemi seçme dialogu. Null dönerse iptal edilmiş demektir.
  Future<_OdemeSecimi?> _odemeDialoguGoster(
    BuildContext context, {
    required double konsolUcreti,
    required double kolEkstraUcreti,
    required double siparisUcreti,
    required double toplamTutar,
    required int kolSayisi,
    required Duration gecenSure,
  }) async {
    OdemeYontemi seciliYontem = OdemeYontemi.nakit;
    final nakitController = TextEditingController();
    final kartController = TextEditingController();
    final tahsilEdilenController = TextEditingController(text: toplamTutar.toStringAsFixed(2));
    String? parcaliHata;
    double guncelTahsilEdilen = toplamTutar;

    return showDialog<_OdemeSecimi>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            title: const Text('Ödeme & Sonlandır'),
            content: SizedBox(
              width: 380,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: AppColors.success,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    // Ücret özeti
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Konsol Ücreti:'),
                        Text(
                          Formatters.para(konsolUcreti),
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    if (kolEkstraUcreti > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Kol Ekstra ($kolSayisi kol):'),
                          Text(
                            Formatters.para(kolEkstraUcreti),
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                    if (siparisUcreti > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Kafeterya:'),
                          Text(
                            Formatters.para(siparisUcreti),
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                    const Divider(height: 20),
                    Text(
                      'TOPLAM HESAP: ${Formatters.para(toplamTutar)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Tahsil Edilen Tutar Alanı
                    TextField(
                      controller: tahsilEdilenController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Tahsil Edilen Tutar (₺)',
                        border: OutlineInputBorder(
                           borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.attach_money),
                        filled: true,
                        fillColor: AppColors.primary.withValues(alpha: 0.1),
                      ),
                      onChanged: (val) {
                         setState(() {
                            guncelTahsilEdilen = double.tryParse(val.replaceAll(',', '.')) ?? toplamTutar;
                            parcaliHata = null;
                         });
                      },
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Süre: ${Formatters.sureDuration(gecenSure)}',
                      style: TextStyle(color: AppColors.textS(ctx)),
                    ),
                    const SizedBox(height: 20),

                    // ── Ödeme yöntemi seçimi ──
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Ödeme Yöntemi',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<OdemeYontemi>(
                      segments: const [
                        ButtonSegment(
                          value: OdemeYontemi.nakit,
                          label: Text('Nakit'),
                          icon: Icon(Icons.money),
                        ),
                        ButtonSegment(
                          value: OdemeYontemi.kart,
                          label: Text('Kart'),
                          icon: Icon(Icons.credit_card),
                        ),
                        ButtonSegment(
                          value: OdemeYontemi.parcali,
                          label: Text('Parçalı'),
                          icon: Icon(Icons.call_split),
                        ),
                      ],
                      selected: {seciliYontem},
                      onSelectionChanged: (set) {
                        setState(() {
                          seciliYontem = set.first;
                          parcaliHata = null;
                        });
                      },
                    ),
                    const SizedBox(height: 12),

                    // Parçalı ödeme alanları
                    if (seciliYontem == OdemeYontemi.parcali) ...[
                      TextField(
                        controller: nakitController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Nakit Tutar (₺)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.money),
                        ),
                        onChanged: (_) {
                          setState(() {
                            parcaliHata = null;
                            final n =
                                double.tryParse(nakitController.text.replaceAll(',', '.')) ??
                                0;
                            final kalan = guncelTahsilEdilen - n;
                            if (kalan >= 0) {
                              kartController.text = kalan.toStringAsFixed(2);
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: kartController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Kart Tutar (₺)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.credit_card),
                        ),
                        onChanged: (_) {
                          setState(() {
                            parcaliHata = null;
                            final k =
                                double.tryParse(kartController.text.replaceAll(',', '.')) ??
                                0;
                            final kalan = guncelTahsilEdilen - k;
                            if (kalan >= 0) {
                              nakitController.text = kalan.toStringAsFixed(2);
                            }
                          });
                        },
                      ),
                      if (parcaliHata != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          parcaliHata!,
                          style: const TextStyle(
                            color: AppColors.error,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(null),
                child: const Text('İptal'),
              ),
              FilledButton(
                onPressed: () {
                  double nakit = 0;
                  double kart = 0;
                  if (seciliYontem == OdemeYontemi.nakit) {
                    nakit = guncelTahsilEdilen;
                  } else if (seciliYontem == OdemeYontemi.kart) {
                    kart = guncelTahsilEdilen;
                  } else {
                    nakit = double.tryParse(nakitController.text.replaceAll(',', '.')) ?? 0;
                    kart = double.tryParse(kartController.text.replaceAll(',', '.')) ?? 0;
                    final fark = (nakit + kart - guncelTahsilEdilen).abs();
                    if (fark > 0.01) {
                      setState(
                        () => parcaliHata =
                            'Nakit + Kart toplamı (${Formatters.para(nakit + kart)}) tahsil edilecek tutarla (${Formatters.para(guncelTahsilEdilen)}) eşleşmiyor.',
                      );
                      return;
                    }
                  }
                  Navigator.of(ctx).pop(
                    _OdemeSecimi(
                      yontem: seciliYontem,
                      nakitTutar: nakit,
                      kartTutar: kart,
                      tahsilEdilenTutar: guncelTahsilEdilen,
                    ),
                  );
                },
                child: const Text('Onayla & Kapat'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Oturum iptal et ──
  Future<void> _oturumIptalEt(BuildContext context, OturumModel oturum) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Oturumu İptal Et'),
        content: const Text(
          'Bu oturum iptal edilecek ve ücret alınmayacak. Emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hayır'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('İptal Et'),
          ),
        ],
      ),
    );

    if (onay == true && context.mounted) {
      final oturumProvider = context.read<OturumProvider>();
      final masaProvider = context.read<MasaProvider>();

      await oturumProvider.oturumIptalEt(oturum.id);
      await masaProvider.durumGuncelle(masa.id, MasaDurum.bos);

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Oturum iptal edildi.')));
      }
    }
  }

  // ── Masa sil onay ──
  Future<void> _masaSilOnay(BuildContext context, MasaProvider provider) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Masayı Sil'),
        content: Text('${masa.ad} silinecek. Emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hayır'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (onay == true && context.mounted) {
      await provider.masaSil(masa.id);
      if (context.mounted) Navigator.of(context).pop();
    }
  }

  // ── Siparişe Aktar & Yeniden Başlat ──
  Future<void> _sipariseAktarVeYenidenBaslat(
    BuildContext context,
    OturumModel oturum,
  ) async {
    final satisProvider = context.read<SatisProvider>();
    final ayarlar = context.read<AyarlarProvider>();

    final zamanUcreti = SureHesaplamaServisi.dinamikKolUcretHesapla(
      kolGecmisi: oturum.kolGecmisi,
      efektifSure: oturum.gecenSure,
      mod: oturum.mod,
      planliSureDk: oturum.sureDk,
      dakikaBasiUcretResolver: (kol) =>
          ayarlar.konsolDakikaBasiUcretHesapla(masa.konsolTipi, kol),
      fallbackKolSayisi: oturum.kolSayisi,
      periyotDk: SureHesaplamaServisi.efektifPeriyot(oturum.butce, ayarlar.guncellemePeriyoduDk, oturum.mod),
      ilkUcretsizDk: ayarlar.ilkUcretsizDk,
    );
    final kolEkstra = ayarlar.kolEkstraUcretHesapla(
      oturum.kolSayisi,
      masa.konsolTipi,
    );
    final toplamUcret = zamanUcreti + kolEkstra;
    final oynananDk = oturum.gecenSure.inMinutes;

    if (!context.mounted) return;
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.restart_alt, color: Colors.orange.shade700, size: 48),
        title: const Text('Siparişe Aktar & Yeniden Başlat'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Mevcut konsol ücreti (${Formatters.para(toplamUcret)}) '
              'sipariş listesine eklenecek.\n'
              'Detay: ${oturum.kolSayisi} kol, $oynananDk dk',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
            ),
            child: const Text('Onayla & Devam'),
          ),
        ],
      ),
    );

    if (onay != true || !context.mounted) return;

    // Kol geçmişinden açıklayıcı metin oluştur
    final kolMetni = () {
      final gecmis = oturum.kolGecmisi;
      if (gecmis.isEmpty) return '${oturum.kolSayisi} kol';
      final distinctKollar = <int>[];
      for (final seg in gecmis) {
        if (distinctKollar.isEmpty || distinctKollar.last != seg.kolSayisi) {
          distinctKollar.add(seg.kolSayisi);
        }
      }
      if (distinctKollar.length <= 1) return '${oturum.kolSayisi} kol';
      return '${distinctKollar.join('→')} kol';
    }();

    await satisProvider.eskiKonsolUcretiEkle(
      oturumId: oturum.id,
      konsolUcreti: zamanUcreti,
      kolEkstraUcreti: kolEkstra,
      kolMetni: kolMetni,
      oynananDk: oynananDk,
      baslangic: oturum.baslangic,
    );

    if (!context.mounted) return;
    _yenidenBaslatDialogu(context, oturum);
  }

  void _yenidenBaslatDialogu(BuildContext context, OturumModel oturum) {
    final ayarlar = context.read<AyarlarProvider>();
    bool sureli = true;
    int seciliKolSayisi = 2;
    final maksKol = ayarlar.maksimumKolSayisi(masa.konsolTipi);
    final controller = TextEditingController(
      text: ayarlar.varsayilanSureDk.toString(),
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Yeni Oturum Başlat'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: true,
                    icon: Icon(Icons.timer, size: 18),
                    label: Text('Süreli'),
                  ),
                  ButtonSegment(
                    value: false,
                    icon: Icon(Icons.all_inclusive, size: 18),
                    label: Text('Süresiz'),
                  ),
                ],
                selected: {sureli},
                onSelectionChanged: (s) => setState(() => sureli = s.first),
              ),
              const SizedBox(height: 12),
              if (sureli)
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Süre (dakika)',
                    border: OutlineInputBorder(),
                    suffixText: 'dk',
                  ),
                ),
              const SizedBox(height: 12),
              // Kol sayısı seçici
              Row(
                children: [
                  const Icon(Icons.sports_esports, size: 20),
                  const SizedBox(width: 8),
                  const Text('Kol Sayısı:'),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: seciliKolSayisi > 2
                        ? () => setState(() => seciliKolSayisi--)
                        : null,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$seciliKolSayisi',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: seciliKolSayisi < maksKol
                        ? () => setState(() => seciliKolSayisi++)
                        : null,
                  ),
                ],
              ),
              Text(
                ayarlar.ucretGosterimMetni(masa.konsolTipi, seciliKolSayisi),
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textS(ctx),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('İptal'),
            ),
            FilledButton.icon(
              onPressed: () {
                if (sureli) {
                  final sureDk = int.tryParse(controller.text.trim());
                  if (sureDk == null || sureDk < ayarlar.minimumSureDk) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Minimum süre ${ayarlar.minimumSureDk} dakikadır.',
                        ),
                      ),
                    );
                    return;
                  }
                  Navigator.of(ctx).pop();
                  _yenidenBaslatUygula(
                    context,
                    oturum,
                    mod: OturumMod.sureli,
                    sureDk: sureDk,
                    kolSayisi: seciliKolSayisi,
                  );
                } else {
                  Navigator.of(ctx).pop();
                  _yenidenBaslatUygula(
                    context,
                    oturum,
                    mod: OturumMod.suresiz,
                    kolSayisi: seciliKolSayisi,
                  );
                }
              },
              icon: const Icon(Icons.restart_alt, size: 18),
              label: const Text('Başlat'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _yenidenBaslatUygula(
    BuildContext context,
    OturumModel oturum, {
    required OturumMod mod,
    int? sureDk,
    required int kolSayisi,
  }) async {
    final oturumProvider = context.read<OturumProvider>();
    final basarili = await oturumProvider.oturumYenidenBaslat(
      oturum.id,
      yeniMod: mod,
      yeniSureDk: sureDk,
      yeniKolSayisi: kolSayisi,
    );
    if (basarili && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Oturum yeniden başlatıldı!')),
      );
    }
  }
}

/// Ödeme dialogu sonucu.
class _OdemeSecimi {
  final OdemeYontemi yontem;
  final double nakitTutar;
  final double kartTutar;
  final double tahsilEdilenTutar;

  const _OdemeSecimi({
    required this.yontem,
    required this.nakitTutar,
    required this.kartTutar,
    required this.tahsilEdilenTutar,
  });
}

/// Aktif oturum bilgi kartı.
class _AktifOturumKarti extends StatelessWidget {
  final OturumModel oturum;
  final String konsolTipi;

  const _AktifOturumKarti({required this.oturum, required this.konsolTipi});

  @override
  Widget build(BuildContext context) {
    final satisProvider = context.watch<SatisProvider>();
    final ayarlar = context.read<AyarlarProvider>();
    final siparisToplami = satisProvider
        .oturumSatislari(oturum.id)
        .fold<double>(0, (t, s) => t + s.toplamTutar);
    // Dinamik kol geçmişi ile ücret hesapla
    final zamanUcreti = SureHesaplamaServisi.dinamikKolUcretHesapla(
      kolGecmisi: oturum.kolGecmisi,
      efektifSure: oturum.gecenSure,
      mod: oturum.mod,
      planliSureDk: oturum.sureDk,
      dakikaBasiUcretResolver: (kol) =>
          ayarlar.konsolDakikaBasiUcretHesapla(konsolTipi, kol),
      fallbackKolSayisi: oturum.kolSayisi,
      periyotDk: SureHesaplamaServisi.efektifPeriyot(oturum.butce, ayarlar.guncellemePeriyoduDk, oturum.mod),
      ilkUcretsizDk: ayarlar.ilkUcretsizDk,
    );
    final kolEkstra = ayarlar.kolEkstraUcretHesapla(
      oturum.kolSayisi,
      konsolTipi,
    );

    return Card(
      color: AppColors.masaDolu.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              'Aktif Oturum',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.masaDolu,
              ),
            ),
            const SizedBox(height: 12),
            SureSayaci(
              baslangic: oturum.baslangic,
              planliSureDk: oturum.sureDk,
              dondurulmus: oturum.isDondurulmus,
              dondurmaAni: oturum.dondurmaAni,
              toplamDondurulmaSuresiSn: oturum.toplamDondurulmaSuresiSn,
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Başlangıç: ${Formatters.saat(oturum.baslangic)}',
              style: TextStyle(color: AppColors.textS(context)),
            ),
            const SizedBox(height: 4),
            Text(
              oturum.mod == OturumMod.sureli
                  ? 'Mod: Süreli (${oturum.sureDk} dk)'
                  : 'Mod: Süresiz',
              style: TextStyle(color: AppColors.textS(context)),
            ),
            const SizedBox(height: 4),
            Text(
              '${oturum.kolSayisi} kol  ·  ${ayarlar.ucretGosterimMetni(konsolTipi, oturum.kolSayisi)}',
              style: TextStyle(color: AppColors.textS(context)),
            ),
            const SizedBox(height: 8),
            // Konsol ücreti
            Text(
              'Konsol: ${Formatters.para(zamanUcreti)}',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textS(context),
              ),
            ),
            // Kol ekstra
            if (kolEkstra > 0)
              Text(
                'Kol Ekstra: ${Formatters.para(kolEkstra)}',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textS(context),
                ),
              ),
            // Sipariş varsa göster
            if (siparisToplami > 0)
              Text(
                'Kafeterya: ${Formatters.para(siparisToplami)}',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textS(context),
                ),
              ),
            const SizedBox(height: 4),
            // Genel toplam
            Text(
              'Toplam: ${Formatters.para(zamanUcreti + kolEkstra + siparisToplami)}',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.vurguMavi(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
