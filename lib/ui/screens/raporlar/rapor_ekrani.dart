import 'package:flutter/services.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../data/models/rapor_model.dart';
import '../../../logic/providers/rapor_provider.dart';
import '../../../logic/providers/masa_provider.dart';
import '../../../logic/providers/ayarlar_provider.dart';
import 'rapor_detay_ekrani.dart';

/// Raporlar sekmesi — filtreleme, listeleme, özet kartları.
class RaporEkrani extends StatefulWidget {
  const RaporEkrani({super.key});

  @override
  State<RaporEkrani> createState() => _RaporEkraniState();
}

class _RaporEkraniState extends State<RaporEkrani> {
  Timer? _sifirlamaTimer;

  @override
  void initState() {
    super.initState();
    // Her sekmeye girildiğinde bugünün periyoduna sıfırla
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ayarlar = context.read<AyarlarProvider>();
      context.read<RaporProvider>().gunlukFiltreyiSifirla(
        sifirlSaat: ayarlar.gunlukSifirlamaSaat,
        sifirlDak: ayarlar.gunlukSifirlamaDakika,
      );
      _sifirlamaTimerKur();
    });
  }

  /// Bir sonraki sıfırlama saatine kadar timer kur.
  /// Saat geldiğinde ekranı yeni periyoda geçir.
  void _sifirlamaTimerKur() {
    _sifirlamaTimer?.cancel();
    if (!mounted) return;

    final ayarlar = context.read<AyarlarProvider>();
    final simdi = DateTime.now();
    final sH = ayarlar.gunlukSifirlamaSaat;
    final sD = ayarlar.gunlukSifirlamaDakika;

    // Bir sonraki sıfırlama noktası
    DateTime hedef = DateTime(simdi.year, simdi.month, simdi.day, sH, sD);
    if (hedef.isBefore(simdi) || hedef.isAtSameMomentAs(simdi)) {
      hedef = hedef.add(const Duration(days: 1));
    }

    _sifirlamaTimer = Timer(hedef.difference(simdi), () {
      if (!mounted) return;
      final ay = context.read<AyarlarProvider>();
      context.read<RaporProvider>().gunlukFiltreyiSifirla(
        sifirlSaat: ay.gunlukSifirlamaSaat,
        sifirlDak: ay.gunlukSifirlamaDakika,
      );
      _sifirlamaTimerKur();
    });
  }

  @override
  void dispose() {
    _sifirlamaTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const _RaporIcerik();
  }
}

class _RaporIcerik extends StatefulWidget {
  const _RaporIcerik();

  @override
  State<_RaporIcerik> createState() => __RaporIcerikState();
}

class __RaporIcerikState extends State<_RaporIcerik> {
  final Set<String> _secilenler = {};
  bool _secimModu = false;

  void _secimModuGir(String id) {
    setState(() {
      _secimModu = true;
      _secilenler.add(id);
    });
  }

  void _secimModuCik() {
    setState(() {
      _secimModu = false;
      _secilenler.clear();
    });
  }

  void _togglSec(String id) {
    setState(() {
      if (_secilenler.contains(id)) {
        _secilenler.remove(id);
        if (_secilenler.isEmpty) _secimModu = false;
      } else {
        _secilenler.add(id);
      }
    });
  }

  void _hepsiniSecToggle(List<RaporModel> liste) {
    setState(() {
      if (_secilenler.length == liste.length) {
        _secilenler.clear();
        if (_secilenler.isEmpty) _secimModu = false;
      } else {
        _secilenler
          ..clear()
          ..addAll(liste.map((r) => r.id));
      }
    });
  }

