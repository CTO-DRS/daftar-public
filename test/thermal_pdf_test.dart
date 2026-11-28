import 'dart:convert';
import 'package:daftar/models/invoice.dart';
import 'package:daftar/models/invoice_item.dart';
import 'package:daftar/services/pdf_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final inv = Invoice(
    vatRate: 15,
    number: '7',
    party: 'مؤسسة النور',
    items: [
      for (var i = 0; i < 30; i++)
        InvoiceItem(description: 'مفتاح كهربائي مزدوج $i', quantity: 2, unit: 'حبة', unitPrice: 12.5),
      InvoiceItem(description: 'بناجر', wholesaleQty: 1, wholesaleUnit: 'كرتون', packSize: 672, wholesalePrice: 100),
    ],
  );

  for (final mm in [80, 58]) {
    test('thermal $mm mm receipt is one page with the roll width', () async {
      final bytes = await PdfService.buildThermal(inv, widthMm: mm, sellerVat: '300000000000003', company: 'مؤسسة سهام');
      final text = latin1.decode(bytes);
      expect(text.startsWith('%PDF'), isTrue);
      expect(RegExp(r'/Type\s*/Page\b').allMatches(text).length, 1);
      final w = mm * 72 / 25.4;
      final box = RegExp(r'/MediaBox\s*\[\s*0\s+0\s+([\d.]+)\s+([\d.]+)').firstMatch(text)!;
      expect(double.parse(box.group(1)!), closeTo(w, 0.5));
      expect(double.parse(box.group(2)!), greaterThan(300)); // طويل بقدر الأصناف
    });
  }
  test('thermal templates route through build()', () async {
    final b = await PdfService.build(inv, template: PdfTemplate.thermal58);
    expect(latin1.decode(b).contains('MediaBox'), isTrue);
    expect(PdfTemplateX.fromDb('thermal80'), PdfTemplate.thermal80);
    expect(PdfTemplate.thermal58.isThermal, isTrue);
  });
}
