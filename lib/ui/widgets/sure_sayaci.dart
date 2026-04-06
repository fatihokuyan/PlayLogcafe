import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';

/// Canlı süre sayacı widget'ı.
/// [baslangic] zamanından itibaren geçen süreyi gösterir.
/// Dondurulmuş durumdayken sayaç durur ve donmuş süreyi düşer.
class SureSayaci extends StatefulWidget {
  final DateTime baslangic;
  final int? planliSureDk;
  final TextStyle? style;

  /// true ise oturum dondurulmuş → sayaç ilerlemez.
  final bool dondurulmus;

  /// Dondurma anı (null ise şu an aktif demek).
  final DateTime? dondurmaAni;

  /// Daha önce birikmiş toplam dondurulma süresi (saniye).
  final int toplamDondurulmaSuresiSn;

  const SureSayaci({
    super.key,
    required this.baslangic,
    this.planliSureDk,
    this.style,
    this.dondurulmus = false,
    this.dondurmaAni,
    this.toplamDondurulmaSuresiSn = 0,
  });

  @override
  State<SureSayaci> createState() => _SureSayaciState();
}

class _SureSayaciState extends State<SureSayaci> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timerKur();
  }

  @override
  void didUpdateWidget(covariant SureSayaci oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dondurulmus != widget.dondurulmus) {
      _timerKur();
    }
  }

  void _timerKur() {
    _timer?.cancel();
    if (!widget.dondurulmus) {
      // Aktif: her saniye güncelle
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Efektif geçen süre — donmuş süreyi düşer.
  Duration get _gecenSure {
    final simdi = DateTime.now();
    final toplamGecen = simdi.difference(widget.baslangic);

    int donmusSn = widget.toplamDondurulmaSuresiSn;
    // Şu anda dondurulmuşsa, aktif donma süresini de ekle
    if (widget.dondurulmus && widget.dondurmaAni != null) {
      donmusSn += simdi.difference(widget.dondurmaAni!).inSeconds;
    }

    final efektifSn = toplamGecen.inSeconds - donmusSn;
    return Duration(seconds: efektifSn < 0 ? 0 : efektifSn);
  }

  @override
  Widget build(BuildContext context) {
    final gecenSure = _gecenSure;

    // ── Süreli mod: GERİ SAYIM ana gösterim ──
    if (widget.planliSureDk != null) {
      final kalanSaniye = (widget.planliSureDk! * 60) - gecenSure.inSeconds;
      final sureDoldu = kalanSaniye <= 0;
      final kalanDuration = Duration(seconds: kalanSaniye.abs());
      final kalanText = Formatters.sureDuration(kalanDuration);

      // Renk: son %20'de uyarı, dolmuşsa kırmızı
      final pieces = widget.planliSureDk! * 60;
      final uyariEsigi = (pieces * 0.2).toInt();
      Color timerColor;
      if (sureDoldu) {
        timerColor = AppColors.error;
      } else if (kalanSaniye <= uyariEsigi) {
        timerColor = AppColors.warning;
      } else {
        timerColor = AppColors.masaBos;
      }

      final defaultStyle = TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        fontFeatures: const [FontFeature.tabularFigures()],
        color: timerColor,
      );

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Ana: geri sayım (veya aşım süresi)
          Text(
            sureDoldu ? '+$kalanText' : kalanText,
            style: widget.style?.copyWith(color: timerColor) ?? defaultStyle,
          ),
          const SizedBox(height: 1),
          Text(
            sureDoldu ? 'AŞIM' : 'kalan',
            style: TextStyle(
              fontSize: 9,
              color: timerColor,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ],
      );
    }

    // ── Süresiz mod: ileri sayım ──
    return Text(
      Formatters.sureDuration(gecenSure),
      style:
          widget.style ??
          const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
    );
  }
}
