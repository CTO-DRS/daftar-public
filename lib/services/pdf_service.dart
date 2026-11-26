import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/invoice.dart';
import '../utils/date_utils.dart';
import '../utils/number_utils.dart';
import '../utils/zatca.dart';

/// يولّد ملف PDF عربي (RTL) بخط Amiri المضمّن في assets.
class PdfService {
  PdfService._();

  static pw.Font? _regular;
  static pw.Font? _bold;

  static Future<void> _loadFonts() async {
    _regular ??=
        pw.Font.ttf(await rootBundle.load('assets/fonts/Amiri-Regular.ttf'));
    _bold ??= pw.Font.ttf(await rootBundle.load('assets/fonts/Amiri-Bold.ttf'));
  }

  static Future<Uint8List> build(
    Invoice inv, {
    String currency = 'ر.س',
    String company = '',
    Uint8List? logo,
    String partyPhone = '',
    String partyAddress = '',
    String sellerVat = '',
  }) async {
    await _loadFonts();
    final items = inv.items.where((e) => !e.isEmpty).toList();
    final theme = pw.ThemeData.withFont(base: _regular!, bold: _bold!);
    final doc = pw.Document(
      title: '${inv.docLabel} ${inv.number}',
      author: company.isEmpty ? 'دفتر' : company,
    );

    final logoImage = logo == null ? null : pw.MemoryImage(logo);
    const headerColor = PdfColor.fromInt(0xFF0F766E);
    const zebra = PdfColor.fromInt(0xFFF0F5F5);

    // الأعمدة بترتيب العرض من اليسار إلى اليمين (م أقصى اليمين).
    final headers = <String>[
      'ملاحظات',
      'الإجمالي',
      'سعر الفردي',
      'العدد',
      'النوع / الوصف',
      'الرقم المرجعي',
      'كود الصنف',
      'م',
    ];
    final data = <List<String>>[];
    for (var i = 0; i < items.length; i++) {
      final it = items[i];
      data.add([
        it.notes,
        formatMoney(it.total),
        formatMoney(it.unitPrice),
        it.unit.trim().isEmpty ? formatQty(it.quantity) : '${formatQty(it.quantity)} ${it.unit.trim()}',
        it.description,
        it.refNumber,
        it.itemCode,
        localizeDigits('${i + 1}'),
      ]);
    }

    const totalFill = PdfColor.fromInt(0xFFCCFBF1);
    final colWidths = <int, pw.TableColumnWidth>{
      0: const pw.FlexColumnWidth(2.2), // ملاحظات
      1: const pw.FlexColumnWidth(1.6), // الإجمالي
      2: const pw.FlexColumnWidth(1.4), // الفردي
      3: const pw.FlexColumnWidth(1.4), // العدد + الوحدة
      4: const pw.FlexColumnWidth(3.0), // النوع
      5: const pw.FlexColumnWidth(1.5), // المرجع
      6: const pw.FlexColumnWidth(1.5), // الكود
      7: const pw.FixedColumnWidth(26), // م
    };

    pw.Widget totalCard() => pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: pw.BoxDecoration(
            color: totalFill,
            border: pw.Border.all(color: headerColor, width: 1.2),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(children: [
            pw.Text('المبلغ الإجمالي',
                style: const pw.TextStyle(
                    fontSize: 9, color: PdfColors.grey700)),
            pw.SizedBox(height: 2),
            pw.Text('${formatMoney(inv.grandTotal)} $currency',
                style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: headerColor)),
          ]),
        );

