import '../../data/models/oturum_model.dart';

/// Süreli/süresiz ücret hesaplama servisi.
class SureHesaplamaServisi {
  SureHesaplamaServisi._();

  /// Bütçeli oturumlar için efektif periyodu belirler.
  /// Bütçeli (ücretli) oturum → her zaman 1 dk (dakika bazlı gerçek hesap).
  /// Standart oturum → kullanıcının global ayarı (ör: 5, 10, 15 dk).
  static int efektifPeriyot(double? butce, int globalPeriyot, OturumMod mod) {
    if (butce != null && butce > 0 && mod == OturumMod.sureli) return 1;
    return globalPeriyot;
  }

  /// Geçen süreyi dakika cinsinden hesapla.
  static int gecenDakika(DateTime baslangic, [DateTime? bitis]) {
    final son = bitis ?? DateTime.now();
    return son.difference(baslangic).inMinutes;
  }

  // ═══════════════════════════════════════════════════
  //  DİLİMLİ (STEP) ÜCRET HESAPLAMA
  // ═══════════════════════════════════════════════════

  /// Dakikayı dilim sayısına yuvarlama (ceiling).
  /// Örn: periyot=15 → 1 dk = 1 dilim, 15 dk = 1 dilim, 16 dk = 2 dilim.
  static int dilimSayisi(int gecenDk, int periyotDk) {
    if (periyotDk <= 0 || gecenDk <= 0) return 0;
    return (gecenDk / periyotDk).ceil();
  }

  /// Bir dilimin birim ücreti.
  /// Saat başı ücret sistemi: saatlikUcret / 60 * periyotDk
  /// Dakika başı ücret sistemi: dakikaBasiUcret * periyotDk
  static double dilimBirimUcret({
    required double dakikaBasiUcret,
    required int periyotDk,
  }) {
    return dakikaBasiUcret * periyotDk;
  }

  /// Dilimli (step-rounded) ücret hesaplama.
  ///
  /// [gecenDk] — geçen efektif dakika (donmuş süre düşülmüş)
  /// [dakikaBasiUcret] — kol/konsol'a göre ayarlanmış dakika başı ücret
  /// [periyotDk] — dilimleme periyodu (1, 5, 10, 15, 30, 60)
  /// [ilkUcretsizDk] — ilk kaç dakika ücretsiz (0 = yok)
  ///
  /// Geri dönüş: dilim bazlı toplam ücret.
  static double dilimliUcretHesapla({
    required int gecenDk,
    required double dakikaBasiUcret,
    required int periyotDk,
    int ilkUcretsizDk = 0,
  }) {
    // Periyot 1 ise veya ≤0 ise klasik hesap (optimizasyon)
    if (periyotDk <= 1) {
      final faturalanacak = (gecenDk - ilkUcretsizDk).clamp(0, 999999);
      return faturalanacak * dakikaBasiUcret;
    }

    // Ücretsiz süreyi düş
    final ucretliDk = (gecenDk - ilkUcretsizDk).clamp(0, 999999);
    if (ucretliDk <= 0) return 0;

    // Dilim sayısı (ceiling)
    final dilimler = dilimSayisi(ucretliDk, periyotDk);
    final birim = dilimBirimUcret(
      dakikaBasiUcret: dakikaBasiUcret,
      periyotDk: periyotDk,
    );
    return dilimler * birim;
  }

  // ═══════════════════════════════════════════════════