  Future<void> _secilenlerinSilDialog(BuildContext context) async {
    final ok = await adminSifreKontrol(context);
    if (!ok) return;
    if (!context.mounted) return;
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(
          Icons.delete_forever,
          color: AppColors.error,
          size: 48,
        ),
        title: const Text('Seçilenleri Sil'),
        content: Text(
          '${_secilenler.length} rapor kalıcı olarak silinecek.\nBu işlem geri alınamaz!',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete, size: 18),
            label: const Text('Sil'),
          ),
        ],
      ),
    );
    if (onay == true) {
      if (!context.mounted) return;
      final ids = List<String>.from(_secilenler);
      _secimModuCik();
      await context.read<RaporProvider>().secilenlerinSil(ids);
    }
  }

  @override
  Widget build(BuildContext context) {
    final raporProvider = context.watch<RaporProvider>();
    final filtrelenmis = raporProvider.filtrelenmisRaporlar;

    return Column(
      children: [
        // ── Filtre çubuğu ──
        _FiltreBar(),
        // ── Seçim modu action bar ──
        if (_secimModu)
          _SecimActionBar(
            secilenSayisi: _secilenler.length,
            toplamSayisi: filtrelenmis.length,
            onTumunuSecToggle: () => _hepsiniSecToggle(filtrelenmis),
            onIptal: _secimModuCik,
            onSil: () => _secilenlerinSilDialog(context),
          ),
        // ── Özet kartları ──
        _OzetKartlari(provider: raporProvider),
        const SizedBox(height: 4),
        // ── Rapor listesi ──
        Expanded(
          child: raporProvider.yukleniyor
              ? const Center(child: CircularProgressIndicator())
              : filtrelenmis.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.assessment_outlined,
                        size: 64,
                        color: AppColors.textS(context),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Rapor bulunamadı.',
                        style: TextStyle(color: AppColors.textS(context)),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.symmetric(
                    horizontal: ResponsiveHelper.isCompactSidebar(context)
                        ? 6
                        : 16,
                    vertical: 4,
                  ),
                  itemCount: filtrelenmis.length,
                  itemBuilder: (ctx, i) {
                    final rapor = filtrelenmis[i];
                    return _RaporKarti(
                      rapor: rapor,
                      secimModu: _secimModu,
                      secili: _secilenler.contains(rapor.id),
                      onToggle: () => _togglSec(rapor.id),
                      onSecimModuGir: () => _secimModuGir(rapor.id),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// Filtre çubuğu — bugün / tarih aralığı / mesai saati / masa / ödeme.
class _FiltreBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final raporProvider = context.watch<RaporProvider>();
    final ayarlar = context.watch<AyarlarProvider>();
    final masaProvider = context.watch<MasaProvider>();
    final masalar = masaProvider.masalar;

    final String sifirlamaStr = _ikiHane(
      ayarlar.gunlukSifirlamaSaat,
      ayarlar.gunlukSifirlamaDakika,
    );

    final compact = ResponsiveHelper.isCompactSidebar(context);

    return Card(
      margin: EdgeInsets.all(compact ? 6 : 12),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 16,
          vertical: compact ? 6 : 12,
        ),
        child: Wrap(
          spacing: compact ? 6 : 10,
          runSpacing: compact ? 4 : 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // ── Bugün chip ──
            FilterChip(
              selected: raporProvider.bugunMu,
              showCheckmark: false,
              avatar: const Icon(Icons.today, size: 16),
              label: const Text('Bugün'),
              onSelected: (_) {
                raporProvider.gunlukFiltreyiSifirla(
                  sifirlSaat: ayarlar.gunlukSifirlamaSaat,
                  sifirlDak: ayarlar.gunlukSifirlamaDakika,
                );
              },
            ),
            // ── Dün chip ──
            FilterChip(
              selected: raporProvider.dunMu,
              showCheckmark: false,
              avatar: const Icon(Icons.history, size: 16),
              label: const Text('Dün'),
              onSelected: (_) {
                raporProvider.dunFiltreyiAyarla(
                  sifirlSaat: ayarlar.gunlukSifirlamaSaat,
                  sifirlDak: ayarlar.gunlukSifirlamaDakika,
                );
              },
            ),
            // ── Tarih aralığı chip ──
            ActionChip(
              avatar: Icon(
                Icons.date_range,
                size: 18,
                color: (raporProvider.bugunMu || raporProvider.dunMu)
                    ? null
                    : Theme.of(context).colorScheme.primary,
              ),
              label: Text(
                (raporProvider.bugunMu || raporProvider.dunMu)
                    ? 'Tarih Aralığı Seç'
                    : '${Formatters.tarih(raporProvider.filtreBas)} – ${Formatters.tarih(raporProvider.filtreSon)}',
                style: (raporProvider.bugunMu || raporProvider.dunMu)
                    ? null
                    : TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
              ),

              onPressed: () async {
                final aralik = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2024),
                  lastDate: DateTime.now().add(const Duration(days: 1)),
                  initialDateRange: DateTimeRange(
                    start: DateTime(
                      raporProvider.filtreBas.year,
                      raporProvider.filtreBas.month,
                      raporProvider.filtreBas.day,
                    ),
                    end: DateTime(
                      raporProvider.filtreSon.year,
                      raporProvider.filtreSon.month,
                      raporProvider.filtreSon.day,
                    ),
                  ),
                );
                if (aralik != null && context.mounted) {
                  final sH = ayarlar.gunlukSifirlamaSaat;
                  final sD = ayarlar.gunlukSifirlamaDakika;
                  raporProvider.tarihFiltresiAyarla(
                    DateTime(
                      aralik.start.year,
                      aralik.start.month,
                      aralik.start.day,
                      sH,
                      sD,
                    ),
                    DateTime(
                      aralik.end.year,
                      aralik.end.month,
                      aralik.end.day,
                      sH,
                      sD,
                    ).subtract(const Duration(seconds: 1)),
                  );
                }
              },
            ),
            // ── Sıfırlama saati chip ──
            ActionChip(
              avatar: const Icon(Icons.schedule, size: 16),
              label: Text('Sıfırlama: $sifirlamaStr'),
              onPressed: () =>
                  _sifirlamaSaatiDiyalogu(context, ayarlar, raporProvider),
            ),
            // ── Masa filtresi ──
            DropdownButton<String?>(
              value: raporProvider.filtreMasaId,
              hint: const Text('Tüm Masalar'),
              underline: const SizedBox.shrink(),
              items: [
                const DropdownMenuItem(value: null, child: Text('Tüm Masalar')),
                ...masalar.map(
                  (m) => DropdownMenuItem(value: m.id, child: Text(m.ad)),
                ),
              ],
              onChanged: (val) => raporProvider.masaFiltresiAyarla(val),
            ),
            // ── Ödeme filtresi ──
            DropdownButton<OdemeYontemi?>(
              value: raporProvider.filtreOdeme,
              hint: const Text('Tüm Ödemeler'),
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(value: null, child: Text('Tüm Ödemeler')),
                DropdownMenuItem(
                  value: OdemeYontemi.nakit,
                  child: Text('Nakit'),
                ),
                DropdownMenuItem(value: OdemeYontemi.kart, child: Text('Kart')),
                DropdownMenuItem(
                  value: OdemeYontemi.parcali,
                  child: Text('Parçalı'),
                ),
              ],
              onChanged: (val) => raporProvider.odemeFiltresiAyarla(val),
            ),
            // ── Sıralama filtresi ──
            DropdownButton<RaporSiralama>(
              value: raporProvider.siralama,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(value: RaporSiralama.zamanAzalan, child: Text('Zaman (Yeni)')),
                DropdownMenuItem(value: RaporSiralama.zamanArtan, child: Text('Zaman (Eski)')),
                DropdownMenuItem(value: RaporSiralama.tutarAzalan, child: Text('Tutar (Yüksek)')),
                DropdownMenuItem(value: RaporSiralama.tutarArtan, child: Text('Tutar (Düşük)')),
              ],
              onChanged: (val) {
                if (val != null) raporProvider.siralamaAyarla(val);
              },
            ),
            // ── Toplu Sil ──
            TextButton.icon(
              onPressed: () async {
                final ok = await adminSifreKontrol(context);
                if (ok && context.mounted) {
                  topluSilDiyalogu(context);
                }
              },
              icon: const Icon(
                Icons.delete_sweep,
                size: 18,
                color: AppColors.error,
              ),
              label: const Text(
                'Toplu Sil',
                style: TextStyle(color: AppColors.error),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _ikiHane(int saat, int dakika) =>
      '${saat.toString().padLeft(2, '0')}:${dakika.toString().padLeft(2, '0')}';
}

/// Günlük sıfırlama saati düzenleme dialogu.
void _sifirlamaSaatiDiyalogu(
  BuildContext context,
  AyarlarProvider ayarlar,
  RaporProvider raporProvider,
) {
  TimeOfDay secilen = ayarlar.gunlukSifirlamaTimeOfDay;

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.schedule, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Günlük Sıfırlama Saati'),
          ],
        ),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Her gün bu saatte raporlar sıfırlanır. Bir oturum, başlangıç saatine göre ilgili güne atanır.',
                  style: TextStyle(fontSize: 13, color: AppColors.textS(ctx)),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                icon: const Icon(Icons.access_time, size: 22),
                label: Text(
                  '${secilen.hour.toString().padLeft(2, '0')}:${secilen.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                onPressed: () async {
                  final picked = await showTimePicker(
                    context: ctx,
                    initialTime: secilen,
                    helpText: 'Günlük Sıfırlama Saati',
                    builder: (c, child) => MediaQuery(
                      data: MediaQuery.of(
                        c,
                      ).copyWith(alwaysUse24HourFormat: true),
                      child: child!,
                    ),
                  );
                  if (picked != null) setState(() => secilen = picked);
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('İptal'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.save, size: 18),
            label: const Text('Kaydet'),
            onPressed: () async {
              await ayarlar.gunlukSifirlamaAyarla(secilen);
              if (raporProvider.bugunMu) {
                raporProvider.gunlukFiltreyiSifirla(
                  sifirlSaat: secilen.hour,
                  sifirlDak: secilen.minute,
                );
              }
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    ),
  );
}

/// Özet kartları — toplam, nakit, kart, rapor sayısı.
class _OzetKartlari extends StatelessWidget {
  final RaporProvider provider;
  const _OzetKartlari({required this.provider});

  @override
  Widget build(BuildContext context) {
    final liste = provider.filtrelenmisRaporlar;
    final compact = ResponsiveHelper.isCompactSidebar(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 12),
      child: Row(
        children: [
          _OzetKart(
            ikon: Icons.receipt_long,
            baslik: 'Toplam',
            deger: Formatters.para(provider.toplamTutar),
            renk: AppColors.vurguMavi(context),
            compact: compact,
          ),
          _OzetKart(
            ikon: Icons.money,
            baslik: 'Nakit',
            deger: Formatters.para(provider.toplamNakit),
            renk: Colors.green,
            compact: compact,
          ),
          _OzetKart(
            ikon: Icons.credit_card,
            baslik: 'Kart',
            deger: Formatters.para(provider.toplamKart),
            renk: AppColors.mavi(context),
            compact: compact,
          ),
          _OzetKart(
            ikon: Icons.list_alt,
            baslik: 'İşlem',
            deger: '${liste.length}',
            renk: Colors.orange,
            compact: compact,
          ),
        ],
      ),
    );
  }
}

class _OzetKart extends StatelessWidget {
  final IconData ikon;
  final String baslik;
  final String deger;
  final Color renk;
  final bool compact;

  const _OzetKart({
    required this.ikon,
    required this.baslik,
    required this.deger,
    required this.renk,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(compact ? 6 : 12),
          child: Column(
            children: [
              Icon(ikon, color: renk, size: compact ? 20 : 28),
              SizedBox(height: compact ? 2 : 4),
              Text(
                baslik,
                style: TextStyle(
                  fontSize: compact ? 9 : 12,
                  color: AppColors.textS(context),
                ),
              ),
              SizedBox(height: compact ? 1 : 2),
              Text(
                deger,
                style: TextStyle(
                  fontSize: compact ? 11 : 16,
                  fontWeight: FontWeight.bold,
                  color: renk,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rapor listesi kartı.
class _RaporKarti extends StatelessWidget {
  final RaporModel rapor;
  final bool secimModu;
  final bool secili;
  final VoidCallback? onToggle;
  final VoidCallback? onSecimModuGir;

  const _RaporKarti({
    required this.rapor,
    this.secimModu = false,
    this.secili = false,
    this.onToggle,
    this.onSecimModuGir,
  });

  @override
  Widget build(BuildContext context) {
    final odemeIkon = switch (rapor.odemeYontemi) {
      OdemeYontemi.nakit => Icons.money,
      OdemeYontemi.kart => Icons.credit_card,
      OdemeYontemi.parcali => Icons.call_split,
    };
    final odemeRenk = switch (rapor.odemeYontemi) {
      OdemeYontemi.nakit => Colors.green,
      OdemeYontemi.kart => AppColors.mavi(context),
      OdemeYontemi.parcali => Colors.orange,
    };

    final isDirekt = rapor.isDirektSatis;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: secili
          ? Theme.of(
              context,
            ).colorScheme.primaryContainer.withValues(alpha: 0.5)
          : null,
      child: ListTile(
        leading: secimModu
            ? Checkbox(
                value: secili,
                onChanged: (_) => onToggle?.call(),
                activeColor: AppColors.primary,
              )
            : isDirekt
            ? CircleAvatar(
                backgroundColor: Colors.orange.withValues(alpha: 0.15),
                child: const Icon(
                  Icons.point_of_sale,
                  color: Colors.orange,
                  size: 20,
                ),
              )
            : CircleAvatar(
                backgroundColor: odemeRenk.withValues(alpha: 0.15),
                child: Icon(odemeIkon, color: odemeRenk, size: 20),
              ),
        title: Text(
          isDirekt ? 'Direkt Satış' : '${rapor.masaAd}  ·  ${rapor.konsolTipi}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isDirekt
                  ? '${Formatters.saat(rapor.baslangic)}  ·  Kafeterya  ·  ${rapor.odemeMetni}'
                  : '${Formatters.saat(rapor.baslangic)} – ${Formatters.saat(rapor.bitis)}  ·  ${rapor.oynananDk} dk  ·  ${rapor.odemeMetni}',
            ),
            if (rapor.aciklama.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  rapor.aciklama,
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: AppColors.textS(context),
                  ),
                ),
              ),
          ],
        ),
        trailing: secimModu
            ? Text(
                Formatters.para(rapor.toplamTutar),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.vurguMavi(context),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    Formatters.para(rapor.toplamTutar),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.vurguMavi(context),
                    ),
                  ),
                  const SizedBox(width: 4),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 20),
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'duzelt',
                        child: Row(
                          children: [
                            Icon(
                              Icons.edit,
                              size: 18,
                              color: Color(0xFF64B5F6),
                            ),
                            SizedBox(width: 8),
                            Text('Düzenle'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'sil',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete,
                              size: 18,
                              color: AppColors.error,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Sil',
                              style: TextStyle(color: AppColors.error),
                            ),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (val) async {
                      if (val == 'duzelt') {
                        final ok = await adminSifreKontrol(context);
                        if (ok && context.mounted) {
                          raporDuzenleDiyalogu(context, rapor);
                        }
                      } else if (val == 'sil') {
                        final ok = await adminSifreKontrol(context);
                        if (ok && context.mounted) {
                          raporSilDiyalogu(context, rapor);
                        }
                      }
                    },
                  ),
                ],
              ),
        onTap: secimModu
            ? onToggle
            : () {
                showDialog(
                  context: context,
                  builder: (_) => RaporDetayEkrani(rapor: rapor),
                );
              },
        onLongPress: secimModu ? null : onSecimModuGir,
      ),
    );
  }
}

