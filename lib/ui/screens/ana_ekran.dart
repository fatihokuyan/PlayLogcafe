import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive_helper.dart';
import '../../data/models/masa_model.dart';
import '../../data/models/oturum_model.dart';
import '../../data/models/rapor_model.dart';
import '../../logic/providers/oturum_provider.dart';
import '../../logic/providers/masa_provider.dart';
import '../../logic/providers/satis_provider.dart';
import '../../logic/providers/ayarlar_provider.dart';
import '../../logic/providers/rapor_provider.dart';
import '../../logic/services/sure_hesaplama_servisi.dart';
import '../widgets/sidebar_menu.dart';
import '../screens/masalar/masalar_ekrani.dart';
import '../screens/kafeterya/kafeterya_ekrani.dart';
import '../screens/raporlar/rapor_ekrani.dart';
import '../screens/muhasebe/muhasebe_ekrani.dart';
import '../screens/ayarlar/ayarlar_ekrani.dart';

/// Ana ekran — responsive shell.
/// Desktop/tablet: Sabit sidebar + içerik alanı.
/// Mobil: AppBar + Drawer + içerik alanı.
class AnaEkran extends StatefulWidget {
  const AnaEkran({super.key});

  @override
  State<AnaEkran> createState() => _AnaEkranState();
}

class _AnaEkranState extends State<AnaEkran> with WindowListener {
  OturumProvider? _oturumProvider;
  AyarlarProvider? _ayarlarProvider;
  VoidCallback? _ayarlarListener;

  int get _seciliIndex => context.read<AyarlarProvider>().seciliSayfaIndex;

  /// Seçili index'e göre gösterilecek ekranlar.
  static const List<Widget> _ekranlar = [
    MasalarEkrani(),
    KafeteryaEkrani(),
    RaporEkrani(),
    MuhasebeEkrani(),
    AyarlarEkrani(),
  ];

  Future<void> _onSecimDegisti(int index) async {
    // Muhasebe (index 3) için admin şifre kontrolü
    if (index == 3) {
      final ok = await adminSifreKontrol(context);
      if (!ok || !mounted) return;
    }
    setState(() => context.read<AyarlarProvider>().seciliSayfaIndex = index);
  }