  /// Ücreti hesapla.
  ///
  /// - **Süreli mod:** Erken kapatılırsa gerçek süre, aşılırsa planlanan süre.
  /// - **Süresiz mod:** Geçen gerçek dakika × dakika başı ücret.
  ///
  /// [dakikaBasiUcret] zaten kol sayısına göre ayarlanmış olarak gelir.
  static double ucretHesapla({
    required DateTime baslangic,
    required DateTime bitis,
    required OturumMod mod,
    int? planliSureDk,
    required double dakikaBasiUcret,
  }) {
    switch (mod) {
      case OturumMod.sureli:
        // Süreli: min(gerçek süre, planlı süre) — erken kapatılırsa az öder
        final gercek = gecenDakika(baslangic, bitis);
        final faturalanacak = gercek < 1 ? 1 : gercek;
        if (planliSureDk != null && faturalanacak < planliSureDk) {
          return faturalanacak * dakikaBasiUcret;
        }
        return (planliSureDk ?? faturalanacak) * dakikaBasiUcret;

      case OturumMod.suresiz:
        // Süresiz modda geçen gerçek süre üzerinden ücret
        final gercekDakika = gecenDakika(baslangic, bitis);
        // Minimum 1 dakika
        final faturalanacak = gercekDakika < 1 ? 1 : gercekDakika;
        return faturalanacak * dakikaBasiUcret;
    }
  }

  /// Anlık tahmini ücreti hesapla (sayaç için).
  static double anlikUcret({
    required DateTime baslangic,
    required OturumMod mod,
    int? planliSureDk,
    required double dakikaBasiUcret,
  }) {
    return ucretHesapla(
      baslangic: baslangic,
      bitis: DateTime.now(),
      mod: mod,
      planliSureDk: planliSureDk,
      dakikaBasiUcret: dakikaBasiUcret,
    );
  }

  /// Dinamik kol geçmişine göre konsol ücreti hesapla.
  ///
  /// Her segment kendi kol sayısı × kendi süresi ile ücretlendirilir.
  /// [kolGecmisi] boşsa fallback olarak [fallbackKolSayisi] kullanılır.
  /// [dakikaBasiUcretResolver] → (kolSayisi) => o kol sayısının dk başı ücreti
  /// [efektifSure] → donmuş süre düşülmüş gerçek oynanan süre
  /// [periyotDk] → dilim periyodu (1 ise klasik hesap)
  /// [ilkUcretsizDk] → ilk kaç dakika ücretsiz
  static double dinamikKolUcretHesapla({
    required List<KolSegment> kolGecmisi,
    required Duration efektifSure,
    required OturumMod mod,
    int? planliSureDk,
    required double Function(int kolSayisi) dakikaBasiUcretResolver,
    int fallbackKolSayisi = 2,
    int periyotDk = 1,
    int ilkUcretsizDk = 0,
  }) {
    // Efektif dakika (minimum 1)
    final efektifDk = efektifSure.inMinutes < 1 ? 1 : efektifSure.inMinutes;

    // Süreli mod: erken kapatılırsa gerçek süre, aşılmışsa planlı süre
    if (mod == OturumMod.sureli && planliSureDk != null) {
      final faturalanacakDk = efektifDk < planliSureDk
          ? efektifDk
          : planliSureDk;
      return _segmentBazliHesapla(
        kolGecmisi: kolGecmisi,
        toplamDk: faturalanacakDk,
        dakikaBasiUcretResolver: dakikaBasiUcretResolver,
        fallbackKolSayisi: fallbackKolSayisi,
        periyotDk: periyotDk,
        ilkUcretsizDk: ilkUcretsizDk,
      );
    }

    // Süresiz mod: efektif süre üzerinden
    final dk = efektifDk;
    return _segmentBazliHesapla(
      kolGecmisi: kolGecmisi,
      toplamDk: dk,
      dakikaBasiUcretResolver: dakikaBasiUcretResolver,
      fallbackKolSayisi: fallbackKolSayisi,
      periyotDk: periyotDk,
      ilkUcretsizDk: ilkUcretsizDk,
    );
  }

