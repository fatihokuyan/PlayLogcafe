import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive_helper.dart';
import '../../logic/providers/auth_provider.dart';
import '../../logic/providers/ayarlar_provider.dart';
import '../../logic/providers/muhasebe_provider.dart';
import '../../logic/providers/rapor_provider.dart';
import '../../logic/providers/oturum_provider.dart';
import '../../logic/providers/masa_provider.dart';
import '../../logic/providers/satis_provider.dart';
import '../../logic/providers/urun_provider.dart';
import '../../logic/services/sure_hesaplama_servisi.dart';
import '../screens/masalar/masalar_ekrani.dart';

/// Menü öğesi veri modeli.
class MenuOgesi {
  final int index;
  final String baslik;
  final IconData ikon;

  const MenuOgesi({
    required this.index,
    required this.baslik,
    required this.ikon,
  });
}

/// Tüm provider state'lerini sıfırlayıp çıkış yapar.
Future<void> _tumVerileriTemizleVeCikisYap(BuildContext context) async {
  context.read<MasaProvider>().temizle();
  context.read<OturumProvider>().temizle();
  context.read<UrunProvider>().temizle();
  context.read<SatisProvider>().temizle();
  context.read<RaporProvider>().temizle();
  context.read<MuhasebeProvider>().temizle();
  context.read<AyarlarProvider>().seciliSayfaIndex = 0;
  MasalarEkrani.detayPaneliAcik.value = false;
  await context.read<AuthProvider>().cikisYap();
}

/// Uygulama menü öğeleri.
const List<MenuOgesi> menuOgeleri = [
  MenuOgesi(index: 0, baslik: 'Masalar', ikon: Icons.gamepad_outlined),
  MenuOgesi(index: 1, baslik: 'Kafeterya', ikon: Icons.local_cafe_outlined),
  MenuOgesi(index: 2, baslik: 'Raporlar', ikon: Icons.assessment_outlined),
  MenuOgesi(
    index: 3,
    baslik: 'Muhasebe',
    ikon: Icons.account_balance_wallet_outlined,
  ),
  MenuOgesi(index: 4, baslik: 'Ayarlar', ikon: Icons.settings_outlined),
];

/// Desktop/tablet için sabit sidebar widget'ı.
class SidebarMenu extends StatelessWidget {
  final int seciliIndex;
  final ValueChanged<int> onSecimDegisti;

  const SidebarMenu({
    super.key,
    required this.seciliIndex,
    required this.onSecimDegisti,
  });

