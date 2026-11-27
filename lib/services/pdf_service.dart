import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/invoice.dart';
import '../models/invoice_item.dart';
import '../utils/brand_color.dart';
import '../utils/date_utils.dart';
import '../utils/number_utils.dart';
import '../utils/statement.dart';
import '../utils/zatca.dart';

/// قوالب الفاتورة: كلاسيكي، عصري، مختصر.
enum PdfTemplate { classic, modern, compact }

extension PdfTemplateX on PdfTemplate {
  String get label => switch (this) {
        PdfTemplate.classic => 'كلاسيكي',
        PdfTemplate.modern => 'عصري',
        PdfTemplate.compact => 'مختصر',
      };
  String get hint => switch (this) {
        PdfTemplate.classic => 'خط أميري، ترويسة بسيطة وجدول بإطار',
        PdfTemplate.modern => 'شريط ملوّن، خط حديث وجدول نظيف',
        PdfTemplate.compact => 'أصغر حجماً لتتسع أسطر أكثر في الصفحة',
      };
  static PdfTemplate fromDb(String? v) => PdfTemplate.values
      .firstWhere((e) => e.name == v, orElse: () => PdfTemplate.classic);
}

/// يولّد ملف PDF عربي (RTL) بخطوط مضمّنة في assets (بدون أي اتصال).
class PdfService {
  PdfService._();

  static pw.Font? _amiri, _amiriBold, _plex, _plexBold;

  static Future<void> _loadFonts() async {
    Future<pw.Font> f(String n) async =>
        pw.Font.ttf(await rootBundle.load('assets/fonts/$n.ttf'));
    _amiri ??= await f('Amiri-Regular');
    _amiriBold ??= await f('Amiri-Bold');
    _plex ??= await f('IBMPlexSansArabic-Regular');
    _plexBold ??= await f('IBMPlexSansArabic-Bold');
  }