  /// Segment bazlı kümülatif dilimli ücret hesaplama.
  ///
  /// ## Temel Kural (Dilim Esası)
  /// Her segment kendi kol sayısının tarifesiyle bağımsız olarak
  /// dilim bazında faturalandırılır: `ceil(segDk / periyotDk)` dilim.
  ///
  /// ## Ara Dakika Kuralı
  /// Kol değişimi dilim sınırında değilse (ör. 20. dakikada, periyot=15):
  ///   - Eski segment → ceiling'e yuvarlanır: 2 dilim = 30 dk gibi ücretlenir.
  ///   - Yeni segment → o "fazla" 10 dk düşülür: efektif süre = (toplam-20-10) dk.
  ///
  /// ## Dondurma Uyumu
  /// Kapalı segmentlerin wall-clock toplamı efektif süreyi aşarsa
  /// (dondurma kapalı segmentte oldu) oransal dağıtım yapılır.
  ///
  /// Formula: Total = Σ [ceil(segDk_i / periyot) × pricePerPeriod_i]
  static double _segmentBazliHesapla({
    required List<KolSegment> kolGecmisi,
    required int toplamDk, // efektif dakika (dondurma süresi düşülmüş)
    required double Function(int kolSayisi) dakikaBasiUcretResolver,
    int fallbackKolSayisi = 2,
    int periyotDk = 1,
    int ilkUcretsizDk = 0,
  }) {
    if (kolGecmisi.isEmpty) {
      return dilimliUcretHesapla(
        gecenDk: toplamDk,
        dakikaBasiUcret: dakikaBasiUcretResolver(fallbackKolSayisi),
        periyotDk: periyotDk,
        ilkUcretsizDk: ilkUcretsizDk,
      );
    }

    if (kolGecmisi.length == 1) {
      return dilimliUcretHesapla(
        gecenDk: toplamDk,
        dakikaBasiUcret: dakikaBasiUcretResolver(kolGecmisi.first.kolSayisi),
        periyotDk: periyotDk,
        ilkUcretsizDk: ilkUcretsizDk,
      );
    }

    // ── Çoklu segment ──────────────────────────────────────────────
    final simdi = DateTime.now();
    double toplam = 0;
    int kalanUcretsizDk = ilkUcretsizDk;

    // Kapalı segmentlerin wall-clock toplamı
    int kapaliWallDkToplam = 0;
    for (int i = 0; i < kolGecmisi.length - 1; i++) {
      kapaliWallDkToplam += kolGecmisi[i + 1].baslangic
          .difference(kolGecmisi[i].baslangic)
          .inMinutes;
    }

    // Toplam wall-clock (oransal dağıtım için)
    final toplamWallDk = simdi
        .difference(kolGecmisi.first.baslangic)
        .inMinutes
        .clamp(1, 999999);

    // Dondurma kapalı segmentte olduysa oransal mod
    final bool proportionalMode = kapaliWallDkToplam >= toplamDk;

    // Ara Dakika Kuralı: önceki segmentin ceiling fazlası sonraki segmentte
    // düşülür. Her segment önceki fazlayı tüketir, kendi ceiling'inden yeni
    // fazla üretir ve sonraki segmente taşır.
    int araDakikaFazlasi = 0;

    for (int i = 0; i < kolGecmisi.length; i++) {
      final segment = kolGecmisi[i];
      final bool sonSegment = (i == kolGecmisi.length - 1);
      final ucret = dakikaBasiUcretResolver(segment.kolSayisi);

      int segmentDk;

      if (sonSegment) {
        // ── Son (açık) segment ──
        if (proportionalMode) {
          final wallDk = simdi.difference(segment.baslangic).inMinutes;
          segmentDk = (wallDk * toplamDk / toplamWallDk).round().clamp(
            0,
            toplamDk,
          );
        } else {
          segmentDk = (toplamDk - kapaliWallDkToplam - araDakikaFazlasi).clamp(
            0,
            toplamDk,
          );
        }
      } else {
        // ── Kapalı segment ──
        final wallDk = kolGecmisi[i + 1].baslangic
            .difference(segment.baslangic)
            .inMinutes;

        if (proportionalMode) {
          segmentDk = (wallDk * toplamDk / toplamWallDk).round().clamp(
            0,
            toplamDk,
          );
        } else {
          // Önceki segmentin fazlasını bu segmentten düş
          final efektifWallDk = (wallDk - araDakikaFazlasi).clamp(0, wallDk);
          final kullanilanFazla = wallDk.clamp(0, araDakikaFazlasi);
          araDakikaFazlasi -= kullanilanFazla;

          segmentDk = efektifWallDk;

          // Bu segmentin kendi ceiling fazlasını hesapla
          if (periyotDk > 1 && efektifWallDk > 0) {
            final billedDk = ((efektifWallDk / periyotDk).ceil()) * periyotDk;
            araDakikaFazlasi += billedDk - efektifWallDk;
          }
        }
      }

      if (segmentDk <= 0) continue;

      // Ücretsiz dakika uygula
      if (kalanUcretsizDk > 0) {
        final ucretsizPay = segmentDk.clamp(0, kalanUcretsizDk);
        kalanUcretsizDk -= ucretsizPay;
        final ucretliDk = segmentDk - ucretsizPay;
        if (ucretliDk > 0) {
          toplam += dilimliUcretHesapla(
            gecenDk: ucretliDk,
            dakikaBasiUcret: ucret,
            periyotDk: periyotDk,
            ilkUcretsizDk: 0,
          );
        }
      } else {
        toplam += dilimliUcretHesapla(
          gecenDk: segmentDk,
          dakikaBasiUcret: ucret,
          periyotDk: periyotDk,
          ilkUcretsizDk: 0,
        );
      }
    }

    return toplam;
  }

