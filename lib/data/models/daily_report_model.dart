/// Günlük kasa raporu modeli.
/// Her tarih için tek satır — otonom ve manuel veriler ayrı tutulur.
class DailyReportModel {
  final String id;
  final DateTime tarih;

  // Otonom veriler (raporlardan hesaplanan)
  final double autoCash;
  final double autoPos;
  final double autoExpense;

  // Manuel override (null = otonom değer kullanılır)
  final double? manualCash;
  final double? manualPos;
  final double? manualExpense;

  // Devreden bakiye
  final double devredenBakiye;

  // Notlar
  final String? notlar;

  final DateTime createdAt;
  final DateTime updatedAt;

  const DailyReportModel({
    required this.id,
    required this.tarih,
    this.autoCash = 0,
    this.autoPos = 0,
    this.autoExpense = 0,
    this.manualCash,
    this.manualPos,
    this.manualExpense,
    this.devredenBakiye = 0,
    this.notlar,
    required this.createdAt,
    required this.updatedAt,
  });

  // ── Efektif değerler (manuel varsa onu, yoksa otonom) ──

  /// Gösterilecek nakit gelir.
  double get nakitGelir => manualCash ?? autoCash;

  /// Gösterilecek POS gelir.
  double get posGelir => manualPos ?? autoPos;

  /// Gösterilecek gider.
  double get gider => manualExpense ?? autoExpense;

  /// Toplam = Nakit + POS (Excel'deki yeşil TOPLAM).
  double get toplam => nakitGelir + posGelir;

  /// Manuel override aktif mi?
  bool get nakitManuelMi => manualCash != null;
  bool get posManuelMi => manualPos != null;
  bool get giderManuelMi => manualExpense != null;

  /// Haftanın günü (1=Pazartesi, 7=Pazar).
  int get haftaGunu => tarih.weekday;

  /// Hafta sonu mu?
  bool get haftaSonuMu =>
      haftaGunu == DateTime.saturday || haftaGunu == DateTime.sunday;

  // ── JSON dönüşümleri ──

  factory DailyReportModel.fromJson(Map<String, dynamic> json) {
    return DailyReportModel(
      id: json['id'] as String,
      tarih: DateTime.parse(json['tarih'] as String),
      autoCash: (json['auto_cash'] as num?)?.toDouble() ?? 0,
      autoPos: (json['auto_pos'] as num?)?.toDouble() ?? 0,
      autoExpense: (json['auto_expense'] as num?)?.toDouble() ?? 0,
      manualCash: (json['manual_cash'] as num?)?.toDouble(),
      manualPos: (json['manual_pos'] as num?)?.toDouble(),
      manualExpense: (json['manual_expense'] as num?)?.toDouble(),
      devredenBakiye: (json['devreden_bakiye'] as num?)?.toDouble() ?? 0,
      notlar: json['notlar'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tarih': _dateOnly(tarih),
      'auto_cash': autoCash,
      'auto_pos': autoPos,
      'auto_expense': autoExpense,
      'manual_cash': manualCash,
      'manual_pos': manualPos,
      'manual_expense': manualExpense,
      'devreden_bakiye': devredenBakiye,
      'notlar': notlar,
    };
  }

  /// Upsert için (created_at/updated_at hariç).
  Map<String, dynamic> toUpsertJson() {
    return {
      'tarih': _dateOnly(tarih),
      'auto_cash': autoCash,
      'auto_pos': autoPos,
      'auto_expense': autoExpense,
      'manual_cash': manualCash,
      'manual_pos': manualPos,
      'manual_expense': manualExpense,
      'devreden_bakiye': devredenBakiye,
      'notlar': notlar,
    };
  }

  DailyReportModel copyWith({
    String? id,
    DateTime? tarih,
    double? autoCash,
    double? autoPos,
    double? autoExpense,
    double? Function()? manualCash,
    double? Function()? manualPos,
    double? Function()? manualExpense,
    double? devredenBakiye,
    String? Function()? notlar,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DailyReportModel(
      id: id ?? this.id,
      tarih: tarih ?? this.tarih,
      autoCash: autoCash ?? this.autoCash,
      autoPos: autoPos ?? this.autoPos,
      autoExpense: autoExpense ?? this.autoExpense,
      manualCash: manualCash != null ? manualCash() : this.manualCash,
      manualPos: manualPos != null ? manualPos() : this.manualPos,
      manualExpense: manualExpense != null
          ? manualExpense()
          : this.manualExpense,
      devredenBakiye: devredenBakiye ?? this.devredenBakiye,
      notlar: notlar != null ? notlar() : this.notlar,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Boş bir günlük rapor oluştur.
  factory DailyReportModel.bos(DateTime tarih) {
    final now = DateTime.now();
    return DailyReportModel(
      id: '',
      tarih: tarih,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Tarih → 'YYYY-MM-DD' string.
  static String _dateOnly(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  @override
  String toString() =>
      'DailyReport(${_dateOnly(tarih)}: nakit=${nakitGelir.toStringAsFixed(2)}, '
      'pos=${posGelir.toStringAsFixed(2)}, gider=${gider.toStringAsFixed(2)})';
}
