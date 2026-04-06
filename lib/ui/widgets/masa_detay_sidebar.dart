import 'dart:async' show unawaited;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../app.dart' show rootScaffoldMessengerKey;
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive_helper.dart';
import '../../data/models/masa_model.dart';
import '../../data/models/oturum_model.dart';
import '../../data/models/rapor_model.dart';
import '../../logic/providers/masa_provider.dart';
import '../../logic/providers/oturum_provider.dart';
import '../../logic/providers/satis_provider.dart';
import '../../logic/providers/urun_provider.dart';
import '../../logic/providers/ayarlar_provider.dart';
import '../../logic/providers/rapor_provider.dart';
import '../../logic/services/sure_hesaplama_servisi.dart';
import 'sure_sayaci.dart';
import 'siparis_dialogu.dart';
import '../screens/raporlar/rapor_ekrani.dart' show adminSifreKontrol;

/// Sağ sidebar — seçili masanın detaylarını ve tüm işlemlerini gösterir.
class MasaDetaySidebar extends StatefulWidget {
  final MasaModel masa;
  final VoidCallback onKapat;

  const MasaDetaySidebar({
    super.key,
    required this.masa,
    required this.onKapat,
  });

  @override
  State<MasaDetaySidebar> createState() => _MasaDetaySidebarState();
}

class _MasaDetaySidebarState extends State<MasaDetaySidebar> {
  MasaModel get masa => widget.masa;
  VoidCallback get onKapat => widget.onKapat;
  bool _sadeceSiparislerModu = false;
  bool _isClosing = false;