/// Seçim modu üst çubuğu.
class _SecimActionBar extends StatelessWidget {
  final int secilenSayisi;
  final int toplamSayisi;
  final VoidCallback onTumunuSecToggle;
  final VoidCallback onIptal;
  final VoidCallback onSil;

  const _SecimActionBar({
    required this.secilenSayisi,
    required this.toplamSayisi,
    required this.onTumunuSecToggle,
    required this.onIptal,
    required this.onSil,
  });

  @override
  Widget build(BuildContext context) {
    final hepsiSecili = secilenSayisi == toplamSayisi && toplamSayisi > 0;
    return Container(
      color: Theme.of(context).colorScheme.primaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Text(
            '$secilenSayisi rapor seçildi',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: onTumunuSecToggle,
            child: Text(hepsiSecili ? 'Seçimi Kaldır' : 'Tümünü Seç'),
          ),
          const SizedBox(width: 4),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: secilenSayisi == 0 ? null : onSil,
            icon: const Icon(Icons.delete, size: 16),
            label: const Text('Sil'),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Seçimi İptal Et',
            onPressed: onIptal,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════
// Ortak fonksiyonlar — admin şifre, düzenle, sil
// ═══════════════════════════════════════

/// Admin şifre doğrulama dialogu.
/// Şifre ayarlanmamışsa direkt true döner.
Future<bool> adminSifreKontrol(BuildContext context) async {
  final ayarlar = context.read<AyarlarProvider>();
  if (!ayarlar.sifreAktifMi) return true;

  final sifreCtrl = TextEditingController();
  String? hata;

  final sonuc = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('Admin Şifre'),
        icon: Icon(Icons.lock, color: AppColors.vurguMavi(ctx)),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Bu işlem için admin şifresi gereklidir.'),
              const SizedBox(height: 12),
              TextField(
                controller: sifreCtrl,
                obscureText: true,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Şifre',
                  prefixIcon: const Icon(Icons.lock_outline),
                  errorText: hata,
                ),
                onSubmitted: (_) {
                  if (ayarlar.sifreDogrula(sifreCtrl.text)) {
                    Navigator.of(ctx).pop(true);
                  } else {
                    setState(() => hata = 'Şifre yanlış!');
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () {
              if (ayarlar.sifreDogrula(sifreCtrl.text)) {
                Navigator.of(ctx).pop(true);
              } else {
                setState(() => hata = 'Şifre yanlış!');
              }
            },
            child: const Text('Onayla'),
          ),
        ],
      ),
    ),
  );
  return sonuc ?? false;
}

