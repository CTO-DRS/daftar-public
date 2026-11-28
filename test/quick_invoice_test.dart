import 'package:flutter_test/flutter_test.dart';
import 'package:daftar/models/invoice_item.dart';
import 'package:daftar/utils/quick_invoice.dart';

void main() {
  voiceParserTests();
  test('party and lines from a spoken sentence', () {
    final q = parseQuickInvoice('فاتورة لأحمد، 5 درزن كولا، 3 كرتون عصير برتقال بسعر 20');
    expect(q.party, 'أحمد');
    expect(q.items.length, 2);
    expect(q.items[0].quantity, 5);
    expect(q.items[0].unit, 'درزن');
    expect(q.items[0].description, 'كولا');
    expect(q.items[1].quantity, 3);
    expect(q.items[1].description, 'عصير برتقال');
    expect(q.items[1].unitPrice, 20);
  });

  test('number words, Arabic digits, and "و" separators', () {
    final q = parseQuickInvoice('اعمل فاتورة للعميل محمد علي خمسة كرتون ماء و ٣ علب شاي');
    expect(q.party, 'محمد علي');
    expect(q.items.map((e) => e.quantity), [5, 3]);
    expect(q.items[1].unit, 'علبة');
    expect(q.items[1].description, 'شاي');
  });

  test('catalog fills price and moves pack units to wholesale', () {
    final cat = [
      InvoiceItem(description: 'كولا', unitPrice: 2, unit: 'حبة', packSize: 24, itemCode: 'C1')
    ];
    final q = parseQuickInvoice('فاتورة لأحمد، 5 كرتون كولا', catalog: cat, parties: ['أحمد خالد']);
    expect(q.party, 'أحمد خالد');
    final it = q.items.single;
    expect(it.itemCode, 'C1');
    expect(it.wholesaleQty, 5);
    expect(it.wholesalePrice, 48);
    expect(it.pieces, 120);
  });

  test('no party and trailing quantity', () {
    final q = parseQuickInvoice('سكر 10');
    expect(q.party, '');
    expect(q.items.single.quantity, 10);
    expect(q.items.single.description, 'سكر');
  });
}

void voiceParserTests() {
  group('voice phrases', () {
    test('repeat last invoice for a customer', () {
      final q = parseQuickInvoice('نفس الفاتورة السابقة لأحمد');
      expect(q.repeatLast, isTrue);
      expect(q.party, 'أحمد');
      final q2 = parseQuickInvoice('كرر آخر فاتورة لمحمد علي');
      expect(q2.repeatLast, isTrue);
      expect(q2.party, 'محمد علي');
    });
    test('repeat plus extra line', () {
      final q = parseQuickInvoice('نفس الفاتورة السابقة لأحمد، 3 كرتون عصير');
      expect(q.repeatLast, isTrue);
      expect(q.items.length, 1);
      expect(q.items.first.description, 'عصير');
    });
    test('vat spoken', () {
      expect(parseQuickInvoice('فاتورة لأحمد، 5 كولا بدون ضريبة').vatRate, 0);
      final q = parseQuickInvoice('فاتورة لأحمد، 5 كولا ضريبة 15%');
      expect(q.vatRate, 15);
      expect(q.items.single.description, 'كولا');
      expect(parseQuickInvoice('فاتورة لأحمد، 5 كولا').vatRate, isNull);
      expect(parseQuickInvoice('فاتورة لأحمد، 5 كولا').repeatLast, isFalse);
    });
  });
  test('compound spoken numbers', () {
    expect(parseQuickInvoice('خمسة وعشرين كولا').items.single.quantity, 25);
    expect(parseQuickInvoice('اثنين وثلاثين حبة بيبسي').items.single.quantity, 32);
    expect(parseQuickInvoice('ميتين كولا').items.single.quantity, 200);
    final two = parseQuickInvoice('عشرين كولا وثلاثين عصير').items;
    expect(two.map((e) => e.quantity), [20, 30]);
  });
}