  @override
  Widget build(BuildContext context) {
    final oturumProvider = context.watch<OturumProvider>();
    final satisProvider = context.watch<SatisProvider>();
    final masaProvider = context.watch<MasaProvider>();
    final oturum = oturumProvider.masaninOturumu(masa.id);

    // Canlı masa durumunu al
    final canliMasa = masaProvider.masalar.firstWhere(
      (m) => m.id == masa.id,
      orElse: () => widget.masa,
    );

    final screenWidth = MediaQuery.of(context).size.width;
    final compact = ResponsiveHelper.isCompactSidebar(context);
    // Sidebar genişliği: ekranın %25'i (non-compact) veya %38'i (compact).
    // Min 200, max 360 — dar ekranlarda orantılı küçülür.
    final sidebarWidth = compact ? screenWidth * 0.40 : screenWidth * 0.27;
    final minW = compact ? 250.0 : 210.0;
    final clampedWidth = sidebarWidth.clamp(minW, 380.0);
    return Container(
      width: clampedWidth,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          left: BorderSide(color: AppColors.borderColor(context), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: AppColors.isDark(context) ? 0.3 : 0.08,
            ),
            blurRadius: 12,
            offset: const Offset(-4, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Header ──
          _SidebarHeader(
            masa: canliMasa,
            oturum: oturum,
            onKapat: widget.onKapat,
            onSil: canliMasa.durum == MasaDurum.bos
                ? () async {
                    final ok = await adminSifreKontrol(context);
                    if (ok && context.mounted) {
                      _masaSilOnay(context, masaProvider, canliMasa);
                    }
                  }
                : null,
            onDuzenle: canliMasa.durum == MasaDurum.bos
                ? () async {
                    final ok = await adminSifreKontrol(context);
                    if (ok && context.mounted) {
                      _masaDuzenleDialogu(context, canliMasa, masaProvider);
                    }
                  }
                : null,
          ),

          // ── İçerik ──
          Expanded(
            child: _sadeceSiparislerModu
                ? _buildSiparislerModu(context, oturum, satisProvider)
                : (compact
                      ? _buildCompactContent(
                          context,
                          oturum,
                          canliMasa,
                          satisProvider,
                        )
                      : _buildNormalContent(
                          context,
                          oturum,
                          canliMasa,
                          satisProvider,
                        )),
          ),
        ],
      ),
    );
  }

  Widget _buildSiparislerModu(
    BuildContext context,
    OturumModel? oturum,
    SatisProvider satisProvider,
  ) {
    if (oturum == null) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Sipariş Detayı',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _sadeceSiparislerModu = false),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: _SiparisListesi(
                satislar: satisProvider.oturumSatislari(oturum.id),
                duzenlenebilir: true,
                onHeaderTap: () {
                  setState(() => _sadeceSiparislerModu = false);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════
  // ── COMPACT / NORMAL İÇERİK OLUŞTURUCULAR ──
  // ══════════════════════════════════════════════════════════

  /// Compact mod: Timer+butonlar sabit, sipariş listesi Expanded
  /// → scroll gerekmez, tüm butonlar her zaman görünür.
  Widget _buildCompactContent(
    BuildContext context,
    OturumModel? oturum,
    MasaModel canliMasa,
    SatisProvider satisProvider,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Aktif Oturum ──
          if (oturum != null && oturum.isAktif) ...[
            _AktifOturumBolumu(
              oturum: oturum,
              masa: canliMasa,
              onBaslangicDegistir: () =>
                  _baslangicSaatiDegistir(context, oturum),
            ),
            const SizedBox(height: 3),
            _AksiyonButonlari(
              oturum: oturum,
              masa: canliMasa,
              onKolDegistir: () => _kolDegistirDialogu(context, oturum),
              onSiparis: () =>
                  SiparisDialogu.goster(context, oturumId: oturum.id),
              onDondur: () => _oturumDondur(context, oturum),
              onSonlandir: () => _oturumSonlandir(context, oturum),
              onIptal: () => _oturumIptalEt(context, oturum),
              onModDegistir: () => _modDegistirDialogu(context, oturum),
              onSureAyarla: oturum.mod == OturumMod.sureli
                  ? () => _sureAyarlaDialogu(context, oturum)
                  : null,
              onSipariseAktarVeYenidenBaslat: () =>
                  _sipariseAktarVeYenidenBaslat(context, oturum),
              onMasaTasi: () => _masaTasiDialogu(context, oturum),
            ),
            const SizedBox(height: 3),
            Expanded(
              child: SingleChildScrollView(
                child: _SiparisListesi(
                  satislar: satisProvider.oturumSatislari(oturum.id),
                  duzenlenebilir: true,
                  onHeaderTap: () =>
                      setState(() => _sadeceSiparislerModu = true),
                ),
              ),
            ),
          ]
          // ── Dondurulmuş Oturum ──
          else if (oturum != null && oturum.isDondurulmus) ...[
            _AktifOturumBolumu(
              oturum: oturum,
              masa: canliMasa,
              onBaslangicDegistir: () =>
                  _baslangicSaatiDegistir(context, oturum),
            ),
            const SizedBox(height: 3),
            _DondurulmusBilgi(),
            const SizedBox(height: 3),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _oturumDevamEt(context, oturum),
                    icon: const Icon(Icons.play_arrow, size: 16),
                    label: const Text('Devam Et'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.masaBos,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _oturumSonlandir(context, oturum),
                    icon: const Icon(Icons.stop, size: 16),
                    label: const Text('Sonlandır'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.masaDolu,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Expanded(
              child: SingleChildScrollView(
                child: _SiparisListesi(
                  satislar: satisProvider.oturumSatislari(oturum.id),
                  duzenlenebilir: true,
                  onHeaderTap: () =>
                      setState(() => _sadeceSiparislerModu = true),
                ),
              ),
            ),
          ]
          // ── Boş Masa ──
          else ...[
            Expanded(
              child: Center(
                child: _BosMasaBolumu(
                  onSureliBaslat: () =>
                      _oturumBaslatDialogu(context, OturumMod.sureli),
                  onSuresizBaslat: () => _suresizOturumBaslatDialogu(context),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Normal (masaüstü) mod: her şey tek ScrollView içinde.
  Widget _buildNormalContent(
    BuildContext context,
    OturumModel? oturum,
    MasaModel canliMasa,
    SatisProvider satisProvider,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Aktif Oturum ──
          if (oturum != null && oturum.isAktif) ...[
            _AktifOturumBolumu(
              oturum: oturum,
              masa: canliMasa,
              onBaslangicDegistir: () =>
                  _baslangicSaatiDegistir(context, oturum),
            ),
            const SizedBox(height: 12),
            _AksiyonButonlari(
              oturum: oturum,
              masa: canliMasa,
              onKolDegistir: () => _kolDegistirDialogu(context, oturum),
              onSiparis: () =>
                  SiparisDialogu.goster(context, oturumId: oturum.id),
              onDondur: () => _oturumDondur(context, oturum),
              onSonlandir: () => _oturumSonlandir(context, oturum),
              onIptal: () => _oturumIptalEt(context, oturum),
              onModDegistir: () => _modDegistirDialogu(context, oturum),
              onSureAyarla: oturum.mod == OturumMod.sureli
                  ? () => _sureAyarlaDialogu(context, oturum)
                  : null,
              onSipariseAktarVeYenidenBaslat: () =>
                  _sipariseAktarVeYenidenBaslat(context, oturum),
              onMasaTasi: () => _masaTasiDialogu(context, oturum),
            ),
            const SizedBox(height: 16),
            _SiparisListesi(
              satislar: satisProvider.oturumSatislari(oturum.id),
              duzenlenebilir: true,
              onHeaderTap: () => setState(() => _sadeceSiparislerModu = true),
            ),
          ]
          // ── Dondurulmuş Oturum ──
          else if (oturum != null && oturum.isDondurulmus) ...[
            _AktifOturumBolumu(
              oturum: oturum,
              masa: canliMasa,
              onBaslangicDegistir: () =>
                  _baslangicSaatiDegistir(context, oturum),
            ),
            const SizedBox(height: 12),
            _DondurulmusBilgi(),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _oturumDevamEt(context, oturum),
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('Devam Et'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.masaBos,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _oturumSonlandir(context, oturum),
                    icon: const Icon(Icons.stop, size: 18),
                    label: const Text('Sonlandır'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.masaDolu,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SiparisListesi(
              satislar: satisProvider.oturumSatislari(oturum.id),
              duzenlenebilir: true,
              onHeaderTap: () => setState(() => _sadeceSiparislerModu = true),
            ),
          ]
          // ── Boş Masa ──
          else ...[
            _BosMasaBolumu(
              onSureliBaslat: () =>
                  _oturumBaslatDialogu(context, OturumMod.sureli),
              onSuresizBaslat: () => _suresizOturumBaslatDialogu(context),
            ),
          ],
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // ── DİALOG METOTLARI (MasaDetayEkrani'ndan taşındı) ──
  // ══════════════════════════════════════════════════════════

  /// Süreli oturum başlatma dialogu (dk veya ₺ ile).
  void _oturumBaslatDialogu(BuildContext context, OturumMod mod) {
    final ayarlar = context.read<AyarlarProvider>();
    final controller = TextEditingController(
      text: ayarlar.varsayilanSureDk.toString(),
    );
    int seciliKolSayisi = 2;
    // false = dakika modu, true = ücret (₺) modu
    bool ucretModu = false;
    // Quick-action buton değerleri — Süre Düzenleme diyaloğuyla aynı pattern
    const List<int> hizliSureler = [60, 90, 120, 150, 180];
    int seciliDk = ayarlar.varsayilanSureDk;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          // ₺ modunda girilen tutardan dk hesapla
          int? hesaplananDk;
          double? girilenTutar;
          if (ucretModu) {
            girilenTutar = double.tryParse(
              controller.text.trim().replaceAll(',', '.'),
            );
            if (girilenTutar != null && girilenTutar > 0) {
              hesaplananDk = ayarlar.butceyiDakikayaCevir(
                girilenTutar,
                masa.konsolTipi,
                seciliKolSayisi,
              );
            }
          }

          return AlertDialog(
            title: const Text('Süreli Oturum'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── dk / ₺ geçiş butonu ──
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<bool>(
                    segments: [
                      ButtonSegment(
                        value: false,
                        icon: const Icon(Icons.timer, size: 16),
                        label: const Text('Dakika'),
                      ),
                      ButtonSegment(
                        value: true,
                        icon: const Icon(Icons.payments_outlined, size: 16),
                        label: Text('Ücret (${ayarlar.paraBirimi})'),
                      ),
                    ],
                    selected: {ucretModu},
                    onSelectionChanged: (s) {
                      setState(() {
                        ucretModu = s.first;
                        controller.clear();
                        if (!ucretModu) {
                          seciliDk = ayarlar.varsayilanSureDk;
                          controller.text = ayarlar.varsayilanSureDk.toString();
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(height: 16),
                // ── Dakika modunda hızlı seçim chip'leri ──
                if (!ucretModu) ...[
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: hizliSureler.map((dk) {
                      final sec = seciliDk == dk;
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
                            seciliDk = dk;
                            controller.text = dk.toString();
                          });
                        },
                        selectedColor:
                            AppColors.primary.withValues(alpha: 0.18),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                ],
                // ── Giriş alanı ──
                TextField(
                  controller: controller,
                  keyboardType: ucretModu
                      ? const TextInputType.numberWithOptions(decimal: true)
                      : TextInputType.number,
                  inputFormatters: ucretModu
                      ? [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*[.,]?\d*'),
                          ),
                        ]
                      : [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: ucretModu
                        ? 'Tutar (${ayarlar.paraBirimi})'
                        : 'Süre (dakika)',
                    border: const OutlineInputBorder(),
                    suffixText: ucretModu ? ayarlar.paraBirimi : 'dk',
                    prefixIcon: Icon(
                      ucretModu ? Icons.payments_outlined : Icons.timer,
                    ),
                  ),
                  autofocus: true,
                  onChanged: (v) {
                    if (!ucretModu) {
                      final val = int.tryParse(v);
                      setState(() => seciliDk = val ?? 0);
                    } else {
                      setState(() {});
                    }
                  },
                ),
                // ── ₺ modunda hesaplanan süre bilgisi ──
                if (ucretModu && hesaplananDk != null && hesaplananDk > 0) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade300),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.access_time,
                          size: 16,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '≈ $hesaplananDk dakika',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                            fontSize: 14,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          ayarlar.ucretGosterimMetni(
                            masa.konsolTipi,
                            seciliKolSayisi,
                          ),
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textS(ctx),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (ucretModu &&
                    girilenTutar != null &&
                    hesaplananDk != null &&
                    hesaplananDk <= 0) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Bu tutar yeterli süre karşılamıyor.',
                      style: TextStyle(color: AppColors.error, fontSize: 12),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                _KolSecici(
                  kolSayisi: seciliKolSayisi,
                  konsolTipi: masa.konsolTipi,
                  onChanged: (v) => setState(() => seciliKolSayisi = v),
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
                  if (ucretModu) {
                    // ₺ modu: tutardan dk hesapla
                    final tutar = double.tryParse(
                      controller.text.trim().replaceAll(',', '.'),
                    );
                    final dk = tutar != null && tutar > 0
                        ? ayarlar.butceyiDakikayaCevir(
                            tutar,
                            masa.konsolTipi,
                            seciliKolSayisi,
                          )
                        : 0;
                    if (dk < ayarlar.minimumSureDk) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Hesaplanan süre minimum ${ayarlar.minimumSureDk} dk olmalı.',
                          ),
                        ),
                      );
                      return;
                    }
                    Navigator.of(ctx).pop();
                    _oturumBaslat(context, mod, dk, seciliKolSayisi, tutar);
                  } else {
                    // dk modu: chip veya manuel girdi kullan
                    final girilmis = int.tryParse(controller.text.trim());
                    final sonucDk = girilmis ?? seciliDk;
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
                  }
                },
                child: const Text('Başlat'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Süresiz oturum başlatma dialogu.
  void _suresizOturumBaslatDialogu(BuildContext context) {
    int seciliKolSayisi = 2;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Süresiz Oturum'),
          content: _KolSecici(
            kolSayisi: seciliKolSayisi,
            konsolTipi: masa.konsolTipi,
            onChanged: (v) => setState(() => seciliKolSayisi = v),
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

  /// Oturum başlat.
  /// 🚀 Optimistic UI: masa kartı ve sidebar anında güncellenir,
  /// Supabase yazımı arka planda tamamlanır — ekran donmaz.
  Future<void> _oturumBaslat(
    BuildContext context,
    OturumMod mod,
    int? sureDk, [
    int kolSayisi = 2,
    double? butce,
  ]) async {
    final oturumProvider = context.read<OturumProvider>();
    final masaProvider = context.read<MasaProvider>();
    final ayarlar = context.read<AyarlarProvider>();

    // Context kapanmadan önce tüm değerleri kopyala
    final masaId = masa.id;

    // 1️⃣ Lokal optimistic oturum oluştur — DB beklenmeden listeye eklenir
    final simdi = DateTime.now();
    final optimistikOturum = OturumModel(
      id: const Uuid().v4(),
      masaId: masaId,
      baslangic: simdi,
      mod: mod,
      sureDk: sureDk,
      tutar: 0,
      durum: OturumDurum.aktif,
      kolSayisi: kolSayisi,
      kolGecmisi: [KolSegment(kolSayisi: kolSayisi, baslangic: simdi)],
      butce: butce,
    );
    oturumProvider.oturumBaslatLokalde(optimistikOturum); // sidebar anında aktif moda geçer
    masaProvider.durumGuncelleLokalde(masaId, MasaDurum.dolu); // kart anında yeşile döner

    // 2️⃣ Kullanıcıya anında geri bildirim (context hâlâ geçerli, async gap yok)
    if (context.mounted) {
      final mesaj = butce != null
          ? 'Oturum başlatıldı! (Bütçe: ${ayarlar.paraBirimi}${butce.toStringAsFixed(0)})'
          : 'Oturum başlatıldı!';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mesaj)));
    }

    // 3️⃣ Arka planda DB'ye yaz — UI'ı bloklamaz
    unawaited(Future.microtask(() async {
      try {
        final basarili = await oturumProvider.oturumBaslat(
          masaId: masaId,
          mod: mod,
          sureDk: sureDk,
          kolSayisi: kolSayisi,
          butce: butce,
        );
        if (basarili) {
          // DB onaylandı: kart durumunu DB'ye de kaydet
          await masaProvider.durumGuncelle(masaId, MasaDurum.dolu);
        } else {
          // DB başarısız: lokal state'i geri al
          oturumProvider.oturumSonlandirLokalde(optimistikOturum.id);
          masaProvider.durumGuncelleLokalde(masaId, MasaDurum.bos);
          rootScaffoldMessengerKey.currentState?.showSnackBar(
            const SnackBar(
              content: Text('⚠ Oturum başlatılamadı, lütfen tekrar deneyin.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      } catch (e) {
        // Ağ hatası: lokal state'i geri al
        oturumProvider.oturumSonlandirLokalde(optimistikOturum.id);
        masaProvider.durumGuncelleLokalde(masaId, MasaDurum.bos);
        rootScaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text('⚠ Oturum başlatılamadı: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }));
  }

  /// Kol sayısı değiştir dialogu.
  void _kolDegistirDialogu(BuildContext context, OturumModel oturum) {
    int yeniKolSayisi = oturum.kolSayisi;
    final ayarlar = context.read<AyarlarProvider>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          // Bütçeli oturumlarda yeni kol için kalan süre preview'ı (dilimli)
          String? butceOnizleme;
          if (oturum.butce != null &&
              oturum.butce! > 0 &&
              oturum.mod == OturumMod.sureli &&
              yeniKolSayisi != oturum.kolSayisi) {
            // Tüm segmentleri dilimli hesapla
            final sonuc = SureHesaplamaServisi.butceHarcamaHesapla(
              kolGecmisi: oturum.kolGecmisi,
              efektifSure: oturum.gecenSure,
              dakikaBasiUcretResolver: (kol) =>
                  ayarlar.konsolDakikaBasiUcretHesapla(masa.konsolTipi, kol),
              fallbackKolSayisi: oturum.kolSayisi,
              periyotDk: SureHesaplamaServisi.efektifPeriyot(oturum.butce, ayarlar.guncellemePeriyoduDk, oturum.mod),
            );

            final kalanButce = (oturum.butce! - sonuc.harcananTutar).clamp(
              0.0,
              oturum.butce!,
            );
            final yeniDkBasiUcret = ayarlar.konsolDakikaBasiUcretHesapla(
              masa.konsolTipi,
              yeniKolSayisi,
            );
            final butcedenKalanDk = yeniDkBasiUcret > 0
                ? (kalanButce / yeniDkBasiUcret).floor()
                : 0;
            final toplamKalanDk = butcedenKalanDk + sonuc.kalanFazlaDk;
            butceOnizleme =
                'Bütçe: ${ayarlar.paraBirimi}${oturum.butce!.toStringAsFixed(0)} · '
                'Harcanan: ${ayarlar.paraBirimi}${sonuc.harcananTutar.toStringAsFixed(0)} · '
                'Kalan: ≈$toplamKalanDk dk';
          }

          return AlertDialog(
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
                      onPressed: yeniKolSayisi < 8
                          ? () => setState(() => yeniKolSayisi++)
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  ayarlar.ucretGosterimMetni(masa.konsolTipi, yeniKolSayisi),
                  style: TextStyle(fontSize: 12, color: AppColors.textS(ctx)),
                ),
                const SizedBox(height: 8),
                // Bütçeli oturumlarda kalan süre önizlemesi
                if (butceOnizleme != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.account_balance_wallet,
                          size: 14,
                          color: Colors.orange.shade700,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            butceOnizleme,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.orange.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
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
          );
        },
      ),
    );
  }

  Future<void> _kolDegistir(
    BuildContext context,
    OturumModel oturum,
    int yeniKol,
  ) async {
    final oturumProvider = context.read<OturumProvider>();
    final ayarlar = context.read<AyarlarProvider>();

    // Bütçeli oturumlar için resolver geç
    double Function(int kolSayisi)? resolver;
    if (oturum.butce != null && oturum.butce! > 0) {
      resolver = (kol) =>
          ayarlar.konsolDakikaBasiUcretHesapla(masa.konsolTipi, kol);
    }

    final basarili = await oturumProvider.kolSayisiDegistir(
      oturum.id,
      yeniKol,
      dakikaBasiUcretResolver: resolver,
      periyotDk: SureHesaplamaServisi.efektifPeriyot(oturum.butce, ayarlar.guncellemePeriyoduDk, oturum.mod),
    );
    if (basarili && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kol sayısı $yeniKol olarak güncellendi.')),
      );
    }
  }

  /// Oturum dondur.
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

  /// Oturum devam et.
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

  // ── Mod Değiştir ──

  /// Oturum modunu değiştir (süresiz↔süreli).
  void _modDegistirDialogu(BuildContext context, OturumModel oturum) {
    if (oturum.mod == OturumMod.suresiz) {
      // Süresiz → Süreli: Süre girişi isteyeceğiz
      _suresizdenSureliyeDialogu(context, oturum);
    } else {
      // Süreli → Süresiz: Onay dialogu
      _surelidenSuresizeDialogu(context, oturum);
    }
  }

  /// Süresiz → Süreli geçiş dialogu (toplam süre girişi).
  void _suresizdenSureliyeDialogu(BuildContext context, OturumModel oturum) {
    final gecenDk = oturum.gecenSure.inMinutes;
    int? secilenDk;
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final toplam = secilenDk;
          final kalan = toplam != null ? toplam - gecenDk : null;
          final gecerli = toplam != null && toplam > gecenDk;

          return Dialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 16,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: SizedBox(
              width: 300,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Başlık
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.withValues(alpha: 0.1),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(14),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.timer,
                          color: Colors.deepPurple,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Süreli Moda Geç',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$gecenDk dk oynandı',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.deepPurple,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Toplam oturum süresini seçin. Kalan süre dolunca oturum kapanır.',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textS(ctx),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [30, 60, 90, 120, 180].map((dk) {
                            final sec = secilenDk == dk;
                            final uygun = dk > gecenDk;
                            return ChoiceChip(
                              label: Text(
                                '$dk dk',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: sec
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              selected: sec,
                              onSelected: uygun
                                  ? (_) {
                                      setState(() {
                                        secilenDk = dk;
                                        controller.text = dk.toString();
                                      });
                                    }
                                  : null,
                              selectedColor: Colors.deepPurple.withValues(
                                alpha: 0.18,
                              ),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 40,
                          child: TextField(
                            controller: controller,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            autofocus: false,
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Süre (dk)',
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
                              setState(() => secilenDk = val);
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (gecerli)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.green.shade300),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Kalan süre:',
                                  style: TextStyle(fontSize: 12),
                                ),
                                Text(
                                  '~$kalan dk',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (toplam != null && !gecerli)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Süre en az ${gecenDk + 1} dk olmalı.',
                              style: const TextStyle(
                                color: AppColors.error,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () => Navigator.of(ctx).pop(),
                                child: const Text('İptal'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FilledButton(
                                onPressed: gecerli
                                    ? () {
                                        Navigator.of(ctx).pop();
                                        _modDegistirUygula(
                                          context,
                                          oturum,
                                          OturumMod.sureli,
                                          sureDk: secilenDk!,
                                        );
                                      }
                                    : null,
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.deepPurple,
                                ),
                                child: const Text('Uygula'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Süreli → Süresiz geçiş onay dialogu.
  void _surelidenSuresizeDialogu(BuildContext context, OturumModel oturum) {
    final kalanDk = (oturum.sureDk ?? 0) - oturum.gecenSure.inMinutes;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Süresiz Moda Geç'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.all_inclusive, size: 48, color: Colors.deepPurple),
            const SizedBox(height: 12),
            Text(
              'Kalan süre: ~$kalanDk dk\n'
              'Süresiz moda geçildiğinde süre sınırı kaldırılır\n'
              've oturum manuel kapatılana kadar devam eder.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13),
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
              _modDegistirUygula(context, oturum, OturumMod.suresiz);
            },
            child: const Text('Süresiz Yap'),
          ),
        ],
      ),
    );
  }

  /// Mod değiştirme işlemi uygula.
  Future<void> _modDegistirUygula(
    BuildContext context,
    OturumModel oturum,
    OturumMod yeniMod, {
    int? sureDk,
  }) async {
    final oturumProvider = context.read<OturumProvider>();
    final basarili = await oturumProvider.modDegistir(
      oturum.id,
      yeniMod,
      sureDk: sureDk,
    );
    if (basarili && context.mounted) {
      final modLabel = yeniMod == OturumMod.suresiz ? 'süresiz' : 'süreli';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Oturum $modLabel moda geçirildi.')),
      );
    }
  }

  // ── Süre Ayarla ──

  /// Süreli oturumun süresine ekleme/çıkarma dialogu. Bütçeli ise Para(₺) veya Dakika eklenebilir.
  void _sureAyarlaDialogu(BuildContext context, OturumModel oturum) {
    final isButceli = oturum.butce != null && oturum.mod == OturumMod.sureli;
    final mevcutSureDk = oturum.sureDk ?? 0;
    final gecenDk = oturum.gecenSure.inMinutes;
    final kalanDk = mevcutSureDk - gecenDk;
    
    final ayarlar = context.read<AyarlarProvider>();
    final masaProvider = context.read<MasaProvider>();
    String konsolTipi = 'PS5';
    try {
      konsolTipi = masaProvider.masalar.firstWhere((m) => m.id == oturum.masaId).konsolTipi;
    } catch (_) {}
    final dkBasiUcret = ayarlar.konsolDakikaBasiUcretHesapla(konsolTipi, oturum.kolSayisi);

    bool isParaModu = isButceli; // Bütçeli ise Tutar seçili başlasın
    int miktar = isParaModu ? 50 : 30; // başlangıç miktar (her zaman pozitif)
    bool isEkle = true; // işlem yönü
    final controller = TextEditingController(text: isParaModu ? '50' : '30');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final etki = isEkle ? miktar : -miktar;
          
          int ekstraDk;
          double ekstraButce;
          
          if (isParaModu) {
            ekstraButce = etki.toDouble();
            ekstraDk = dkBasiUcret > 0 ? (etki / dkBasiUcret).floor() : 0;
          } else {
            ekstraDk = etki;
            ekstraButce = isButceli ? (etki * dkBasiUcret) : 0.0;
          }
          
          final yeniToplam = mevcutSureDk + ekstraDk;
          final yeniKalan = yeniToplam - gecenDk;
          
          final yeniButce = isButceli ? (oturum.butce! + ekstraButce) : 0.0;
          
          final gecerli = miktar > 0 && yeniKalan > 0 && (!isButceli || yeniButce > 0);

          return Dialog(
             insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
             child: SizedBox(
               width: 300,
               child: Column(
                 mainAxisSize: MainAxisSize.min,
                 crossAxisAlignment: CrossAxisAlignment.stretch,
                 children: [
                   // Başlık
                   Container(
                     padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                     decoration: BoxDecoration(
                       color: Colors.teal.withValues(alpha: 0.1),
                       borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                     ),
                     child: Row(
                       children: [
                         const Icon(Icons.edit_calendar, color: Colors.teal, size: 18),
                         const SizedBox(width: 6),
                         Text(
                           isButceli ? 'Kredi / Süre Düzenleme' : 'Süre Düzenleme',
                           style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                         ),
                         const Spacer(),
                         Column(
                           crossAxisAlignment: CrossAxisAlignment.end,
                           children: [
                             if (isButceli)
                               Text(
                                 'Kredi: ${Formatters.para(oturum.butce!)}',
                                 style: const TextStyle(fontSize: 10, color: Colors.teal, fontWeight: FontWeight.w600),
                               )
                             else
                               Text(
                                 'Toplam $mevcutSureDk dk',
                                 style: const TextStyle(fontSize: 10, color: Colors.teal, fontWeight: FontWeight.w600),
                               ),
                             Text(
                               'Kalan ~$kalanDk dk',
                               style: TextStyle(fontSize: 10, color: kalanDk <= 5 ? AppColors.error : AppColors.textS(ctx)),
                             ),
                           ],
                         ),
                       ],
                     ),
                   ),
                   Padding(
                     padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                     child: Column(
                       mainAxisSize: MainAxisSize.min,
                       crossAxisAlignment: CrossAxisAlignment.stretch,
                       children: [
                         // Mod Seçimi (Tutar veya Dakika)
                         if (isButceli) ...[
                           SizedBox(
                             height: 32, // Daha sıkı bir yükseklik
                             child: SegmentedButton<bool>(
                               style: SegmentedButton.styleFrom(
                                 visualDensity: VisualDensity.compact,
                                 textStyle: const TextStyle(fontSize: 12),
                               ),
                               segments: const [
                                 ButtonSegment(value: true, label: Text('Tutar (₺)')),
                                 ButtonSegment(value: false, label: Text('Dakika (dk)')),
                               ],
                               selected: {isParaModu},
                               onSelectionChanged: (set) {
                                 setState(() {
                                   isParaModu = set.first;
                                   miktar = isParaModu ? 50 : 30;
                                   controller.text = miktar.toString();
                                 });
                               },
                             ),
                           ),
                           const SizedBox(height: 10),
                         ],
                         // Miktar chip'leri + input yan yana
                         Wrap(
                           spacing: 6,
                           runSpacing: 4,
                           alignment: WrapAlignment.center,
                           children: (isParaModu ? [20, 50, 100, 200] : [15, 30, 60, 90]).map((deger) {
                             final sec = miktar == deger;
                             return ChoiceChip(
                               label: Text(
                                 isParaModu ? '₺$deger' : '$deger dk',
                                 style: TextStyle(fontSize: 12, fontWeight: sec ? FontWeight.bold : FontWeight.normal),
                               ),
                               selected: sec,
                               onSelected: (_) {
                                 setState(() {
                                   miktar = deger;
                                   controller.text = deger.toString();
                                 });
                               },
                               selectedColor: Colors.teal.withValues(alpha: 0.18),
                               visualDensity: VisualDensity.compact,
                               materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                             );
                           }).toList(),
                         ),
                         const SizedBox(height: 8),
                         SizedBox(
                           height: 40,
                           child: TextField(
                             controller: controller,
                             keyboardType: TextInputType.number,
                             inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                             style: const TextStyle(fontSize: 13),
                             decoration: InputDecoration(
                               hintText: isParaModu ? 'Tutar' : 'Dakika',
                               suffixText: isParaModu ? '₺' : 'dk',
                               isDense: true,
                               contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                               border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                             ),
                             onChanged: (v) {
                               final val = int.tryParse(v);
                               setState(() => miktar = val ?? 0);
                             },
                           ),
                         ),
                         const SizedBox(height: 8),
                         // Ekle / Çıkar — kompakt
                         Row(
                           children: [
                             Expanded(
                               child: _islemButonu(
                                 ctx: ctx,
                                 label: 'Ekle',
                                 ikon: Icons.add_circle_outline,
                                 renk: Colors.teal,
                                 secili: isEkle,
                                 onTap: () => setState(() => isEkle = true),
                               ),
                             ),
                             const SizedBox(width: 6),
                             Expanded(
                               child: _islemButonu(
                                 ctx: ctx,
                                 label: 'Çıkar',
                                 ikon: Icons.remove_circle_outline,
                                 renk: Colors.red.shade600,
                                 secili: !isEkle,
                                 onTap: () => setState(() => isEkle = false),
                               ),
                             ),
                           ],
                         ),
                         const SizedBox(height: 8),
                         // Önizleme — kompakt
                         Container(
                           padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                           decoration: BoxDecoration(
                             color: gecerli
                                 ? (isEkle ? Colors.teal.withValues(alpha: 0.08) : Colors.orange.withValues(alpha: 0.08))
                                 : AppColors.error.withValues(alpha: 0.08),
                             borderRadius: BorderRadius.circular(6),
                             border: Border.all(
                               color: gecerli
                                   ? (isEkle ? Colors.teal.shade300 : Colors.orange.shade300)
                                   : AppColors.error,
                             ),
                           ),
                           child: Row(
                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
                             children: [
                               if (isButceli)
                                 Text(
                                   gecerli ? (isEkle ? '₺${oturum.butce} + ₺${ekstraButce.toInt()}' : '₺${oturum.butce} − ₺${ekstraButce.abs().toInt()}') : 'Geçersiz',
                                   style: TextStyle(fontSize: 11, color: gecerli ? AppColors.textS(ctx) : AppColors.error),
                                 )
                               else
                                 Text(
                                   gecerli ? (isEkle ? '$mevcutSureDk + $ekstraDk' : '$mevcutSureDk − ${ekstraDk.abs()}') : 'Geçersiz',
                                   style: TextStyle(fontSize: 11, color: gecerli ? AppColors.textS(ctx) : AppColors.error),
                                 ),
                               Text(
                                 gecerli ? '→ $yeniToplam dk (~$yeniKalan kalan)' : '',
                                 style: TextStyle(
                                   fontWeight: FontWeight.bold,
                                   fontSize: 12,
                                   color: gecerli ? (isEkle ? Colors.teal : Colors.orange.shade700) : AppColors.error,
                                 ),
                               ),
                             ],
                           ),
                         ),
                         const SizedBox(height: 10),
                         Row(
                           children: [
                             Expanded(
                               child: TextButton(
                                 onPressed: () => Navigator.of(ctx).pop(),
                                 child: const Text('İptal'),
                               ),
                             ),
                             const SizedBox(width: 8),
                             Expanded(
                               child: FilledButton(
                                 onPressed: gecerli
                                     ? () {
                                         Navigator.of(ctx).pop();
                                         if (isButceli) {
                                           _sureVeButceAyarlaUygula(context, oturum, ekstraDk, ekstraButce);
                                         } else {
                                           _sureAyarlaUygula(context, oturum, ekstraDk);
                                         }
                                       }
                                     : null,
                                 style: FilledButton.styleFrom(
                                   backgroundColor: isEkle ? Colors.teal : Colors.red.shade600,
                                 ),
                                 child: const Text('Uygula'),
                               ),
                             ),
                           ],
                         ),
                       ],
                     ),
                   ),
                 ],
               ),
             ),
           );
        },
      ),
    );
  }

  /// Ekle/Çıkar işlem seçim butonu.
  Widget _islemButonu({
    BuildContext? ctx,
    required String label,
    required IconData ikon,
    required Color renk,
    required bool secili,
    required VoidCallback onTap,
  }) {
    final c = ctx ?? context;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: secili ? renk.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: secili ? renk : AppColors.textS(c).withValues(alpha: 0.3),
            width: secili ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(ikon, size: 16, color: secili ? renk : AppColors.textS(c)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontWeight: secili ? FontWeight.bold : FontWeight.normal,
                color: secili ? renk : AppColors.textS(c),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Süre ve Bütçe ayarlama işlemi uygula (Ücretli Oturumlar için).
  Future<void> _sureVeButceAyarlaUygula(
    BuildContext context,
    OturumModel oturum,
    int ekstraDk,
    double ekstraButce,
  ) async {
    final oturumProvider = context.read<OturumProvider>();
    final basarili = await oturumProvider.sureVeButceAyarla(oturum.id, ekstraDk, ekstraButce);
    if (basarili && context.mounted) {
      final islem = ekstraButce > 0
          ? '+${Formatters.para(ekstraButce)} eklendi (+$ekstraDk dk)'
          : '${Formatters.para(ekstraButce.abs())} çıkarıldı (${ekstraDk.abs()} dk)';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Kredi ve süre güncellendi: $islem')));
    }
  }

  /// Süre ayarlama işlemi uygula.
  Future<void> _sureAyarlaUygula(
    BuildContext context,
    OturumModel oturum,
    int ekstraDk,
  ) async {
    final oturumProvider = context.read<OturumProvider>();
    final basarili = await oturumProvider.sureAyarla(oturum.id, ekstraDk);
    if (basarili && context.mounted) {
      final islem = ekstraDk > 0
          ? '+$ekstraDk dk eklendi'
          : '${ekstraDk.abs()} dk çıkarıldı';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Süre güncellendi: $islem')));
    }
  }

  /// Oturum sonlandır (ödeme dialogu ile).
  /// 🔒 Çift-tıklama kilidi: `_isClosing` metot GİRİŞİNDE set edilir (dialog öncesi).
  /// 🚀 Ateşle-unut: Dialog onaylandıktan sonra UI anında güncellenir,
  ///    Supabase yazımları arka planda tamamlanır.
  Future<void> _oturumSonlandir(
    BuildContext context,
    OturumModel oturum,
  ) async {
    // 🔒 Kesinlikle ilk satır: dialog açılmadan ÖNCE kilitle
    // Bu sayede çift-tıklamada ikinci çağrı anında engellenir
    if (_isClosing) return;
    setState(() => _isClosing = true);

    final oturumProvider = context.read<OturumProvider>();
    final masaProvider = context.read<MasaProvider>();
    final satisProvider = context.read<SatisProvider>();
    final ayarlar = context.read<AyarlarProvider>();
    final raporProvider = context.read<RaporProvider>();

    final siparisToplami = satisProvider
        .oturumSatislari(oturum.id)
        .fold<double>(0, (t, s) => t + s.toplamTutar);

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

    if (!context.mounted) {
      if (mounted) setState(() => _isClosing = false);
      return;
    }
    final odemeResult = await _odemeDialoguGoster(
      context,
      konsolUcreti: tahminiZaman,
      kolEkstraUcreti: kolEkstra,
      siparisUcreti: siparisToplami,
      toplamTutar: tahminiToplam,
      kolSayisi: oturum.kolSayisi,
      gecenSure: oturum.gecenSure,
    );

    // Kullanıcı ödeme dialogunu iptal etti → kilidi serbest bırak
    if (odemeResult == null) {
      if (mounted) setState(() => _isClosing = false);
      return;
    }

    if (!mounted) return;

    // ── 🚀 OPTİMİSTİK UI: tüm değerleri context kapanmadan kopyala ──
    // Widget unmount olduktan sonra bu final değişkenler fire-and-forget
    // closure'ı içinde güvenle kullanılabilir (context erişimi YOK).
    final oturumId = oturum.id;
    final masaId = masa.id;
    final masaAd = masa.ad;
    final konsolTipi = masa.konsolTipi;
    final baslangic = oturum.baslangic;
    final bitis = DateTime.now();
    final oynananDk = oturum.gecenSure.inMinutes;
    final kolSayisi = oturum.kolSayisi;
    final kolGecmisiKayit = oturum.kolGecmisi
        .map((s) => KolGecmisiKayit(kolSayisi: s.kolSayisi, baslangic: s.baslangic))
        .toList();
    final zamanUcreti = tahminiZaman;
    final genelToplam = tahminiToplam;
    final tahsilEdilen = odemeResult.tahsilEdilenTutar;
    final odemeYontemi = odemeResult.yontem;
    final nakitTutar = odemeResult.nakitTutar;
    final kartTutar = odemeResult.kartTutar;
    final aciklama = (genelToplam - tahsilEdilen).abs() > 0.01
        ? 'Not: Toplam: ${Formatters.para(genelToplam)}, Tahsil Edilen: ${Formatters.para(tahsilEdilen)}'
        : '';

    // 1️⃣ Lokal state anında güncelle — kullanıcı sıfır bekleme
    oturumProvider.oturumSonlandirLokalde(oturumId);
    masaProvider.durumGuncelleLokalde(masaId, MasaDurum.bos);

    // 2️⃣ Sidebar anında kapat — bu widget unmount olur (context artık geçersiz)
    onKapat();

    // 3️⃣ Supabase yazımları ARKA PLANDA — UI'ı bloklamaz, context kullanılmaz
    unawaited(Future.microtask(() async {
      try {
        // DB: oturum tutarını kaydet (lokal removeWhere zaten yapıldı, harmless)
        await oturumProvider.oturumSonlandirTutarli(oturumId, zamanUcreti);

        // DB: rapor oluştur
        await raporProvider.raporOlustur(
          oturumId: oturumId,
          masaId: masaId,
          masaAd: masaAd,
          konsolTipi: konsolTipi,
          baslangic: baslangic,
          bitis: bitis,
          oynananDk: oynananDk,
          kolSayisi: kolSayisi,
          konsolUcreti: zamanUcreti,
          kolEkstraUcreti: kolEkstra,
          siparisUcreti: siparisToplami,
          toplamTutar: tahsilEdilen,
          aciklama: aciklama,
          odemeYontemi: odemeYontemi,
          nakitTutar: nakitTutar,
          kartTutar: kartTutar,
          kolGecmisi: kolGecmisiKayit,
        );

        // DB: masa durumunu kalıcı hale getir
        await masaProvider.durumGuncelle(masaId, MasaDurum.bos);

        // Başarı bildirimi — context yok, global key kullan
        rootScaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    'Oturum tamamlandı — ${Formatters.para(genelToplam)} (${odemeYontemi.label})',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade600.withValues(alpha: 0.9),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      } catch (e) {
        // DB hatası: lokal state'i geri al (masa tekrar dolu görünür)
        masaProvider.durumGuncelleLokalde(masaId, MasaDurum.dolu);
        rootScaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text('⚠ Raporlama hatası: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }));
  }

  /// Ödeme yöntemi seçme dialogu.
  /// 🔒 `isSubmitting` kilidi: "Onayla & Kapat" butonu sadece bir kez tetiklenir.
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
    // 🔒 Çift-tıklama koruması: dialog kapanana kadar true
    bool isSubmitting = false;

    return showDialog<_OdemeSecimi>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final isCompact = MediaQuery.of(ctx).size.height < 600;

          return AlertDialog(
            insetPadding: isCompact
                ? const EdgeInsets.symmetric(horizontal: 16, vertical: 8)
                : const EdgeInsets.symmetric(horizontal: 40.0, vertical: 24.0),
            titlePadding: isCompact
                ? const EdgeInsets.fromLTRB(16, 12, 16, 4)
                : null,
            contentPadding: isCompact
                ? const EdgeInsets.symmetric(horizontal: 16, vertical: 4)
                : null,
            actionsPadding: isCompact
                ? const EdgeInsets.fromLTRB(16, 4, 16, 12)
                : null,
            title: Text(
              'Ödeme & Sonlandır',
              style: TextStyle(fontSize: isCompact ? 16 : 18),
            ),
            content: SizedBox(
              width: 380,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isCompact) ...[
                      const Icon(
                        Icons.check_circle,
                        color: AppColors.success,
                        size: 40,
                      ),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Konsol Ücreti:',
                          style: TextStyle(fontSize: isCompact ? 12 : 13),
                        ),
                        Text(
                          Formatters.para(konsolUcreti),
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: isCompact ? 12 : 13,
                          ),
                        ),
                      ],
                    ),
                    if (kolEkstraUcreti > 0) ...[
                      SizedBox(height: isCompact ? 0 : 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Kol Ekstra ($kolSayisi kol):',
                            style: TextStyle(fontSize: isCompact ? 12 : 13),
                          ),
                          Text(
                            Formatters.para(kolEkstraUcreti),
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: isCompact ? 12 : 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (siparisUcreti > 0) ...[
                      SizedBox(height: isCompact ? 0 : 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Kafeterya:',
                            style: TextStyle(fontSize: isCompact ? 12 : 13),
                          ),
                          Text(
                            Formatters.para(siparisUcreti),
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: isCompact ? 12 : 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                    Divider(height: isCompact ? 8 : 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TOPLAM HESAP',
                              style: TextStyle(
                                fontSize: isCompact ? 11 : 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              Formatters.para(toplamTutar),
                              style: TextStyle(
                                fontSize: isCompact ? 16 : 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.success,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'SÜRE',
                              style: TextStyle(
                                fontSize: isCompact ? 10 : 10,
                                color: AppColors.textS(ctx),
                              ),
                            ),
                            Text(
                              Formatters.sureDuration(gecenSure),
                              style: TextStyle(
                                fontSize: isCompact ? 12 : 14,
                                color: AppColors.textS(ctx),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: isCompact ? 8 : 12),
                    // Tahsil Edilen Tutar Alanı
                    TextField(
                      controller: tahsilEdilenController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: TextStyle(fontSize: isCompact ? 13 : 14),
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: 'Tahsil Edilen (₺)',
                        border: OutlineInputBorder(
                           borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.attach_money, size: 20),
                        filled: true,
                        fillColor: AppColors.primary.withValues(alpha: 0.1),
                        contentPadding: isCompact
                            ? const EdgeInsets.symmetric(horizontal: 4, vertical: 8)
                            : null,
                      ),
                      onChanged: (val) {
                         setState(() {
                            guncelTahsilEdilen = double.tryParse(val.replaceAll(',', '.')) ?? toplamTutar;
                            parcaliHata = null;
                         });
                      },
                    ),
                    SizedBox(height: isCompact ? 8 : 20),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Ödeme Yöntemi',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: isCompact ? 12 : 13,
                        ),
                      ),
                    ),
                    SizedBox(height: isCompact ? 4 : 6),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<OdemeYontemi>(
                        style: SegmentedButton.styleFrom(
                          padding: isCompact ? EdgeInsets.zero : null,
                          visualDensity: isCompact
                              ? VisualDensity.compact
                              : null,
                        ),
                        segments: [
                          ButtonSegment(
                            value: OdemeYontemi.nakit,
                            label: Text(
                              'Nakit',
                              style: TextStyle(fontSize: isCompact ? 11 : 14),
                            ),
                            icon: isCompact
                                ? null
                                : const Icon(Icons.money, size: 20),
                          ),
                          ButtonSegment(
                            value: OdemeYontemi.kart,
                            label: Text(
                              'Kart',
                              style: TextStyle(fontSize: isCompact ? 11 : 14),
                            ),
                            icon: isCompact
                                ? null
                                : const Icon(Icons.credit_card, size: 20),
                          ),
                          ButtonSegment(
                            value: OdemeYontemi.parcali,
                            label: Text(
                              'Parçalı',
                              style: TextStyle(fontSize: isCompact ? 11 : 14),
                            ),
                            icon: isCompact
                                ? null
                                : const Icon(Icons.call_split, size: 20),
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
                    ),
                    if (seciliYontem == OdemeYontemi.parcali) ...[
                      SizedBox(height: isCompact ? 6 : 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: nakitController,
                              style: TextStyle(fontSize: isCompact ? 13 : 14),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d*\.?\d*'),
                                ),
                              ],
                              textAlign: TextAlign.center,
                              decoration: InputDecoration(
                                isDense: true,
                                hintText: 'Nakit ₺',
                                hintStyle: TextStyle(
                                  fontSize: isCompact ? 12 : 14,
                                  color: AppColors.textS(ctx),
                                ),
                                border: const OutlineInputBorder(),
                                contentPadding: isCompact
                                    ? const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 8,
                                      )
                                    : null,
                              ),
                              onChanged: (_) {
                                setState(() {
                                  parcaliHata = null;
                                  final n =
                                      double.tryParse(
                                        nakitController.text.replaceAll(',', '.'),
                                      ) ??
                                      0;
                                  final kalan = guncelTahsilEdilen - n;
                                  if (kalan >= 0) {
                                    kartController.text = kalan.toStringAsFixed(
                                      2,
                                    );
                                  }
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: kartController,
                              style: TextStyle(fontSize: isCompact ? 13 : 14),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d*\.?\d*'),
                                ),
                              ],
                              textAlign: TextAlign.center,
                              decoration: InputDecoration(
                                isDense: true,
                                hintText: 'Kart ₺',
                                hintStyle: TextStyle(
                                  fontSize: isCompact ? 12 : 14,
                                  color: AppColors.textS(ctx),
                                ),
                                border: const OutlineInputBorder(),
                                contentPadding: isCompact
                                    ? const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 8,
                                      )
                                    : null,
                              ),
                              onChanged: (_) {
                                setState(() {
                                  parcaliHata = null;
                                  final k =
                                      double.tryParse(
                                        kartController.text.replaceAll(',', '.'),
                                      ) ??
                                      0;
                                  final kalan = guncelTahsilEdilen - k;
                                  if (kalan >= 0) {
                                    nakitController.text = kalan
                                        .toStringAsFixed(2);
                                  }
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      if (parcaliHata != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          parcaliHata!,
                          style: const TextStyle(
                            color: AppColors.error,
                            fontSize: 11,
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
                // 🔒 isSubmitting=true iken buton null callback → fiziksel olarak devre dışı
                onPressed: isSubmitting
                    ? null
                    : () {
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
                        // 🔒 Kilitle — çift pop'u engelle
                        setState(() => isSubmitting = true);
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

  /// Oturum iptal et.
  /// 🔒 Dialog onay butonunda çift-tık kilidi.
  /// 🚀 Ateşle-unut: onay sonrası UI anında kapanır, DB arka planda silinir.
  Future<void> _oturumIptalEt(BuildContext context, OturumModel oturum) async {
    // 🔒 Zaten bir kapama işlemi varsa engelle
    if (_isClosing) return;

    // Provider referanslarını async gap ÖNCESİNDE al (use_build_context_synchronously)
    final oturumProvider = context.read<OturumProvider>();
    final masaProvider = context.read<MasaProvider>();

    bool isIptalSubmitting = false;

    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
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
              // 🔒 Çift-tık koruması
              onPressed: isIptalSubmitting
                  ? null
                  : () {
                      setDlgState(() => isIptalSubmitting = true);
                      Navigator.of(ctx).pop(true);
                    },
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              child: const Text('İptal Et'),
            ),
          ],
        ),
      ),
    );

    if (onay != true || !mounted) return;

    setState(() => _isClosing = true);

    final oturumId = oturum.id;
    final masaId = masa.id;

    // 1️⃣ Lokal state anında güncelle — kullanıcı beklemiyor
    oturumProvider.oturumSonlandirLokalde(oturumId);
    masaProvider.durumGuncelleLokalde(masaId, MasaDurum.bos);

    // 2️⃣ Sidebar anında kapat
    onKapat();

    // 3️⃣ DB iptal işlemi arka planda
    unawaited(Future.microtask(() async {
      try {
        await oturumProvider.oturumIptalEt(oturumId);
        await masaProvider.durumGuncelle(masaId, MasaDurum.bos);
        rootScaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(content: Text('Oturum iptal edildi.')),
        );
      } catch (e) {
        // DB hatası: masa tekrar dolu görünür
        masaProvider.durumGuncelleLokalde(masaId, MasaDurum.dolu);
        rootScaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text('⚠ İptal işlemi başarısız: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }));
  }

  /// Başlangıç saati değiştirme dialogu.
  void _baslangicSaatiDegistir(BuildContext context, OturumModel oturum) async {
    final now = DateTime.now();
    // Saat seçici
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(oturum.baslangic),
      helpText: 'Başlangıç Saatini Seçin',
    );
    if (picked == null || !context.mounted) return;

    final yeniBaslangic = DateTime(
      oturum.baslangic.year,
      oturum.baslangic.month,
      oturum.baslangic.day,
      picked.hour,
      picked.minute,
    );

    // Gelecekte olamaz
    if (yeniBaslangic.isAfter(now)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Başlangıç saati gelecekte olamaz.')),
        );
      }
      return;
    }

    final oturumProvider = context.read<OturumProvider>();
    final basarili = await oturumProvider.baslangicGuncelle(
      oturum.id,
      yeniBaslangic,
    );
    if (basarili && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Başlangıç saati ${Formatters.saat(yeniBaslangic)} olarak güncellendi.',
          ),
        ),
      );
    }
  }

  /// Masa düzenleme dialogu (ad ve konsol tipi).
  void _masaDuzenleDialogu(
    BuildContext context,
    MasaModel masa,
    MasaProvider masaProvider,
  ) {
    final adController = TextEditingController(text: masa.ad);
    final ayarlar = context.read<AyarlarProvider>();
    String secilenKonsol = masa.konsolTipi;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('Masayı Düzenle'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: adController,
                decoration: const InputDecoration(
                  labelText: 'Masa Adı',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: ayarlar.konsolTipleri.contains(secilenKonsol)
                    ? secilenKonsol
                    : ayarlar.konsolTipleri.first,
                decoration: const InputDecoration(
                  labelText: 'Konsol Tipi',
                  border: OutlineInputBorder(),
                ),
                items: ayarlar.konsolTipleri
                    .map(
                      (tip) => DropdownMenuItem(value: tip, child: Text(tip)),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setStateDialog(() => secilenKonsol = value);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('İptal'),
            ),
            FilledButton(
              onPressed: () async {
                final ad = adController.text.trim();
                if (ad.isEmpty) return;

                final guncellenen = masa.copyWith(
                  ad: ad,
                  konsolTipi: secilenKonsol,
                );
                await masaProvider.masaBilgiGuncelle(guncellenen);
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Masa güncellendi.')),
                  );
                }
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }

  /// Masa sil onay.
  Future<void> _masaSilOnay(
    BuildContext context,
    MasaProvider provider,
    MasaModel hedefMasa,
  ) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Masayı Sil'),
        content: Text('${hedefMasa.ad} kalıcı olarak silinecek. Emin misiniz?'),
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
      final basarili = await provider.masaSil(hedefMasa.id);
      if (basarili) {
        onKapat();
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.hata ?? 'Masa silinemedi.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // ── Masa Taşı ──

  Future<void> _masaTasiDialogu(
    BuildContext context,
    OturumModel oturum,
  ) async {
    // Dondurulmuş oturum taşınamaz
    if (oturum.isDondurulmus) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dondurulmuş oturum taşınamaz. Önce devam ettirin.'),
        ),
      );
      return;
    }

    // Ücretli oturum kısıtlaması (Tamamen taşıma yasaklanmıştır)
    final isUcretli = oturum.butce != null && oturum.butce! > 0;
    if (isUcretli) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ücretli (ön ödemeli) olarak açılmış oturumlar başka bir masaya taşınamaz/birleştirilemez.'),
          ),
        );
      }
      return;
    }

    final masaProvider = context.read<MasaProvider>();
    final ayarlar = context.read<AyarlarProvider>();

    // Hedef masaları kurallara göre filtrele (Artık "isUcretli" zaten return ile durdurulduğundan normal filtreleme devam eder)
    final hedefMasalar = masaProvider.masalar.where((m) {
      if (m.id == masa.id) return false;
      return true;
    }).toList()
      ..sort((a, b) => a.ad.compareTo(b.ad));

    if (hedefMasalar.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Taşınabilecek masa yok.')),
      );
      return;
    }

    // Mevcut ücret hesapla
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
    final kalanDk = oturum.mod == OturumMod.sureli
        ? ((oturum.sureDk ?? 0) - oynananDk).clamp(1, 9999)
        : null;

    if (!context.mounted) return;

    MasaModel? secilenMasa;
    int yeniKolSayisi = oturum.kolSayisi;

    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final farkliTip =
              secilenMasa != null && secilenMasa!.konsolTipi != masa.konsolTipi;
          final hedefDolu = secilenMasa != null && secilenMasa!.durum != MasaDurum.bos;

          return AlertDialog(
            icon: Icon(Icons.swap_horiz, color: Colors.blue.shade700, size: 40),
            title: const Text('Masa Taşı'),
            content: SizedBox(
              width: 340,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                   // Özet
                  Text(
                    '${masa.ad} (${masa.konsolTipi})  ·  $oynananDk dk oynandı'
                    '${oturum.mod == OturumMod.sureli ? "  ·  ~$kalanDk dk kalan" : ""}',
                    style: TextStyle(fontSize: 12, color: AppColors.textS(ctx)),
                  ),
                  const SizedBox(height: 12),
                  // Hedef masa seçimi
                  DropdownButtonFormField<MasaModel>(
                    decoration: const InputDecoration(
                      labelText: 'Hedef Masa',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    initialValue: secilenMasa,
                    items: hedefMasalar.map((m) {
                      return DropdownMenuItem(
                        value: m,
                        child: Text(
                          '${m.ad}  (${m.konsolTipi})${m.durum != MasaDurum.bos ? ' - Dolu (Birleştir)' : ''}',
                          style: TextStyle(
                            fontSize: 13,
                            color: m.durum != MasaDurum.bos
                                ? AppColors.error
                                : m.konsolTipi != masa.konsolTipi
                                    ? Colors.orange.shade700
                                    : null,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => secilenMasa = v),
                  ),

                  // Uyarı ve Ekstra Girdiler
                  if (secilenMasa != null) ...[
                    const SizedBox(height: 12),
                    
                    if (hedefDolu)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.merge_type, color: AppColors.error, size: 18),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Dolu Masaya Taşıma (Birleştirme). Toplam ücret (${Formatters.para(toplamUcret)}) ve mevcut siparişler, ${secilenMasa!.ad} masasının siparişlerine eklenecek. Seçili masa kapatılacak.',
                                style: const TextStyle(fontSize: 11, color: AppColors.error),
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (farkliTip) ...[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 18),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${masa.konsolTipi} → ${secilenMasa!.konsolTipi} geçiş. Biriken ücret (${Formatters.para(toplamUcret)}) siparişe aktarılacak, yeni masada ${secilenMasa!.konsolTipi} tarifesiyle yeniden başlatılacak.',
                                style: TextStyle(fontSize: 11, color: Colors.orange.shade800),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text('Yeni Masadaki Kol Sayısı:', style: TextStyle(fontSize: 12)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, size: 28),
                            color: Colors.blue.shade700,
                            onPressed: yeniKolSayisi > 1
                                ? () => setState(() => yeniKolSayisi--)
                                : null,
                          ),
                          Container(
                            constraints: const BoxConstraints(minWidth: 48),
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.surface(ctx),
                              border: Border.all(color: AppColors.borderColor(ctx)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$yeniKolSayisi',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, size: 28),
                            color: Colors.blue.shade700,
                            onPressed: yeniKolSayisi < 4
                                ? () => setState(() => yeniKolSayisi++)
                                : null,
                          ),
                        ],
                      ),
                    ] else
                      Text(
                        'Oturum olduğu gibi yeni masada devam edecek. Zamanlama ve ücret korunur.',
                        style: TextStyle(fontSize: 11, color: AppColors.textS(ctx)),
                      ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('İptal'),
              ),
              FilledButton.icon(
                onPressed: secilenMasa != null
                    ? () => Navigator.of(ctx).pop(true)
                    : null,
                icon: const Icon(Icons.swap_horiz, size: 18),
                label: const Text('Taşı'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                ),
              ),
            ],
          );
        },
      ),
    );

    if (onay != true || secilenMasa == null || !context.mounted) return;

    await _masaTasiUygula(
      context,
      oturum,
      hedefMasa: secilenMasa!,
      zamanUcreti: zamanUcreti,
      kolEkstra: kolEkstra,
      yeniKolSayisi: yeniKolSayisi,
    );
  }

  Future<void> _masaTasiUygula(
    BuildContext context,
    OturumModel oturum, {
    required MasaModel hedefMasa,
    required double zamanUcreti,
    required double kolEkstra,
    required int yeniKolSayisi,
  }) async {
    final oturumProvider = context.read<OturumProvider>();
    final masaProvider = context.read<MasaProvider>();
    final satisProvider = context.read<SatisProvider>();

    final ayniTip = masa.konsolTipi == hedefMasa.konsolTipi;
    final hedefDolu = hedefMasa.durum != MasaDurum.bos;

    bool basarili = true;

    // Kol metni oluşturucu yardımcı
    String kolOzetMetni() {
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
    }

    if (hedefDolu) {
      // ── Dolu Masaya Taşıma (Birleştirme) ──
      final hedefOturum = oturumProvider.masaninOturumu(hedefMasa.id);
      if (hedefOturum == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hedef masa oturumu bulunamadı.')));
        }
        return;
      }

      // Kaynak masanın siparişlerini hedefe aktar
      await satisProvider.satisOturumaAktar(oturum.id, hedefOturum.id);

      // Kaynak masanın birikmiş konsol ücretini hedefe aktar
      final toplamUcret = zamanUcreti + kolEkstra;
      if (toplamUcret > 0) {
        await satisProvider.eskiKonsolUcretiEkle(
          oturumId: hedefOturum.id,
          konsolUcreti: zamanUcreti,
          kolEkstraUcreti: kolEkstra,
          kolMetni: '${kolOzetMetni()}, ${masa.ad}→${hedefMasa.ad}',
          oynananDk: oturum.gecenSure.inMinutes,
          baslangic: oturum.baslangic,
        );
      }

      // Kaynak oturumu iptal et (kapatıyoruz)
      basarili = await oturumProvider.oturumIptalEt(oturum.id);

    } else {
      // ── Boş Masaya Taşıma ──
      if (ayniTip) {
        // Aynı konsol tipi: sadece masaId değiştir
        basarili = await oturumProvider.masaIdDegistir(oturum.id, hedefMasa.id);
      } else {
        // Farklı konsol tipi: biriken ücreti siparişe aktar + sıfırla
        final toplamUcret = zamanUcreti + kolEkstra;
        final kalanDk = oturum.mod == OturumMod.sureli
            ? ((oturum.sureDk ?? 0) - oturum.gecenSure.inMinutes).clamp(1, 9999)
            : null;

        if (toplamUcret > 0) {
          await satisProvider.eskiKonsolUcretiEkle(
            oturumId: oturum.id,
            konsolUcreti: zamanUcreti,
            kolEkstraUcreti: kolEkstra,
            kolMetni: '${kolOzetMetni()}, ${masa.ad}→${hedefMasa.ad}',
            oynananDk: oturum.gecenSure.inMinutes,
            baslangic: oturum.baslangic,
          );
        }

        basarili = await oturumProvider.masaTasi(
          oturum.id,
          hedefMasa.id,
          kalanSureDk: kalanDk,
          kolSayisi: yeniKolSayisi,
        );
      }
    }

    if (!basarili) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Masa taşıma başarısız.')));
      }
      return;
    }

    // Masa durumlarını güncelle
    await masaProvider.durumGuncelle(masa.id, MasaDurum.bos);
    await masaProvider.durumGuncelle(hedefMasa.id, MasaDurum.dolu);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${masa.ad} → ${hedefMasa.ad} taşındı.')),
      );
    }

    // Sidebar'ı kapat (kaynak masa artık boş)
    widget.onKapat();
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
              // Kol seçici
              _KolSecici(
                kolSayisi: seciliKolSayisi,
                konsolTipi: masa.konsolTipi,
                onChanged: (v) => setState(() => seciliKolSayisi = v),
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

// ══════════════════════════════════════════════════════════
// ── ALT WİDGET'LAR ──
// ══════════════════════════════════════════════════════════

/// Sidebar header — masa adı, konsol tipi, durum badge, kapat butonu.
class _SidebarHeader extends StatelessWidget {
  final MasaModel masa;
  final OturumModel? oturum;
  final VoidCallback onKapat;
  final VoidCallback? onSil;
  final VoidCallback? onDuzenle;

  const _SidebarHeader({
    required this.masa,
    required this.oturum,
    required this.onKapat,
    this.onSil,
    this.onDuzenle,
  });

  String _durumText() {
    switch (masa.durum) {
      case MasaDurum.bos:
        return 'Boş';
      case MasaDurum.dolu:
        return 'Aktif';
      case MasaDurum.rezerve:
        return 'Rezerve';
      case MasaDurum.dondurulmus:
        return 'Dondurulmuş';
    }
  }

  Color _durumRengi() {
    switch (masa.durum) {
      case MasaDurum.bos:
        return AppColors.masaBos;
      case MasaDurum.dolu:
        return AppColors.masaDolu;
      case MasaDurum.rezerve:
        return Colors.orange;
      case MasaDurum.dondurulmus:
        return AppColors.masaDondurulmus;
    }
  }

  @override
  Widget build(BuildContext context) {
    final renk = _durumRengi();
    final compact = ResponsiveHelper.isCompactSidebar(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: renk.withValues(alpha: 0.08),
        border: Border(bottom: BorderSide(color: renk.withValues(alpha: 0.3))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Üst satır: Masa adı + kapat butonu
          Row(
            children: [
              Icon(Icons.sports_esports, color: renk, size: compact ? 18 : 20),
              SizedBox(width: compact ? 5 : 6),
              Expanded(
                child: Text(
                  masa.ad,
                  style: TextStyle(
                    fontSize: compact ? 14 : 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (onDuzenle != null)
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  tooltip: 'Masayı Düzenle',
                  onPressed: onDuzenle,
                  constraints: const BoxConstraints(
                    minHeight: 32,
                    minWidth: 32,
                  ),
                  padding: EdgeInsets.zero,
                  style: IconButton.styleFrom(
                    foregroundColor: AppColors.vurguMavi(context),
                  ),
                ),
              if (onSil != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  tooltip: 'Masayı Sil',
                  onPressed: onSil,
                  constraints: const BoxConstraints(
                    minHeight: 32,
                    minWidth: 32,
                  ),
                  padding: EdgeInsets.zero,
                  style: IconButton.styleFrom(foregroundColor: AppColors.error),
                ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                tooltip: 'Kapat',
                onPressed: onKapat,
                constraints: const BoxConstraints(minHeight: 32, minWidth: 32),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          const SizedBox(height: 3),
          // Alt satır: Konsol tipi + Durum + Kol sayısı
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.vurguMavi(context).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  masa.konsolTipi,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.vurguMavi(context),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: renk.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _durumText(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: renk,
                  ),
                ),
              ),
              if (oturum != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.sports_esports,
                        size: 12,
                        color: Colors.purple,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${oturum!.kolSayisi} Kol',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.purple,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Aktif oturum bilgi bölümü — süre sayacı + fiyat dökümü.
class _AktifOturumBolumu extends StatelessWidget {
  final OturumModel oturum;
  final MasaModel masa;
  final VoidCallback? onBaslangicDegistir;

  const _AktifOturumBolumu({
    required this.oturum,
    required this.masa,
    this.onBaslangicDegistir,
  });

  @override
  Widget build(BuildContext context) {
    final satisProvider = context.watch<SatisProvider>();
    final ayarlar = context.read<AyarlarProvider>();
    final siparisToplami = satisProvider
        .oturumSatislari(oturum.id)
        .fold<double>(0, (t, s) => t + s.toplamTutar);

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

    final compact = ResponsiveHelper.isCompactSidebar(context);
    final toplamTutar = zamanUcreti + kolEkstra + siparisToplami;
    final vurguRenk = AppColors.isDark(context)
        ? AppColors.accent
        : AppColors.primary;

    if (compact) {
      // ── Compact: Timer (sol) | Fiyat (sağ) — yatay düzen ──
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.borderColor(context)),
          color: AppColors.surface(context),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // ── Sol: Sayaç + Mod ──
              Expanded(
                flex: 3,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SureSayaci(
                      baslangic: oturum.baslangic,
                      planliSureDk: oturum.sureDk,
                      dondurulmus: oturum.isDondurulmus,
                      dondurmaAni: oturum.dondurmaAni,
                      toplamDondurulmaSuresiSn: oturum.toplamDondurulmaSuresiSn,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        Text(
                          oturum.mod == OturumMod.sureli
                              ? '${oturum.sureDk}dk'
                              : 'Süresiz',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textS(context),
                          ),
                        ),
                        if (oturum.butce != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Bütçe: ${ayarlar.paraBirimi}${oturum.butce!.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: Colors.orange.shade700,
                              ),
                            ),
                          ),
                        InkWell(
                          onTap: onBaslangicDegistir,
                          borderRadius: BorderRadius.circular(4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                Formatters.saat(oturum.baslangic),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: vurguRenk,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Icon(Icons.edit, size: 10, color: vurguRenk),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Dikey ayırıcı
              VerticalDivider(
                width: 16,
                thickness: 1,
                color: AppColors.borderColor(context),
              ),
              // ── Sağ: Fiyat dökümü ──
              Expanded(
                flex: 2,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _compactFiyat('Konsol', zamanUcreti, context),
                    if (kolEkstra > 0)
                      _compactFiyat('Kol +', kolEkstra, context),
                    if (siparisToplami > 0)
                      _compactFiyat('Kafe', siparisToplami, context),
                    Divider(height: 6, color: AppColors.borderColor(context)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'TOPLAM',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                            color: vurguRenk,
                          ),
                        ),
                        Text(
                          Formatters.para(toplamTutar),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: vurguRenk,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ── Normal: dikey düzen (masaüstü) ──
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.borderColor(context)),
      ),
      color: AppColors.surface(context),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SureSayaci(
              baslangic: oturum.baslangic,
              planliSureDk: oturum.sureDk,
              dondurulmus: oturum.isDondurulmus,
              dondurmaAni: oturum.dondurmaAni,
              toplamDondurulmaSuresiSn: oturum.toplamDondurulmaSuresiSn,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                Text(
                  oturum.mod == OturumMod.sureli
                      ? 'Süreli (${oturum.sureDk} dk)'
                      : 'Süresiz',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textS(context),
                  ),
                ),
                if (oturum.butce != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Bütçe: ${ayarlar.paraBirimi}${oturum.butce!.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ),
                InkWell(
                  onTap: onBaslangicDegistir,
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Başlangıç: ${Formatters.saat(oturum.baslangic)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: vurguRenk,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(Icons.edit, size: 12, color: vurguRenk),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            _FiyatSatiri(label: 'Konsol', tutar: zamanUcreti),
            if (kolEkstra > 0)
              _FiyatSatiri(
                label: 'Kol Ekstra (${oturum.kolSayisi} kol)',
                tutar: kolEkstra,
              ),
            if (siparisToplami > 0)
              _FiyatSatiri(label: 'Kafeterya', tutar: siparisToplami),
            const Divider(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'TOPLAM',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: vurguRenk,
                  ),
                ),
                Text(
                  Formatters.para(toplamTutar),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: vurguRenk,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Compact fiyat satırı — tek satır, küçük font.
  Widget _compactFiyat(String label, double tutar, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 10, color: AppColors.textS(context)),
          ),
          Text(
            Formatters.para(tutar),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 11,
              color: AppColors.textP(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// Aksiyon butonları — Kol, Sipariş, Dondur, Sonlandır, İptal, Mod Değiştir, Süre Ayarla.
class _AksiyonButonlari extends StatelessWidget {
  final OturumModel oturum;
  final MasaModel masa;
  final VoidCallback onKolDegistir;
  final VoidCallback onSiparis;
  final VoidCallback onDondur;
  final VoidCallback onSonlandir;
  final VoidCallback onIptal;
  final VoidCallback onModDegistir;
  final VoidCallback? onSureAyarla;
  final VoidCallback? onSipariseAktarVeYenidenBaslat;
  final VoidCallback? onMasaTasi;

  const _AksiyonButonlari({
    required this.oturum,
    required this.masa,
    required this.onKolDegistir,
    required this.onSiparis,
    required this.onDondur,
    required this.onSonlandir,
    required this.onIptal,
    required this.onModDegistir,
    this.onSureAyarla,
    this.onSipariseAktarVeYenidenBaslat,
    this.onMasaTasi,
  });

  @override
  Widget build(BuildContext context) {
    final compact = ResponsiveHelper.isCompactSidebar(context);
    final btnPad = EdgeInsets.symmetric(vertical: compact ? 4 : 7);
    final iconSz = compact ? 13.0 : 14.0;
    final gap = compact ? 4.0 : 6.0;

    return Column(
      children: [
        // ── 1. satır: Kol + Sipariş ──
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: onKolDegistir,
                icon: Icon(Icons.sports_esports, size: iconSz),
                label: Text('Kol: ${oturum.kolSayisi}'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: btnPad,
                ),
              ),
            ),
            SizedBox(width: gap),
            Expanded(
              child: FilledButton.icon(
                onPressed: onSiparis,
                icon: Icon(Icons.shopping_cart_outlined, size: iconSz),
                label: const Text('Sipariş'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.75),
                  padding: btnPad,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: gap),
        // ── 2. satır: Mod Değiştir + Süre Ayarla ──
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onModDegistir,
                icon: Icon(
                  oturum.mod == OturumMod.sureli
                      ? Icons.all_inclusive
                      : Icons.timer,
                  size: iconSz,
                ),
                label: Text(
                  oturum.mod == OturumMod.sureli ? 'Süresiz Yap' : 'Süreli Yap',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.isDark(context)
                      ? Colors.lightBlue.shade300
                      : Colors.blue.shade700,
                  side: BorderSide(
                    color: AppColors.isDark(context)
                        ? Colors.lightBlue.withValues(alpha: 0.6)
                        : Colors.blue.shade600,
                    width: 1.2,
                  ),
                  padding: btnPad,
                ),
              ),
            ),
            if (oturum.mod == OturumMod.sureli && onSureAyarla != null) ...[
              SizedBox(width: gap),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onSureAyarla,
                  icon: Icon(Icons.more_time, size: iconSz),
                  label: const Text('Süre Ayarla'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.isDark(context)
                        ? Colors.lightBlue.shade300
                        : Colors.blue.shade700,
                    side: BorderSide(
                      color: AppColors.isDark(context)
                          ? Colors.lightBlue.withValues(alpha: 0.6)
                          : Colors.blue.shade600,
                      width: 1.2,
                    ),
                    padding: btnPad,
                  ),
                ),
              ),
            ],
          ],
        ),
        SizedBox(height: gap),
        // ── Siparişe Aktar + Masa Taşı ──
        if (onSipariseAktarVeYenidenBaslat != null || onMasaTasi != null)
          Row(
            children: [
              if (onSipariseAktarVeYenidenBaslat != null)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onSipariseAktarVeYenidenBaslat,
                    icon: Icon(
                      Icons.restart_alt,
                      size: iconSz,
                      color: Colors.orange.shade700,
                    ),
                    label: Text(
                      'Aktar & Başlat',
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontSize: compact ? 11 : 13,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: Colors.orange.shade600,
                        width: 1.3,
                      ),
                      backgroundColor: Colors.orange.withValues(alpha: 0.10),
                      padding: btnPad,
                    ),
                  ),
                ),
              if (onSipariseAktarVeYenidenBaslat != null && onMasaTasi != null)
                SizedBox(width: gap),
              if (onMasaTasi != null)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onMasaTasi,
                    icon: Icon(
                      Icons.swap_horiz,
                      size: iconSz,
                      color: Colors.blue.shade700,
                    ),
                    label: Text(
                      'Masa Taşı',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: compact ? 11 : 13,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: Colors.blue.shade600,
                        width: 1.3,
                      ),
                      backgroundColor: Colors.blue.withValues(alpha: 0.10),
                      padding: btnPad,
                    ),
                  ),
                ),
            ],
          ),
        SizedBox(height: compact ? 4 : 7),
        // ── ince ayraç ──
        Divider(
          height: 1,
          thickness: 1,
          color: AppColors.dividerColor(context),
        ),
        SizedBox(height: compact ? 4 : 7),
        // ── 3. satır: Dondur + Bitir + İptal ──
        Row(
          children: [
            // Dondur — belirgin outlined
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onDondur,
                icon: Icon(
                  Icons.ac_unit,
                  size: compact ? 13 : 15,
                  color: AppColors.isDark(context)
                      ? AppColors.masaDondurulmus
                      : Colors.blue.shade700,
                ),
                label: Text(
                  'Dondur',
                  style: TextStyle(
                    color: AppColors.isDark(context)
                        ? AppColors.masaDondurulmus
                        : Colors.blue.shade700,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: AppColors.isDark(context)
                        ? AppColors.masaDondurulmus.withValues(alpha: 0.5)
                        : Colors.blue.shade600,
                    width: 1.3,
                  ),
                  backgroundColor: AppColors.isDark(context)
                      ? AppColors.masaDondurulmus.withValues(alpha: 0.06)
                      : Colors.blue.withValues(alpha: 0.10),
                  padding: btnPad,
                ),
              ),
            ),
            SizedBox(width: gap),
            // Bitir — HIGHLIGHTED filled red
            Expanded(
              child: FilledButton.icon(
                onPressed: onSonlandir,
                icon: Icon(
                  Icons.stop_circle_outlined,
                  size: compact ? 13 : 15,
                  color: Colors.white,
                ),
                label: const Text(
                  'Bitir',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.masaDolu,
                  padding: btnPad,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            SizedBox(width: gap),
            // İptal — subtle grey text
            SizedBox(
              height: compact ? 32 : 40,
              child: TextButton(
                onPressed: onIptal,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textS(context),
                  padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12),
                ),
                child: Text(
                  'İptal',
                  style: TextStyle(fontSize: compact ? 11 : 13),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Dondurulmuş bilgi kartı.
class _DondurulmusBilgi extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Koyu modda açık mavi, beyaz modda köyü mavi (her iki temada okunabilir)
    final isDark = AppColors.isDark(context);
    final bgColor = isDark
        ? AppColors.masaDondurulmus.withValues(alpha: 0.15)
        : const Color(0xFF1565C0).withValues(alpha: 0.10); // koyu mavi zemin
    final metin = isDark ? AppColors.masaDondurulmus : const Color(0xFF0D47A1);
    final ikon = isDark ? AppColors.masaDondurulmus : const Color(0xFF1565C0);

    return Card(
      color: bgColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.ac_unit, color: ikon, size: 17),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Oturum donduruldu — süre ve ücret işlemiyor',
                style: TextStyle(
                  color: metin,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Boş masa — oturum başlatma butonları.
class _BosMasaBolumu extends StatelessWidget {
  final VoidCallback onSureliBaslat;
  final VoidCallback onSuresizBaslat;

  const _BosMasaBolumu({
    required this.onSureliBaslat,
    required this.onSuresizBaslat,
  });

  @override
  Widget build(BuildContext context) {
    final compact = ResponsiveHelper.isCompactSidebar(context);
    return Column(
      children: [
        SizedBox(height: compact ? 12 : 24),
        Icon(
          Icons.gamepad_outlined,
          size: compact ? 36 : 48,
          color: AppColors.textS(context).withValues(alpha: 0.5),
        ),
        SizedBox(height: compact ? 6 : 12),
        Text(
          'Bu masa şu an boş',
          style: TextStyle(
            fontSize: compact ? 12 : 14,
            color: AppColors.textS(context),
          ),
        ),
        SizedBox(height: compact ? 10 : 18),
        Row(
          children: [
            Expanded(
              child: Builder(
                builder: (btnCtx) {
                  final isDark = AppColors.isDark(btnCtx);
                  return FilledButton(
                    onPressed: onSureliBaslat,
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: compact ? 12 : 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      backgroundColor: isDark
                          ? const Color(0xFF1565C0).withValues(alpha: 0.30)
                          : AppColors.primary.withValues(alpha: 0.12),
                      foregroundColor: isDark
                          ? const Color(0xFF82B1FF)
                          : AppColors.primary,
                      elevation: 0,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.timer, size: compact ? 28 : 36),
                        SizedBox(height: compact ? 4 : 8),
                        Text(
                          'S\u00fcreli Ba\u015flat',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: compact ? 12 : 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            SizedBox(width: compact ? 8 : 12),
            Expanded(
              child: Builder(
                builder: (btnCtx) {
                  final isDark = AppColors.isDark(btnCtx);
                  return FilledButton(
                    onPressed: onSuresizBaslat,
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: compact ? 12 : 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      backgroundColor: isDark
                          ? const Color(0xFF00838F).withValues(alpha: 0.30)
                          : const Color(0xFF006064).withValues(alpha: 0.14),
                      foregroundColor: isDark
                          ? const Color(0xFF80DEEA)
                          : const Color(0xFF004D40),
                      elevation: 0,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.all_inclusive, size: compact ? 28 : 36),
                        SizedBox(height: compact ? 4 : 8),
                        Text(
                          'Süresiz Başlat',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: compact ? 12 : 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Sipariş listesi — aktif oturumun kafeterya siparişleri.
class _SiparisListesi extends StatelessWidget {
  final List satislar;
  final bool duzenlenebilir;
  final VoidCallback? onHeaderTap;

  const _SiparisListesi({
    required this.satislar,
    this.duzenlenebilir = false,
    this.onHeaderTap,
  });

  @override
  Widget build(BuildContext context) {
    if (satislar.isEmpty) {
      return GestureDetector(
        onTap: onHeaderTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface(context),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.borderColor(context)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.fastfood_outlined,
                size: 18,
                color: AppColors.textS(context),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Henüz sipariş yok (Sipariş Ekranı İçin Dokun)',
                  style: TextStyle(
                    color: AppColors.textS(context),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: onHeaderTap,
          child: Row(
            children: [
              Icon(
                Icons.receipt_long,
                size: 16,
                color: AppColors.vurguMavi(context),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Siparişler (${satislar.length})',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.vurguMavi(context),
                  ),
                ),
              ),
              Icon(
                Icons.open_in_full,
                size: 14,
                color: AppColors.vurguMavi(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface(context),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.borderColor(context)),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: satislar.length,
            separatorBuilder: (_, _) =>
                Divider(height: 1, color: AppColors.dividerColor(context)),
            itemBuilder: (context, index) {
              final satis = satislar[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Tooltip(
                            message: satis.urunAd,
                            waitDuration: const Duration(milliseconds: 300),
                            child: Text(
                              satis.urunAd,
                              style: const TextStyle(fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            Formatters.para(satis.toplamTutar),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: AppColors.vurguMavi(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (duzenlenebilir) ...[
                      // Adet azalt
                      if (satis.urunId != null)
                        SizedBox(
                        width: 28,
                        height: 28,
                        child: IconButton(
                          icon: const Icon(
                            Icons.remove_circle_outline,
                            size: 18,
                          ),
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            final satisProvider = context.read<SatisProvider>();
                            final urunProvider = context.read<UrunProvider>();
                            if (satis.adet <= 1) {
                              satisProvider.satisSil(satis.id);
                              if (satis.urunId != null) {
                                urunProvider.stokArtir(satis.urunId!, 1);
                              }
                            } else {
                              satisProvider.satisAdetGuncelle(
                                satis.id,
                                satis.adet - 1,
                              );
                              if (satis.urunId != null) {
                                urunProvider.stokArtir(satis.urunId!, 1);
                              }
                            }
                          },
                          color: AppColors.error,
                        ),
                      ),
                      // Adet gösterge
                      Container(
                        constraints: const BoxConstraints(minWidth: 28),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${satis.adet}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      // Adet arttır
                      if (satis.urunId != null)
                        SizedBox(
                        width: 28,
                        height: 28,
                        child: IconButton(
                          icon: const Icon(Icons.add_circle_outline, size: 18),
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            final satisProvider = context.read<SatisProvider>();
                            final urunProvider = context.read<UrunProvider>();
                            satisProvider.satisAdetGuncelle(
                              satis.id,
                              satis.adet + 1,
                            );
                            if (satis.urunId != null) {
                              urunProvider.stokAzalt(satis.urunId!, 1);
                            }
                          },
                          color: AppColors.masaBos,
                        ),
                      ),
                      // Sil
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: IconButton(
                          icon: const Icon(Icons.delete_outline, size: 16),
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            final satisProvider = context.read<SatisProvider>();
                            final urunProvider = context.read<UrunProvider>();
                            if (satis.urunId != null) {
                              urunProvider.stokArtir(satis.urunId!, satis.adet);
                            }
                            satisProvider.satisSil(satis.id);
                          },
                          color: AppColors.error,
                        ),
                      ),
                    ] else ...[
                      Text(
                        '×${satis.adet}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppColors.textS(context),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        Formatters.para(satis.toplamTutar),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        // Toplam
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            'Sipariş Toplamı: ${Formatters.para(satislar.fold<double>(0, (t, s) => t + s.toplamTutar))}',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: AppColors.vurguMavi(context),
            ),
          ),
        ),
      ],
    );
  }
}

/// Fiyat satırı yardımcı widget.
class _FiyatSatiri extends StatelessWidget {
  final String label;
  final double tutar;

  const _FiyatSatiri({required this.label, required this.tutar});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 13, color: AppColors.textP(context)),
          ),
          Text(
            Formatters.para(tutar),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: AppColors.textP(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kol seçici yardımcı widget.
class _KolSecici extends StatelessWidget {
  final int kolSayisi;
  final String konsolTipi;
  final ValueChanged<int> onChanged;

  const _KolSecici({
    required this.kolSayisi,
    required this.konsolTipi,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final ayarlar = context.read<AyarlarProvider>();
    final maksKol = ayarlar.maksimumKolSayisi(konsolTipi);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Icon(Icons.sports_esports, size: 20),
            const SizedBox(width: 8),
            const Text('Kol Sayısı:'),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: kolSayisi > 2 ? () => onChanged(kolSayisi - 1) : null,
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$kolSayisi',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: kolSayisi < maksKol
                  ? () => onChanged(kolSayisi + 1)
                  : null,
            ),
          ],
        ),
        Text(
          ayarlar.ucretGosterimMetni(konsolTipi, kolSayisi),
          style: TextStyle(fontSize: 12, color: AppColors.textS(context)),
        ),
        if (kolSayisi >= maksKol)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Bu tarife için maksimum $maksKol kol seçebilirsiniz',
              style: TextStyle(
                fontSize: 11,
                color: Colors.orange.shade700,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
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