/// Rapor düzenleme dialogu.
void raporDuzenleDiyalogu(BuildContext context, RaporModel rapor) {
  final raporProvider = context.read<RaporProvider>();
  final messenger = ScaffoldMessenger.of(context);
  OdemeYontemi secilen = rapor.odemeYontemi;
  final toplamCtrl = TextEditingController(
    text: rapor.toplamTutar.toStringAsFixed(2),
  );
  final nakitCtrl = TextEditingController(
    text: rapor.nakitTutar.toStringAsFixed(2),
  );
  final kartCtrl = TextEditingController(
    text: rapor.kartTutar.toStringAsFixed(2),
  );
  final konsolCtrl = TextEditingController(
    text: rapor.konsolUcreti.toStringAsFixed(2),
  );
  final kolEkstraCtrl = TextEditingController(
    text: rapor.kolEkstraUcreti.toStringAsFixed(2),
  );
  final siparisCtrl = TextEditingController(
    text: rapor.siparisUcreti.toStringAsFixed(2),
  );
  String? hata;

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        void toplamGuncelle() {
          final konsol = double.tryParse(konsolCtrl.text) ?? 0;
          final kolE = double.tryParse(kolEkstraCtrl.text) ?? 0;
          final sip = double.tryParse(siparisCtrl.text) ?? 0;
          final toplam = konsol + kolE + sip;
          toplamCtrl.text = toplam.toStringAsFixed(2);

          if (secilen == OdemeYontemi.nakit) {
            nakitCtrl.text = toplam.toStringAsFixed(2);
            kartCtrl.text = '0.00';
          } else if (secilen == OdemeYontemi.kart) {
            kartCtrl.text = toplam.toStringAsFixed(2);
            nakitCtrl.text = '0.00';
          }
        }

        return AlertDialog(
          title: const Text('Rapor Düzenle'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Masa bilgisi (salt okunur)
                  Text(
                    rapor.isDirektSatis
                        ? 'Direkt Satış'
                        : '${rapor.masaAd} · ${rapor.konsolTipi}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textS(ctx),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Ücret alanları
                  const Text(
                    'Ücret Kırılımı',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  if (!rapor.isDirektSatis) ...[
                    _raporDuzenleSatiri('Konsol Ücreti', konsolCtrl, () {
                      toplamGuncelle();
                      setState(() {});
                    }),
                    const SizedBox(height: 8),
                    _raporDuzenleSatiri('Kol Ekstra', kolEkstraCtrl, () {
                      toplamGuncelle();
                      setState(() {});
                    }),
                    const SizedBox(height: 8),
                  ],
                  _raporDuzenleSatiri('Kafeterya', siparisCtrl, () {
                    toplamGuncelle();
                    setState(() {});
                  }),
                  const Divider(height: 20),

                  // Toplam (salt okunur)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'TOPLAM',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.vurguMavi(ctx),
                        ),
                      ),
                      Text(
                        '₺${toplamCtrl.text}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: AppColors.vurguMavi(ctx),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Ödeme yöntemi
                  const Text(
                    'Ödeme Yöntemi',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<OdemeYontemi>(
                    segments: const [
                      ButtonSegment(
                        value: OdemeYontemi.nakit,
                        icon: Icon(Icons.money, size: 16),
                        label: Text('Nakit'),
                      ),
                      ButtonSegment(
                        value: OdemeYontemi.kart,
                        icon: Icon(Icons.credit_card, size: 16),
                        label: Text('Kart'),
                      ),
                      ButtonSegment(
                        value: OdemeYontemi.parcali,
                        icon: Icon(Icons.call_split, size: 16),
                        label: Text('Parçalı'),
                      ),
                    ],
                    selected: {secilen},
                    onSelectionChanged: (s) {
                      setState(() {
                        secilen = s.first;
                        toplamGuncelle();
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
                            keyboardType: const TextInputType.numberWithOptions(
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
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: kartCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
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
                          ),
                        ),
                      ],
                    ),
                  ],

                  if (hata != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      hata!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('İptal'),
            ),
            FilledButton.icon(
              onPressed: () async {
                final toplam = double.tryParse(toplamCtrl.text) ?? 0;
                final nakit = double.tryParse(nakitCtrl.text) ?? 0;
                final kart = double.tryParse(kartCtrl.text) ?? 0;
                final konsol = double.tryParse(konsolCtrl.text) ?? 0;
                final kolE = double.tryParse(kolEkstraCtrl.text) ?? 0;
                final sip = double.tryParse(siparisCtrl.text) ?? 0;

                if (secilen == OdemeYontemi.parcali) {
                  final fark = (nakit + kart - toplam).abs();
                  if (fark > 0.01) {
                    setState(
                      () => hata =
                          'Nakit + Kart toplamı (₺${(nakit + kart).toStringAsFixed(2)}) genel toplamla (₺${toplam.toStringAsFixed(2)}) eşleşmiyor!',
                    );
                    return;
                  }
                }

                final guncellenmis = rapor.copyWith(
                  konsolUcreti: konsol,
                  kolEkstraUcreti: kolE,
                  siparisUcreti: sip,
                  toplamTutar: toplam,
                  odemeYontemi: secilen,
                  nakitTutar: nakit,
                  kartTutar: kart,
                );

                final basarili = await raporProvider.raporGuncelle(
                  guncellenmis,
                );
                if (ctx.mounted) Navigator.of(ctx).pop();
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      basarili ? 'Rapor güncellendi ✓' : 'Güncelleme hatası!',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.save, size: 18),
              label: const Text('Kaydet'),
            ),
          ],
        );
      },
    ),
  );
}