  /// Süreli modda kalan süre (dakika).
  /// Negatifse süre aşılmış demektir.
  static int kalanDakika({
    required DateTime baslangic,
    required int planliSureDk,
  }) {
    final gecen = gecenDakika(baslangic);
    return planliSureDk - gecen;
  }

  /// Süreli modda süre dolmuş mu?
  static bool sureDolduMu({
    required DateTime baslangic,
    required int planliSureDk,
  }) {
    return kalanDakika(baslangic: baslangic, planliSureDk: planliSureDk) <= 0;
  }

  /// Bütçeli oturumlarda kol değişikliği için harcama hesapla.
  ///
  /// Tüm kolGecmisi segmentlerini dilimli hesaplar ve:
  /// - [harcananTutar]: toplam harcanan ücret
  /// - [kalanFazlaDk]: son segmentin ceiling fazlası (yeni segmente bedava taşınır)
  ///
  /// Bu, _segmentBazliHesapla ile aynı mantığı kullanır ama
  /// fazla dk'yı da ayrıca döndürür.
  static ({double harcananTutar, int kalanFazlaDk}) butceHarcamaHesapla({
    required List<KolSegment> kolGecmisi,
    required Duration efektifSure,
    required double Function(int kolSayisi) dakikaBasiUcretResolver,
    int fallbackKolSayisi = 2,
    int periyotDk = 1,
    int ilkUcretsizDk = 0,
  }) {
    final efektifDk = efektifSure.inMinutes < 1 ? 1 : efektifSure.inMinutes;

    if (kolGecmisi.isEmpty) {
      final ucret = dilimliUcretHesapla(
        gecenDk: efektifDk,
        dakikaBasiUcret: dakikaBasiUcretResolver(fallbackKolSayisi),
        periyotDk: periyotDk,
        ilkUcretsizDk: ilkUcretsizDk,
      );
      final billed = periyotDk > 1
          ? ((efektifDk / periyotDk).ceil()) * periyotDk
          : efektifDk;
      return (harcananTutar: ucret, kalanFazlaDk: billed - efektifDk);
    }

    if (kolGecmisi.length == 1) {
      final ucret = dilimliUcretHesapla(
        gecenDk: efektifDk,
        dakikaBasiUcret: dakikaBasiUcretResolver(kolGecmisi.first.kolSayisi),
        periyotDk: periyotDk,
        ilkUcretsizDk: ilkUcretsizDk,
      );
      final billed = periyotDk > 1
          ? ((efektifDk / periyotDk).ceil()) * periyotDk
          : efektifDk;
      return (harcananTutar: ucret, kalanFazlaDk: billed - efektifDk);
    }

    // ── Çoklu segment ──
    final simdi = DateTime.now();
    double toplam = 0;
    int kalanUcretsizDk = ilkUcretsizDk;
    int araDakikaFazlasi = 0;

    int kapaliWallDkToplam = 0;
    for (int i = 0; i < kolGecmisi.length - 1; i++) {
      kapaliWallDkToplam += kolGecmisi[i + 1].baslangic
          .difference(kolGecmisi[i].baslangic)
          .inMinutes;
    }

    final toplamWallDk = simdi
        .difference(kolGecmisi.first.baslangic)
        .inMinutes
        .clamp(1, 999999);
    final bool proportionalMode = kapaliWallDkToplam >= efektifDk;

    for (int i = 0; i < kolGecmisi.length; i++) {
      final segment = kolGecmisi[i];
      final bool sonSegment = (i == kolGecmisi.length - 1);
      final ucret = dakikaBasiUcretResolver(segment.kolSayisi);

      int segmentDk;

      if (sonSegment) {
        if (proportionalMode) {
          final wallDk = simdi.difference(segment.baslangic).inMinutes;
          segmentDk = (wallDk * efektifDk / toplamWallDk).round().clamp(
            0,
            efektifDk,
          );
        } else {
          segmentDk = (efektifDk - kapaliWallDkToplam - araDakikaFazlasi).clamp(
            0,
            efektifDk,
          );
        }

        // Son segmentin kendi ceiling fazlasını hesapla
        if (periyotDk > 1 && segmentDk > 0) {
          final billedDk = ((segmentDk / periyotDk).ceil()) * periyotDk;
          araDakikaFazlasi = billedDk - segmentDk;
        } else {
          araDakikaFazlasi = 0;
        }
      } else {
        final wallDk = kolGecmisi[i + 1].baslangic
            .difference(segment.baslangic)
            .inMinutes;

        if (proportionalMode) {
          segmentDk = (wallDk * efektifDk / toplamWallDk).round().clamp(
            0,
            efektifDk,
          );
        } else {
          // Önceki segmentin fazlasını bu segmentten düş
          final efektifWallDk = (wallDk - araDakikaFazlasi).clamp(0, wallDk);
          final kullanilanFazla = wallDk.clamp(0, araDakikaFazlasi);
          araDakikaFazlasi -= kullanilanFazla;

          segmentDk = efektifWallDk;

          if (periyotDk > 1 && efektifWallDk > 0) {
            final billedDk = ((efektifWallDk / periyotDk).ceil()) * periyotDk;
            araDakikaFazlasi += billedDk - efektifWallDk;
          }
        }
      }

      if (segmentDk <= 0) continue;

      if (kalanUcretsizDk > 0) {
        final ucretsizPay = segmentDk.clamp(0, kalanUcretsizDk);
        kalanUcretsizDk -= ucretsizPay;
        final ucretliDk = segmentDk - ucretsizPay;
        if (ucretliDk > 0) {
          toplam += dilimliUcretHesapla(
            gecenDk: ucretliDk,
            dakikaBasiUcret: ucret,
            periyotDk: periyotDk,
            ilkUcretsizDk: 0,
          );
        }
      } else {
        toplam += dilimliUcretHesapla(
          gecenDk: segmentDk,
          dakikaBasiUcret: ucret,
          periyotDk: periyotDk,
          ilkUcretsizDk: 0,
        );
      }
    }

    return (harcananTutar: toplam, kalanFazlaDk: araDakikaFazlasi);
  }
}
