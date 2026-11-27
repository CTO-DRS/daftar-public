import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:daftar/services/logo_service.dart';
import 'dart:io';

import 'package:daftar/models/invoice.dart';
import 'package:daftar/models/invoice_item.dart';
import 'package:daftar/services/pdf_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('PDF with Arabic content is generated', () async {
    final inv = Invoice(vatRate: 15,
      number: '15',
      party: 'مؤسسة النور للتجارة',
      notes: 'تسليم خلال أسبوع',
      items: List.generate(
        40,
        (i) => InvoiceItem(unit: i.isEven ? 'درزن' : 'كرتون',
          itemCode: 'A${i + 1}',
          refNumber: '${100 + i}',
          description: 'مفتاح كهربائي مزدوج',
          quantity: 3.0 + i,
          unitPrice: 12.5,
          notes: i % 5 == 0 ? 'عاجل' : '',
        ),
      ),
    );
    final logoImg = img.Image(width: 600, height: 300);
    img.fill(logoImg, color: img.ColorRgb8(15, 118, 110));
    final logo = LogoService.normalize(Uint8List.fromList(img.encodePng(logoImg)));
    expect(img.decodePng(logo)!.width, 400);
    final out = Platform.environment['PDF_OUT'];
    for (final t in PdfTemplate.values) {
      inv.paidAmount = 5000;
      inv.status = InvoiceStatus.confirmed;
      final bytes = await PdfService.build(inv,
          company: 'شركة دفتر',
          logo: logo,
          partyPhone: '0551234567',
          partyAddress: 'المدينة المنورة',
          sellerVat: '310122393500003',
          template: t,
          brandColor: t == PdfTemplate.modern ? 0xFF1E3A5F : null);
      expect(bytes.length, greaterThan(5000));
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
      if (out != null) File('$out-${t.name}.pdf').writeAsBytesSync(bytes);
    }
  });

  test('issued-by footer: exact text, last page only, invoices only', () async {
    expect(PdfService.issuedByLines, [
      'تم إصدار هذه الفاتورة إلكترونيًا بواسطة تطبيق دفتر',
      'دفتر | لإدارة الفواتير والحسابات',
      'تطوير وبرمجة: رشيد الحداد',
      '© جميع الحقوق محفوظة لتطبيق دفتر.',
    ]);
    expect(PdfService.showsIssuedBy(Invoice(number: '1')), isTrue);
    expect(PdfService.showsIssuedBy(Invoice(number: '1', noteType: 'credit')), isTrue);
    expect(PdfService.showsIssuedBy(Invoice(number: '1', kind: DocKind.quote)), isFalse);
    expect(PdfService.showsIssuedBy(Invoice(number: '1', kind: DocKind.inventory)), isFalse);
    expect(PdfService.showsIssuedBy(Invoice(number: '1', kind: DocKind.expense)), isFalse);

    // نص الصفحات عبر pdftotext إن توفر (يتخطى الاختبار بصمت إن لم يتوفر).
    final has = (await Process.run('which', ['pdftotext'])).exitCode == 0;
    if (!has) return;
    Future<List<String>> pages(Invoice inv, PdfTemplate t) async {
      final bytes = await PdfService.build(inv, company: 'شركة', template: t);
      final f = File('${Directory.systemTemp.path}/issued_${inv.items.length}_${t.name}.pdf')
        ..writeAsBytesSync(bytes);
      final r = await Process.run('pdftotext', ['-layout', f.path, '-']);
      return (r.stdout as String).split('\f').where((p) => p.trim().isNotEmpty).toList();
    }
    // pdftotext يعيد أشكال العرض (presentation forms) لا الحروف الأصلية.
    bool has1(String p) => p.contains('\uFE8D\uFEDF\uFEA4\uFEAA\uFE8D\uFEA9');
    for (final t in PdfTemplate.values) {
      final big = Invoice(number: '9', items: List.generate(
          60, (i) => InvoiceItem(description: 'صنف $i', quantity: 2, unitPrice: 3)));
      final pg = await pages(big, t);
      expect(pg.length, greaterThan(1), reason: t.name);
      expect(pg.where(has1).length, 1, reason: '${t.name}: exactly one page');
      expect(has1(pg.last), isTrue, reason: '${t.name}: last page');
      final one = await pages(Invoice(number: '1', items: [InvoiceItem(description: 'x', quantity: 1, unitPrice: 1)]), t);
      expect(one.length, 1);
      expect(has1(one.single), isTrue);
      final q = await pages(Invoice(number: '2', kind: DocKind.quote, items: [InvoiceItem(description: 'x', quantity: 1, unitPrice: 1)]), t);
      expect(q.any(has1), isFalse);
    }
  });

  test('manual pages: each chosen page starts a new sheet, in page order', () async {
    final has = (await Process.run('which', ['pdftotext'])).exitCode == 0;
    if (!has) return;
    Future<List<String>> pages(Invoice inv, PdfTemplate t) async {
      final bytes = await PdfService.build(inv, company: 'Co', template: t);
      final f = File('${Directory.systemTemp.path}/pages_${t.name}.pdf')..writeAsBytesSync(bytes);
      final r = await Process.run('pdftotext', ['-layout', f.path, '-']);
      return (r.stdout as String).split('\f').where((p) => p.trim().isNotEmpty).toList();
    }
    InvoiceItem it(String d, int pg) => InvoiceItem(description: d, quantity: 1, unitPrice: 5, page: pg);
    bool has1(String p) => p.contains('\uFE8D\uFEDF\uFEA4\uFEAA\uFE8D\uFEA9');
    for (final t in PdfTemplate.values) {
      // ALPHA ص1، BETA ص3، GAMMA ص2: ثلاث ورقات بالترتيب ALPHA, GAMMA, BETA
      final pg = await pages(
          Invoice(number: '7', items: [it('ALPHA', 1), it('BETA', 3), it('GAMMA', 2)]), t);
      expect(pg.length, 3, reason: t.name);
      expect(pg[0].contains('ALPHA') && !pg[0].contains('GAMMA') && !pg[0].contains('BETA'), isTrue, reason: t.name);
      expect(pg[1].contains('GAMMA') && !pg[1].contains('BETA'), isTrue, reason: t.name);
      expect(pg[2].contains('BETA'), isTrue, reason: t.name);
      expect(pg.where(has1).length, 1, reason: '${t.name}: credit footer only on last');
      expect(has1(pg.last), isTrue);
      // بدون صفحات يدوية: ورقة واحدة كما كان.
      final auto = await pages(Invoice(number: '8', items: [it('ALPHA', 0), it('BETA', 0)]), t);
      expect(auto.length, 1, reason: t.name);
    }
  });
}
