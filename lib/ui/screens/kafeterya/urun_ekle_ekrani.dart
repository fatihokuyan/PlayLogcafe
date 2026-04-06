import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/urun_model.dart';
import '../../../logic/providers/urun_provider.dart';
import '../../../logic/providers/ayarlar_provider.dart';

/// Ürün ekleme/düzenlem dialog'u.
class UrunEkleEkrani extends StatefulWidget {
  /// Eğer verilirse düzenleme modu, null ise ekleme modu.
  final UrunModel? duzenlenecekUrun;

  const UrunEkleEkrani({super.key, this.duzenlenecekUrun});

  /// Dialog olarak aç.
  static void goster(BuildContext context, {UrunModel? duzenlenecekUrun}) {
    showDialog(
      context: context,
      builder: (_) => UrunEkleEkrani(duzenlenecekUrun: duzenlenecekUrun),
    );
  }

  @override
  State<UrunEkleEkrani> createState() => _UrunEkleEkraniState();
}

class _UrunEkleEkraniState extends State<UrunEkleEkrani> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _adController;
  late TextEditingController _fiyatController;
  late TextEditingController _stokController;
  late String _secilenKategori;
  bool _kaydediliyor = false;

  bool get _duzenlemeModuMu => widget.duzenlenecekUrun != null;

  @override
  void initState() {
    super.initState();
    final urun = widget.duzenlenecekUrun;
    _adController = TextEditingController(text: urun?.ad ?? '');
    _fiyatController = TextEditingController(
      text: urun?.fiyat.toString() ?? '',
    );
    _stokController = TextEditingController(
      text: urun?.stokMiktari.toString() ?? '0',
    );
    _secilenKategori = urun?.kategori ?? '';
  }

  @override
  void dispose() {
    _adController.dispose();
    _fiyatController.dispose();
    _stokController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kategoriler = context.read<AyarlarProvider>().urunKategorileri;
    if (_secilenKategori.isEmpty && kategoriler.isNotEmpty) {
      _secilenKategori = kategoriler.first;
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Başlık
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.vurguMavi(context).withValues(alpha: 0.1),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _duzenlemeModuMu ? Icons.edit : Icons.add_circle_outline,
                    color: AppColors.vurguMavi(context),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _duzenlemeModuMu ? 'Ürün Düzenleme' : 'Yeni Ürün Ekle',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            // Form içeriği
            Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Ürün Adı
                    TextFormField(
                      controller: _adController,
                      decoration: const InputDecoration(
                        labelText: 'Ürün Adı',
                        hintText: 'Örn: Coca Cola',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.label_outline),
                        isDense: true,
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Ürün adı boş olamaz';
                        }
                        return null;
                      },
                      autofocus: !_duzenlemeModuMu,
                    ),
                    const SizedBox(height: 14),
                    // Kategori
                    DropdownButtonFormField<String>(
                      initialValue: _secilenKategori.isEmpty
                          ? kategoriler.first
                          : _secilenKategori,
                      decoration: const InputDecoration(
                        labelText: 'Kategori',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.category_outlined),
                        isDense: true,
                      ),
                      items: kategoriler
                          .map(
                            (k) => DropdownMenuItem(value: k, child: Text(k)),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _secilenKategori = v);
                      },
                    ),
                    const SizedBox(height: 14),
                    // Fiyat & Stok yan yana
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _fiyatController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d*'),
                              ),
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Fiyat',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.attach_money),
                              suffixText: '₺',
                              isDense: true,
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Gerekli';
                              }
                              final f = double.tryParse(v.trim());
                              if (f == null || f <= 0) return 'Geçersiz';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _stokController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Stok',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.inventory_2_outlined),
                              suffixText: 'adet',
                              isDense: true,
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Gerekli';
                              }
                              final s = int.tryParse(v.trim());
                              if (s == null || s < 0) return 'Geçersiz';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Butonlar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: _kaydediliyor
                              ? null
                              : () => Navigator.of(context).pop(),
                          child: const Text('İptal'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: _kaydediliyor ? null : _kaydet,
                          icon: _kaydediliyor
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Icon(_duzenlemeModuMu ? Icons.save : Icons.add),
                          label: Text(_duzenlemeModuMu ? 'Güncelle' : 'Ekle'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _kaydet() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _kaydediliyor = true);

    final urunProvider = context.read<UrunProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final ad = _adController.text.trim();
    final fiyat = double.parse(_fiyatController.text.trim());
    final stok = int.parse(_stokController.text.trim());

    bool basarili;

    if (_duzenlemeModuMu) {
      final guncellenen = widget.duzenlenecekUrun!.copyWith(
        ad: ad,
        kategori: _secilenKategori,
        fiyat: fiyat,
        stokMiktari: stok,
      );
      basarili = await urunProvider.urunGuncelle(guncellenen);
    } else {
      basarili = await urunProvider.urunEkle(
        ad: ad,
        kategori: _secilenKategori,
        fiyat: fiyat,
        stokMiktari: stok,
      );
    }

    if (mounted) {
      setState(() => _kaydediliyor = false);
      if (basarili) {
        Navigator.of(context).pop();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              _duzenlemeModuMu ? 'Ürün güncellendi ✓' : 'Ürün eklendi ✓',
            ),
          ),
        );
      }
    }
  }
}
