import 'dart:io';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import '../../data/models/daily_report_model.dart';
import '../../data/models/muhasebe_model.dart';

/// Muhasebe verilerini Excel dosyasına aktar.
class ExcelExportServisi {
  static const List<String> _ayAdlari = [
    '',
    'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
    'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
  ];

  static const List<String> _gunAdlari = [
    '', 'Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz',
  ];

  /// Türk sayı formatı: binler ayırıcısı nokta, ondalık virgül (1.234,56)
  static final _paraFormati = NumberFormat('#,##0.00', 'tr_TR');

  /// Muhasebe aylık kasa tablosunu Excel olarak indir.
  /// Döndürür: kaydedilen dosyanın tam yolu.
  static Future<String> muhasebeExcelIndir({
    required int yil,
    required int ay,
    required List<DailyReportModel> gunlukKayitlar,
    required List<MuhasebeModel> giderKayitlari,
    required double oncekiAyBakiyesi,
    required double Function(DateTime) nakitGiderForDate,
    required double Function(DateTime) kartGiderForDate,
  }) async {
    final excel = Excel.createExcel();
    final ayAdi = _ayAdlari[ay];

    // ─── ORTAK STİL TANIMLAMALARI ───────────────────────────────────────
    final baslikStyle = CellStyle(
      bold: true,
      fontSize: 10,
      backgroundColorHex: ExcelColor.fromHexString('#1A237E'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      textWrapping: TextWrapping.WrapText,
      leftBorder: Border(borderStyle: BorderStyle.Thin, borderColorHex: ExcelColor.fromHexString('#FFFFFF')),
      rightBorder: Border(borderStyle: BorderStyle.Thin, borderColorHex: ExcelColor.fromHexString('#FFFFFF')),
      topBorder: Border(borderStyle: BorderStyle.Thin, borderColorHex: ExcelColor.fromHexString('#FFFFFF')),
      bottomBorder: Border(borderStyle: BorderStyle.Thin, borderColorHex: ExcelColor.fromHexString('#FFFFFF')),
    );

    final baslikStyleLeft = CellStyle(
      bold: true,
      fontSize: 10,
      backgroundColorHex: ExcelColor.fromHexString('#1A237E'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      horizontalAlign: HorizontalAlign.Left,
      verticalAlign: VerticalAlign.Center,
      leftBorder: Border(borderStyle: BorderStyle.Thin, borderColorHex: ExcelColor.fromHexString('#FFFFFF')),
      rightBorder: Border(borderStyle: BorderStyle.Thin, borderColorHex: ExcelColor.fromHexString('#FFFFFF')),
      topBorder: Border(borderStyle: BorderStyle.Thin, borderColorHex: ExcelColor.fromHexString('#FFFFFF')),
      bottomBorder: Border(borderStyle: BorderStyle.Thin, borderColorHex: ExcelColor.fromHexString('#FFFFFF')),
    );

    final inceKenar = Border(borderStyle: BorderStyle.Thin, borderColorHex: ExcelColor.fromHexString('#B0BEC5'));

    final devredenStyle = CellStyle(
      bold: true,
      fontSize: 9,
      backgroundColorHex: ExcelColor.fromHexString('#C5CAE9'),
      fontColorHex: ExcelColor.fromHexString('#1A237E'),
      horizontalAlign: HorizontalAlign.Right,
      leftBorder: inceKenar,
      rightBorder: inceKenar,
      topBorder: inceKenar,
      bottomBorder: inceKenar,
    );

    final devredenStyleLeft = CellStyle(
      bold: true,
      fontSize: 9,
      backgroundColorHex: ExcelColor.fromHexString('#C5CAE9'),
      fontColorHex: ExcelColor.fromHexString('#1A237E'),
      horizontalAlign: HorizontalAlign.Left,
      leftBorder: inceKenar,
      rightBorder: inceKenar,
      topBorder: inceKenar,
      bottomBorder: inceKenar,
    );

    final toplamStyle = CellStyle(
      bold: true,
      fontSize: 9,
      backgroundColorHex: ExcelColor.fromHexString('#E8F5E9'),
      fontColorHex: ExcelColor.fromHexString('#1B5E20'),
      horizontalAlign: HorizontalAlign.Right,
      leftBorder: Border(borderStyle: BorderStyle.Medium, borderColorHex: ExcelColor.fromHexString('#43A047')),
      rightBorder: Border(borderStyle: BorderStyle.Medium, borderColorHex: ExcelColor.fromHexString('#43A047')),
      topBorder: Border(borderStyle: BorderStyle.Medium, borderColorHex: ExcelColor.fromHexString('#43A047')),
      bottomBorder: Border(borderStyle: BorderStyle.Medium, borderColorHex: ExcelColor.fromHexString('#43A047')),
    );

    final toplamStyleLeft = CellStyle(
      bold: true,
      fontSize: 9,
      backgroundColorHex: ExcelColor.fromHexString('#E8F5E9'),
      fontColorHex: ExcelColor.fromHexString('#1B5E20'),
      horizontalAlign: HorizontalAlign.Left,
      leftBorder: Border(borderStyle: BorderStyle.Medium, borderColorHex: ExcelColor.fromHexString('#43A047')),
      rightBorder: Border(borderStyle: BorderStyle.Medium, borderColorHex: ExcelColor.fromHexString('#43A047')),
      topBorder: Border(borderStyle: BorderStyle.Medium, borderColorHex: ExcelColor.fromHexString('#43A047')),
      bottomBorder: Border(borderStyle: BorderStyle.Medium, borderColorHex: ExcelColor.fromHexString('#43A047')),
    );

    final haftaSonuStyle = CellStyle(
      fontSize: 9,
      backgroundColorHex: ExcelColor.fromHexString('#FFF9C4'),
      horizontalAlign: HorizontalAlign.Right,
      leftBorder: inceKenar,
      rightBorder: inceKenar,
      topBorder: inceKenar,
      bottomBorder: inceKenar,
    );

    final haftaSonuStyleLeft = CellStyle(
      fontSize: 9,
      backgroundColorHex: ExcelColor.fromHexString('#FFF9C4'),
      horizontalAlign: HorizontalAlign.Left,
      leftBorder: inceKenar,
      rightBorder: inceKenar,
      topBorder: inceKenar,
      bottomBorder: inceKenar,
    );

    final normalStyle = CellStyle(
      fontSize: 9,
      horizontalAlign: HorizontalAlign.Right,
      leftBorder: inceKenar,
      rightBorder: inceKenar,
      topBorder: inceKenar,
      bottomBorder: inceKenar,
    );

    final normalStyleLeft = CellStyle(
      fontSize: 9,
      horizontalAlign: HorizontalAlign.Left,
      leftBorder: inceKenar,
      rightBorder: inceKenar,
      topBorder: inceKenar,
      bottomBorder: inceKenar,
    );

    final altSatirStyle = CellStyle(
      fontSize: 9,
      backgroundColorHex: ExcelColor.fromHexString('#F5F5F5'),
      horizontalAlign: HorizontalAlign.Right,
      leftBorder: inceKenar,
      rightBorder: inceKenar,
      topBorder: inceKenar,
      bottomBorder: inceKenar,
    );

    final altSatirStyleLeft = CellStyle(
      fontSize: 9,
      backgroundColorHex: ExcelColor.fromHexString('#F5F5F5'),
      horizontalAlign: HorizontalAlign.Left,
      leftBorder: inceKenar,
      rightBorder: inceKenar,
      topBorder: inceKenar,
      bottomBorder: inceKenar,
    );

    // ─── SAYFA 1: KASA TABLOSU ───────────────────────────────────────────
    final kasaSheet = excel['Kasa Tablosu'];
    excel.setDefaultSheet('Kasa Tablosu');

    // Başlık satırı (Satır 0) — tam genişlik renk bloğu
    final titleStyle = CellStyle(
      bold: true,
      fontSize: 14,
      backgroundColorHex: ExcelColor.fromHexString('#0D47A1'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      horizontalAlign: HorizontalAlign.Left,
      verticalAlign: VerticalAlign.Center,
    );
    final titleFillStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#0D47A1'),
    );
    final titleCell = kasaSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0));
    titleCell.value = TextCellValue('  $ayAdi $yil — KASA TABLOSU');
    titleCell.cellStyle = titleStyle;
    for (int c = 1; c < 10; c++) {
      kasaSheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0)).cellStyle = titleFillStyle;
    }
    kasaSheet.setRowHeight(0, 30);

    // Sütun başlıkları (Satır 1)
    final basliklar = [
      'Tarih', 'Gün', 'Nakit Gelir', 'Kart Gelir', 'Toplam Gelir',
      'Nakit Gider', 'Kart Gider', 'Net Kar', 'Kasa Bakiyesi', 'Not',
    ];
    for (int c = 0; c < basliklar.length; c++) {
      final cell = kasaSheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 1));
      cell.value = TextCellValue(basliklar[c]);
      cell.cellStyle = c == 0 || c == 1 || c == 9 ? baslikStyleLeft : baslikStyle;
    }
    kasaSheet.setRowHeight(1, 24);

    // Devreden satırı (Satır 2)
    int satir = 2;
    {
      final cell0 = kasaSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: satir));
      cell0.value = TextCellValue('Önceki Aydan Devreden');
      cell0.cellStyle = devredenStyleLeft;
      for (int c = 1; c < 8; c++) {
        final cell = kasaSheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: satir));
        cell.value = TextCellValue('');
        cell.cellStyle = devredenStyle;
      }
      final cellBakiye = kasaSheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: satir));
      cellBakiye.value = TextCellValue(_formatPara(oncekiAyBakiyesi));
      cellBakiye.cellStyle = devredenStyle;
      final cellNot = kasaSheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: satir));
      cellNot.value = TextCellValue('');
      cellNot.cellStyle = devredenStyleLeft;
      satir++;
    }

    // Günlük kayıtlar
    double topNakit = 0, topKart = 0, topNakitGider = 0, topKartGider = 0;
    int veriSatirNo = 0;
    for (final kayit in gunlukKayitlar) {
      final nakit = kayit.nakitGelir;
      final kart = kayit.posGelir;
      final toplam = nakit + kart;
      final nGider = nakitGiderForDate(kayit.tarih);
      final kGider = kartGiderForDate(kayit.tarih);
      final net = toplam - nGider - kGider;

      topNakit += nakit;
      topKart += kart;
      topNakitGider += nGider;
      topKartGider += kGider;

      final gunAdi = _gunAdlari[kayit.tarih.weekday];
      final tarihStr =
          '${kayit.tarih.day.toString().padLeft(2, '0')}.${kayit.tarih.month.toString().padLeft(2, '0')}.${kayit.tarih.year}';

      final isHaftaSonu = kayit.haftaSonuMu;
      final isAltSatir = !isHaftaSonu && veriSatirNo.isOdd;

      CellStyle getStyle(bool isLeft) {
        if (isHaftaSonu) return isLeft ? haftaSonuStyleLeft : haftaSonuStyle;
        if (isAltSatir) return isLeft ? altSatirStyleLeft : altSatirStyle;
        return isLeft ? normalStyleLeft : normalStyle;
      }

      final degerler = [
        (tarihStr, true),
        (gunAdi, true),
        (_formatPara(nakit), false),
        (_formatPara(kart), false),
        (_formatPara(toplam), false),
        (_formatPara(nGider), false),
        (_formatPara(kGider), false),
        (_formatPara(net), false),
        (_formatPara(kayit.devredenBakiye), false),
        (kayit.notlar ?? '', true),
      ];

      for (int c = 0; c < degerler.length; c++) {
        final cell = kasaSheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: satir));
        cell.value = TextCellValue(degerler[c].$1);
        cell.cellStyle = getStyle(degerler[c].$2);
      }
      satir++;
      veriSatirNo++;
    }

    // Toplam satırı
    {
      final toplamVeri = [
        ('TOPLAM', true),
        ('', false),
        (_formatPara(topNakit), false),
        (_formatPara(topKart), false),
        (_formatPara(topNakit + topKart), false),
        (_formatPara(topNakitGider), false),
        (_formatPara(topKartGider), false),
        (_formatPara(topNakit + topKart - topNakitGider - topKartGider), false),
        ('', false),
        ('', true),
      ];
      for (int c = 0; c < toplamVeri.length; c++) {
        final cell = kasaSheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: satir));
        cell.value = TextCellValue(toplamVeri[c].$1);
        cell.cellStyle = toplamVeri[c].$2 ? toplamStyleLeft : toplamStyle;
      }
      kasaSheet.setRowHeight(satir, 22);
    }

    // Sütun genişlikleri
    kasaSheet.setColumnWidth(0, 13);  // Tarih
    kasaSheet.setColumnWidth(1, 5);   // Gün
    kasaSheet.setColumnWidth(2, 13);  // Nakit Gelir
    kasaSheet.setColumnWidth(3, 13);  // Kart Gelir
    kasaSheet.setColumnWidth(4, 14);  // Toplam Gelir
    kasaSheet.setColumnWidth(5, 13);  // Nakit Gider
    kasaSheet.setColumnWidth(6, 13);  // Kart Gider
    kasaSheet.setColumnWidth(7, 13);  // Net Kar
    kasaSheet.setColumnWidth(8, 15);  // Kasa Bakiyesi
    kasaSheet.setColumnWidth(9, 24);  // Not

    // ─── SAYFA 2: GİDER DETAYI ───────────────────────────────────────────
    final giderSheet = excel['Gider Detayı'];

    // Başlık satırı
    final gTitle = giderSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0));
    gTitle.value = TextCellValue('  $ayAdi $yil — GİDER DETAYI');
    gTitle.cellStyle = titleStyle;
    for (int c = 1; c < 5; c++) {
      giderSheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0)).cellStyle = titleFillStyle;
    }
    giderSheet.setRowHeight(0, 30);

    // Sütun başlıkları
    final giderBasliklar = ['Tarih', 'Açıklama', 'Tür', 'Ödeme', 'Tutar'];
    for (int c = 0; c < giderBasliklar.length; c++) {
      final cell = giderSheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 1));
      cell.value = TextCellValue(giderBasliklar[c]);
      cell.cellStyle = c == 0 || c == 1 ? baslikStyleLeft : baslikStyle;
    }
    giderSheet.setRowHeight(1, 24);

    int gSatir = 2;
    double gToplamNakit = 0, gToplamKart = 0;
    int gVeriSatirNo = 0;
    for (final gider in giderKayitlari) {
      final tarihStr =
          '${gider.tarih.day.toString().padLeft(2, '0')}.${gider.tarih.month.toString().padLeft(2, '0')}.${gider.tarih.year}';
      final odeme = gider.odemeYontemi == OdemeYontemi.nakit ? 'Nakit' : 'Kart';

      if (gider.odemeYontemi == OdemeYontemi.nakit) {
        gToplamNakit += gider.tutar;
      } else {
        gToplamKart += gider.tutar;
      }

      final isAlt = gVeriSatirNo.isOdd;
      final rowStyle = isAlt ? altSatirStyle : normalStyle;
      final rowStyleLeft = isAlt ? altSatirStyleLeft : normalStyleLeft;

      final veri = [
        (tarihStr, true),
        (gider.aciklama, true),
        (gider.tur == MuhasebeTur.gider ? 'Gider' : 'Gelir', false),
        (odeme, false),
        (_formatPara(gider.tutar), false),
      ];
      for (int c = 0; c < veri.length; c++) {
        final cell = giderSheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: gSatir));
        cell.value = TextCellValue(veri[c].$1);
        cell.cellStyle = veri[c].$2 ? rowStyleLeft : rowStyle;
      }
      gSatir++;
      gVeriSatirNo++;
    }

    // Gider toplamları
    gSatir++;
    _giderToplamSatir(giderSheet, gSatir, 'Nakit Gider Toplam', gToplamNakit, toplamStyle, toplamStyleLeft);
    gSatir++;
    _giderToplamSatir(giderSheet, gSatir, 'Kart Gider Toplam', gToplamKart, toplamStyle, toplamStyleLeft);
    gSatir++;
    _giderToplamSatir(giderSheet, gSatir, 'Genel Toplam', gToplamNakit + gToplamKart, toplamStyle, toplamStyleLeft);

    giderSheet.setColumnWidth(0, 13);
    giderSheet.setColumnWidth(1, 35);
    giderSheet.setColumnWidth(2, 10);
    giderSheet.setColumnWidth(3, 10);
    giderSheet.setColumnWidth(4, 14);

    // ── Dosyayı kaydet ──
    final dizin = await _kayitDizini();
    if (dizin == null) {
      throw Exception('İşlem kullanıcı tarafından iptal edildi.');
    }
    
    final dosyaAdi = 'PlayLog_Muhasebe_${ayAdi}_$yil.xlsx';
    final dosya = File('${dizin.path}/$dosyaAdi');

    final bytes = excel.encode();
    if (bytes == null) throw Exception('Excel encode hatası');
    await dosya.writeAsBytes(bytes);

    return dosya.path;
  }

  static void _giderToplamSatir(
    Sheet sheet,
    int satir,
    String etiket,
    double deger,
    CellStyle style,
    CellStyle styleLeft,
  ) {
    for (int c = 0; c < 3; c++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: satir)).cellStyle = styleLeft;
    }
    final cell3 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: satir));
    cell3.value = TextCellValue(etiket);
    cell3.cellStyle = styleLeft;
    final cell4 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: satir));
    cell4.value = TextCellValue(_formatPara(deger));
    cell4.cellStyle = style;
  }

  static Future<Directory?> _kayitDizini() async {
    final selectedDirectory = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Excel Dosyasını Kaydedeceğiniz Klasörü Seçin',
    );
    if (selectedDirectory == null) return null;
    return Directory(selectedDirectory);
  }

  static String _formatPara(double deger) {
    if (deger == 0) return '-';
    return '${_paraFormati.format(deger)} ₺';
  }
}
