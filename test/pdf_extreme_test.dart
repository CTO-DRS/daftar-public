import 'package:daftar/models/invoice.dart';
import 'package:daftar/models/invoice_item.dart';
import 'package:daftar/services/pdf_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final long = 'بناجر بناتي أوميغا موديل W-2130 مع علبة هدايا فاخرة وملحقات إضافية كثيرة جداً ' * 4;
  final inv = Invoice(
    number: 'INV-٠٠١',
    party: 'مؤسسة النور للتجارة والمقاولات العامة ذ.م.م ' * 3,
    notes: 'ملاحظة طويلة ' * 60,
    vatRate: 15,
    items: [
      for (var i = 0; i < 220; i++)
        InvoiceItem(
          description: i % 7 == 0 ? long : 'Item $i صنف',
          itemCode: i.isEven ? 'W-${2000 + i}' : '',
          refNumber: i % 3 == 0 ? 'REF/$i' : '',
          quantity: i % 5 == 0 ? 0 : 1.5 * i,
          unitPrice: 1234567.891,
          unit: 'كرتون',
          wholesaleQty: i % 4 == 0 ? 3 : 0,
          wholesaleUnit: 'كرتون',
          wholesalePrice: 99999.5,
          packSize: 672,
          notes: i % 9 == 0 ? long : '',
        ),
    ],
  );
  for (final t in PdfTemplate.values) {
    test('${t.name} survives 220 rows, very long text, huge numbers, mixed RTL/LTR', () async {
      final b = await PdfService.build(inv, template: t, company: 'شركة ' * 20, sellerVat: '300000000000003', partyPhone: '+966 55 340 5949');
      expect(b.length, greaterThan(2000));
    });
  }
}