/// Ücret düzenleme satırı.
Widget _raporDuzenleSatiri(
  String label,
  TextEditingController ctrl,
  VoidCallback onChange,
) {
  return Row(
    children: [
      SizedBox(
        width: 120,
        child: Text(label, style: const TextStyle(fontSize: 13)),
      ),
      Expanded(
        child: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
          ],
          decoration: const InputDecoration(prefixText: '₺ ', isDense: true),
          onChanged: (_) => onChange(),
        ),
      ),
    ],
  );
}

/// Toplu rapor silme dialogu — tarih aralığı / saat aralığı / tümünü sil.
void topluSilDiyalogu(BuildContext context) {
  final raporProvider = context.read<RaporProvider>();
  final masaProvider = context.read<MasaProvider>();
  final messenger = ScaffoldMessenger.of(context);

  int mod = 0; // 0=tarih, 1=saat, 2=masa, 3=tümünü
  DateTime tarihBas = DateTime.now().subtract(const Duration(days: 30));
  DateTime tarihSon = DateTime.now();
  TimeOfDay saatBas = const TimeOfDay(hour: 0, minute: 0);
  TimeOfDay saatSon = const TimeOfDay(hour: 23, minute: 59);
  String? secilenMasaId;
  bool islem = false;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_sweep, color: AppColors.error),
            SizedBox(width: 8),
            Text('Toplu Rapor Sil'),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Mod seçimi
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(
                      value: 0,
                      icon: Icon(Icons.date_range, size: 16),
                      label: Text('Tarih'),
                    ),
                    ButtonSegment(
                      value: 1,
                      icon: Icon(Icons.schedule, size: 16),
                      label: Text('Saat'),
                    ),
                    ButtonSegment(
                      value: 2,
                      icon: Icon(Icons.videogame_asset, size: 16),
                      label: Text('Masa Seç'),
                    ),
                    ButtonSegment(
                      value: 3,
                      icon: Icon(Icons.delete_forever, size: 16),
                      label: Text('Tümünü'),
                    ),
                  ],
                  selected: {mod},
                  onSelectionChanged: islem
                      ? null
                      : (s) => setState(() => mod = s.first),
                ),
              ),
              const SizedBox(height: 16),

              // İçerik: Tarih Aralığı
              if (mod == 0)
                ..._tarihAraligiIcerik(
                  ctx,
                  tarihBas,
                  tarihSon,
                  islem,
                  (d) => setState(() => tarihBas = d),
                  (d) => setState(() => tarihSon = d),
                ),

              // İçerik: Saat Aralığı
              if (mod == 1)
                ..._saatAraligiIcerik(
                  ctx,
                  tarihBas,
                  tarihSon,
                  saatBas,
                  saatSon,
                  islem,
                  (d) => setState(() => tarihBas = d),
                  (d) => setState(() => tarihSon = d),
                  (t) => setState(() => saatBas = t),
                  (t) => setState(() => saatSon = t),
                ),

              // İçerik: Masa Seç
              if (mod == 2)
                ..._masaSecimIcerik(
                  ctx,
                  masaProvider.masalar,
                  secilenMasaId,
                  islem,
                  (id) => setState(() => secilenMasaId = id),
                ),

              // İçerik: Tümünü Sil
              if (mod == 3)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.delete_forever,
                        color: AppColors.error,
                        size: 44,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'TÜM RAPORLAR SİLİNECEK!',
                        style: TextStyle(
                          color: AppColors.error,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Sistemdeki tüm rapor kayıtları kalıcı\nolarak silinecek. Bu işlem geri alınamaz!',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textS(ctx),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: islem ? null : () => Navigator.of(ctx).pop(),
            child: const Text('İptal'),
          ),
          FilledButton.icon(
            onPressed: islem
                ? null
                : () async {
                    if (mod == 2 && secilenMasaId == null) return;
                    setState(() => islem = true);
                    int silinen = 0;
                    if (mod == 0) {
                      silinen = await raporProvider.tarihAraligiTopluSil(
                        tarihBas,
                        tarihSon.add(
                          const Duration(days: 1) - const Duration(seconds: 1),
                        ),
                      );
                    } else if (mod == 1) {
                      silinen = await raporProvider.saatAraligiTopluSil(
                        tarihBas: tarihBas,
                        tarihSon: tarihSon.add(
                          const Duration(days: 1) - const Duration(seconds: 1),
                        ),
                        saatBasDak: saatBas.hour * 60 + saatBas.minute,
                        saatSonDak: saatSon.hour * 60 + saatSon.minute,
                      );
                    } else if (mod == 2) {
                      silinen = await raporProvider.masaKayitlariniTopluSil(
                        secilenMasaId!,
                      );
                    } else {
                      silinen = await raporProvider.tumRaporlariSil();
                    }
                    if (ctx.mounted) Navigator.of(ctx).pop();
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('$silinen rapor silindi ✓'),
                        backgroundColor: silinen > 0 ? Colors.green : null,
                      ),
                    );
                  },
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            icon: islem
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.delete_sweep, size: 18),
            label: const Text('Sil'),
          ),
        ],
      ),
    ),
  );
}