  @override
  Widget build(BuildContext context) {
    final compact = ResponsiveHelper.isCompactSidebar(context);
    final sidebarW = ResponsiveHelper.sidebarWidth(context);
    final s = ResponsiveHelper.sidebarScale(context);

    return Container(
      width: sidebarW,
      decoration: const BoxDecoration(
        color: AppColors.primaryDark,
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(2, 0)),
        ],
      ),
      child: Column(
        children: [
          // ═══════════════════════════════════════════════════════
          // ▌ SABİT ÜST KISIM — Logo, Menü öğeleri, Günlük Kazanç
          // ═══════════════════════════════════════════════════════

          // ── Logo / Başlık ──
          if (compact)
            Container(
              height: 58,
              alignment: Alignment.center,
              child: Image.asset(
                'assets/images/logo.png',
                width: 46,
                height: 46,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.sports_esports,
                  color: AppColors.accent,
                  size: 34,
                ),
              ),
            )
          else
            Consumer<AyarlarProvider>(
              builder: (context, ayarlar, _) {
                final s = ResponsiveHelper.sidebarScale(context);
                final isletmeAdi = ayarlar.hazir
                    ? ayarlar.isletmeAdi
                    : 'PlayLog';
                // Uzunluğa göre dinamik font boyutu
                final double fontSize = isletmeAdi.length <= 10
                    ? 20
                    : isletmeAdi.length <= 16
                    ? 16
                    : isletmeAdi.length <= 22
                    ? 13
                    : 11;

                return Container(
                  height: 82 * s,
                  alignment: Alignment.center,
                  padding: EdgeInsets.symmetric(horizontal: 10 * s),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.sports_esports,
                        color: AppColors.accent,
                        size: 20 * s,
                      ),
                      SizedBox(width: 6 * s),
                      Flexible(
                        child: Text(
                          isletmeAdi,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: fontSize * s,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          const Divider(color: Colors.white24, height: 1),

          // ── Menü öğeleri (sabit sayıda — scroll gereksiz) ──
          Consumer<AyarlarProvider>(
            builder: (context, ayarlar, _) {
              final aktifMenuOgeleri = menuOgeleri.where((oge) {
                if (oge.index == 2) {
                  return ayarlar.hazir ? ayarlar.raporlarSekmesiniGoster : true;
                }
                if (oge.index == 3) {
                  return ayarlar.hazir ? ayarlar.muhasebeSekmesiniGoster : true;
                }
                return true;
              }).toList();

              return Padding(
                padding: EdgeInsets.symmetric(vertical: compact ? 4 : 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: aktifMenuOgeleri.map((oge) {
                    final secili = oge.index == seciliIndex;
                    return compact
                        ? _CompactMenuTile(
                            oge: oge,
                            secili: secili,
                            onTap: () => onSecimDegisti(oge.index),
                          )
                        : _MenuTile(
                            oge: oge,
                            secili: secili,
                            onTap: () => onSecimDegisti(oge.index),
                          );
                  }).toList(),
                ),
              );
            },
          ),

          // ── Günlük Kazanç (sabit üst bölümün parçası) ──
          if (compact)
            const _CompactKazancBolumu()
          else
            const _GunlukKazancBolumu(),

          // ═══════════════════════════════════════════════════════
          // ▌ KAYDIRMALI ORTA KISIM — Tarife listesi
          // ▌ Konsol sayısı arttıkça (PS5, PS6, PS7...) sadece
          // ▌ bu bölüm scroll olur, üst ve alt sabit kalır.
          // ═══════════════════════════════════════════════════════
          if (compact)
            const _CompactTarifeBolumu()
          else ...[
            const Divider(color: Colors.white24, height: 1),
            Expanded(
              child: Consumer<AyarlarProvider>(
                builder: (context, ayarlar, _) {
                  if (!ayarlar.hazir) return const SizedBox.shrink();
                  final konsolTipleri = ayarlar.konsolTipleri;
                  final birim = ayarlar.birimEtiketi;
                  final paraBirimi = ayarlar.paraBirimi;
                  final kolModu = ayarlar.kolUcretModu;
                  final s = ResponsiveHelper.sidebarScale(context);

                  return SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10 * s,
                      vertical: 8 * s,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Tarife başlığı
                        Row(
                          children: [
                            Icon(
                              Icons.receipt_long,
                              color: Colors.white54,
                              size: 14 * s,
                            ),
                            SizedBox(width: 4 * s),
                            Text(
                              'Tarife',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 11 * s,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 6 * s),
                        // Konsol bazlı fiyat listesi
                        ...konsolTipleri.map((konsol) {
                          final temelUcret = ayarlar.konsolTemelUcret(konsol);
                          final kolTarifeleri =
                              ayarlar.konsolKolTarifeleri[konsol] ?? {};

                          return Padding(
                            padding: EdgeInsets.only(bottom: 6 * s),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  konsol,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12 * s,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                SizedBox(height: 2 * s),
                                // Temel fiyat (1-2 kol)
                                Text(
                                  '  1-2 kol: $paraBirimi${temelUcret.toStringAsFixed(0)}$birim',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 11 * s,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                // Kol tarifeleri (3+ kol)
                                if (kolModu == 'tarife') ...[
                                  ...kolTarifeleri.entries
                                      .where((e) => e.key > 2)
                                      .toList()
                                      .map(
                                        (e) => Text(
                                          '  ${e.key} kol: $paraBirimi${e.value.toStringAsFixed(0)}$birim',
                                          style: TextStyle(
                                            color: Colors.white54,
                                            fontSize: 11 * s,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                ],
                                if (kolModu == 'ekstra') ...[
                                  () {
                                    final ekstraBirim = ayarlar
                                        .konsolKolBasinaEkstraUcret(konsol);
                                    if (ekstraBirim > 0) {
                                      return Text(
                                        '  +$paraBirimi${ekstraBirim.toStringAsFixed(0)}/ekstra kol',
                                        style: TextStyle(
                                          color: Colors.white54,
                                          fontSize: 11 * s,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      );
                                    }
                                    return const SizedBox.shrink();
                                  }(),
                                ],
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],

          // ═══════════════════════════════════════════════════════
          // ▌ SABİT ALT KISIM — Çıkış butonu + Versiyon
          // ═══════════════════════════════════════════════════════
          if (!compact) const Divider(color: Colors.white24, height: 1),
          // Çıkış butonu
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 4 : 8 * s,
              vertical: 2,
            ),
            child: compact
                ? IconButton(
                    icon: const Icon(
                      Icons.logout,
                      color: Colors.white38,
                      size: 18,
                    ),
                    tooltip: 'Çıkış Yap',
                    onPressed: () => _cikisYap(context),
                  )
                : TextButton.icon(
                    onPressed: () => _cikisYap(context),
                    icon: Icon(
                      Icons.logout,
                      color: Colors.white38,
                      size: 14 * s,
                    ),
                    label: Text(
                      'Çıkış Yap',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 11 * s,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8 * s,
                        vertical: 4 * s,
                      ),
                    ),
                  ),
          ),
          Padding(
            padding: EdgeInsets.only(
              left: compact ? 3 : 8 * s,
              right: compact ? 3 : 8 * s,
              bottom: 8,
            ),
            child: Text(
              compact ? 'v2' : 'v2.0.0',
              style: TextStyle(color: Colors.white38, fontSize: 11 * s),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  void _cikisYap(BuildContext context) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Çıkış Yap'),
        content: const Text('Hesabınızdan çıkış yapmak istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Çıkış Yap'),
          ),
        ],
      ),
    ).then((onay) async {
      if (onay == true && context.mounted) {
        await _tumVerileriTemizleVeCikisYap(context);
      }
    });
  }
}

/// Mobil için drawer widget'ı — aynı menü öğelerini kullanır.
class DrawerMenu extends StatelessWidget {
  final int seciliIndex;
  final ValueChanged<int> onSecimDegisti;

  const DrawerMenu({
    super.key,
    required this.seciliIndex,
    required this.onSecimDegisti,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.primaryDark,
      child: SafeArea(
        child: Column(
          children: [
            // ── Başlık ──
            Container(
              height: 90,
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/logo.png',
                    width: 64,
                    height: 64,
                    errorBuilder: (_, _, _) =>
                        const Icon(Icons.sports_esports, color: AppColors.accent, size: 38),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'PlayLog',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white24, height: 1),

            // ── Menü öğeleri ──
            Expanded(
              child: Consumer<AyarlarProvider>(
                builder: (context, ayarlar, _) {
                  final aktifMenuOgeleri = menuOgeleri.where((oge) {
                    if (oge.index == 2) {
                      return ayarlar.hazir ? ayarlar.raporlarSekmesiniGoster : true;
                    }
                    if (oge.index == 3) {
                      return ayarlar.hazir ? ayarlar.muhasebeSekmesiniGoster : true;
                    }
                    return true;
                  }).toList();

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: aktifMenuOgeleri.length,
                    itemBuilder: (context, index) {
                      final oge = aktifMenuOgeleri[index];
                      final secili = oge.index == seciliIndex;
                      return _MenuTile(
                        oge: oge,
                        secili: secili,
                        onTap: () {
                          onSecimDegisti(oge.index);
                          Navigator.of(context).pop(); // Drawer'ı kapat
                        },
                      );
                    },
                  );
                },
              ),
            ),

            // ── Çıkış butonu (Drawer) ──
            const Divider(color: Colors.white24, height: 1),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.white54),
              title: const Text(
                'Çıkış Yap',
                style: TextStyle(color: Colors.white54),
              ),
              onTap: () {
                Navigator.of(context).pop();
                showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Çıkış Yap'),
                    content: const Text(
                        'Hesabınızdan çıkış yapmak istediğinize emin misiniz?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('İptal'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Çıkış Yap'),
                      ),
                    ],
                  ),
                ).then((onay) async {
                  if (onay == true && context.mounted) {
                    await _tumVerileriTemizleVeCikisYap(context);
                  }
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Tek menü satırı widget'ı (sidebar ve drawer ortak kullanır).
class _MenuTile extends StatelessWidget {
  final MenuOgesi oge;
  final bool secili;
  final VoidCallback onTap;

  const _MenuTile({
    required this.oge,
    required this.secili,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final s = ResponsiveHelper.sidebarScale(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 6 * s, vertical: 1 * s),
      child: Material(
        color: secili ? AppColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(7),
        child: InkWell(
          borderRadius: BorderRadius.circular(7),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12 * s, vertical: 9 * s),
            child: Row(
              children: [
                Icon(
                  oge.ikon,
                  color: secili ? AppColors.accent : Colors.white70,
                  size: 19 * s,
                ),
                SizedBox(width: 10 * s),
                Text(
                  oge.baslik,
                  style: TextStyle(
                    color: secili ? Colors.white : Colors.white70,
                    fontWeight: secili ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 13.5 * s,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Kompakt menü satırı — sadece ikon + küçük yazı (mobil yatay).
class _CompactMenuTile extends StatelessWidget {
  final MenuOgesi oge;
  final bool secili;
  final VoidCallback onTap;

  const _CompactMenuTile({
    required this.oge,
    required this.secili,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      child: Material(
        color: secili ? AppColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  oge.ikon,
                  color: secili ? AppColors.accent : Colors.white70,
                  size: 17,
                ),
                const SizedBox(height: 2),
                Text(
                  oge.baslik,
                  style: TextStyle(
                    color: secili ? Colors.white : Colors.white70,
                    fontWeight: secili ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 9,
                  ),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Günlük kazanç bölümü — rapor toplamı + anlık aktif masalar.
/// Switch ile sadece rapor veya rapor+anlık gösterim.
class _GunlukKazancBolumu extends StatefulWidget {
  const _GunlukKazancBolumu();

  @override
  State<_GunlukKazancBolumu> createState() => _GunlukKazancBolumuState();
}

class _GunlukKazancBolumuState extends State<_GunlukKazancBolumu> {
  bool _anlikDahil = false;
  bool _gizli = false;

  @override
  Widget build(BuildContext context) {
    final raporProvider = context.watch<RaporProvider>();
    final ayarlar = context.watch<AyarlarProvider>();
    final paraBirimi = ayarlar.hazir ? ayarlar.paraBirimi : '₺';
    final s = ResponsiveHelper.sidebarScale(context);

    // Bugünün rapor toplamı
    final raporToplam = raporProvider.toplamTutar;

    // Anlık aktif masaların koşan ücreti
    double anlikToplam = 0;
    if (_anlikDahil) {
      anlikToplam = _aktifMasalarToplami(context, ayarlar);
    }

    final gosterilenToplam = raporToplam + anlikToplam;

    return Column(
      children: [
        const Divider(color: Colors.white24, height: 1),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 10 * s, vertical: 8 * s),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Başlık satırı
              Row(
                children: [
                  Icon(
                    Icons.monetization_on,
                    color: Colors.greenAccent,
                    size: 13 * s,
                  ),
                  SizedBox(width: 4 * s),
                  Expanded(
                    child: Text(
                      'Günlük Kazanç',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 10 * s,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  // Gizle/göster butonu
                  GestureDetector(
                    onTap: () => setState(() => _gizli = !_gizli),
                    child: Icon(
                      _gizli
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      color: Colors.white38,
                      size: 15 * s,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 6 * s),
              // Toplam tutar
              Center(
                child: Text(
                  _gizli
                      ? '***'
                      : '$paraBirimi${gosterilenToplam.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: _anlikDahil ? Colors.greenAccent : Colors.white,
                    fontSize: 16 * s,
                    fontWeight: FontWeight.bold,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              SizedBox(height: 3 * s),
              // Alt açıklama
              if (!_gizli)
                Center(
                  child: Text(
                    _anlikDahil
                        ? 'Rapor: ${Formatters.para(raporToplam)}  ·  Aktif: ${Formatters.para(anlikToplam)}'
                        : 'Kesinleşen (rapor toplamı)',
                    style: TextStyle(color: Colors.white38, fontSize: 10 * s),
                    textAlign: TextAlign.center,
                  ),
                ),
              SizedBox(height: 4 * s),
              // Switch
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Aktif masalar dahil',
                      style: TextStyle(color: Colors.white54, fontSize: 10 * s),
                    ),
                  ),
                  Transform.scale(
                    scale: 0.6 * s,
                    child: Switch(
                      value: _anlikDahil,
                      onChanged: (v) => setState(() => _anlikDahil = v),
                      activeThumbColor: Colors.greenAccent,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Tüm aktif masaların (oturumların) anlık koşan ücretini hesaplar.
  double _aktifMasalarToplami(BuildContext context, AyarlarProvider ayarlar) {
    final oturumProvider = context.watch<OturumProvider>();
    final masaProvider = context.watch<MasaProvider>();
    final satisProvider = context.watch<SatisProvider>();

    double toplam = 0;
    for (final oturum in oturumProvider.aktifOturumlar) {
      // Masanın konsol tipini bul
      String konsolTipi = 'PS5';
      try {
        konsolTipi = masaProvider.masalar
            .firstWhere((m) => m.id == oturum.masaId)
            .konsolTipi;
      } catch (_) {}

      // Zaman ücreti
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

      // Kol ekstra ücreti
      final kolEkstra = ayarlar.kolEkstraUcretHesapla(
        oturum.kolSayisi,
        konsolTipi,
      );

      // Sipariş toplamı
      final siparisToplami = satisProvider
          .oturumSatislari(oturum.id)
          .fold<double>(0, (t, s) => t + s.toplamTutar);

      toplam += zamanUcreti + kolEkstra + siparisToplami;
    }
    return toplam;
  }
}

/// Compact sidebar — günlük kazanç özeti (ikon + tutar).
/// Dokunulunca detay popup açar.
class _CompactKazancBolumu extends StatelessWidget {
  const _CompactKazancBolumu();

  @override
  Widget build(BuildContext context) {
    final raporProvider = context.watch<RaporProvider>();
    final ayarlar = context.watch<AyarlarProvider>();
    final paraBirimi = ayarlar.hazir ? ayarlar.paraBirimi : '₺';
    final toplam = raporProvider.toplamTutar;

    return Column(
      children: [
        const Divider(color: Colors.white24, height: 1),
        GestureDetector(
          onTap: () => _showKazancDetayPopup(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Column(
              children: [
                const Icon(
                  Icons.monetization_on,
                  color: Colors.greenAccent,
                  size: 14,
                ),
                const SizedBox(height: 1),
                Text(
                  '$paraBirimi${toplam.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showKazancDetayPopup(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => const _GunlukKazancDetayDialogu(),
    );
  }
}

/// Compact sidebar — tarife bilgisi ikonu (dokunulunca popup açılır).
class _CompactTarifeBolumu extends StatelessWidget {
  const _CompactTarifeBolumu();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: GestureDetector(
        onTap: () => _showTarifePopup(context),
        child: const Column(
          children: [
            Icon(Icons.receipt_long, color: Colors.white38, size: 16),
            SizedBox(height: 1),
            Text(
              'Tarife',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 8,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showTarifePopup(BuildContext context) {
    final ayarlar = context.read<AyarlarProvider>();
    if (!ayarlar.hazir) return;

    final konsolTipleri = ayarlar.konsolTipleri;
    final birim = ayarlar.birimEtiketi;
    final paraBirimi = ayarlar.paraBirimi;
    final kolModu = ayarlar.kolUcretModu;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.receipt_long, size: 20),
            SizedBox(width: 8),
            Text('Tarife', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: konsolTipleri.map((konsol) {
              final temelUcret = ayarlar.konsolTemelUcret(konsol);
              final kolTarifeleri = ayarlar.konsolKolTarifeleri[konsol] ?? {};
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      konsol,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '  1-2 kol: $paraBirimi${temelUcret.toStringAsFixed(0)}$birim',
                      style: const TextStyle(fontSize: 13),
                    ),
                    if (kolModu == 'tarife')
                      ...kolTarifeleri.entries
                          .where((e) => e.key > 2)
                          .map(
                            (e) => Text(
                              '  ${e.key} kol: $paraBirimi${e.value.toStringAsFixed(0)}$birim',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                    if (kolModu == 'ekstra')
                      () {
                        final ekstra = ayarlar.konsolKolBasinaEkstraUcret(
                          konsol,
                        );
                        if (ekstra > 0) {
                          return Text(
                            '  +$paraBirimi${ekstra.toStringAsFixed(0)}/ekstra kol',
                            style: const TextStyle(fontSize: 13),
                          );
                        }
                        return const SizedBox.shrink();
                      }(),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }
}

/// Günlük kazanç detay dialogu — compact sidebar'dan açılır.
/// Masaüstü sürümündeki detaylı döküm + aktif masalar switch'ini gösterir.
class _GunlukKazancDetayDialogu extends StatefulWidget {
  const _GunlukKazancDetayDialogu();

  @override
  State<_GunlukKazancDetayDialogu> createState() =>
      _GunlukKazancDetayDialoguState();
}

class _GunlukKazancDetayDialoguState extends State<_GunlukKazancDetayDialogu> {
  bool _anlikDahil = false;
  bool _gizli = false;

  @override
  Widget build(BuildContext context) {
    final raporProvider = context.watch<RaporProvider>();
    final ayarlar = context.watch<AyarlarProvider>();
    final paraBirimi = ayarlar.hazir ? ayarlar.paraBirimi : '₺';
    final raporToplam = raporProvider.toplamTutar;

    double anlikToplam = 0;
    if (_anlikDahil) {
      anlikToplam = _aktifMasalarToplami(context, ayarlar);
    }
    final gosterilenToplam = raporToplam + anlikToplam;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(
            Icons.monetization_on,
            color: Colors.greenAccent,
            size: 20,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('Günlük Kazanç', style: TextStyle(fontSize: 16)),
          ),
          GestureDetector(
            onTap: () => setState(() => _gizli = !_gizli),
            child: Icon(
              _gizli ? Icons.visibility_off_rounded : Icons.visibility_rounded,
              size: 20,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Toplam tutar
          Text(
            _gizli
                ? '***'
                : '$paraBirimi${gosterilenToplam.toStringAsFixed(2)}',
            style: TextStyle(
              color: _anlikDahil ? Colors.greenAccent : null,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 8),
          if (!_gizli) ...[
            // Döküm satırları
            _kazancSatiri(
              'Kesinleşen (Rapor)',
              raporToplam,
              paraBirimi,
              Icons.check_circle_outline,
              Colors.green,
            ),
            if (_anlikDahil)
              _kazancSatiri(
                'Aktif Masalar',
                anlikToplam,
                paraBirimi,
                Icons.play_circle_outline,
                Colors.orange,
              ),
            const Divider(height: 20),
          ],
          // Switch
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Aktif masalar dahil edilsin mi?',
                  style: TextStyle(fontSize: 13),
                ),
              ),
              Switch(
                value: _anlikDahil,
                onChanged: (v) => setState(() => _anlikDahil = v),
                activeThumbColor: Colors.greenAccent,
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Kapat'),
        ),
      ],
    );
  }

  Widget _kazancSatiri(
    String label,
    double tutar,
    String paraBirimi,
    IconData icon,
    Color renk,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 16, color: renk),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
          Text(
            '$paraBirimi${tutar.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: renk,
            ),
          ),
        ],
      ),
    );
  }

  double _aktifMasalarToplami(BuildContext context, AyarlarProvider ayarlar) {
    final oturumProvider = context.watch<OturumProvider>();
    final masaProvider = context.watch<MasaProvider>();
    final satisProvider = context.watch<SatisProvider>();

    double toplam = 0;
    for (final oturum in oturumProvider.aktifOturumlar) {
      String konsolTipi = 'PS5';
      try {
        konsolTipi = masaProvider.masalar
            .firstWhere((m) => m.id == oturum.masaId)
            .konsolTipi;
      } catch (_) {}

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

      final siparisToplami = satisProvider
          .oturumSatislari(oturum.id)
          .fold<double>(0, (t, s) => t + s.toplamTutar);

      toplam += zamanUcreti + kolEkstra + siparisToplami;
    }
    return toplam;
  }
}
