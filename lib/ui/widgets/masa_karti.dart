import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/masa_model.dart';
import '../../data/models/oturum_model.dart';
import '../../logic/providers/oturum_provider.dart';
import '../../logic/providers/satis_provider.dart';
import '../../logic/providers/ayarlar_provider.dart';
import '../../logic/services/sure_hesaplama_servisi.dart';
import 'sure_sayaci.dart';

/// Masa grid kartı widget'ı.
/// Güçlü renk kodlu durum, konsol tipi ve oturum bilgisi gösterimi.
class MasaKarti extends StatelessWidget {
  final MasaModel masa;
  final VoidCallback onTap;
  final bool secili;

  const MasaKarti({
    super.key,
    required this.masa,
    required this.onTap,
    this.secili = false,
  });

  // ── Durum renkleri (arka plan) ──
  Color _arkaplanRengi(BuildContext context, bool aktif, OturumModel? oturum) {
    final dark = AppColors.isDark(context);
    switch (masa.durum) {
      case MasaDurum.bos:
        return dark ? const Color(0xFF15242E) : const Color(0xFFE8F5E9);
      case MasaDurum.dolu:
        if (oturum != null && oturum.mod == OturumMod.sureli) {
          return dark ? const Color(0xFF1E2A1A) : const Color(0xFFFFF3E0);
        }
        return dark ? const Color(0xFF2C1B2A) : const Color(0xFFFFEBEE);
      case MasaDurum.rezerve:
        return dark ? const Color(0xFF2A2518) : const Color(0xFFFFF8E1);
      case MasaDurum.dondurulmus:
        return dark ? const Color(0xFF142838) : const Color(0xFFE3F2FD);
    }
  }

  Color _durumRengi(OturumModel? oturum) {
    switch (masa.durum) {
      case MasaDurum.bos:
        return AppColors.masaBos;
      case MasaDurum.dolu:
        if (oturum != null && oturum.mod == OturumMod.sureli) {
          return const Color(0xFFFF9800); // Turuncu (süreli)
        }
        return AppColors.masaDolu; // Kırmızı (süresiz)
      case MasaDurum.rezerve:
        return AppColors.masaRezerve;
      case MasaDurum.dondurulmus:
        return AppColors.masaDondurulmus;
    }
  }

  String _durumMetni(OturumModel? oturum) {
    switch (masa.durum) {
      case MasaDurum.bos:
        return 'BOŞ';
      case MasaDurum.dolu:
        if (oturum != null && oturum.mod == OturumMod.sureli) {
          return 'SÜRELİ';
        }
        return 'SÜRESİZ';
      case MasaDurum.rezerve:
        return 'REZERVE';
      case MasaDurum.dondurulmus:
        return 'DONDURULDU';
    }
  }

  IconData _durumIkonu(OturumModel? oturum) {
    switch (masa.durum) {
      case MasaDurum.bos:
        return Icons.gamepad_outlined;
      case MasaDurum.dolu:
        if (oturum != null && oturum.mod == OturumMod.sureli) {
          return Icons.hourglass_bottom;
        }
        return Icons.all_inclusive;
      case MasaDurum.rezerve:
        return Icons.event_seat;
      case MasaDurum.dondurulmus:
        return Icons.ac_unit;
    }
  }

  // ── Konsol tipi rengi ──
  Color _konsolRengi() {
    final tip = masa.konsolTipi.toLowerCase();
    if (tip.contains('ps5')) return const Color(0xFF0070D1); // PS5 mavi
    if (tip.contains('ps4')) return const Color(0xFF1A237E); // PS4 lacivert
    if (tip.contains('xbox')) return const Color(0xFF2E7D32); // Yeşil
    if (tip.contains('pc')) return const Color(0xFF6A1B9A); // Mor
    if (tip.contains('nintendo') || tip.contains('switch')) {
      return const Color(0xFFD32F2F); // Kırmızı
    }
    return AppColors.primary;
  }

  IconData _konsolIkonu() {
    final tip = masa.konsolTipi.toLowerCase();
    if (tip.contains('ps5') || tip.contains('ps4')) return Icons.sports_esports;
    if (tip.contains('xbox')) return Icons.gamepad;
    if (tip.contains('pc')) return Icons.computer;
    if (tip.contains('nintendo') || tip.contains('switch')) {
      return Icons.videogame_asset;
    }
    return Icons.sports_esports;
  }

