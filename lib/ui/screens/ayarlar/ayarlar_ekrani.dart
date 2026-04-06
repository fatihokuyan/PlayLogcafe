import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../logic/providers/auth_provider.dart';
import '../../../logic/providers/ayarlar_provider.dart';

/// Ayarlar ekranı — kullanıcının tüm uygulama ayarlarını özelleştirmesi.
class AyarlarEkrani extends StatefulWidget {
  const AyarlarEkrani({super.key});

  @override
  State<AyarlarEkrani> createState() => _AyarlarEkraniState();
}

class _AyarlarEkraniState extends State<AyarlarEkrani> {
  static double _scrollOffset = 0.0;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController(initialScrollOffset: _scrollOffset);
    _scrollController.addListener(() {
      _scrollOffset = _scrollController.offset;
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ayarlar = context.watch<AyarlarProvider>();
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      body: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        children: [
          // ═══════════════════════════════════════
          // HESAP BİLGİLERİ
          // ═══════════════════════════════════════
          _BolumBasligi(ikon: Icons.account_circle, baslik: 'Hesap Bilgileri'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.email_outlined),
                  title: const Text('E-posta'),
                  subtitle: Text(auth.session?.user.email ?? '-'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.lock_reset),
                  title: const Text('Şifre Değiştir'),
                  subtitle: const Text('Hesap şifrenizi güncelleyin'),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () => _sifreDegistirDialog(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // ═══════════════════════════════════════
          // İŞLETME BİLGİLERİ
          // ═══════════════════════════════════════
          _BolumBasligi(ikon: Icons.store, baslik: 'İşletme Bilgileri'),
          Card(
            child: Column(
              children: [
                ListTile(
                  title: const Text('İşletme Adı'),
                  subtitle: Text(ayarlar.isletmeAdi),
                  trailing: const Icon(Icons.edit, size: 20),
                  onTap: () => _metinDuzenle(
                    context,
                    baslik: 'İşletme Adı',
                    mevcutDeger: ayarlar.isletmeAdi,
                    onKaydet: (v) => ayarlar.isletmeAdiAyarla(v),
                  ),
                ),
                ListTile(
                  title: const Text('Para Birimi'),
                  subtitle: Text(ayarlar.paraBirimi),
                  trailing: const Icon(Icons.edit, size: 20),
                  onTap: () => _metinDuzenle(
                    context,
                    baslik: 'Para Birimi',
                    mevcutDeger: ayarlar.paraBirimi,
                    onKaydet: (v) => ayarlar.paraBirimiAyarla(v),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ═══════════════════════════════════════
          // ÜCRETLENDİRME
          // ═══════════════════════════════════════
          _BolumBasligi(ikon: Icons.monetization_on, baslik: 'Ücretlendirme'),
          Card(
            child: Column(
              children: [
                // Ücret birimi toggle
                ListTile(
                  title: const Text('Ücret Birimi'),
                  trailing: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'saat', label: Text('Saat Başı')),
                      ButtonSegment(
                        value: 'dakika',
                        label: Text('Dakika Başı'),
                      ),
                    ],
                    selected: {ayarlar.ucretBirimi},
                    onSelectionChanged: (s) =>
                        ayarlar.ucretBirimiAyarla(s.first),
                  ),
                ),
                const Divider(height: 1),
                // Konsol başı ücretler
                ...ayarlar.konsolTipleri.map((tip) {
                  final ucret = ayarlar.konsolTemelUcret(tip);
                  final birimLabel = ayarlar.ucretBirimi == 'saat'
                      ? '/saat'
                      : '/dk';
                  return ListTile(
                    title: Text('$tip Ücreti (2 Kol)'),
                    subtitle: Text(
                      '${ayarlar.paraBirimi}${ucret.toStringAsFixed(2)} $birimLabel',
                    ),
                    trailing: const Icon(Icons.edit, size: 20),
                    onTap: () => _sayiDuzenle(
                      context,
                      baslik:
                          '$tip Ücreti (${ayarlar.ucretBirimi == "saat" ? "saat" : "dakika"} başı)',
                      mevcutDeger: ucret,
                      ondalik: true,
                      onKaydet: (v) => ayarlar.konsolUcretAyarla(tip, v),
                    ),
                  );
                }),
                const Divider(height: 1),
                ListTile(
                  title: const Text('Varsayılan Oturum Süresi'),
                  subtitle: Text('${ayarlar.varsayilanSureDk} dakika'),
                  trailing: const Icon(Icons.edit, size: 20),
                  onTap: () => _sayiDuzenle(
                    context,
                    baslik: 'Varsayılan Oturum Süresi (dk)',
                    mevcutDeger: ayarlar.varsayilanSureDk.toDouble(),
                    ondalik: false,
                    onKaydet: (v) => ayarlar.varsayilanSureDkAyarla(v.toInt()),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('Minimum Oturum Süresi'),
                  subtitle: Text('${ayarlar.minimumSureDk} dakika'),
                  trailing: const Icon(Icons.edit, size: 20),
                  onTap: () => _sayiDuzenle(
                    context,
                    baslik: 'Minimum Oturum Süresi (dk)',
                    mevcutDeger: ayarlar.minimumSureDk.toDouble(),
                    ondalik: false,
                    onKaydet: (v) => ayarlar.minimumSureDkAyarla(v.toInt()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ═══════════════════════════════════════
          // DİLİMLİ ÜCRET AYARI
          // ═══════════════════════════════════════
          _BolumBasligi(ikon: Icons.timelapse, baslik: 'Dilimli Ücretlendirme'),
          Card(
            child: Column(
              children: [
                ListTile(
                  title: const Text('Faturalandırma Periyodu'),
                  subtitle: Text(
                    ayarlar.guncellemePeriyoduDk == 1
                        ? 'Her dakika ayrı ayrı ücretlendirilir'
                        : 'Her ${ayarlar.guncellemePeriyoduDk} dakika bir dilim olarak ücretlendirilir\n'
                              '(Başlayan dilim tam sayılır)',
                  ),
                  trailing: DropdownButton<int>(
                    value: ayarlar.guncellemePeriyoduDk,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('1 dk')),
                      DropdownMenuItem(value: 5, child: Text('5 dk')),
                      DropdownMenuItem(value: 10, child: Text('10 dk')),
                      DropdownMenuItem(value: 15, child: Text('15 dk')),
                      DropdownMenuItem(value: 30, child: Text('30 dk')),
                      DropdownMenuItem(value: 60, child: Text('60 dk')),
                    ],
                    onChanged: (v) {
                      if (v != null) ayarlar.guncellemePeriyoduDkAyarla(v);
                    },
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('İlk Ücretsiz Süre'),
                  subtitle: Text(
                    ayarlar.ilkUcretsizDk == 0
                        ? 'Ücretsiz süre yok'
                        : 'İlk ${ayarlar.ilkUcretsizDk} dakika ücretsiz',
                  ),
                  trailing: SizedBox(
                    width: 80,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${ayarlar.ilkUcretsizDk} dk',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.edit, size: 20),
                      ],
                    ),
                  ),
                  onTap: () => _sayiDuzenle(
                    context,
                    baslik: 'İlk Ücretsiz Dakika',
                    mevcutDeger: ayarlar.ilkUcretsizDk.toDouble(),
                    ondalik: false,
                    onKaydet: (v) => ayarlar.ilkUcretsizDkAyarla(v.toInt()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ═══════════════════════════════════════
          // KOL TARİFESİ
          // ═══════════════════════════════════════
          _BolumBasligi(ikon: Icons.sports_esports, baslik: 'Kol Tarifesi'),
          Card(
            child: Column(
              children: [
                // Kol ücret modu toggle
                ListTile(
                  title: const Text('Kol Ücret Modu'),
                  subtitle: Text(
                    ayarlar.kolUcretModu == 'tarife'
                        ? 'Kol sayısına göre saatlik tarife değişir'
                        : 'Kol başına tek seferlik ekstra ücret eklenir',
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'tarife',
                        label: Text('Tarife Değişir'),
                        icon: Icon(Icons.trending_up, size: 18),
                      ),
                      ButtonSegment(
                        value: 'ekstra',
                        label: Text('Ekstra Ücret'),
                        icon: Icon(Icons.add_shopping_cart, size: 18),
                      ),
                    ],
                    selected: {ayarlar.kolUcretModu},
                    onSelectionChanged: (s) =>
                        ayarlar.kolUcretModuAyarla(s.first),
                  ),
                ),
                const Divider(height: 1),
                // Ekstra mod: konsol bazlı kol başına ücret
                if (ayarlar.kolUcretModu == 'ekstra')
                  ...ayarlar.konsolTipleri.map((tip) {
                    final ucret = ayarlar.konsolKolBasinaEkstraUcret(tip);
                    return ListTile(
                      title: Text('$tip — Kol Başına Ekstra Ücret'),
                      subtitle: Text(
                        '${ayarlar.paraBirimi}${ucret.toStringAsFixed(2)} / kol',
                      ),
                      trailing: const Icon(Icons.edit, size: 20),
                      onTap: () => _sayiDuzenle(
                        context,
                        baslik: '$tip — Kol Başına Ekstra Ücret',
                        mevcutDeger: ucret,
                        ondalik: true,
                        onKaydet: (v) =>
                            ayarlar.konsolKolEkstraUcretAyarla(tip, v),
                      ),
                    );
                  }),
                // Tarife modu: per-console kol tarifeleri
                if (ayarlar.kolUcretModu == 'tarife')
                  ...ayarlar.konsolTipleri.map((tip) {
                    final tarifeler = ayarlar.konsolKolTarifeleri[tip] ?? {};
                    final birimLabel = ayarlar.ucretBirimi == 'saat'
                        ? '/saat'
                        : '/dk';
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                          child: Text(
                            tip,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppColors.vurguMavi(context),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            '2 Kol (varsayılan): ${ayarlar.paraBirimi}${ayarlar.konsolTemelUcret(tip).toStringAsFixed(2)} $birimLabel',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textS(context),
                            ),
                          ),
                        ),
                        ...tarifeler.entries.map(
                          (entry) => ListTile(
                            dense: true,
                            title: Text('${entry.key} Kol'),
                            subtitle: Text(
                              '${ayarlar.paraBirimi}${entry.value.toStringAsFixed(2)} $birimLabel',
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.remove_circle_outline,
                                color: AppColors.error,
                                size: 20,
                              ),
                              onPressed: () => _silOnay(
                                context,
                                baslik: 'Kol Tarifesi Sil',
                                mesaj:
                                    '$tip ${entry.key} kol tarifesi silinsin mi?',
                                onSil: () => ayarlar.konsolKolTarifesiSil(
                                  tip,
                                  entry.key,
                                ),
                              ),
                            ),
                            onTap: () => _konsolKolTarifesiDuzenle(
                              context,
                              konsolTipi: tip,
                              kolSayisi: entry.key,
                              mevcutUcret: entry.value,
                              ayarlar: ayarlar,
                            ),
                          ),
                        ),
                        ListTile(
                          dense: true,
                          leading: Icon(
                            Icons.add_circle_outline,
                            color: AppColors.vurguMavi(context),
                            size: 20,
                          ),
                          title: Text(
                            '$tip Kol Tarifesi Ekle',
                            style: TextStyle(
                              color: AppColors.vurguMavi(context),
                              fontSize: 13,
                            ),
                          ),
                          onTap: () =>
                              _yeniKonsolKolTarifesiEkle(context, ayarlar, tip),
                        ),
                      ],
                    );
                  }),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ═══════════════════════════════════════
          // STOK YÖNETİMİ
          // ═══════════════════════════════════════
          _BolumBasligi(ikon: Icons.inventory_2, baslik: 'Stok Yönetimi'),
          Card(
            child: ListTile(
              title: const Text('Kritik Stok Eşiği'),
              subtitle: Text(
                '${ayarlar.kritikStokEsigi} adedin altında uyarı verilir',
              ),
              trailing: const Icon(Icons.edit, size: 20),
              onTap: () => _sayiDuzenle(
                context,
                baslik: 'Kritik Stok Eşiği',
                mevcutDeger: ayarlar.kritikStokEsigi.toDouble(),
                ondalik: false,
                onKaydet: (v) => ayarlar.kritikStokEsigiAyarla(v.toInt()),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ═══════════════════════════════════════
          // KONSOL TİPLERİ
          // ═══════════════════════════════════════
          _BolumBasligi(ikon: Icons.sports_esports, baslik: 'Konsol Tipleri'),
          Card(
            child: Column(
              children: [
                ...ayarlar.konsolTipleri.map(
                  (tip) => ListTile(
                    title: Text(tip),
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.remove_circle_outline,
                        color: AppColors.error,
                        size: 20,
                      ),
                      onPressed: ayarlar.konsolTipleri.length > 1
                          ? () => _silOnay(
                              context,
                              baslik: 'Konsol Tipi Sil',
                              mesaj: '"$tip" silinsin mi?',
                              onSil: () => ayarlar.konsolTipiSil(tip),
                            )
                          : null,
                    ),
                  ),
                ),
                ListTile(
                  leading: Icon(
                    Icons.add_circle_outline,
                    color: AppColors.vurguMavi(context),
                  ),
                  title: Text(
                    'Yeni Konsol Tipi Ekle',
                    style: TextStyle(color: AppColors.vurguMavi(context)),
                  ),
                  onTap: () => _metinDuzenle(
                    context,
                    baslik: 'Yeni Konsol Tipi',
                    mevcutDeger: '',
                    onKaydet: (v) {
                      if (v.isNotEmpty) ayarlar.konsolTipiEkle(v);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ═══════════════════════════════════════
          // ÜRÜN KATEGORİLERİ
          // ═══════════════════════════════════════
          _BolumBasligi(ikon: Icons.category, baslik: 'Ürün Kategorileri'),
          Card(
            child: Column(
              children: [
                ...ayarlar.urunKategorileri.map(
                  (kat) => ListTile(
                    title: Text(kat),
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.remove_circle_outline,
                        color: AppColors.error,
                        size: 20,
                      ),
                      onPressed: ayarlar.urunKategorileri.length > 1
                          ? () => _silOnay(
                              context,
                              baslik: 'Kategori Sil',
                              mesaj: '"$kat" silinsin mi?',
                              onSil: () => ayarlar.kategoriSil(kat),
                            )
                          : null,
                    ),
                  ),
                ),
                ListTile(
                  leading: Icon(
                    Icons.add_circle_outline,
                    color: AppColors.vurguMavi(context),
                  ),
                  title: Text(
                    'Yeni Kategori Ekle',
                    style: TextStyle(color: AppColors.vurguMavi(context)),
                  ),
                  onTap: () => _metinDuzenle(
                    context,
                    baslik: 'Yeni Kategori',
                    mevcutDeger: '',
                    onKaydet: (v) {
                      if (v.isNotEmpty) ayarlar.kategoriEkle(v);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ═══════════════════════════════════════
          // GÖRÜNÜM
          // ═══════════════════════════════════════
          _BolumBasligi(ikon: Icons.palette, baslik: 'Görünüm'),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const SizedBox.shrink(),
                    value: ayarlar.muhasebeSekmesiniGoster,
                    onChanged: (v) => ayarlar.muhasebeSekmesiniGosterAyarla(v),
                    visualDensity: VisualDensity.compact,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const SizedBox.shrink(),
                    value: ayarlar.raporlarSekmesiniGoster,
                    onChanged: (v) => ayarlar.raporlarSekmesiniGosterAyarla(v),
                    visualDensity: VisualDensity.compact,
                  ),
                  const Divider(height: 24),
                  Text('Tema', style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 4),
                  Text(
                    _temaMetni(ayarlar.temaMode),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textS(context),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.light,
                          icon: Icon(Icons.light_mode, size: 18),
                          label: Text('Açık'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          icon: Icon(Icons.dark_mode, size: 18),
                          label: Text('Koyu'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.system,
                          icon: Icon(Icons.auto_mode, size: 18),
                          label: Text('Sistem'),
                        ),
                      ],
                      selected: {ayarlar.temaMode},
                      onSelectionChanged: (s) {
                        ayarlar.temaModAyarla(s.first);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ═══════════════════════════════════════
          // RAPORLAMA — GÜNLÜK SIFIRLAMA SAATİ
          // ═══════════════════════════════════════
          _BolumBasligi(ikon: Icons.schedule, baslik: 'Raporlama'),
          const SizedBox(height: 8),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: ListTile(
              leading: const Icon(Icons.schedule),
              title: const Text('Günlük Sıfırlama Saati'),
              subtitle: Text(
                'Her gün raporların sıfırlandığı saat. Oturum başlangıç saatine göre atanır.',
                style: TextStyle(fontSize: 12),
              ),
              trailing: Text(
                '${ayarlar.gunlukSifirlamaSaat.toString().padLeft(2, '0')}:${ayarlar.gunlukSifirlamaDakika.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () async {
                final secilen = await showTimePicker(
                  context: context,
                  initialTime: ayarlar.gunlukSifirlamaTimeOfDay,
                  helpText: 'Günlük Sıfırlama Saati',
                  builder: (c, child) => MediaQuery(
                    data: MediaQuery.of(
                      c,
                    ).copyWith(alwaysUse24HourFormat: true),
                    child: child!,
                  ),
                );
                if (secilen != null) {
                  await ayarlar.gunlukSifirlamaAyarla(secilen);
                }
              },
            ),
          ),
          const SizedBox(height: 24),

          // ═══════════════════════════════════════
          // GÜVENLİK — ADMİN ŞİFRE
          // ═══════════════════════════════════════
          _BolumBasligi(ikon: Icons.lock_outline, baslik: 'Güvenlik'),
          const SizedBox(height: 8),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        ayarlar.sifreAktifMi ? Icons.lock : Icons.lock_open,
                        color: ayarlar.sifreAktifMi
                            ? Colors.green
                            : AppColors.textS(context),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        ayarlar.sifreAktifMi
                            ? 'Admin şifresi aktif'
                            : 'Admin şifresi ayarlanmamış',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: ayarlar.sifreAktifMi
                              ? Colors.green
                              : AppColors.textS(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Rapor düzenleme ve silme işlemleri için admin şifresi gerekir.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textS(context),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      FilledButton.icon(
                        onPressed: () => _adminSifreDegistir(context, ayarlar),
                        icon: Icon(
                          ayarlar.sifreAktifMi ? Icons.edit : Icons.add,
                          size: 18,
                        ),
                        label: Text(
                          ayarlar.sifreAktifMi
                              ? 'Şifre Değiştir'
                              : 'Şifre Belirle',
                        ),
                      ),
                      if (ayarlar.sifreAktifMi) ...[
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () => _adminSifreKaldir(context, ayarlar),
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: AppColors.error,
                          ),
                          label: const Text(
                            'Şifreyi Kaldır',
                            style: TextStyle(color: AppColors.error),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ═══════════════════════════════════════
          // FABRİKA AYARLARI
          // ═══════════════════════════════════════
          Center(
            child: OutlinedButton.icon(
              onPressed: () => _silOnay(
                context,
                baslik: 'Fabrika Ayarlarına Dön',
                mesaj:
                    'Tüm ayarlar varsayılan değerlere sıfırlanacak. Emin misiniz?',
                onSil: () => ayarlar.fabrikaAyarlarina(),
              ),
              icon: const Icon(Icons.restore, color: AppColors.error),
              label: const Text(
                'Fabrika Ayarlarına Dön',
                style: TextStyle(color: AppColors.error),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Versiyon & Geliştirici bilgisi ──
          Center(
            child: Column(
              children: [
                Text(
                  'PS Salon Yönetim v2.0.0',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textS(context),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.12),
                        AppColors.primary.withValues(alpha: 0.04),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.code_rounded,
                        size: 16,
                        color: AppColors.primary.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Geliştirici: ',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textS(context),
                        ),
                      ),
                      Text(
                        'mfo',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  String _temaMetni(ThemeMode mod) {
    switch (mod) {
      case ThemeMode.light:
        return 'Açık';
      case ThemeMode.dark:
        return 'Koyu';
      case ThemeMode.system:
        return 'Sistem';
    }
  }

  // ── Şifre değiştirme dialogu ──
  void _sifreDegistirDialog(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final otpModu = auth.sifirlamaOturumu;

    final eskiCtrl = TextEditingController();
    final yeniCtrl = TextEditingController();
    final tekrarCtrl = TextEditingController();
    bool eskiGizli = true;
    bool yeniGizli = true;
    bool tekrarGizli = true;
    String? hata;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Şifre Değiştir'),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (otpModu) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          color: Colors.green.shade700,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'OTP ile giriş yapıldı. Eski şifre gerekmeden yeni şifrenizi belirleyebilirsiniz.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ] else ...[
                  TextField(
                    controller: eskiCtrl,
                    obscureText: eskiGizli,
                    decoration: InputDecoration(
                      labelText: 'Mevcut Şifre',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          eskiGizli
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () =>
                            setDlgState(() => eskiGizli = !eskiGizli),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 4),
                ],
                TextField(
                  controller: yeniCtrl,
                  obscureText: yeniGizli,
                  decoration: InputDecoration(
                    labelText: 'Yeni Şifre',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        yeniGizli
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () =>
                          setDlgState(() => yeniGizli = !yeniGizli),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: tekrarCtrl,
                  obscureText: tekrarGizli,
                  decoration: InputDecoration(
                    labelText: 'Yeni Şifre (Tekrar)',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        tekrarGizli
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () =>
                          setDlgState(() => tekrarGizli = !tekrarGizli),
                    ),
                  ),
                ),
                if (hata != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    hata!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('İptal'),
            ),
            FilledButton(
              onPressed: () async {
                if (!otpModu && eskiCtrl.text.isEmpty) {
                  setDlgState(() => hata = 'Mevcut şifrenizi girin!');
                  return;
                }
                if (yeniCtrl.text.length < 6) {
                  setDlgState(
                    () => hata = 'Yeni şifre en az 6 karakter olmalı!',
                  );
                  return;
                }
                if (yeniCtrl.text != tekrarCtrl.text) {
                  setDlgState(() => hata = 'Şifreler eşleşmiyor!');
                  return;
                }
                if (!otpModu && eskiCtrl.text == yeniCtrl.text) {
                  setDlgState(
                    () => hata = 'Yeni şifre mevcut şifreyle aynı olamaz!',
                  );
                  return;
                }
                Navigator.of(ctx).pop();
                final err = await context.read<AuthProvider>().sifreDegistir(
                  eskiCtrl.text,
                  yeniCtrl.text,
                );
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(err ?? 'Şifre başarıyla güncellendi ✓'),
                    backgroundColor: err != null
                        ? Colors.red.shade800
                        : Colors.green,
                  ),
                );
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Metin düzenleme dialogu ──
  void _metinDuzenle(
    BuildContext context, {
    required String baslik,
    required String mevcutDeger,
    required Function(String) onKaydet,
  }) {
    final ctrl = TextEditingController(text: mevcutDeger);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(baslik),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            hintText: baslik,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () {
              final deger = ctrl.text.trim();
              if (deger.isNotEmpty) {
                onKaydet(deger);
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  // ── Sayı düzenleme dialogu ──
  void _sayiDuzenle(
    BuildContext context, {
    required String baslik,
    required double mevcutDeger,
    required bool ondalik,
    required Function(double) onKaydet,
  }) {
    final ctrl = TextEditingController(
      text: ondalik
          ? mevcutDeger.toStringAsFixed(2)
          : mevcutDeger.toInt().toString(),
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(baslik),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.numberWithOptions(decimal: ondalik),
          inputFormatters: [
            ondalik
                ? FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
                : FilteringTextInputFormatter.digitsOnly,
          ],
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            hintText: baslik,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () {
              final deger = double.tryParse(
                ctrl.text.trim().replaceAll(',', '.'),
              );
              if (deger != null && deger > 0) {
                onKaydet(deger);
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  // ── Konsol kol tarifesi düzenleme dialogu ──
  void _konsolKolTarifesiDuzenle(
    BuildContext context, {
    required String konsolTipi,
    required int kolSayisi,
    required double mevcutUcret,
    required AyarlarProvider ayarlar,
  }) {
    final ctrl = TextEditingController(text: mevcutUcret.toStringAsFixed(2));
    final birimLabel = ayarlar.ucretBirimi == 'saat'
        ? 'Saat Başı Ücret'
        : 'Dakika Başı Ücret';
    final suffixLabel = ayarlar.ucretBirimi == 'saat'
        ? '${ayarlar.paraBirimi}/saat'
        : '${ayarlar.paraBirimi}/dk';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$konsolTipi — $kolSayisi Kol'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
          ],
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: birimLabel,
            suffixText: suffixLabel,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () {
              final deger = double.tryParse(
                ctrl.text.trim().replaceAll(',', '.'),
              );
              if (deger != null && deger > 0) {
                ayarlar.konsolKolTarifesiAyarla(konsolTipi, kolSayisi, deger);
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  // ── Yeni konsol kol tarifesi ekleme dialogu ──
  void _yeniKonsolKolTarifesiEkle(
    BuildContext context,
    AyarlarProvider ayarlar,
    String konsolTipi,
  ) {
    final kolCtrl = TextEditingController();
    final ucretCtrl = TextEditingController(
      text: ayarlar.konsolTemelUcret(konsolTipi).toStringAsFixed(2),
    );
    final birimLabel = ayarlar.ucretBirimi == 'saat'
        ? 'Saat Başı Ücret'
        : 'Dakika Başı Ücret';
    final suffixLabel = ayarlar.ucretBirimi == 'saat'
        ? '${ayarlar.paraBirimi}/saat'
        : '${ayarlar.paraBirimi}/dk';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$konsolTipi — Yeni Kol Tarifesi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: kolCtrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Kol Sayısı',
                hintText: 'Örn: 3',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ucretCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: birimLabel,
                suffixText: suffixLabel,
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
              final kol = int.tryParse(kolCtrl.text.trim());
              final ucret = double.tryParse(
                ucretCtrl.text.trim().replaceAll(',', '.'),
              );
              if (kol != null && kol >= 3 && ucret != null && ucret > 0) {
                ayarlar.konsolKolTarifesiAyarla(konsolTipi, kol, ucret);
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
  }

  // ── Admin şifre değiştirme dialogu ──
  void _adminSifreDegistir(BuildContext context, AyarlarProvider ayarlar) {
    final eskiSifreCtrl = TextEditingController();
    final yeniSifreCtrl = TextEditingController();
    final tekrarCtrl = TextEditingController();
    String? hata;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(
            ayarlar.sifreAktifMi ? 'Şifre Değiştir' : 'Şifre Belirle',
          ),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (ayarlar.sifreAktifMi)
                  TextField(
                    controller: eskiSifreCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Mevcut Şifre',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                  ),
                if (ayarlar.sifreAktifMi) const SizedBox(height: 12),
                TextField(
                  controller: yeniSifreCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Yeni Şifre',
                    prefixIcon: Icon(Icons.lock),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: tekrarCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Yeni Şifre (Tekrar)',
                    prefixIcon: Icon(Icons.lock),
                  ),
                ),
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
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('İptal'),
            ),
            FilledButton(
              onPressed: () {
                // Mevcut şifre kontrolü
                if (ayarlar.sifreAktifMi &&
                    !ayarlar.sifreDogrula(eskiSifreCtrl.text)) {
                  setState(() => hata = 'Mevcut şifre yanlış!');
                  return;
                }
                if (yeniSifreCtrl.text.isEmpty) {
                  setState(() => hata = 'Yeni şifre boş olamaz!');
                  return;
                }
                if (yeniSifreCtrl.text.length < 4) {
                  setState(() => hata = 'Şifre en az 4 karakter olmalı!');
                  return;
                }
                if (yeniSifreCtrl.text != tekrarCtrl.text) {
                  setState(() => hata = 'Şifreler eşleşmiyor!');
                  return;
                }
                ayarlar.adminSifreAyarla(yeniSifreCtrl.text);
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Admin şifresi güncellendi ✓')),
                );
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Admin şifre kaldırma ──
  void _adminSifreKaldir(BuildContext context, AyarlarProvider ayarlar) {
    final sifreCtrl = TextEditingController();
    String? hata;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Şifreyi Kaldır'),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Şifreyi kaldırmak için mevcut şifrenizi girin.'),
                const SizedBox(height: 12),
                TextField(
                  controller: sifreCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Mevcut Şifre',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
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
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('İptal'),
            ),
            FilledButton(
              onPressed: () {
                if (!ayarlar.sifreDogrula(sifreCtrl.text)) {
                  setState(() => hata = 'Şifre yanlış!');
                  return;
                }
                ayarlar.adminSifreAyarla('');
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Admin şifresi kaldırıldı')),
                );
              },
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              child: const Text('Kaldır'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Silme onay dialogu ──
  void _silOnay(
    BuildContext context, {
    required String baslik,
    required String mesaj,
    required VoidCallback onSil,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(baslik),
        content: Text(mesaj),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () {
              onSil();
              Navigator.of(ctx).pop();
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Onayla'),
          ),
        ],
      ),
    );
  }
}

/// Bölüm başlığı widget'ı.
class _BolumBasligi extends StatelessWidget {
  final IconData ikon;
  final String baslik;

  const _BolumBasligi({required this.ikon, required this.baslik});

  @override
  Widget build(BuildContext context) {
    final renk = AppColors.vurguMavi(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Row(
        children: [
          Icon(ikon, size: 20, color: renk),
          const SizedBox(width: 8),
          Text(
            baslik,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: renk,
            ),
          ),
        ],
      ),
    );
  }
}