  /// كشف حساب عميل/مورد بصيغة PDF عربي.
  static Future<Uint8List> buildStatementPdf(
    Statement st, {
    String currency = 'ر.س',
    String company = '',
    Uint8List? logo,
    String partyPhone = '',
    DateTime? now,
    int? brandColor,
    PdfTemplate template = PdfTemplate.classic,
  }) async {
    await _loadFonts();
    final modern = template == PdfTemplate.modern;
    final theme = modern
        ? pw.ThemeData.withFont(base: _plex!, bold: _plexBold!)
        : pw.ThemeData.withFont(base: _amiri!, bold: _amiriBold!);
    final brand = PdfColor.fromInt(resolveBrandColor(chosen: brandColor, logo: logo));
    final tint = PdfColor(brand.red + (1 - brand.red) * .9,
        brand.green + (1 - brand.green) * .9, brand.blue + (1 - brand.blue) * .9);
    final name = company.isEmpty ? 'دفتر' : company;
    final today = now ?? DateTime.now();
    final doc = pw.Document(title: 'كشف حساب ${st.party}', author: name);
    final headers = ['الرصيد', 'المسدَّد', 'المبلغ', 'الاستحقاق', 'البيان', 'التاريخ'];
    final data = [
      for (final r in st.rows)
        [
          formatMoney(r.balance),
          r.paid > 0.005 ? formatMoney(r.paid) : '-',
          formatMoney(r.amount),
          r.due == null ? '-' : formatDate(r.due!),
          r.label,
          formatDate(r.date),
        ]
    ];
    final logoImage = logo == null ? null : pw.MemoryImage(logo);
    final owes = st.balance > 0.005;
    doc.addPage(pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 26, 28, 28),
        theme: theme,
        textDirection: pw.TextDirection.rtl,
      ),
      footer: (c) => pw.Align(
          alignment: pw.Alignment.center,
          child: pw.Text('${localizeDigits('${c.pageNumber}')} / ${localizeDigits('${c.pagesCount}')}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600))),
      build: (c) => [
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
          if (logoImage != null) pw.Container(width: 46, height: 46, margin: const pw.EdgeInsetsDirectional.only(end: 10), child: pw.Image(logoImage)),
          pw.Expanded(child: pw.Text(name, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: brand))),
          pw.Text('كشف حساب', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        ]),
        pw.Divider(color: brand, thickness: 1.2),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(color: tint, borderRadius: pw.BorderRadius.circular(6)),
          child: pw.Row(children: [
            pw.Expanded(
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(st.party, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              if (partyPhone.isNotEmpty) pw.Text(localizeDigits(partyPhone), style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
            ])),
            pw.Text('بتاريخ ${formatDate(today)}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          ]),
        ),
        pw.SizedBox(height: 12),
        if (data.isEmpty)
          pw.Padding(padding: const pw.EdgeInsets.all(20), child: pw.Center(child: pw.Text('لا توجد مستندات معتمدة لهذا الطرف.')))
        else
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: data,
            border: pw.TableBorder(
              horizontalInside: const pw.BorderSide(color: PdfColors.grey300, width: .5),
              bottom: pw.BorderSide(color: brand, width: 1),
            ),
            headerDecoration: pw.BoxDecoration(color: modern ? tint : brand),
            headerStyle: pw.TextStyle(color: modern ? brand : PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10),
            cellStyle: const pw.TextStyle(fontSize: 10),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
            headerAlignment: pw.Alignment.center,
            cellAlignment: pw.Alignment.center,
            cellAlignments: {4: pw.Alignment.centerRight},
            columnWidths: {
              0: const pw.FlexColumnWidth(1.5),
              1: const pw.FlexColumnWidth(1.4),
              2: const pw.FlexColumnWidth(1.4),
              3: const pw.FlexColumnWidth(1.5),
              4: const pw.FlexColumnWidth(2.4),
              5: const pw.FlexColumnWidth(1.5),
            },
          ),
        pw.SizedBox(height: 14),
        pw.Align(
          alignment: pw.Alignment.centerLeft,
          child: pw.Container(
            width: 230,
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: brand, width: 1), borderRadius: pw.BorderRadius.circular(6)),
            child: pw.Column(children: [
              _srow('إجمالي المستندات', '${formatMoney(st.totalAmount)} $currency'),
              _srow('إجمالي المسدَّد', '${formatMoney(st.totalPaid)} $currency'),
              pw.Divider(color: PdfColors.grey400, height: 10),
              _srow(owes ? 'الرصيد المستحق' : 'الرصيد', '${formatMoney(st.balance.abs())} $currency',
                  bold: true, color: owes ? PdfColors.red800 : brand),
            ]),
          ),
        ),
      ],
    ));
    return doc.save();
  }

  /// عبارة توثيق المصدر: أسطر نصها كما اعتمده المطور، تُطبع في آخر صفحة فقط.
  static const issuedByLines = <String>[
    'تم إصدار هذه الفاتورة إلكترونيًا بواسطة تطبيق دفتر',
    'دفتر | لإدارة الفواتير والحسابات',
    'تطوير وبرمجة: رشيد الحداد',
    '© جميع الحقوق محفوظة لتطبيق دفتر.',
  ];

  /// الفواتير والإشعارات فقط (عرض السعر والجرد والمصروف ليست فواتير صادرة).
  static bool showsIssuedBy(Invoice inv) => inv.kind == DocKind.invoice;

  static pw.Widget _issuedByBlock() => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 18),
        child: pw.Column(children: [
          pw.Divider(thickness: .5, color: PdfColors.grey500, height: 6),
          pw.SizedBox(height: 4),
          pw.Text(issuedByLines[0],
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
          pw.Text(issuedByLines[1],
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700, fontWeight: pw.FontWeight.bold)),
          pw.Text(issuedByLines[2],
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
          pw.Text(issuedByLines[3],
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
        ]),
      );

  static pw.Widget _srow(String a, String b, {bool bold = false, PdfColor? color}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text(a, style: pw.TextStyle(fontSize: bold ? 12 : 10.5, fontWeight: bold ? pw.FontWeight.bold : null)),
          pw.Text(b, style: pw.TextStyle(fontSize: bold ? 13 : 10.5, fontWeight: bold ? pw.FontWeight.bold : null, color: color)),
        ]),
      );

  static Future<Uint8List> build(
    Invoice inv, {
    String currency = 'ر.س',
    String company = '',
    Uint8List? logo,
    String partyPhone = '',
    String partyAddress = '',
    String sellerVat = '',
    PdfTemplate template = PdfTemplate.classic,
    int? brandColor, // ARGB؛ null = تلقائي من الشعار
  }) async {
    await _loadFonts();
    final items = inv.items.where((e) => !e.isEmpty).toList();
    final modern = template == PdfTemplate.modern;
    final compact = template == PdfTemplate.compact;
    final theme = modern
        ? pw.ThemeData.withFont(base: _plex!, bold: _plexBold!)
        : pw.ThemeData.withFont(base: _amiri!, bold: _amiriBold!);
    final name = company.isEmpty ? 'دفتر' : company;
    final doc = pw.Document(title: '${inv.docLabel} ${inv.number}', author: name);

    final logoImage = logo == null ? null : pw.MemoryImage(logo);
    final brand = PdfColor.fromInt(resolveBrandColor(chosen: brandColor, logo: logo));
    final tint = PdfColor(brand.red + (1 - brand.red) * .88,
        brand.green + (1 - brand.green) * .88, brand.blue + (1 - brand.blue) * .88);
    final softTint = PdfColor(brand.red + (1 - brand.red) * .94,
        brand.green + (1 - brand.green) * .94, brand.blue + (1 - brand.blue) * .94);
    const grey = PdfColors.grey700;

    final fs = compact ? 9.0 : 10.0; // خط الجدول
    final fsInfo = compact ? 10.0 : 11.5;
    final vatOn = inv.kind == DocKind.invoice && inv.vatRate > 0;
    final money = currency;

    // ---- الجدول: الأعمدة من اليسار إلى اليمين (م أقصى اليمين) ----
    // الأعمدة تظهر حسب البيانات: الجملة والمرجع والكود والملاحظات تختفي إن كانت فارغة.
    final anyWholesale = items.any((e) => e.hasWholesale);
    final anyRef = items.any((e) => e.refNumber.trim().isNotEmpty);
    final anyCode = items.any((e) => e.itemCode.trim().isNotEmpty);
    final anyNotes = items.any((e) => e.notes.trim().isNotEmpty);
    String wq(InvoiceItem it) {
      if (!it.hasWholesale) return '';
      final base = it.wholesaleUnit.trim().isEmpty
          ? formatQty(it.wholesaleQty)
          : '${formatQty(it.wholesaleQty)} ${it.wholesaleUnit.trim()}';
      return it.packSize > 0 ? '$base (${formatQty(it.wholesaleQty * it.packSize)})' : base;
    }
    // (العنوان، العرض، محاذاة لليمين؟، القيمة) من اليسار إلى اليمين (م أقصى اليمين).
    final cols = <(String, double, bool, String Function(InvoiceItem, int))>[
      if (anyNotes) ('ملاحظات', compact ? 1.8 : 2.0, true, (it, i) => it.notes),
      ('الإجمالي', 1.6, false, (it, i) => formatMoney(it.total)),
      if (anyWholesale) ('سعر الجملة', 1.4, false, (it, i) => it.hasWholesale ? formatMoney(it.wholesalePrice) : ''),
      if (anyWholesale) ('عدد الجملة', 1.4, false, (it, i) => wq(it)),
      ('سعر الفردي', 1.4, false, (it, i) => it.quantity == 0 && it.unitPrice == 0 ? '' : formatMoney(it.unitPrice)),
      ('العدد', 1.0, false, (it, i) => it.quantity == 0 && it.unitPrice == 0 ? '' : formatQty(it.quantity)),
      ('الوحدة', 1.1, false, (it, i) => it.unit.trim()),
      ('النوع / الوصف', 3.0, true, (it, i) => it.description),
      if (anyRef) ('الرقم المرجعي', 1.5, false, (it, i) => it.refNumber),
      if (anyCode) ('كود الصنف', 1.5, false, (it, i) => it.itemCode),
      ('م', 0, false, (it, i) => localizeDigits('${i + 1}')),
    ];
    final headers = [for (final c in cols) c.$1];
    final data = <List<String>>[
      for (var i = 0; i < items.length; i++) [for (final c in cols) c.$4(items[i], i)]
    ];
    final colWidths = <int, pw.TableColumnWidth>{
      for (var i = 0; i < cols.length; i++)
        i: cols[i].$2 == 0 ? const pw.FixedColumnWidth(24) : pw.FlexColumnWidth(cols[i].$2),
    };
    final rightAligned = <int, pw.Alignment>{
      for (var i = 0; i < cols.length; i++)
        if (cols[i].$3) i: pw.Alignment.centerRight,
    };
    final pad = pw.EdgeInsets.symmetric(horizontal: 4, vertical: compact ? 2.5 : (modern ? 6 : 4.5));

    pw.Widget table() {
      if (modern) {
        return pw.TableHelper.fromTextArray(
          headers: headers,
          data: data,
          border: pw.TableBorder(
            horizontalInside: pw.BorderSide(color: PdfColors.grey300, width: .5),
            bottom: pw.BorderSide(color: brand, width: 1),
          ),
          headerDecoration: pw.BoxDecoration(color: tint),
          headerStyle: pw.TextStyle(color: brand, fontWeight: pw.FontWeight.bold, fontSize: fs),
          cellStyle: pw.TextStyle(fontSize: fs),
          cellPadding: pad,
          headerAlignment: pw.Alignment.center,
          cellAlignment: pw.Alignment.center,
          cellAlignments: rightAligned,
          columnWidths: colWidths,
        );
      }
      return pw.TableHelper.fromTextArray(
        headers: headers,
        data: data,
        border: pw.TableBorder.all(color: PdfColors.grey400, width: .5),
        headerDecoration: pw.BoxDecoration(color: compact ? PdfColors.grey200 : brand),
        headerStyle: pw.TextStyle(
            color: compact ? PdfColors.black : PdfColors.white,
            fontWeight: pw.FontWeight.bold,
            fontSize: fs),
        cellStyle: pw.TextStyle(fontSize: fs),
        cellPadding: pad,
        oddRowDecoration: compact ? null : pw.BoxDecoration(color: softTint),
        headerAlignment: pw.Alignment.center,
        cellAlignment: pw.Alignment.center,
        cellAlignments: rightAligned,
        columnWidths: colWidths,
      );
    }

    // ---- الإجماليات ----
    pw.Widget line(String a, String b, {bool bold = false, double size = 11, PdfColor? color}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text(a, style: pw.TextStyle(fontSize: size, color: color ?? (bold ? null : grey), fontWeight: bold ? pw.FontWeight.bold : null)),
            pw.Text(b, style: pw.TextStyle(fontSize: size, color: color, fontWeight: bold ? pw.FontWeight.bold : null)),
          ]),
        );

    pw.Widget totalsBox() {
      final paid = inv.kind == DocKind.invoice && !inv.isNote && inv.paidAmount > 0 && !inv.isFullyPaid;
      return pw.Container(
        width: compact ? 210 : 245,
        padding: const pw.EdgeInsets.all(9),
        decoration: pw.BoxDecoration(
          color: modern ? softTint : null,
          border: modern ? null : pw.Border.all(color: brand, width: .8),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(children: [
          line('عدد الأصناف', localizeDigits('${inv.itemCount}')),
          line('العدد الكلي', formatQty(inv.totalQuantity)),
          if (vatOn) ...[
            pw.Divider(thickness: .4, color: PdfColors.grey400, height: 8),
            line('الإجمالي قبل الضريبة', '${formatMoney(inv.subtotal)} $money'),
            line('ضريبة القيمة المضافة (${formatQty(inv.vatRate)}%)', '${formatMoney(inv.vatAmount)} $money'),
          ],
          pw.Divider(thickness: .8, color: brand, height: 10),
          line(vatOn ? 'الإجمالي شامل الضريبة' : 'المبلغ الإجمالي', '${formatMoney(inv.grandTotal)} $money',
              bold: true, size: compact ? 12 : 14, color: brand),
          if (paid) ...[
            pw.SizedBox(height: 3),
            line('المدفوع', '${formatMoney(inv.paidAmount)} $money'),
            line('المتبقي', '${formatMoney(inv.remaining)} $money', bold: true, size: 12),
          ],
        ]),
      );
    }

    pw.Widget qrBlock() {
      if (!vatOn || sellerVat.trim().isEmpty) return pw.SizedBox();
      final n = DateTime.now();
      final ts = DateTime(inv.date.year, inv.date.month, inv.date.day, n.hour, n.minute, n.second);
      final qr = zatcaPhase1Qr(
        sellerName: name,
        vatNumber: normalizeDigits(sellerVat).trim(),
        timestamp: ts,
        totalWithVat: inv.grandTotal,
        vatAmount: inv.vatAmount,
      );
      return pw.Column(children: [
        pw.BarcodeWidget(barcode: pw.Barcode.qrCode(), data: qr, width: 88, height: 88),
        pw.SizedBox(height: 2),
        pw.Text('رمز QR (صيغة المرحلة الأولى)', style: const pw.TextStyle(fontSize: 7, color: grey)),
      ]);
    }

    pw.Widget summarySection() => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 12),
          child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            totalsBox(),
            pw.Spacer(),
            qrBlock(),
          ]),
        );

    // ---- الترويسة ----
    final title = '${inv.docLabel} رقم ${localizeDigits(inv.number)}';
    final dateLine = 'التاريخ: ${formatDate(inv.date)}';
    final dueLine = inv.kind == DocKind.invoice && !inv.isNote && inv.dueDate != null
        ? 'الاستحقاق: ${formatDate(inv.dueDate!)}'
        : null;
    final statusLine = 'الحالة: ${inv.status.label}';
    final contact = [
      if (partyPhone.isNotEmpty) 'هاتف: ${localizeDigits(partyPhone)}',
      if (partyAddress.isNotEmpty) 'العنوان: $partyAddress',
    ].join('   |   ');
    final sellerLine = vatOn && sellerVat.trim().isNotEmpty
        ? 'الرقم الضريبي للمنشأة: ${localizeDigits(normalizeDigits(sellerVat).trim())}'
        : null;
    final refLine = inv.isNote && inv.refNumber.isNotEmpty ? 'عن الفاتورة رقم: ${localizeDigits(inv.refNumber)}' : null;

    pw.Widget logoW(double h) => logoImage == null
        ? pw.SizedBox()
        : pw.Padding(
            padding: const pw.EdgeInsetsDirectional.only(end: 10),
            child: pw.Image(logoImage, height: h, fit: pw.BoxFit.contain));

    pw.Widget infoCard(String head, List<String> lines) => pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300, width: .6),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(head, style: pw.TextStyle(fontSize: 9, color: brand, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 3),
              for (final l in lines) pw.Text(l, style: pw.TextStyle(fontSize: fsInfo)),
            ]),
          ),
        );

    pw.Widget firstHeader() {
      if (modern) {
        return pw.Column(children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: pw.BoxDecoration(color: brand, borderRadius: pw.BorderRadius.circular(10)),
            child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Row(children: [
                if (logoImage != null)
                  pw.Container(
                      padding: const pw.EdgeInsets.all(4),
                      margin: const pw.EdgeInsetsDirectional.only(end: 10),
                      decoration: pw.BoxDecoration(color: PdfColors.white, borderRadius: pw.BorderRadius.circular(6)),
                      child: pw.Image(logoImage, height: 36, fit: pw.BoxFit.contain)),
                pw.Text(name, style: pw.TextStyle(fontSize: 17, color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
              ]),
              pw.Text(title, style: pw.TextStyle(fontSize: 16, color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
            ]),
          ),
          pw.SizedBox(height: 8),
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            infoCard('العميل / المورد', [
              inv.party.isEmpty ? '-' : inv.party,
              if (contact.isNotEmpty) contact,
            ]),
            pw.SizedBox(width: 8),
            infoCard('تفاصيل المستند', [
              dateLine,
              ?dueLine,
              statusLine,
              ?refLine,
              ?sellerLine,
            ]),
          ]),
          if (inv.notes.isNotEmpty)
            pw.Padding(
                padding: const pw.EdgeInsets.only(top: 6),
                child: pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text('ملاحظات: ${inv.notes}', style: pw.TextStyle(fontSize: fsInfo - 1)))),
          pw.SizedBox(height: 10),
        ]);
      }
      if (compact) {
        return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Row(children: [
              logoW(26),
              pw.Text(name, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: brand)),
            ]),
            pw.Text(title, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
            pw.Text([dateLine, ?dueLine].join('  |  '), style: pw.TextStyle(fontSize: fsInfo)),
          ]),
          pw.SizedBox(height: 3),
          pw.Text(
              [
                'العميل: ${inv.party.isEmpty ? '-' : inv.party}',
                if (contact.isNotEmpty) contact,
                ?refLine,
                ?sellerLine,
                if (inv.notes.isNotEmpty) 'ملاحظات: ${inv.notes}',
              ].join('   |   '),
              style: pw.TextStyle(fontSize: fsInfo - .5)),
          pw.Divider(thickness: .8, color: brand, height: 8),
        ]);
      }
      // كلاسيكي
      return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Row(children: [
            logoW(44),
            pw.Text(name, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: brand)),
          ]),
          pw.Text(title, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        ]),
        pw.SizedBox(height: 6),
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('اسم العميل / المورد: ${inv.party.isEmpty ? '-' : inv.party}', style: pw.TextStyle(fontSize: fsInfo + .5)),
            if (contact.isNotEmpty) pw.Text(contact, style: pw.TextStyle(fontSize: fsInfo)),
            if (sellerLine != null) pw.Text(sellerLine, style: pw.TextStyle(fontSize: fsInfo)),
            if (inv.notes.isNotEmpty) pw.Text('ملاحظات: ${inv.notes}', style: pw.TextStyle(fontSize: fsInfo)),
          ]),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text([dateLine, ?dueLine].join('   |   '), style: pw.TextStyle(fontSize: fsInfo)),
            pw.Text(statusLine, style: pw.TextStyle(fontSize: fsInfo)),
            if (refLine != null) pw.Text(refLine, style: pw.TextStyle(fontSize: fsInfo)),
          ]),
        ]),
        pw.SizedBox(height: 6),
        pw.Divider(thickness: 1, color: brand),
        pw.SizedBox(height: 2),
      ]);
    }

    pw.Widget miniHeader() => pw.Column(children: [
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text(name, style: pw.TextStyle(fontSize: 11, color: brand, fontWeight: pw.FontWeight.bold)),
            pw.Text(title, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          ]),
          pw.Divider(thickness: .6, color: brand, height: 8),
        ]);

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.fromLTRB(28, 26, 28, compact ? 24 : 28),
          theme: theme,
          textDirection: pw.TextDirection.rtl,
        ),
        header: (ctx) => ctx.pageNumber == 1 ? firstHeader() : miniHeader(),
        footer: (ctx) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 6),
          child: pw.Align(
            alignment: pw.Alignment.center,
            child: pw.Text('صفحة ${localizeDigits('${ctx.pageNumber}')} من ${localizeDigits('${ctx.pagesCount}')}',
                style: const pw.TextStyle(fontSize: 9, color: grey)),
          ),
        ),
        build: (ctx) => [
          if (data.isEmpty) pw.Center(child: pw.Text('لا توجد أصناف')) else table(),
          if (data.isNotEmpty) pw.Wrap(children: [summarySection()]),
          if (showsIssuedBy(inv)) _issuedByBlock(),
        ],
      ),
    );
    return doc.save();
  }
}