List<Widget> _masaSecimIcerik(
  BuildContext context,
  List<dynamic> masalar,
  String? secilenMasaId,
  bool disabled,
  ValueChanged<String?> onDegistir,
) {
  return [
    const Text(
      'Silinecek masayı seçin:',
      style: TextStyle(fontWeight: FontWeight.w600),
    ),
    const SizedBox(height: 8),
    DropdownButtonFormField<String>(
      initialValue: secilenMasaId,
      hint: const Text('Masa seçiniz...'),
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.videogame_asset),
        isDense: true,
      ),
      items: masalar
          .map(
            (m) => DropdownMenuItem<String>(
              value: m.id as String,
              child: Text(m.ad as String),
            ),
          )
          .toList(),
      onChanged: disabled ? null : onDegistir,
    ),
    const SizedBox(height: 12),
    if (secilenMasaId != null)
      _uyariKutusu('Seçilen masaya ait tüm rapor kayıtları silinecek.')
    else
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'Lütfen yukarıdan bir masa seçin.',
          style: TextStyle(fontSize: 12, color: AppColors.textS(context)),
          textAlign: TextAlign.center,
        ),
      ),
  ];
}

List<Widget> _tarihAraligiIcerik(
  BuildContext context,
  DateTime tarihBas,
  DateTime tarihSon,
  bool disabled,
  ValueChanged<DateTime> onBas,
  ValueChanged<DateTime> onSon,
) {
  return [
    const Text(
      'Silinecek tarih aralığı:',
      style: TextStyle(fontWeight: FontWeight.w600),
    ),
    const SizedBox(height: 8),
    Row(
      children: [
        Expanded(
          child: _tarihSeciciButon(
            context,
            tarihBas,
            'Başlangıç',
            disabled,
            onBas,
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text('–'),
        ),
        Expanded(
          child: _tarihSeciciButon(context, tarihSon, 'Bitiş', disabled, onSon),
        ),
      ],
    ),
    const SizedBox(height: 12),
    _uyariKutusu(
      '${Formatters.tarih(tarihBas)} – ${Formatters.tarih(tarihSon)} '
      'arasındaki tüm raporlar silinecek.',
    ),
  ];
}

List<Widget> _saatAraligiIcerik(
  BuildContext context,
  DateTime tarihBas,
  DateTime tarihSon,
  TimeOfDay saatBas,
  TimeOfDay saatSon,
  bool disabled,
  ValueChanged<DateTime> onTarihBas,
  ValueChanged<DateTime> onTarihSon,
  ValueChanged<TimeOfDay> onSaatBas,
  ValueChanged<TimeOfDay> onSaatSon,
) {
  return [
    const Text('Tarih aralığı:', style: TextStyle(fontWeight: FontWeight.w600)),
    const SizedBox(height: 8),
    Row(
      children: [
        Expanded(
          child: _tarihSeciciButon(
            context,
            tarihBas,
            'Başlangıç',
            disabled,
            onTarihBas,
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text('–'),
        ),
        Expanded(
          child: _tarihSeciciButon(
            context,
            tarihSon,
            'Bitiş',
            disabled,
            onTarihSon,
          ),
        ),
      ],
    ),
    const SizedBox(height: 10),
    const Text('Saat aralığı:', style: TextStyle(fontWeight: FontWeight.w600)),
    const SizedBox(height: 8),
    Row(
      children: [
        Expanded(
          child: _saatSeciciButon(
            context,
            saatBas,
            'Saat Başlangıç',
            disabled,
            onSaatBas,
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text('–'),
        ),
        Expanded(
          child: _saatSeciciButon(
            context,
            saatSon,
            'Saat Bitiş',
            disabled,
            onSaatSon,
          ),
        ),
      ],
    ),
    const SizedBox(height: 12),
    _uyariKutusu(
      '${Formatters.tarih(tarihBas)} – ${Formatters.tarih(tarihSon)} tarihlerinde\n'
      '${saatBas.format(context)} – ${saatSon.format(context)} saatleri arasındaki raporlar silinecek.',
    ),
  ];
}

Widget _tarihSeciciButon(
  BuildContext context,
  DateTime mevcut,
  String ipucu,
  bool disabled,
  ValueChanged<DateTime> onChange,
) {
  return OutlinedButton.icon(
    icon: const Icon(Icons.calendar_today, size: 14),
    label: Text(Formatters.tarih(mevcut), style: const TextStyle(fontSize: 13)),
    onPressed: disabled
        ? null
        : () async {
            final secilen = await showDatePicker(
              context: context,
              initialDate: mevcut,
              firstDate: DateTime(2024),
              lastDate: DateTime.now().add(const Duration(days: 1)),
              helpText: ipucu,
            );
            if (secilen != null) onChange(secilen);
          },
  );
}

Widget _saatSeciciButon(
  BuildContext context,
  TimeOfDay mevcut,
  String ipucu,
  bool disabled,
  ValueChanged<TimeOfDay> onChange,
) {
  return OutlinedButton.icon(
    icon: const Icon(Icons.access_time, size: 14),
    label: Text(mevcut.format(context), style: const TextStyle(fontSize: 13)),
    onPressed: disabled
        ? null
        : () async {
            final secilen = await showTimePicker(
              context: context,
              initialTime: mevcut,
              helpText: ipucu,
            );
            if (secilen != null) onChange(secilen);
          },
  );
}

Widget _uyariKutusu(String mesaj) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: AppColors.error.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.warning_amber, color: AppColors.error, size: 16),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            mesaj,
            style: const TextStyle(fontSize: 12, color: AppColors.error),
          ),
        ),
      ],
    ),
  );
}

/// Rapor silme onay dialogu.
void raporSilDiyalogu(BuildContext context, RaporModel rapor) {
  final raporProvider = context.read<RaporProvider>();
  final messenger = ScaffoldMessenger.of(context);
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.delete_forever, color: AppColors.error, size: 48),
      title: const Text('Raporu Sil'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${rapor.masaAd} · ${Formatters.saat(rapor.baslangic)} · ${Formatters.para(rapor.toplamTutar)}',
              style: const TextStyle(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Bu rapor kalıcı olarak silinecek.\nBu işlem geri alınamaz!',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textS(ctx)),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('İptal'),
        ),
        FilledButton.icon(
          onPressed: () async {
            final basarili = await raporProvider.raporSil(rapor.id);
            if (ctx.mounted) Navigator.of(ctx).pop();
            messenger.showSnackBar(
              SnackBar(
                content: Text(basarili ? 'Rapor silindi ✓' : 'Silme hatası!'),
              ),
            );
          },
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          icon: const Icon(Icons.delete, size: 18),
          label: const Text('Sil'),
        ),
      ],
    ),
  );
}
