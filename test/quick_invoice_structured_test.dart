import 'package:flutter_test/flutter_test.dart';
import 'package:daftar/models/invoice_item.dart';
import 'package:daftar/utils/quick_invoice.dart';

void main() {
  test('structured scanned line maps into fields, not one long description', () {
    final q = parseQuickInvoice(
        'بناجر بناتي أوميغا – موديل W-2130 – عدد 56 كرتون/باكت – الباكت 12 × 6 حبات.\n'
        'بناجر عادي – موديل W-641 – عدد 50 كرتون – الدرزن 12 × 12 حبة.\n'
        'مثلج ذهبي – موديل X-648 – عدد 42 كرتون/كيس – الكيس 48 حبة.');
    expect(q.items.length, 3);
    final a = q.items[0];
    expect(a.description, 'بناجر بناتي أوميغا');
    expect(a.itemCode, 'W-2130');
    expect(a.packSize, 72);
    expect(a.unit, 'كرتون');
    expect(a.wholesaleQty, 56);
    expect(q.items[1].packSize, 144);
    expect(q.items[1].itemCode, 'W-641');
    expect(q.items[2].packSize, 48);
    expect(q.items[2].wholesaleQty, 42);
  });
  test('prices come from the catalog item with the same model code', () {
    final cat = [InvoiceItem(itemCode: 'W-2130', description: 'بناجر قديم', unitPrice: 2.5, unit: 'حبة')];
    final q = parseQuickInvoice('بناجر بناتي أوميغا – موديل W2130 – عدد 10 كرتون – الباكت 12 × 6 حبات', catalog: cat);
    final i = q.items.single;
    expect(i.unitPrice, 2.5);
    expect(i.wholesalePrice, 2.5 * 72);
    expect(i.itemCode, 'W-2130');
  });
  test('incomplete count line keeps the number and note', () {
    final q = parseQuickInvoice('خواتم ذهبي – موديل A-299 – عدد 294 (وحدة التعبئة غير مكتملة في البيانات).');
    final i = q.items.single;
    expect(i.quantity, 294);
    expect(i.itemCode, 'A-299');
    expect(i.notes, contains('غير مكتملة'));
  });
  test('normal dictation still parses', () {
    final q = parseQuickInvoice('فاتورة لأحمد، 5 درزن كولا، 3 كرتون عصير بسعر 20');
    expect(q.party, 'أحمد');
    expect(q.items.length, 2);
  });
  test('"و" before an Arabic number word splits lines (no ASCII word boundary)', () {
    final q = parseQuickInvoice('فاتورة لأحمد، خمسة كولا و ثلاثة عصير');
    expect(q.items.length, 2);
    expect(q.items[1].quantity, 3);
  });
}
