import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../data/models/urun_model.dart';
import '../../../logic/providers/urun_provider.dart';
import '../../../logic/providers/ayarlar_provider.dart';
import '../../../logic/services/stok_servisi.dart';
import '../../widgets/direkt_satis_dialogu.dart';
import 'urun_ekle_ekrani.dart';

/// Kafeterya ekranı — ürün listesi, stok yönetimi.
class KafeteryaEkrani extends StatefulWidget {
  const KafeteryaEkrani({super.key});

  @override
  State<KafeteryaEkrani> createState() => _KafeteryaEkraniState();
}

class _KafeteryaEkraniState extends State<KafeteryaEkrani>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;

  // Kategorileri ayarlardan al
  List<String> _tablar = ['Tümü'];

  void _tablariGuncelle(List<String> kategoriler) {
    final yeniTablar = ['Tümü', ...kategoriler];
    if (_tablar.length != yeniTablar.length ||
        !_tablar.every((t) => yeniTablar.contains(t))) {
      _tablar = yeniTablar;
      _tabController?.dispose();
      _tabController = TabController(length: _tablar.length, vsync: this);
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final urunProvider = context.watch<UrunProvider>();
    final ayarlar = context.watch<AyarlarProvider>();
    final kritikUrunler = urunProvider.kritikStokUrunleriHesapla(
      ayarlar.kritikStokEsigi,
    );

    // Tab'ları ayarlardaki kategorilere göre güncelle
    _tablariGuncelle(ayarlar.urunKategorileri);
    _tabController ??= TabController(length: _tablar.length, vsync: this);

    return Scaffold(
      body: Column(
        children: [
          // ── Başlık + kritik stok uyarı ──
          Container(
            padding: EdgeInsets.fromLTRB(
              ResponsiveHelper.isCompactSidebar(context) ? 8 : 16,
              8,
              ResponsiveHelper.isCompactSidebar(context) ? 8 : 16,
              0,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.local_cafe,
                  color: AppColors.vurguMavi(context),
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Kafeterya',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (kritikUrunler.isNotEmpty)
                  Tooltip(
                    message: StokServisi.topluUyarilar(
                      kritikUrunler,
                    ).join('\n'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.warning_amber,
                            size: 16,
                            color: AppColors.warning,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${kritikUrunler.length} ürün kritik stok',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.warning,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Kategori tabları ──
          TabBar(
            controller: _tabController!,
            isScrollable: true,
            labelColor: AppColors.vurguMavi(context),
            unselectedLabelColor: AppColors.textS(context),
            indicatorColor: AppColors.vurguMavi(context),
            tabAlignment: TabAlignment.start,
            tabs: _tablar.map((t) => Tab(text: t)).toList(),
          ),

          // ── Ürün listesi ──
          Expanded(
            child: urunProvider.yukleniyor
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController!,
                    children: _tablar.map((tab) {
                      final urunler = tab == 'Tümü'
                          ? urunProvider.urunler
                          : urunProvider.kategoriyeGore(tab);

                      if (urunler.isEmpty) {
                        return Center(
                          child: Text(
                            tab == 'Tümü'
                                ? 'Henüz ürün eklenmedi.'
                                : '$tab kategorisinde ürün yok.',
                            style: TextStyle(
                              color: AppColors.textS(context),
                            ),
                          ),
                        );
                      }

                      return ListView.separated(
                        padding: EdgeInsets.all(
                          ResponsiveHelper.isCompactSidebar(context) ? 8 : 16,
                        ),
                        itemCount: urunler.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          return _UrunTile(urun: urunler[index]);
                        },
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'direkt_satis',
            onPressed: () => DirektSatisDialogu.goster(context),
            icon: const Icon(Icons.point_of_sale),
            label: const Text('Direkt Satış'),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'urun_ekle',
            onPressed: () => UrunEkleEkrani.goster(context),
            tooltip: 'Yeni Ürün Ekle',
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}

/// Ürün satır widget'ı.
class _UrunTile extends StatelessWidget {
  final UrunModel urun;

  const _UrunTile({required this.urun});

  @override
  Widget build(BuildContext context) {
    final esik = context.read<AyarlarProvider>().kritikStokEsigi;
    final stokKritik = StokServisi.stokKritikMi(urun, esik);
    final stokBitti = urun.stokBittiMi;

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: stokBitti
              ? AppColors.error.withValues(alpha: 0.1)
              : AppColors.vurguMavi(context).withValues(alpha: 0.1),
          child: Icon(
            _kategoriIkonu(urun.kategori),
            color: stokBitti ? AppColors.error : AppColors.vurguMavi(context),
            size: 22,
          ),
        ),
        title: Text(
          urun.ad,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.vurguMavi(context).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                urun.kategori,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.vurguMavi(context),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.inventory_2_outlined,
              size: 14,
              color: stokKritik ? AppColors.warning : AppColors.textS(context),
            ),
            const SizedBox(width: 2),
            Text(
              'Stok: ${urun.stokMiktari}',
              style: TextStyle(
                fontSize: 12,
                color: stokBitti
                    ? AppColors.error
                    : stokKritik
                    ? AppColors.warning
                    : AppColors.textS(context),
                fontWeight: stokKritik ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              Formatters.para(urun.fiyat),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.vurguMavi(context),
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              onSelected: (value) => _menuIslem(context, value, urun),
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'stok_artir',
                  child: Text('Stok Ekle'),
                ),
                const PopupMenuItem(value: 'duzenle', child: Text('Düzenle')),
                const PopupMenuItem(value: 'sil', child: Text('Sil')),
              ],
            ),
          ],
        ),
      ),
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

  void _menuIslem(BuildContext context, String islem, UrunModel urun) {
    switch (islem) {
      case 'stok_artir':
        _stokEkleDialogu(context, urun);
        break;
      case 'duzenle':
        UrunEkleEkrani.goster(context, duzenlenecekUrun: urun);
        break;
      case 'sil':
        _silOnay(context, urun);
        break;
    }
  }

  void _stokEkleDialogu(BuildContext context, UrunModel urun) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${urun.ad} — Stok Ekle'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Eklenecek Miktar',
            border: OutlineInputBorder(),
            suffixText: 'adet',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () {
              final miktar = int.tryParse(controller.text.trim());
              if (miktar == null || miktar <= 0) return;
              context.read<UrunProvider>().stokArtir(urun.id, miktar);
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$miktar adet stok eklendi.')),
              );
            },
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
  }

  void _silOnay(BuildContext context, UrunModel urun) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ürünü Sil'),
        content: Text('${urun.ad} silinecek. Emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Hayır'),
          ),
          FilledButton(
            onPressed: () {
              context.read<UrunProvider>().urunSil(urun.id);
              Navigator.of(ctx).pop();
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }
}
