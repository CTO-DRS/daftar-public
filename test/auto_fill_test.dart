import 'package:flutter_test/flutter_test.dart';
import 'package:daftar/models/invoice_item.dart';
import 'package:daftar/utils/auto_fill.dart';

void main() {
  scanSpeedTests();
  test('party match ignores hamza and tolerates one typo, never guesses', () {
    final k = ['أحمد العتيبي', 'محمد سالم'];
    expect(matchParty('احمد العتيبي', k), 'أحمد العتيبي');
    expect(matchParty('احمد العتيبى', k), 'أحمد العتيبي');
    expect(matchParty('خالد', k), isNull);
    expect(matchParty('', k), isNull);
  });
  test('enrich fills only missing fields from history', () {
    final h = {'كولا': InvoiceItem(description: 'كولا', unitPrice: 2, costPrice: 1.2, unit: 'حبة', packSize: 24, itemCode: 'C1')};
    final a = InvoiceItem(description: 'كولا', quantity: 3);
    final b = InvoiceItem(description: 'كولا', quantity: 1, unitPrice: 2.5, costPrice: 1.5);
    final c = InvoiceItem(description: 'ماء', quantity: 1);
    expect(enrichItems([a, b, c], h), 2);
    expect([a.unitPrice, a.costPrice, a.unit, a.packSize, a.itemCode], [2, 1.2, 'حبة', 24, 'C1']);
    expect([b.unitPrice, b.costPrice], [2.5, 1.5]);
    expect(c.unitPrice, 0);
  });
}

void scanSpeedTests() {
  group('scan speed pass', () {
    test('snapItemNames fixes one-letter OCR typos only', () {
      final its = [InvoiceItem(description: 'مكرونه سباغيتي'), InvoiceItem(description: 'شاي'), InvoiceItem(description: 'منتج غريب')];
      final n = snapItemNames(its, ['مكرونة سباغيتي', 'شاي احمر']);
      expect(its[0].description, 'مكرونة سباغيتي');
      expect(its[1].description, 'شاي');
      expect(its[2].description, 'منتج غريب');
      expect(n, 1);
    });
    test('applyCustomerPrices fills only empty prices', () {
      final its = [InvoiceItem(description: 'رز', unitPrice: 0), InvoiceItem(description: 'سكر', unitPrice: 9)];
      final n = applyCustomerPrices(its, {normArabic('رز'): 11, normArabic('سكر'): 4});
      expect(n, 1);
      expect(its[0].unitPrice, 11);
      expect(its[1].unitPrice, 9);
    });
  });
}
