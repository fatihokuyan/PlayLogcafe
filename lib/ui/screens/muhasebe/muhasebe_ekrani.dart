import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../data/models/daily_report_model.dart';
import '../../../data/models/muhasebe_model.dart';
import '../../../logic/providers/kasa_provider.dart';
import '../../../core/utils/excel_export_servisi.dart';

/// Muhasebe / Kasa Takibi ekranı — 2 sekmeli (Kasa + Giderler).
class MuhasebeEkrani extends StatelessWidget {
  const MuhasebeEkrani({super.key});

  @override
  Widget build(BuildContext context) {
    // KasaProvider app seviyesinde önceden yükleniyor (app.dart).
    // Burada tekrar oluşturmak yerine mevcut instance'u kullan.
    return const _MuhasebeIcerik();
  }
}

// ═══════════════════════════════════════════════════════
// ANA İÇERİK — TabController ile 2 sekme
// ═══════════════════════════════════════════════════════

class _MuhasebeIcerik extends StatefulWidget {
  const _MuhasebeIcerik();

  @override
  State<_MuhasebeIcerik> createState() => _MuhasebeIcerikState();
}

class _MuhasebeIcerikState extends State<_MuhasebeIcerik>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kasa = context.watch<KasaProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Column(
        children: [
          // ── Ay seçici + Tab bar ──
          _UstBar(kasa: kasa, isDark: isDark, tabController: _tabController),

          // ── Sekme içerikleri ──
          Expanded(
            child: kasa.yukleniyor
                ? const Center(child: CircularProgressIndicator())
                : kasa.hata != null
                ? _HataDurumu(kasa: kasa)
                : TabBarView(
                    controller: _tabController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _KasaSekmesi(kasa: kasa, isDark: isDark),
                      _GiderlerSekmesi(kasa: kasa, isDark: isDark),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// ÜST BAR — Ay seçici + TabBar
// ═══════════════════════════════════════════════════════

class _UstBar extends StatelessWidget {
  final KasaProvider kasa;
  final bool isDark;
  final TabController tabController;

  const _UstBar({
    required this.kasa,
    required this.isDark,
    required this.tabController,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? AppColors.surfaceDark : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Ay seçici satırı
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
            child: Row(
              children: [
                _AyNavBtn(icon: Icons.chevron_left, onTap: kasa.oncekiAy),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => _ayYilSec(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.primary.withValues(alpha: 0.25)
                          : AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${KasaProvider.ayAdlari[kasa.secilenAy]} ${kasa.secilenYil}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                _AyNavBtn(icon: Icons.chevron_right, onTap: kasa.sonrakiAy),
                const Spacer(),
                // ── Excel İndir ──
                IconButton(
                  icon: const Icon(Icons.file_download_outlined, size: 20),
                  tooltip: 'Excel İndir (.xlsx)',
                  style: IconButton.styleFrom(
                    padding: const EdgeInsets.all(6),
                    minimumSize: const Size(32, 32),
                  ),
                  onPressed: () async {
                    try {
                      final path =
                          await ExcelExportServisi.muhasebeExcelIndir(
                            yil: kasa.secilenYil,
                            ay: kasa.secilenAy,
                            gunlukKayitlar: kasa.gunlukKayitlar,
                            giderKayitlari: kasa.giderKayitlari,
                            oncekiAyBakiyesi: kasa.oncekiAyBakiyesi,
                            nakitGiderForDate: kasa.nakitGiderForDate,
                            kartGiderForDate: kasa.kartGiderForDate,
                          );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Excel kaydedildi:\n$path'),
                            duration: const Duration(seconds: 6),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Hata: $e')),
                        );
                      }
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  onPressed: kasa.ayiYukle,
                  tooltip: 'Yenile',
                  style: IconButton.styleFrom(
                    padding: const EdgeInsets.all(6),
                    minimumSize: const Size(32, 32),
                  ),
                ),
              ],
            ),
          ),

          // Tab bar
          TabBar(
            controller: tabController,
            labelColor: isDark ? Colors.white : AppColors.primary,
            unselectedLabelColor: isDark
                ? Colors.white54
                : AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            indicatorWeight: 2.5,
            labelStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            tabs: const [
              Tab(
                height: 36,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.table_chart_outlined, size: 16),
                    SizedBox(width: 6),
                    Text('Kasa Tablosu'),
                  ],
                ),
              ),
              Tab(
                height: 36,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 16),
                    SizedBox(width: 6),
                    Text('Giderler'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _ayYilSec(BuildContext context) async {
    final now = DateTime.now();
    final secilen = await showDatePicker(
      context: context,
      initialDate: DateTime(kasa.secilenYil, kasa.secilenAy, 1),
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (secilen != null) {
      kasa.ayDegistir(secilen.year, secilen.month);
    }
  }
}

class _AyNavBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _AyNavBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 22),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// HATA DURUMU
// ═══════════════════════════════════════════════════════

class _HataDurumu extends StatelessWidget {
  final KasaProvider kasa;
  const _HataDurumu({required this.kasa});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 44, color: AppColors.error),
          const SizedBox(height: 8),
          Text(
            kasa.hata!,
            style: TextStyle(
              color: AppColors.textS(context),
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: kasa.ayiYukle,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Tekrar Dene', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// SEKME 1 — KASA TABLOSU
// ═══════════════════════════════════════════════════════

class _KasaSekmesi extends StatelessWidget {
  final KasaProvider kasa;
  final bool isDark;
  const _KasaSekmesi({required this.kasa, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _OzetKartlar(kasa: kasa, isDark: isDark),
        Expanded(
          child: _KasaTablosu(kasa: kasa, isDark: isDark),
        ),
      ],
    );
  }
}

// ── Özet kartları ──

class _OzetKartlar extends StatelessWidget {
  final KasaProvider kasa;
  final bool isDark;
  const _OzetKartlar({required this.kasa, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final netKazanc = kasa.filtreNetKazanc;
    final compact = ResponsiveHelper.isCompactSidebar(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(compact ? 6 : 10, 4, compact ? 6 : 10, 2),
      child: Column(
        children: [
          // Filtre satırı — yatay kaydırılabilir
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Icon(
                  Icons.filter_list,
                  size: 14,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                ),
                const SizedBox(width: 4),
                ...OzetFiltresi.values.map(
                  (f) => Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: _FiltreChip(
                      etiket: f.etiket,
                      secili: kasa.ozetFiltresi == f,
                      isDark: isDark,
                      onTap: () => kasa.ozetFiltresiDegistir(f),
                    ),
                  ),
                ),
                // Yıllık seçiliyken yıl navigasyonu göster
                if (kasa.ozetFiltresi == OzetFiltresi.yillik) ...[
                  const SizedBox(width: 6),
                  _YilSecici(kasa: kasa, isDark: isDark),
                ],
              ],
            ),
          ),
          const SizedBox(height: 4),
          // Kartlar — compact modda 2 satır (3+3)
          if (compact)
            Column(
              children: [
                Row(
                  children: [
                    _MiniKart(
                      'T. Nakit Gelir',
                      kasa.filtreNakitGelir,
                      Colors.green.shade600,
                      Icons.payments_outlined,
                      isDark,
                      compact: true,
                    ),
                    const SizedBox(width: 3),
                    _MiniKart(
                      'T. Kart Gelir',
                      kasa.filtreKartGelir,
                      Colors.blue.shade600,
                      Icons.credit_card_outlined,
                      isDark,
                      compact: true,
                    ),
                    const SizedBox(width: 3),
                    _MiniKart(
                      'T. Nakit Gider',
                      kasa.filtreNakitGider,
                      Colors.orange.shade700,
                      Icons.money_off_outlined,
                      isDark,
                      compact: true,
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    _MiniKart(
                      'T. Kart Gider',
                      kasa.filtreKartGider,
                      Colors.red.shade600,
                      Icons.credit_card_off_outlined,
                      isDark,
                      compact: true,
                    ),
                    const SizedBox(width: 3),
                    _MiniKart(
                      'Toplam Ciro',
                      kasa.filtreToplamCiro,
                      Colors.indigo.shade600,
                      Icons.bar_chart_outlined,
                      isDark,
                      compact: true,
                      vurgulu: true,
                    ),
                    const SizedBox(width: 3),
                    _MiniKart(
                      'Net Kazanç',
                      netKazanc,
                      netKazanc >= 0
                          ? Colors.teal.shade700
                          : Colors.red.shade700,
                      Icons.account_balance_wallet_outlined,
                      isDark,
                      compact: true,
                      vurgulu: true,
                    ),
                  ],
                ),
              ],
            )
          else
            Row(
              children: [
                _MiniKart(
                  'T. Nakit Gelir',
                  kasa.filtreNakitGelir,
                  Colors.green.shade600,
                  Icons.payments_outlined,
                  isDark,
                ),
                const SizedBox(width: 4),
                _MiniKart(
                  'T. Kart Gelir',
                  kasa.filtreKartGelir,
                  Colors.blue.shade600,
                  Icons.credit_card_outlined,
                  isDark,
                ),
                const SizedBox(width: 4),
                _MiniKart(
                  'T. Nakit Gider',
                  kasa.filtreNakitGider,
                  Colors.orange.shade700,
                  Icons.money_off_outlined,
                  isDark,
                ),
                const SizedBox(width: 4),
                _MiniKart(
                  'T. Kart Gider',
                  kasa.filtreKartGider,
                  Colors.red.shade600,
                  Icons.credit_card_off_outlined,
                  isDark,
                ),
                const SizedBox(width: 4),
                _MiniKart(
                  'Toplam Ciro',
                  kasa.filtreToplamCiro,
                  Colors.indigo.shade600,
                  Icons.bar_chart_outlined,
                  isDark,
                  vurgulu: true,
                ),
                const SizedBox(width: 4),
                _MiniKart(
                  'Net Kazanç',
                  netKazanc,
                  netKazanc >= 0 ? Colors.teal.shade700 : Colors.red.shade700,
                  Icons.account_balance_wallet_outlined,
                  isDark,
                  vurgulu: true,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _FiltreChip extends StatelessWidget {
  final String etiket;
  final bool secili;
  final bool isDark;
  final VoidCallback onTap;
  const _FiltreChip({
    required this.etiket,
    required this.secili,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = isDark ? Colors.blue.shade300 : AppColors.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: secili
              ? (isDark
                    ? activeColor.withValues(alpha: 0.22)
                    : activeColor.withValues(alpha: 0.16))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: secili
                ? activeColor
                : (isDark ? Colors.grey.shade600 : Colors.grey.shade500),
            width: secili ? 1.4 : 1.0,
          ),
        ),
        child: Text(
          etiket,
          style: TextStyle(
            fontSize: 10,
            fontWeight: secili ? FontWeight.w700 : FontWeight.w600,
            color: secili
                ? activeColor
                : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
          ),
        ),
      ),
    );
  }
}

class _YilSecici extends StatelessWidget {
  final KasaProvider kasa;
  final bool isDark;
  const _YilSecici({required this.kasa, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final activeColor = isDark ? Colors.blue.shade300 : AppColors.primary;
    final yil = kasa.filtreYili;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
      decoration: BoxDecoration(
        color: isDark
            ? activeColor.withValues(alpha: 0.15)
            : activeColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: activeColor.withValues(alpha: 0.4),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _yilBtn(
            Icons.chevron_left,
            () => kasa.filtreYiliniDegistir(yil - 1),
            activeColor,
          ),
          Text(
            '$yil',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: activeColor,
            ),
          ),
          _yilBtn(
            Icons.chevron_right,
            yil < DateTime.now().year
                ? () => kasa.filtreYiliniDegistir(yil + 1)
                : null,
            activeColor,
          ),
        ],
      ),
    );
  }

  Widget _yilBtn(IconData icon, VoidCallback? onTap, Color color) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Icon(
          icon,
          size: 16,
          color: onTap != null ? color : color.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}

class _MiniKart extends StatelessWidget {
  final String baslik;
  final double tutar;
  final Color renk;
  final IconData ikon;
  final bool isDark;
  final bool compact;
  final bool vurgulu;

  const _MiniKart(
    this.baslik,
    this.tutar,
    this.renk,
    this.ikon,
    this.isDark, {
    this.compact = false,
    this.vurgulu = false,
  });

  @override
  Widget build(BuildContext context) {
    // Vurgulu kartlar 1.4x flex alarak daha geniş olur
    return Expanded(
      flex: vurgulu ? 14 : 10,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? (vurgulu ? 4 : 3) : (vurgulu ? 6 : 4),
          vertical: compact ? (vurgulu ? 5 : 4) : (vurgulu ? 8 : 6),
        ),
        decoration: BoxDecoration(
          color: isDark
              ? renk.withValues(alpha: vurgulu ? 0.22 : 0.14)
              : renk.withValues(alpha: vurgulu ? 0.18 : 0.11),
          borderRadius: BorderRadius.circular(compact ? 6 : 8),
          border: Border.all(
            color: isDark
                ? renk.withValues(alpha: vurgulu ? 0.65 : 0.40)
                : renk.withValues(alpha: vurgulu ? 0.80 : 0.55),
            width: vurgulu ? 1.6 : 1.1,
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  ikon,
                  size: compact ? (vurgulu ? 11 : 9) : (vurgulu ? 14 : 11),
                  color: renk,
                ),
                const SizedBox(width: 2),
                Flexible(
                  child: Text(
                    baslik,
                    style: TextStyle(
                      fontSize: compact
                          ? (vurgulu ? 8.5 : 7.5)
                          : (vurgulu ? 10 : 9),
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? (vurgulu ? Colors.white : Colors.white60)
                          : renk,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: compact ? (vurgulu ? 2 : 1) : (vurgulu ? 3 : 2)),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                Formatters.para(tutar),
                style: TextStyle(
                  fontSize: compact
                      ? (vurgulu ? 12.5 : 10)
                      : (vurgulu ? 15 : 12),
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? (vurgulu ? Colors.white : Colors.white70)
                      : renk,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Excel benzeri tablo ──

class _KasaTablosu extends StatelessWidget {
  final KasaProvider kasa;
  final bool isDark;
  const _KasaTablosu({required this.kasa, required this.isDark});

  // Kolon genişlikleri (7 sütun) — dar ekranda küçültülür
  static double colTarih_(BuildContext c) => _compact(c) ? 56 : 68;
  static double colNakit_(BuildContext c) => _compact(c) ? 66 : 82;
  static double colNGider_(BuildContext c) => _compact(c) ? 60 : 76;
  static double colKGider_(BuildContext c) => _compact(c) ? 60 : 76;
  static double colBakiye_(BuildContext c) => _compact(c) ? 78 : 100;
  static double colPos_(BuildContext c) => _compact(c) ? 58 : 72;

  static bool _compact(BuildContext c) => ResponsiveHelper.isCompactSidebar(c);

  @override
  Widget build(BuildContext context) {
    final bugun = DateTime.now();
    final bugununTarihi = DateTime(bugun.year, bugun.month, bugun.day);

    return Column(
      children: [
        _BaslikSatiri(isDark: isDark),
        Expanded(
          child: ListView.builder(
            itemCount: kasa.gunlukKayitlar.length + 1, // +1 devreden satırı
            itemBuilder: (context, index) {
              // İlk satır: Önceki Aydan Devreden
              if (index == 0) {
                return _DevredenSatiri(
                  bakiye: kasa.oncekiAyBakiyesi,
                  isDark: isDark,
                );
              }
              final kayit = kasa.gunlukKayitlar[index - 1];
              final kayitTarihi = DateTime(
                kayit.tarih.year,
                kayit.tarih.month,
                kayit.tarih.day,
              );
              return _VeriSatiri(
                kayit: kayit,
                isDark: isDark,
                gelecekteMi: kayitTarihi.isAfter(bugununTarihi),
                bugunMu: kayitTarihi.isAtSameMomentAs(bugununTarihi),
                kasa: kasa,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DevredenSatiri extends StatelessWidget {
  final double bakiye;
  final bool isDark;
  const _DevredenSatiri({required this.bakiye, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final bg = isDark
        ? Colors.purple.shade900.withValues(alpha: 0.35)
        : Colors.purple.shade50;
    final borderColor = isDark
        ? Colors.purple.shade700.withValues(alpha: 0.4)
        : Colors.purple.shade200;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border(bottom: BorderSide(color: borderColor, width: 0.8)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          SizedBox(
            width:
                _KasaTablosu.colTarih_(context) +
                _KasaTablosu.colNakit_(context) +
                _KasaTablosu.colNGider_(context) +
                _KasaTablosu.colKGider_(context),
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                'Önceki Aydan Devreden',
                style: TextStyle(
                  fontSize: _KasaTablosu._compact(context) ? 9.5 : 11,
                  fontWeight: FontWeight.w700,
                  fontStyle: FontStyle.italic,
                  color: isDark
                      ? Colors.purple.shade200
                      : Colors.purple.shade800,
                ),
              ),
            ),
          ),
          SizedBox(
            width: _KasaTablosu.colBakiye_(context),
            child: Text(
              _VeriSatiri._fp(bakiye),
              style: TextStyle(
                fontSize: _KasaTablosu._compact(context) ? 9.5 : 11,
                fontWeight: FontWeight.bold,
                color: bakiye >= 0
                    ? (isDark ? Colors.green.shade300 : Colors.green.shade800)
                    : (isDark ? Colors.red.shade300 : Colors.red.shade700),
              ),
              textAlign: TextAlign.right,
            ),
          ),
          // Kalan sütunlar boş
          const Expanded(child: SizedBox.shrink()),
        ],
      ),
    );
  }
}

class _BaslikSatiri extends StatelessWidget {
  final bool isDark;
  const _BaslikSatiri({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF1A2F44) : AppColors.primary;

    return Container(
      decoration: BoxDecoration(color: bg),
      child: Row(
        children: [
          _BH('TARİH', _KasaTablosu.colTarih_(context)),
          _BH('N.GELİR', _KasaTablosu.colNakit_(context)),
          _BH('N.GİDER', _KasaTablosu.colNGider_(context)),
          _BH('K.GİDER', _KasaTablosu.colKGider_(context)),
          _BH('D.BAKİYE\n(NAKİT)', _KasaTablosu.colBakiye_(context)),
          _BH('KART', _KasaTablosu.colPos_(context)),
          const Expanded(child: _BH('TOPLAM', 0)),
        ],
      ),
    );
  }
}

class _BH extends StatelessWidget {
  final String text;
  final double width;
  const _BH(this.text, this.width);

  @override
  Widget build(BuildContext context) {
    final compact = _KasaTablosu._compact(context);
    final child = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 2 : 3,
        vertical: compact ? 6 : 8,
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontSize: compact ? 8 : 9.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
        textAlign: TextAlign.center,
      ),
    );
    return width > 0 ? SizedBox(width: width, child: child) : child;
  }
}

// ── Veri satırı ──

class _VeriSatiri extends StatelessWidget {
  final DailyReportModel kayit;
  final bool isDark;
  final bool gelecekteMi;
  final bool bugunMu;
  final KasaProvider kasa;

  const _VeriSatiri({
    required this.kayit,
    required this.isDark,
    required this.gelecekteMi,
    required this.bugunMu,
    required this.kasa,
  });

  @override
  Widget build(BuildContext context) {
    Color? satirBg;
    if (bugunMu) {
      satirBg = isDark
          ? Colors.amber.withValues(alpha: 0.10)
          : Colors.amber.withValues(alpha: 0.12);
    } else if (kayit.haftaSonuMu) {
      satirBg = isDark
          ? Colors.yellow.withValues(alpha: 0.04)
          : const Color(0xFFFFFDE7);
    } else if (gelecekteMi) {
      satirBg = isDark
          ? Colors.white.withValues(alpha: 0.01)
          : Colors.grey.withValues(alpha: 0.03);
    }

    final satirRenk = gelecekteMi
        ? (isDark ? Colors.white24 : Colors.grey.shade400)
        : (isDark ? Colors.white : AppColors.textPrimary);

    // Nakit ve kart gider değerleri
    final nGider = kasa.nakitGiderForDate(kayit.tarih);
    final kGider = kasa.kartGiderForDate(kayit.tarih);

    return Container(
      decoration: BoxDecoration(
        color: satirBg,
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.grey.shade300,
            width: 1,
          ),
          left: bugunMu
              ? const BorderSide(color: Colors.amber, width: 3)
              : BorderSide.none,
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
        children: [
          // TARİH
          Container(
            width: _KasaTablosu.colTarih_(context),
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.10)
                      : Colors.grey.shade300,
                  width: 1,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
              child: Column(
                children: [
                  Text(
                    '${kayit.tarih.day.toString().padLeft(2, '0')}.${kayit.tarih.month.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: bugunMu ? FontWeight.bold : FontWeight.w500,
                      color: satirRenk,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    KasaProvider.gunAdi(kayit.haftaGunu),
                    style: TextStyle(
                      fontSize: 8,
                      color: kayit.haftaSonuMu
                          ? Colors.red.shade400
                          : (isDark ? Colors.white30 : Colors.grey.shade500),
                      fontWeight: kayit.haftaSonuMu
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // NAKİT
          _DH(
            deger: kayit.nakitGelir,
            manuelMi: kayit.nakitManuelMi,
            renk: satirRenk,
            width: _KasaTablosu.colNakit_(context),
            gelecekteMi: gelecekteMi,
            isDark: isDark,
            onTap: gelecekteMi
                ? null
                : () => _degerDuzenle(
                    context,
                    baslik: 'Nakit Gelir',
                    mevcutDeger: kayit.nakitGelir,
                    otonomDeger: kayit.autoCash,
                    manuelMi: kayit.nakitManuelMi,
                    onKaydet: (d) => kasa.manuelNakitAyarla(kayit.tarih, d),
                  ),
          ),

          // NAKİT GİDER
          _DH(
            deger: nGider,
            manuelMi: false,
            renk: nGider > 0 ? Colors.orange.shade700 : satirRenk,
            width: _KasaTablosu.colNGider_(context),
            gelecekteMi: gelecekteMi,
            isDark: isDark,
          ),

          // KART GİDER
          _DH(
            deger: kGider,
            manuelMi: false,
            renk: kGider > 0 ? Colors.red.shade600 : satirRenk,
            width: _KasaTablosu.colKGider_(context),
            gelecekteMi: gelecekteMi,
            isDark: isDark,
          ),

          // BAKİYE
          Container(
            width: _KasaTablosu.colBakiye_(context),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.10)
                      : Colors.grey.shade300,
                  width: 1,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
              child: Text(
                gelecekteMi ? '-' : _fp(kayit.devredenBakiye),
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: gelecekteMi
                      ? (isDark ? Colors.white24 : Colors.grey.shade400)
                      : (kayit.devredenBakiye >= 0
                            ? Colors.green.shade700
                            : Colors.red.shade700),
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ),

          // POS
          _DH(
            deger: kayit.posGelir,
            manuelMi: kayit.posManuelMi,
            renk: satirRenk,
            width: _KasaTablosu.colPos_(context),
            gelecekteMi: gelecekteMi,
            isDark: isDark,
            onTap: gelecekteMi
                ? null
                : () => _degerDuzenle(
                    context,
                    baslik: 'Kart Gelir',
                    mevcutDeger: kayit.posGelir,
                    otonomDeger: kayit.autoPos,
                    manuelMi: kayit.posManuelMi,
                    onKaydet: (d) => kasa.manuelPosAyarla(kayit.tarih, d),
                  ),
          ),

          // TOPLAM (günlük ciro = nakit gelir + kart gelir)
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
              decoration: BoxDecoration(
                color: gelecekteMi
                    ? null
                    : (isDark
                          ? Colors.green.withValues(alpha: 0.08)
                          : const Color(0xFFE8F5E9)),
                border: Border(
                  left: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.10)
                        : Colors.grey.shade300,
                    width: 1,
                  ),
                ),
              ),
              child: Text(
                gelecekteMi ? '-' : _fp(kayit.toplam),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: gelecekteMi
                      ? (isDark ? Colors.white24 : Colors.grey.shade400)
                      : Colors.green.shade800,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }

  static String _fp(double t) => '${t.toStringAsFixed(2)} ₺';

  void _degerDuzenle(
    BuildContext context, {
    required String baslik,
    required double mevcutDeger,
    required double otonomDeger,
    required bool manuelMi,
    required Future<void> Function(double?) onKaydet,
  }) {
    final controller = TextEditingController(
      text: mevcutDeger > 0 ? mevcutDeger.toStringAsFixed(2) : '',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        actionsPadding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        title: Text(baslik, style: const TextStyle(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Builder(
              builder: (dialogCtx) {
                final maviRenk = AppColors.mavi(dialogCtx);
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: maviRenk.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome, size: 14, color: maviRenk),
                      const SizedBox(width: 5),
                      Text(
                        'Otonom: ${otonomDeger.toStringAsFixed(2)} ₺',
                        style: TextStyle(fontSize: 12, color: maviRenk),
                      ),
                    ],
                  ),
                );
              },
            ),
            if (manuelMi) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit, size: 14, color: Colors.orange),
                    SizedBox(width: 5),
                    Text(
                      'Manuel override aktif',
                      style: TextStyle(fontSize: 11, color: Colors.orange),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
              ],
              decoration: InputDecoration(
                labelText: 'Tutar (₺)',
                isDense: true,
                border: const OutlineInputBorder(),
                prefixText: '₺ ',
                suffixIcon: manuelMi
                    ? IconButton(
                        icon: Icon(
                          Icons.restore,
                          color: AppColors.mavi(ctx),
                          size: 20,
                        ),
                        tooltip: 'Otonom değere dön',
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          onKaydet(null);
                        },
                      )
                    : null,
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('İptal', style: TextStyle(fontSize: 13)),
          ),
          if (manuelMi)
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                onKaydet(null);
              },
              child: Text(
                'Otonomu Kullan',
                style: TextStyle(color: AppColors.mavi(ctx), fontSize: 13),
              ),
            ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim().replaceAll(',', '.');
              final deger = double.tryParse(text);
              if (deger == null && text.isNotEmpty) return;
              Navigator.of(ctx).pop();
              onKaydet(deger);
            },
            child: const Text('Kaydet', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

// ── Değer hücresi ──

class _DH extends StatelessWidget {
  final double deger;
  final bool manuelMi;
  final Color renk;
  final double width;
  final bool gelecekteMi;
  final bool isDark;
  final VoidCallback? onTap;

  const _DH({
    required this.deger,
    required this.manuelMi,
    required this.renk,
    required this.width,
    required this.gelecekteMi,
    required this.isDark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final compact = _KasaTablosu._compact(context);
    final dividerColor = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.grey.shade300;
    return Container(
      width: width,
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: dividerColor, width: 1),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 2,
            vertical: compact ? 4 : 5,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (manuelMi && !gelecekteMi)
                Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: Icon(
                    Icons.edit,
                    size: compact ? 6 : 8,
                    color: Colors.orange.shade400,
                  ),
                ),
              Flexible(
                child: Text(
                  gelecekteMi ? '-' : _VeriSatiri._fp(deger),
                  style: TextStyle(
                    fontSize: compact ? 9 : 10.5,
                    fontWeight: manuelMi ? FontWeight.bold : FontWeight.w500,
                    color: renk,
                    fontStyle: manuelMi ? FontStyle.italic : FontStyle.normal,
                  ),
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// SEKME 2 — GİDERLER
// ═══════════════════════════════════════════════════════

class _GiderlerSekmesi extends StatelessWidget {
  final KasaProvider kasa;
  final bool isDark;
  const _GiderlerSekmesi({required this.kasa, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final kayitlar = kasa.giderKayitlari;
    final toplam = kayitlar.fold<double>(0, (t, k) => t + k.tutar);
    final nakitToplam = kayitlar
        .where((k) => k.odemeYontemi == OdemeYontemi.nakit)
        .fold<double>(0, (t, k) => t + k.tutar);
    final kartToplam = kayitlar
        .where((k) => k.odemeYontemi == OdemeYontemi.kart)
        .fold<double>(0, (t, k) => t + k.tutar);
    final compact = _KasaTablosu._compact(context);

    return Stack(
      children: [
        Column(
          children: [
            // Üst özet
            Container(
              margin: EdgeInsets.fromLTRB(
                compact ? 6 : 12,
                compact ? 4 : 8,
                compact ? 6 : 12,
                4,
              ),
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 8 : 14,
                vertical: compact ? 6 : 10,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [
                          Colors.red.shade900.withValues(alpha: 0.3),
                          Colors.red.shade800.withValues(alpha: 0.15),
                        ]
                      : [
                          Colors.red.shade50,
                          Colors.red.shade100.withValues(alpha: 0.3),
                        ],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.red.withValues(alpha: 0.2),
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.receipt_long,
                    size: 20,
                    color: Colors.red.shade400,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${kayitlar.length} kayıt',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white70 : Colors.red.shade700,
                    ),
                  ),
                  const Spacer(),
                  // Nakit / Kart ayrımı
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.payments_outlined,
                            size: 12,
                            color: Colors.orange.shade600,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            Formatters.para(nakitToplam),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.credit_card,
                            size: 12,
                            color: Colors.red.shade500,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            Formatters.para(kartToplam),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.red.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Text(
                    Formatters.para(toplam),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade600,
                    ),
                  ),
                ],
              ),
            ),

            // Liste
            Expanded(
              child: kayitlar.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 48,
                            color: isDark
                                ? Colors.white24
                                : Colors.grey.shade300,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Bu ay gider kaydı yok',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white38
                                  : Colors.grey.shade500,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Sağ alttaki + butonuyla ekleyin',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white24
                                  : Colors.grey.shade400,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.fromLTRB(
                        compact ? 6 : 10,
                        4,
                        compact ? 6 : 10,
                        80,
                      ),
                      separatorBuilder: (_, _) => const SizedBox(height: 4),
                      itemCount: kayitlar.length,
                      itemBuilder: (context, index) {
                        final kayit = kayitlar[index];
                        return _GiderKarti(
                          kayit: kayit,
                          isDark: isDark,
                          kasa: kasa,
                        );
                      },
                    ),
            ),
          ],
        ),

        // FAB
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            heroTag: 'gider_ekle_fab',
            onPressed: () => _GiderDialogHelper.gosterDialog(
              context: context,
              kasa: kasa,
              kayit: null,
            ),
            backgroundColor: Colors.red.shade600,
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

// ── Gider kartı ──

class _GiderKarti extends StatelessWidget {
  final MuhasebeModel kayit;
  final bool isDark;
  final KasaProvider kasa;

  const _GiderKarti({
    required this.kayit,
    required this.isDark,
    required this.kasa,
  });

  @override
  Widget build(BuildContext context) {
    final isNakit = kayit.odemeYontemi == OdemeYontemi.nakit;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDarkElevated : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark
              ? Colors.red.withValues(alpha: 0.15)
              : Colors.grey.shade200,
          width: 0.8,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _GiderDialogHelper.gosterDialog(
            context: context,
            kasa: kasa,
            kayit: kayit,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                // Sol ikon — ödeme yöntemi göster
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: (isNakit ? Colors.orange : Colors.red).withValues(
                      alpha: isDark ? 0.2 : 0.08,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isNakit ? Icons.payments_outlined : Icons.credit_card,
                    size: 17,
                    color: isNakit
                        ? Colors.orange.shade600
                        : Colors.red.shade400,
                  ),
                ),
                const SizedBox(width: 10),

                // Açıklama + tarih + tür etiketi
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        kayit.aciklama.isEmpty
                            ? '(Açıklama yok)'
                            : kayit.aciklama,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            Formatters.tarih(kayit.tarih),
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? Colors.white54
                                  : AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: (isNakit ? Colors.orange : Colors.red)
                                  .withValues(alpha: isDark ? 0.2 : 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isNakit ? 'Nakit' : 'Kart',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: isNakit
                                    ? Colors.orange.shade700
                                    : Colors.red.shade600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Tutar
                Text(
                  Formatters.para(kayit.tutar),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade600,
                  ),
                ),

                // Sil butonu
                const SizedBox(width: 4),
                _SilButonu(onSil: () => _silOnay(context), isDark: isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _silOnay(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Gider Sil', style: TextStyle(fontSize: 16)),
        content: Text(
          '"${kayit.aciklama}" kaydını silmek istiyor musunuz?',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              kasa.giderSil(kayit.id);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }
}

/// Küçük çöp kutusu sil butonu.
class _SilButonu extends StatelessWidget {
  final VoidCallback onSil;
  final bool isDark;
  const _SilButonu({required this.onSil, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onSil,
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(
            Icons.delete_outline_rounded,
            size: 18,
            color: isDark ? Colors.white38 : Colors.grey.shade400,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// GİDER EKLEME / DÜZENLEME DİALOG
// ═══════════════════════════════════════════════════════

class _GiderDialogHelper {
  static void gosterDialog({
    required BuildContext context,
    required KasaProvider kasa,
    required MuhasebeModel? kayit,
  }) {
    final duzenleModu = kayit != null;
    final aciklamaCtrl = TextEditingController(
      text: duzenleModu ? kayit.aciklama : '',
    );
    final tutarCtrl = TextEditingController(
      text: duzenleModu ? kayit.tutar.toStringAsFixed(2) : '',
    );
    DateTime secilenTarih = duzenleModu ? kayit.tarih : DateTime.now();
    OdemeYontemi secilenYontem = duzenleModu
        ? kayit.odemeYontemi
        : OdemeYontemi.nakit;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            actionsPadding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            title: Row(
              children: [
                Icon(
                  duzenleModu ? Icons.edit : Icons.add_circle_outline,
                  size: 20,
                  color: Colors.red.shade400,
                ),
                const SizedBox(width: 8),
                Text(
                  duzenleModu ? 'Gider Düzenle' : 'Yeni Gider',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
            content: SizedBox(
              width: 340,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Açıklama
                  TextField(
                    controller: aciklamaCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Açıklama',
                      hintText: 'Ör: Elektrik faturası',
                      isDense: true,
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.description_outlined, size: 20),
                    ),
                    style: const TextStyle(fontSize: 14),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 12),

                  // Tutar
                  TextField(
                    controller: tutarCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Tutar (₺)',
                      isDense: true,
                      border: OutlineInputBorder(),
                      prefixText: '₺ ',
                      prefixIcon: Icon(Icons.payments_outlined, size: 20),
                    ),
                    style: const TextStyle(fontSize: 14),
                    autofocus: !duzenleModu,
                  ),
                  const SizedBox(height: 12),

                  // Ödeme yöntemi seçici
                  Row(
                    children: [
                      Expanded(
                        child: _OdemeSecenegi(
                          etiket: 'Nakit',
                          ikon: Icons.payments_outlined,
                          renk: Colors.orange,
                          secili: secilenYontem == OdemeYontemi.nakit,
                          isDark: isDark,
                          onTap: () => setDialogState(
                            () => secilenYontem = OdemeYontemi.nakit,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _OdemeSecenegi(
                          etiket: 'Kart',
                          ikon: Icons.credit_card,
                          renk: Colors.red,
                          secili: secilenYontem == OdemeYontemi.kart,
                          isDark: isDark,
                          onTap: () => setDialogState(
                            () => secilenYontem = OdemeYontemi.kart,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Tarih seçici (ileri tarih seçilemez)
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () async {
                      final secim = await showDatePicker(
                        context: ctx,
                        initialDate: secilenTarih,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (secim != null) {
                        setDialogState(() => secilenTarih = secim);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Tarih',
                        isDense: true,
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(
                          Icons.calendar_today_outlined,
                          size: 20,
                        ),
                      ),
                      child: Text(
                        Formatters.tarihKisa(secilenTarih),
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('İptal', style: TextStyle(fontSize: 13)),
              ),
              FilledButton.icon(
                onPressed: () {
                  final aciklama = aciklamaCtrl.text.trim();
                  final tutarStr = tutarCtrl.text.trim().replaceAll(',', '.');
                  final tutar = double.tryParse(tutarStr);
                  if (tutar == null || tutar <= 0) return;

                  Navigator.of(ctx).pop();

                  if (duzenleModu) {
                    kasa.giderGuncelle(
                      kayit.copyWith(
                        aciklama: aciklama,
                        tutar: tutar,
                        tarih: secilenTarih,
                        odemeYontemi: secilenYontem,
                      ),
                    );
                  } else {
                    kasa.giderEkle(
                      aciklama: aciklama,
                      tutar: tutar,
                      tarih: secilenTarih,
                      odemeYontemi: secilenYontem,
                    );
                  }
                },
                icon: Icon(duzenleModu ? Icons.save : Icons.add, size: 16),
                label: Text(
                  duzenleModu ? 'Güncelle' : 'Ekle',
                  style: const TextStyle(fontSize: 13),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Ödeme yöntemi seçenek kutusu (Nakit / Kart).
class _OdemeSecenegi extends StatelessWidget {
  final String etiket;
  final IconData ikon;
  final MaterialColor renk;
  final bool secili;
  final bool isDark;
  final VoidCallback onTap;

  const _OdemeSecenegi({
    required this.etiket,
    required this.ikon,
    required this.renk,
    required this.secili,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: secili
                ? renk.withValues(alpha: isDark ? 0.2 : 0.1)
                : (isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : Colors.grey.withValues(alpha: 0.06)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: secili
                  ? renk.withValues(alpha: 0.5)
                  : (isDark ? Colors.white12 : Colors.grey.shade300),
              width: secili ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                ikon,
                size: 18,
                color: secili
                    ? renk.shade600
                    : (isDark ? Colors.white38 : Colors.grey),
              ),
              const SizedBox(width: 6),
              Text(
                etiket,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: secili ? FontWeight.w700 : FontWeight.w500,
                  color: secili
                      ? renk.shade700
                      : (isDark ? Colors.white54 : Colors.grey.shade600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
