import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../data/models/masa_model.dart';
import '../../../logic/providers/masa_provider.dart';
import '../../../logic/providers/ayarlar_provider.dart';
import '../../widgets/masa_karti.dart';
import '../../widgets/masa_detay_sidebar.dart';
import '../raporlar/rapor_ekrani.dart' show adminSifreKontrol;

/// Masalar ekranı — tüm masaların grid görünümü + sağ sidebar detay paneli.
class MasalarEkrani extends StatefulWidget {
  const MasalarEkrani({super.key});

  /// Detay panelinin açık olup olmadığını bildiren notifier.
  /// AnaEkran bu değere bakarak compact modda sidebar'ı gizler.
  static final ValueNotifier<bool> detayPaneliAcik = ValueNotifier(false);

  @override
  State<MasalarEkrani> createState() => _MasalarEkraniState();
}

class _MasalarEkraniState extends State<MasalarEkrani> {
  MasaModel? _seciliMasa;

  Future<void> _masaEkleDialogu(BuildContext context) async {
    final ok = await adminSifreKontrol(context);
    if (!ok || !context.mounted) return;

    final adController = TextEditingController();
    final ayarlar = context.read<AyarlarProvider>();
    String secilenKonsol = ayarlar.konsolTipleri.first;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('Yeni Masa Ekle'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: adController,
                decoration: const InputDecoration(
                  labelText: 'Masa Adı',
                  hintText: 'Örn: Masa 1',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: secilenKonsol,
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

                final provider = context.read<MasaProvider>();
                await provider.masaEkle(ad: ad, konsolTipi: secilenKonsol);
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: const Text('Ekle'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final masaProvider = context.watch<MasaProvider>();
    final masalar = masaProvider.masalar;
    final columnCount = ResponsiveHelper.gridColumnCount(context);
    final isCompact = ResponsiveHelper.isCompactSidebar(context);

    // Seçili masa silinmişse sidebar'ı kapat
    if (_seciliMasa != null && !masalar.any((m) => m.id == _seciliMasa!.id)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _seciliMasa = null);
          MasalarEkrani.detayPaneliAcik.value = false;
        }
      });
    }

    // Seçili masa varsa canlı versiyonunu al
    final canliSeciliMasa = _seciliMasa != null
        ? masalar.firstWhere(
            (m) => m.id == _seciliMasa!.id,
            orElse: () => _seciliMasa!,
          )
        : null;

    return Scaffold(
      body: Stack(
        children: [
          // ── Arka plan filigran logo ──
          Positioned.fill(
            child: Align(
              alignment: Alignment.center,
              child: Opacity(
                opacity: Theme.of(context).brightness == Brightness.dark
                    ? 0.10
                    : 0.18,
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 520,
                  height: 520,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),
          // ── Grid (full width her zaman) ──
          Column(
            children: [
              // ── Özet bar ──
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 10 : 16,
                  vertical: isCompact ? 8 : 12,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.sports_esports,
                      color: AppColors.vurguMavi(context),
                      size: isCompact ? 20 : 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Masalar',
                      style: TextStyle(
                        fontSize: isCompact ? 16 : 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    _OzetChip(
                      label: 'Toplam',
                      deger: '${masaProvider.toplamMasa}',
                      renk: AppColors.vurguMavi(context),
                      compact: isCompact,
                    ),
                    const SizedBox(width: 8),
                    _OzetChip(
                      label: 'Boş',
                      deger: '${masaProvider.bosMasaSayisi}',
                      renk: AppColors.masaBos,
                      compact: isCompact,
                    ),
                    const SizedBox(width: 8),
                    _OzetChip(
                      label: 'Dolu',
                      deger: '${masaProvider.doluMasaSayisi}',
                      renk: AppColors.masaDolu,
                      compact: isCompact,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // ── Grid ──
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    // Boş alana tıklanınca sidebar kapansın
                    if (_seciliMasa != null) {
                      setState(() => _seciliMasa = null);
                      MasalarEkrani.detayPaneliAcik.value = false;
                    }
                  },
                  behavior: HitTestBehavior.translucent,
                  child: masaProvider.yukleniyor
                      ? const Center(child: CircularProgressIndicator())
                      : masalar.isEmpty
                      ? Center(
                          child: Text(
                            'Henüz masa eklenmedi.\nSağ alttaki + butonuna tıklayın.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textS(context)),
                          ),
                        )
                      : GridView.builder(
                          padding: EdgeInsets.all(isCompact ? 6 : 10),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columnCount,
                                crossAxisSpacing: isCompact ? 5 : 8,
                                mainAxisSpacing: isCompact ? 5 : 8,
                                childAspectRatio: isCompact ? 1.1 : 1.05,
                              ),
                          itemCount: masalar.length,
                          itemBuilder: (context, index) {
                            final masa = masalar[index];
                            return MasaKarti(
                              masa: masa,
                              secili: canliSeciliMasa?.id == masa.id,
                              onTap: () {
                                setState(() {
                                  if (_seciliMasa?.id == masa.id) {
                                    _seciliMasa = null;
                                    MasalarEkrani.detayPaneliAcik.value = false;
                                  } else {
                                    _seciliMasa = masa;
                                    MasalarEkrani.detayPaneliAcik.value = true;
                                  }
                                });
                              },
                            );
                          },
                        ),
                ),
              ),
            ],
          ),

          // ── Overlay + Sidebar ──
          if (canliSeciliMasa != null) ...[
            // Yarı saydam arka plan — boş alanına tıklayınca kapanır
            // IgnorePointer aracılığıyla grid tıklamalarını engellemiyor
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: Colors.black.withValues(
                    alpha: AppColors.isDark(context) ? 0.4 : 0.15,
                  ),
                ),
              ),
            ),
            // Sidebar — sağdan kayarak açılır
            Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              child: MasaDetaySidebar(
                key: ValueKey(canliSeciliMasa.id),
                masa: canliSeciliMasa,
                onKapat: () {
                  setState(() => _seciliMasa = null);
                  MasalarEkrani.detayPaneliAcik.value = false;
                },
              ),
            ),
          ],
        ],
      ),
      floatingActionButton: ValueListenableBuilder<bool>(
        valueListenable: MasalarEkrani.detayPaneliAcik,
        builder: (context, acik, child) {
          if (acik) return const SizedBox.shrink();
          return child!;
        },
        child: FloatingActionButton(
          onPressed: () => _masaEkleDialogu(context),
          tooltip: 'Yeni Masa Ekle',
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}

/// Özet chip widget'ı (Toplam / Boş / Dolu sayıları).
class _OzetChip extends StatelessWidget {
  final String label;
  final String deger;
  final Color renk;
  final bool compact;

  const _OzetChip({
    required this.label,
    required this.deger,
    required this.renk,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 10,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: renk.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: renk.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            deger,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: renk,
              fontSize: compact ? 12 : 14,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: renk, fontSize: compact ? 10 : 12),
          ),
        ],
      ),
    );
  }
}