  // ── Konsol PNG asset yolu ──
  String? _konsolGorselYolu() {
    final tip = masa.konsolTipi.toLowerCase();
    if (tip.contains('ps5')) return 'assets/images/consoles/ps5.png';
    if (tip.contains('ps4')) return 'assets/images/consoles/ps4.png';
    if (tip.contains('xbox')) return 'assets/images/consoles/xbox.png';
    if (tip.contains('pc')) return 'assets/images/consoles/pc.png';
    if (tip.contains('nintendo') || tip.contains('switch')) {
      return 'assets/images/consoles/nintendo.png';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final oturumProvider = context.watch<OturumProvider>();
    final satisProvider = context.watch<SatisProvider>();
    final oturum = oturumProvider.masaninOturumu(masa.id);
    final aktif = oturum != null && (oturum.isAktif || oturum.isDondurulmus);
    final renk = _durumRengi(oturum);
    final konsolRenk = _konsolRengi();

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: secili ? 8 : (aktif ? 12 : 2),
      shadowColor: secili
          ? AppColors.primary.withValues(alpha: 0.5)
          : (aktif
                ? renk.withValues(alpha: 0.7)
                : (AppColors.isDark(context)
                      ? Colors.black38
                      : Colors.black12)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: secili
              ? AppColors.primary
              : aktif ? renk : renk.withValues(alpha: 0.5),
          width: secili ? 3.0 : (aktif ? 3.5 : 1.5),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // ── Dinamik ölçekleme ──
            // Referans: ~220px genişlik = 1.0 scale
            final s = (constraints.maxWidth / 220).clamp(0.65, 1.0);
            final h = constraints.maxHeight;

            // PNG boyutu
            final pngBoyut = (h * 0.50 * s).clamp(60.0, 160.0);

            return Container(
              decoration: BoxDecoration(
                color: _arkaplanRengi(context, aktif, oturum),
              ),
              child: Stack(
                children: [
                  // ── Konsol PNG watermark ──
                  if (_konsolGorselYolu() != null)
                    Positioned(
                      right: 4,
                      bottom: 4,
                      child: Opacity(
                        opacity: aktif ? 1.0 : 0.40,
                        child: Image.asset(
                          _konsolGorselYolu()!,
                          width: pngBoyut,
                          height: pngBoyut,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        ),
                      ),
                    ),

                  // ── Durum sticker (kum saati / sonsuz / kar tanesi) ──
                  if (aktif)
                    Positioned(
                      top: (36 * s) + 4,
                      right: 6 * s,
                      child: Container(
                        padding: EdgeInsets.all(4 * s),
                        decoration: BoxDecoration(
                          color: renk.withValues(alpha: 0.13),
                          borderRadius: BorderRadius.circular(10 * s),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _durumIkonu(oturum),
                              size: 22 * s,
                              color: renk.withValues(alpha: 0.6),
                            ),
                            if (oturum.mod == OturumMod.sureli &&
                                masa.durum != MasaDurum.dondurulmus) ...[
                              // ignore: unnecessary_null_comparison
                              SizedBox(width: 2 * s),
                              Text(
                                '${oturum.sureDk}dk',
                                style: TextStyle(
                                  fontSize: 11 * s,
                                  fontWeight: FontWeight.w900,
                                  color: renk.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                  // ── Kart içeriği ──
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Üst Header: Konsol tipi + Durum badge ──
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10 * s,
                          vertical: 6 * s,
                        ),
                        decoration: BoxDecoration(color: konsolRenk),
                        child: Row(
                          children: [
                            Icon(
                              _konsolIkonu(),
                              size: 13 * s,
                              color: Colors.white,
                            ),
                            SizedBox(width: 4 * s),
                            Expanded(
                              child: Text(
                                masa.konsolTipi,
                                style: TextStyle(
                                  fontSize: 11 * s,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // Durum etiketi
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 5 * s,
                                vertical: 2 * s,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(8 * s),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _durumIkonu(oturum),
                                    size: 10 * s,
                                    color: Colors.white,
                                  ),
                                  SizedBox(width: 2 * s),
                                  Text(
                                    _durumMetni(oturum),
                                    style: TextStyle(
                                      fontSize: 8 * s,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ── İçerik ──
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            8 * s,
                            4 * s,
                            8 * s,
                            4 * s,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Masa adı + kol sayısı
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      masa.ad,
                                      style: TextStyle(
                                        fontSize: 18 * s,
                                        fontWeight: FontWeight.w900,
                                        color: renk,
                                        letterSpacing: 0.3,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (aktif && oturum.kolSayisi > 1) ...[
                                    SizedBox(width: 4 * s),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 4 * s,
                                        vertical: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: renk.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.sports_esports,
                                            size: 11 * s,
                                            color: renk,
                                          ),
                                          SizedBox(width: 2 * s),
                                          Text(
                                            '${oturum.kolSayisi} kol',
                                            style: TextStyle(
                                              fontSize: 10 * s,
                                              fontWeight: FontWeight.w800,
                                              color: renk,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),

                              SizedBox(height: 2 * s),

                              // ── Aktif oturum bilgisi ──
                              if (aktif) ...[
                                // Süre sayacı
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: SureSayaci(
                                    baslangic: oturum.baslangic,
                                    planliSureDk: oturum.sureDk,
                                    dondurulmus: oturum.isDondurulmus,
                                    dondurmaAni: oturum.dondurmaAni,
                                    toplamDondurulmaSuresiSn:
                                        oturum.toplamDondurulmaSuresiSn,
                                    style: TextStyle(
                                      fontSize: 20 * s,
                                      fontWeight: FontWeight.w900,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                      color: renk,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                // Toplam ücret
                                Align(
                                  alignment: Alignment.bottomLeft,
                                  child: Builder(
                                    builder: (context) {
                                      final ayarlar = context
                                          .read<AyarlarProvider>();
                                      final kolEkstra = ayarlar
                                          .kolEkstraUcretHesapla(
                                            oturum.kolSayisi,
                                            masa.konsolTipi,
                                          );
                                      final zamanUcreti =
                                          SureHesaplamaServisi.dinamikKolUcretHesapla(
                                            kolGecmisi: oturum.kolGecmisi,
                                            efektifSure: oturum.gecenSure,
                                            mod: oturum.mod,
                                            planliSureDk: oturum.sureDk,
                                            dakikaBasiUcretResolver: (kol) =>
                                                ayarlar
                                                    .konsolDakikaBasiUcretHesapla(
                                                      masa.konsolTipi,
                                                      kol,
                                                    ),
                                            fallbackKolSayisi: oturum.kolSayisi,
                                            periyotDk:
                                                SureHesaplamaServisi.efektifPeriyot(oturum.butce, ayarlar.guncellemePeriyoduDk, oturum.mod,),
                                            ilkUcretsizDk:
                                                ayarlar.ilkUcretsizDk,
                                          );
                                      final satislar = satisProvider
                                          .oturumSatislari(oturum.id);
                                      final siparis = satislar.fold<double>(
                                        0,
                                        (t, s) => t + s.toplamTutar,
                                      );
                                      return Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 8 * s,
                                          vertical: 3 * s,
                                        ),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              AppColors.primary.withValues(
                                                alpha: 0.18,
                                              ),
                                              AppColors.primary.withValues(
                                                alpha: 0.08,
                                              ),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: AppColors.primary.withValues(
                                              alpha: 0.2,
                                            ),
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          Formatters.para(
                                            zamanUcreti + kolEkstra + siparis,
                                          ),
                                          style: TextStyle(
                                            fontSize: 17 * s,
                                            fontWeight: FontWeight.w900,
                                            color: AppColors.isDark(context)
                                                ? AppColors.accent
                                                : AppColors.primary,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],

                              // ── Boş masa ──
                              if (masa.durum == MasaDurum.bos) ...[
                                const Spacer(),
                                Align(
                                  alignment: Alignment.bottomLeft,
                                  child: Icon(
                                    Icons.play_circle_outline,
                                    size: 40 * s,
                                    color: AppColors.masaBos.withValues(
                                      alpha: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