  @override
  void initState() {
    super.initState();
    // Yeni kullanıcı girişinde detay paneli kapalı başlasın
    MasalarEkrani.detayPaneliAcik.value = false;
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      windowManager.addListener(this);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _oturumDinleyiciKur();
    });
  }

  @override
  void onWindowClose() async {
    if (!mounted) return;
    final karar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        icon: const Icon(Icons.exit_to_app, size: 40, color: Colors.orange),
        title: const Text('Çıkmak istiyor musunuz?'),
        content: const Text(
          'Açık oturumlar ve kaydedilmemiş veriler kaybolabilir.\n'
          'Uygulamadan çıkmak istediğinize emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hayır'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Evet, Çık'),
          ),
        ],
      ),
    );
    if (karar == true) exit(0);
  }

  /// OturumProvider'ı dinle, süre dolan bildirimleri yakala.
  void _oturumDinleyiciKur() {
    if (!mounted) return;
    final ayarlar = context.read<AyarlarProvider>();

    // AyarlarProvider henüz hazır değilse, hazır olduğunda yeniden dene
    if (!ayarlar.hazir) {
      void bekleyici() {
        if (!mounted) {
          ayarlar.removeListener(bekleyici);
          return;
        }
        if (ayarlar.hazir) {
          ayarlar.removeListener(bekleyici);
          _oturumDinleyiciKur();
        }
      }

      ayarlar.addListener(bekleyici);
      return;
    }

    final oturumProvider = context.read<OturumProvider>();
    _oturumProvider = oturumProvider;
    final masaProvider = context.read<MasaProvider>();

    // Konsol tipine göre dakika başı ücret resolver
    oturumProvider.ucretResolverAyarla((masaId, kolSayisi) {
      String konsolTipi = 'PS5';
      try {
        konsolTipi = masaProvider.masalar
            .firstWhere((m) => m.id == masaId)
            .konsolTipi;
      } catch (_) {}
      return ayarlar.konsolDakikaBasiUcretHesapla(konsolTipi, kolSayisi);
    });
    oturumProvider.kolEkstraResolverAyarla(ayarlar.kolEkstraUcretHesapla);
    // Fallback dakika başı ücret (resolver yoksa kullanılır)
    oturumProvider.dakikaBasiUcretAyarla(
      ayarlar.konsolDakikaBasiUcretHesapla('PS5', 2),
    );

    oturumProvider.addListener(_sureBitenKontrol);

    // Ayarlar değiştiğinde fallback'ı güncelle
    _ayarlarProvider = ayarlar;
    _ayarlarListener = () {
      oturumProvider.dakikaBasiUcretAyarla(
        ayarlar.konsolDakikaBasiUcretHesapla('PS5', 2),
      );
    };
    ayarlar.addListener(_ayarlarListener!);
  }

  /// Süre biten bildirimleri işle — masa kapat + doğru ücret hesapla + rapor kaydet + uyarı göster.
  void _sureBitenKontrol() {
    if (!mounted) return;

    final oturumProvider = context.read<OturumProvider>();
    final bildirimler = oturumProvider.sureBitenBildirimler;
    if (bildirimler.isEmpty) return;

    // Bildirimleri kopyala, temizlenecek
    final islenecekler = List<SureBitenBildirim>.from(bildirimler);

    // Hepsini hemen temizle (tekrar tetiklenmesin)
    for (final b in islenecekler) {
      oturumProvider.bildirimGoruldu(b.oturumId);
    }

    // Post-frame'de işle (build sırasında showDialog çağrılmasın)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      final ayarlar = context.read<AyarlarProvider>();
      final masaProvider = context.read<MasaProvider>();
      final satisProvider = context.read<SatisProvider>();
      final raporProvider = context.read<RaporProvider>();

      for (final bildirim in islenecekler) {
        // Masa henüz kapatılmıyor — oturum dondurulmuş halde,
        // kullanıcı ödeme mi yapacak yoksa uzatma mı seçecek ona bakılıyor.

        // Konsol tipini bul
        final masalar = masaProvider.masalar;
        String masaAd = 'Masa';
        String konsolTipi = 'PS5';
        try {
          final masa = masalar.firstWhere((m) => m.id == bildirim.masaId);
          masaAd = masa.ad;
          konsolTipi = masa.konsolTipi;
        } catch (_) {}

        // Sipariş toplamını hesapla
        final siparisToplami = satisProvider
            .oturumSatislari(bildirim.oturumId)
            .fold<double>(0, (t, s) => t + s.toplamTutar);

        // Dinamik kol + dilimli ücret hesapla
        // Bütçeli oturum kontrolü: butce varsa periyot=1
        final oturumButce = oturumProvider
            .masaninOturumu(bildirim.masaId)
            ?.butce;
        final zamanUcreti = SureHesaplamaServisi.dinamikKolUcretHesapla(
          kolGecmisi: bildirim.kolGecmisi,
          efektifSure: bildirim.efektifSure,
          mod: OturumMod.sureli,
          planliSureDk: bildirim.planliSureDk,
          dakikaBasiUcretResolver: (kol) =>
              ayarlar.konsolDakikaBasiUcretHesapla(konsolTipi, kol),
          fallbackKolSayisi: bildirim.kolSayisi,
          periyotDk: SureHesaplamaServisi.efektifPeriyot(oturumButce, ayarlar.guncellemePeriyoduDk, OturumMod.sureli),
          ilkUcretsizDk: ayarlar.ilkUcretsizDk,
        );
        final kolEkstra = ayarlar.kolEkstraUcretHesapla(
          bildirim.kolSayisi,
          konsolTipi,
        );
        final genelToplam = zamanUcreti + kolEkstra + siparisToplami;

        if (!mounted) continue;

        final odemeSecimi = await _sureBittiDialoguGoster(
          oturumId: bildirim.oturumId,
          masaId: bildirim.masaId,
          masaAd: masaAd,
          konsolTipi: konsolTipi,
          planliSureDk: bildirim.planliSureDk,
          oynananDk: bildirim.efektifSure.inMinutes,
          kolSayisi: bildirim.kolSayisi,
          zamanUcreti: zamanUcreti,
          kolEkstra: kolEkstra,
          siparisToplami: siparisToplami,
          genelToplam: genelToplam,
        );

        if (odemeSecimi == null) continue;

        // ── Uzatma seçildi ──
        if (odemeSecimi.uzatmaDk != null) {
          final ext = odemeSecimi.uzatmaDk!;
          // Kol sayısı değişmişse güncelle
          if (odemeSecimi.uzatmaKolSayisi != null &&
              odemeSecimi.uzatmaKolSayisi != bildirim.kolSayisi) {
            await oturumProvider.kolSayisiDegistir(
              bildirim.oturumId,
              odemeSecimi.uzatmaKolSayisi!,
            );
          }
          // Süreli oturumun süresini uzat ve devam ettir
          await oturumProvider.sureAyarla(bildirim.oturumId, ext);
          await oturumProvider.oturumDevamEt(bildirim.oturumId);
          // Masa zaten dolu olarak duruyordu — değiştirmeye gerek yok
          continue;
        }

        // ── Ödeme yapıldı ──
        await oturumProvider.oturumSonlandirTutarli(
          bildirim.oturumId,
          zamanUcreti,
        );
        await masaProvider.durumGuncelle(bildirim.masaId, MasaDurum.bos);
        await raporProvider.raporOlustur(
          oturumId: bildirim.oturumId,
          masaId: bildirim.masaId,
          masaAd: masaAd,
          konsolTipi: konsolTipi,
          baslangic: bildirim.oturumBaslangic,
          bitis: DateTime.now(),
          oynananDk: bildirim.efektifSure.inMinutes,
          kolSayisi: bildirim.kolSayisi,
          konsolUcreti: zamanUcreti,
          kolEkstraUcreti: kolEkstra,
          siparisUcreti: siparisToplami,
          toplamTutar: odemeSecimi.tahsilEdilenTutar,
          aciklama: (genelToplam - odemeSecimi.tahsilEdilenTutar).abs() > 0.01 
              ? 'Not: Toplam: ${Formatters.para(genelToplam)}, Tahsil Edilen: ${Formatters.para(odemeSecimi.tahsilEdilenTutar)}'
              : '',
          odemeYontemi: odemeSecimi.yontem!,
          nakitTutar: odemeSecimi.nakit,
          kartTutar: odemeSecimi.kart,
          kolGecmisi: bildirim.kolGecmisi
              .map(
                (s) => KolGecmisiKayit(
                  kolSayisi: s.kolSayisi,
                  baslangic: s.baslangic,
                ),
              )
              .toList(),
        );
      }
    });
  }

  /// Süre doldu uyarı dialogu — ödeme seçimi + uzatma seçeneği.
  /// Null dönmez (barrierDismissible false). Uzatma seçilirse uzatmaDk dolu gelir.
  Future<_OdemeSecimi?> _sureBittiDialoguGoster({
    required String oturumId,
    required String masaId,
    required String masaAd,
    required String konsolTipi,
    required int planliSureDk,
    required int oynananDk,
    required int kolSayisi,
    required double zamanUcreti,
    required double kolEkstra,
    required double siparisToplami,
    required double genelToplam,
  }) {
    return showDialog<_OdemeSecimi>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        OdemeYontemi secilen = OdemeYontemi.nakit;
        final tahsilEdilenCtrl = TextEditingController(text: genelToplam.toStringAsFixed(2));
        double guncelTahsilEdilen = genelToplam;
        final nakitCtrl = TextEditingController(
          text: genelToplam.toStringAsFixed(2),
        );
        final kartCtrl = TextEditingController(text: '0');
        String? parcaliHata;

        return StatefulBuilder(
          builder: (ctx, setState) => AlertDialog(
            icon: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.timer_off,
                color: AppColors.error,
                size: 48,
              ),
            ),
            title: Text(
              '$masaAd — Süre Doldu!',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Bilgi kutusu
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: AppColors.error,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Planlanan $planliSureDk dakika doldu.\nMasa donduruldu — ödeme yapın veya süreyi uzatın.',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textS(ctx),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Detay satırları
                    _bilgiSatiri('Konsol', konsolTipi, ctx: ctx),
                    _bilgiSatiri('Kol Sayısı', '$kolSayisi', ctx: ctx),
                    _bilgiSatiri(
                      'Oynanan Süre',
                      '$oynananDk dk / $planliSureDk dk',
                      ctx: ctx,
                    ),
                    const Divider(height: 16),
                    _ucretSatiri('Konsol Ücreti', zamanUcreti),
                    if (kolEkstra > 0) _ucretSatiri('Kol Ekstra', kolEkstra),
                    if (siparisToplami > 0)
                      _ucretSatiri('Kafeterya', siparisToplami),
                    const Divider(height: 20),
                    // TOPLAM
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.isDark(ctx)
                            ? AppColors.accent.withValues(alpha: 0.10)
                            : AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'TOPLAM',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.vurguMavi(ctx),
                            ),
                          ),
                          Text(
                            Formatters.para(genelToplam),
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.vurguMavi(ctx),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: tahsilEdilenCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: 'Tahsil Edilen (₺)',
                        border: OutlineInputBorder(
                           borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.attach_money, size: 20),
                        filled: true,
                        fillColor: AppColors.primary.withValues(alpha: 0.1),
                      ),
                      onChanged: (val) {
                         setState(() {
                            guncelTahsilEdilen = double.tryParse(val.replaceAll(',', '.')) ?? genelToplam;
                            parcaliHata = null;
                            if (secilen != OdemeYontemi.parcali) {
                              nakitCtrl.text = secilen == OdemeYontemi.nakit ? guncelTahsilEdilen.toStringAsFixed(2) : '0';
                              kartCtrl.text = secilen == OdemeYontemi.kart ? guncelTahsilEdilen.toStringAsFixed(2) : '0';
                            }
                         });
                      },
                    ),
                    const SizedBox(height: 16),

                    // ── Ödeme Yöntemi Seçimi ──
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Ödeme Yöntemi',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<OdemeYontemi>(
                      segments: const [
                        ButtonSegment(
                          value: OdemeYontemi.nakit,
                          icon: Icon(Icons.money, size: 18),
                          label: Text('Nakit'),
                        ),
                        ButtonSegment(
                          value: OdemeYontemi.kart,
                          icon: Icon(Icons.credit_card, size: 18),
                          label: Text('Kart'),
                        ),
                        ButtonSegment(
                          value: OdemeYontemi.parcali,
                          icon: Icon(Icons.call_split, size: 18),
                          label: Text('Parçalı'),
                        ),
                      ],
                      selected: {secilen},
                      onSelectionChanged: (s) {
                        setState(() {
                          secilen = s.first;
                          parcaliHata = null;
                          if (secilen != OdemeYontemi.parcali) {
                            nakitCtrl.text = secilen == OdemeYontemi.nakit
                                ? guncelTahsilEdilen.toStringAsFixed(2)
                                : '0';
                            kartCtrl.text = secilen == OdemeYontemi.kart
                                ? guncelTahsilEdilen.toStringAsFixed(2)
                                : '0';
                          } else {
                            nakitCtrl.text = '';
                            kartCtrl.text = '';
                          }
                        });
                      },
                    ),

                    // Parçalı ödeme alanları
                    if (secilen == OdemeYontemi.parcali) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: nakitCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d*\.?\d*'),
                                ),
                              ],
                              decoration: const InputDecoration(
                                labelText: 'Nakit ₺',
                                prefixIcon: Icon(Icons.money, size: 18),
                                isDense: true,
                              ),
                              onChanged: (_) {
                                setState(() {
                                  parcaliHata = null;
                                  final n = double.tryParse(nakitCtrl.text.replaceAll(',', '.')) ?? 0;
                                  final kalan = guncelTahsilEdilen - n;
                                  if (kalan >= 0) {
                                    kartCtrl.text = kalan.toStringAsFixed(2);
                                  }
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: kartCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d*\.?\d*'),
                                ),
                              ],
                              decoration: const InputDecoration(
                                labelText: 'Kart ₺',
                                prefixIcon: Icon(Icons.credit_card, size: 18),
                                isDense: true,
                              ),
                              onChanged: (_) {
                                setState(() {
                                  parcaliHata = null;
                                  final k = double.tryParse(kartCtrl.text.replaceAll(',', '.')) ?? 0;
                                  final kalan = guncelTahsilEdilen - k;
                                  if (kalan >= 0) {
                                    nakitCtrl.text = kalan.toStringAsFixed(2);
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
              // ── Uzat Butonu ──
              OutlinedButton.icon(
                onPressed: () async {
                  // Uzatma sub-diyalogu göster
                  final uzatmaSonuc = await _uzatmaDiyalogu(
                    ctx,
                    planliSureDk,
                    kolSayisi,
                    konsolTipi,
                  );
                  if (uzatmaSonuc != null && ctx.mounted) {
                    Navigator.of(ctx).pop(
                      _OdemeSecimi.uzat(
                        dk: uzatmaSonuc.dk,
                        kolSayisi: uzatmaSonuc.kolSayisi,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.more_time, color: Colors.teal),
                label: const Text('Uzat', style: TextStyle(color: Colors.teal)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.teal),
                ),
              ),
              // ── Ödeme Onayla ──
              FilledButton.icon(
                onPressed: () {
                  double nakit = 0;
                  double kart = 0;

                  if (secilen == OdemeYontemi.nakit) {
                    nakit = guncelTahsilEdilen;
                  } else if (secilen == OdemeYontemi.kart) {
                    kart = guncelTahsilEdilen;
                  } else {
                    // Parçalı
                    nakit = double.tryParse(nakitCtrl.text) ?? 0;
                    kart = double.tryParse(kartCtrl.text) ?? 0;
                    final fark = (nakit + kart - guncelTahsilEdilen).abs();
                    if (fark > 0.01) {
                      setState(
                        () => parcaliHata =
                            'Toplam ${Formatters.para(guncelTahsilEdilen)} olmalı (şu an: ${Formatters.para(nakit + kart)})',
                      );
                      return;
                    }
                  }

                  Navigator.of(ctx).pop(
                    _OdemeSecimi.odeme(
                      yontem: secilen,
                      nakit: nakit,
                      kart: kart,
                      tahsilEdilenTutar: guncelTahsilEdilen,
                    ),
                  );
                },
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Onayla'),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Bilgi satırı (label — value).
  Widget _bilgiSatiri(String label, String value, {BuildContext? ctx}) {
    final c = ctx ?? context;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: AppColors.textS(c), fontSize: 13),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ],
      ),
    );
  }

  /// Ücret satırı (label — fiyat).
  Widget _ucretSatiri(String label, double tutar) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(
            Formatters.para(tutar),
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ],
      ),
    );
  }

  /// Uzatma sub-diyalogu: kullanıcı ek dakika + kol sayısı seçer.
  Future<_UzatmaSonuc?> _uzatmaDiyalogu(
    BuildContext parentCtx,
    int mevcutSureDk,
    int mevcutKolSayisi,
    String konsolTipi,
  ) {
    int? secilen = 30;
    final ctrl = TextEditingController(text: '30');
    int kolSayisi = mevcutKolSayisi;

    return showDialog<_UzatmaSonuc>(
      context: parentCtx,
      barrierDismissible: false,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, setState) {
          final gecerli = secilen != null && secilen! > 0;
          final ayarlar = parentCtx.read<AyarlarProvider>();
          const maksKol = 8;

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: SizedBox(
              width: 340,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: 0.1),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.more_time,
                          color: Colors.teal,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Süreyi Uzat',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.teal.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Toplam $mevcutSureDk dk',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.teal,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Kaç dakika daha eklensin?',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textS(dCtx),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Hızlı seçim
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [15, 30, 60, 90, 120].map((dk) {
                            final sec = secilen == dk;
                            return FilterChip(
                              label: Text(
                                '+$dk dk',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: sec
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              selected: sec,
                              onSelected: (_) {
                                setState(() {
                                  secilen = dk;
                                  ctrl.text = dk.toString();
                                });
                              },
                              selectedColor: Colors.teal.withValues(
                                alpha: 0.18,
                              ),
                              checkmarkColor: Colors.teal,
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 10),
                        // Manuel giriş
                        TextField(
                          controller: ctrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: InputDecoration(
                            hintText: 'Dakika girin...',
                            suffixText: 'dk',
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onChanged: (v) =>
                              setState(() => secilen = int.tryParse(v)),
                        ),
                        const SizedBox(height: 14),
                        // ── Kol Sayısı Seçici ──
                        Row(
                          children: [
                            const Icon(
                              Icons.sports_esports,
                              size: 18,
                              color: Colors.teal,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Kol Sayısı:',
                              style: TextStyle(fontSize: 13),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(
                                Icons.remove_circle_outline,
                                size: 22,
                              ),
                              onPressed: kolSayisi > 2
                                  ? () => setState(() => kolSayisi--)
                                  : null,
                              visualDensity: VisualDensity.compact,
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.teal.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$kolSayisi',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.add_circle_outline,
                                size: 22,
                              ),
                              onPressed: kolSayisi < maksKol
                                  ? () => setState(() => kolSayisi++)
                                  : null,
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                        if (kolSayisi != mevcutKolSayisi) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Mevcut: $mevcutKolSayisi kol → Yeni: $kolSayisi kol',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.orange.shade700,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Text(
                          ayarlar.ucretGosterimMetni(konsolTipi, kolSayisi),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textS(dCtx),
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (gecerli) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.teal.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.teal.shade300),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Yeni toplam:',
                                  style: TextStyle(fontSize: 13),
                                ),
                                Text(
                                  '${mevcutSureDk + secilen!} dk · $kolSayisi kol',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () => Navigator.of(dCtx).pop(null),
                                child: const Text('İptal'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FilledButton(
                                onPressed: gecerli
                                    ? () => Navigator.of(dCtx).pop(
                                        _UzatmaSonuc(
                                          dk: secilen!,
                                          kolSayisi: kolSayisi,
                                        ),
                                      )
                                    : null,
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.teal,
                                ),
                                child: const Text('Uzat'),
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

  @override
  void dispose() {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      windowManager.removeListener(this);
    }
    _oturumProvider?.removeListener(_sureBitenKontrol);
    if (_ayarlarListener != null) {
      _ayarlarProvider?.removeListener(_ayarlarListener!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final genisMi = ResponsiveHelper.showSidebar(context);

    if (genisMi) {
      final isCompact = ResponsiveHelper.isCompactSidebar(context);
      // ── Desktop / Tablet: Sidebar + İçerik ──
      // Compact modda detay paneli açıkken sidebar gizlenir
      return Scaffold(
        body: ValueListenableBuilder<bool>(
          valueListenable: MasalarEkrani.detayPaneliAcik,
          builder: (context, detayAcik, _) {
            final sidebarGizle = isCompact && detayAcik && _seciliIndex == 0;
            return Row(
              children: [
                if (!sidebarGizle)
                  SidebarMenu(
                    seciliIndex: _seciliIndex,
                    onSecimDegisti: _onSecimDegisti,
                  ),
                Expanded(child: _ekranlar[_seciliIndex]),
              ],
            );
          },
        ),
      );
    }

    // ── Mobil: AppBar + Drawer ──
    return Scaffold(
      appBar: AppBar(title: Text(menuOgeleri[_seciliIndex].baslik)),
      drawer: DrawerMenu(
        seciliIndex: _seciliIndex,
        onSecimDegisti: _onSecimDegisti,
      ),
      body: _ekranlar[_seciliIndex],
    );
  }
}

/// Ödeme seçimi sonucu (süre doldu dialogundan döner).
class _OdemeSecimi {
  final OdemeYontemi? yontem; // null = uzatma seçildi
  final double nakit;
  final double kart;
  final double tahsilEdilenTutar;
  final int? uzatmaDk; // null = normal ödeme, not-null = uzatma
  final int? uzatmaKolSayisi; // uzatmada kol sayısı değişikliği

  const _OdemeSecimi.odeme({
    required this.yontem,
    required this.nakit,
    required this.kart,
    required this.tahsilEdilenTutar,
  }) : uzatmaDk = null,
       uzatmaKolSayisi = null;

  const _OdemeSecimi.uzat({required int dk, int? kolSayisi})
    : yontem = null,
      nakit = 0,
      kart = 0,
      tahsilEdilenTutar = 0,
      uzatmaDk = dk,
      uzatmaKolSayisi = kolSayisi;
}

/// Uzatma dialogu sonucu.
class _UzatmaSonuc {
  final int dk;
  final int kolSayisi;
  const _UzatmaSonuc({required this.dk, required this.kolSayisi});
}