    final showVat = inv.kind == DocKind.invoice && inv.vatRate > 0;
    pw.Widget vatBlock() {
      final qrOk = sellerVat.trim().isNotEmpty;
      String? qr;
      if (qrOk) {
        final n = DateTime.now();
        final ts = DateTime(inv.date.year, inv.date.month, inv.date.day,
            n.hour, n.minute, n.second);
        qr = zatcaPhase1Qr(
          sellerName: company.isEmpty ? 'دفتر' : company,
          vatNumber: normalizeDigits(sellerVat).trim(),
          timestamp: ts,
          totalWithVat: inv.grandTotal,
          vatAmount: inv.vatAmount,
        );
      }
      pw.Widget line(String a, String b, {bool bold = false}) => pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(a,
                  style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: bold ? pw.FontWeight.bold : null)),
              pw.Text('$b $currency',
                  style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: bold ? pw.FontWeight.bold : null)),
            ],
          );
      return pw.Padding(
        padding: const pw.EdgeInsets.only(top: 10),
        child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: 230,
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: headerColor, width: .8),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(children: [
                  line('الإجمالي قبل الضريبة', formatMoney(inv.subtotal)),
                  pw.SizedBox(height: 3),
                  line('ضريبة القيمة المضافة (${formatQty(inv.vatRate)}%)',
                      formatMoney(inv.vatAmount)),
                  pw.Divider(thickness: .5, color: PdfColors.grey500),
                  line('الإجمالي شامل الضريبة', formatMoney(inv.grandTotal),
                      bold: true),
                ]),
              ),
              pw.Spacer(),
              if (qr != null)
                pw.Column(children: [
                  pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: qr,
                    width: 86,
                    height: 86,
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text('رمز QR (صيغة المرحلة الأولى)',
                      style: const pw.TextStyle(
                          fontSize: 7, color: PdfColors.grey700)),
                ]),
            ]),
      );
    }

    pw.Widget summary() => pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: pw.BoxDecoration(
            color: headerColor,
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('عدد الأصناف: ${localizeDigits('${inv.itemCount}')}',
                  style: const pw.TextStyle(color: PdfColors.white, fontSize: 11)),
              pw.Text('العدد الكلي: ${formatQty(inv.totalQuantity)}',
                  style: const pw.TextStyle(color: PdfColors.white, fontSize: 11)),
              pw.Text('المبلغ الإجمالي: ${formatMoney(inv.grandTotal)} $currency',
                  style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold)),
            ],
          ),
        );

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 28),
          theme: theme,
          textDirection: pw.TextDirection.rtl,
        ),
        header: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Row(children: [
                  if (logoImage != null)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(left: 10),
                      child: pw.Image(logoImage,
                          height: 44, fit: pw.BoxFit.contain),
                    ),
                  pw.Text(
                    company.isEmpty ? 'دفتر' : company,
                    style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: headerColor),
                  ),
                ]),
                pw.Text(
                  '${inv.docLabel} رقم ${localizeDigits(inv.number)}',
                  style: pw.TextStyle(
                      fontSize: 18, fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                    'اسم العميل / المورد: ${inv.party.isEmpty ? '-' : inv.party}',
                    style: const pw.TextStyle(fontSize: 12)),
                pw.Text(
                    'التاريخ: ${formatDate(inv.date)}'
                    '${inv.kind == DocKind.invoice && inv.dueDate != null ? '   |   الاستحقاق: ${formatDate(inv.dueDate!)}' : ''}'
                    '   |   الحالة: ${inv.status.label}',
                    style: const pw.TextStyle(fontSize: 12)),
                if (inv.isNote && inv.refNumber.isNotEmpty)
                  pw.Text('عن الفاتورة رقم: ${localizeDigits(inv.refNumber)}',
                      style: const pw.TextStyle(fontSize: 12)),
              ],
            ),
            if (showVat && sellerVat.trim().isNotEmpty) ...[
              pw.SizedBox(height: 2),
              pw.Text('الرقم الضريبي للمنشأة: ${localizeDigits(normalizeDigits(sellerVat).trim())}',
                  style: const pw.TextStyle(fontSize: 11)),
            ],
            if (partyPhone.isNotEmpty || partyAddress.isNotEmpty) ...[
              pw.SizedBox(height: 2),
              pw.Text(
                  [
                    if (partyPhone.isNotEmpty) 'هاتف: ${localizeDigits(partyPhone)}',
                    if (partyAddress.isNotEmpty) 'العنوان: $partyAddress',
                  ].join('   |   '),
                  style: const pw.TextStyle(fontSize: 11)),
            ],
            if (inv.notes.isNotEmpty) ...[
              pw.SizedBox(height: 2),
              pw.Text('ملاحظات: ${inv.notes}',
                  style: const pw.TextStyle(fontSize: 11)),
            ],
            pw.SizedBox(height: 6),
            pw.Divider(thickness: 1, color: headerColor),
            pw.SizedBox(height: 4),
          ],
        ),
        footer: (ctx) => pw.Column(children: [
          pw.Divider(thickness: .5, color: PdfColors.grey500),
          summary(),
          if (inv.kind == DocKind.invoice && inv.paidAmount > 0 && !inv.isFullyPaid)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 3),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('المدفوع: ${formatMoney(inv.paidAmount)} $currency',
                      style: const pw.TextStyle(fontSize: 11)),
                  pw.Text('المتبقي: ${formatMoney(inv.remaining)} $currency',
                      style: pw.TextStyle(
                          fontSize: 12, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ),
          pw.SizedBox(height: 4),
          pw.Align(
            alignment: pw.Alignment.center,
            child: pw.Text('صفحة ${localizeDigits('${ctx.pageNumber}')} من ${localizeDigits('${ctx.pagesCount}')}',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
          ),
        ]),
        build: (ctx) => [
          if (data.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 8),
              child: pw.Align(
                  alignment: pw.Alignment.centerLeft, child: totalCard()),
            ),
          if (data.isEmpty)
            pw.Center(child: pw.Text('لا توجد أصناف'))
          else
            pw.TableHelper.fromTextArray(
              headers: headers,
              data: data,
              border: pw.TableBorder.all(color: PdfColors.grey400, width: .5),
              headerDecoration: const pw.BoxDecoration(color: headerColor),
              headerStyle: pw.TextStyle(
                  color: PdfColors.white,
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10),
              cellStyle: const pw.TextStyle(fontSize: 10),
              cellPadding:
                  const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              oddRowDecoration: const pw.BoxDecoration(color: zebra),
              headerAlignment: pw.Alignment.center,
              cellAlignment: pw.Alignment.center,
              cellAlignments: {
                0: pw.Alignment.centerRight,
                4: pw.Alignment.centerRight,
              },
              columnWidths: colWidths,
            ),
          if (data.isNotEmpty)
            pw.TableHelper.fromTextArray(
              data: [
                [
                  '',
                  formatMoney(inv.grandTotal),
                  '',
                  formatQty(inv.totalQuantity),
                  'الإجمالي',
                  '',
                  '',
                  '',
                ]
              ],
              border: pw.TableBorder.all(color: headerColor, width: .8),
              cellStyle: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: headerColor),
              headerCount: 0,
              oddRowDecoration: const pw.BoxDecoration(color: totalFill),
              rowDecoration: const pw.BoxDecoration(color: totalFill),
              cellPadding:
                  const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
              cellAlignment: pw.Alignment.center,
              cellAlignments: {4: pw.Alignment.centerRight},
              columnWidths: colWidths,
            ),
          if (showVat && data.isNotEmpty) vatBlock(),
        ],
      ),
    );
    return doc.save();
  }
}
