import 'package:flutter_test/flutter_test.dart';
import 'package:daftar/models/invoice.dart';
import 'package:daftar/models/invoice_item.dart';
import 'package:daftar/utils/number_utils.dart';
import 'package:daftar/utils/sort_utils.dart';

void main() {
  digitTests();
  test('Arabic-Indic digits parse', () {
    expect(parseNumber('١٢٣'), 123);
    expect(parseNumber('١٢٫٥'), 12.5);
    expect(parseNumber('1,250.50'), 1250.5);
    expect(parseNumber('12,5'), 12.5);
    expect(parseNumber('abc'), isNull);
    expect(parseNumber(''), isNull);
  });

  test('invoice totals', () {
    final inv = Invoice(number: '1', items: [
      InvoiceItem(quantity: 3, unitPrice: 10),
      InvoiceItem(quantity: 2, unitPrice: 5.5),
    ]);
    expect(inv.itemCount, 2);
    expect(inv.totalQuantity, 5);
    expect(inv.grandTotal, 41);
  });

  test('natural sort and descending', () {
    final items = [
      InvoiceItem(itemCode: 'A10'),
      InvoiceItem(itemCode: 'A2'),
      InvoiceItem(itemCode: 'A1'),
    ];
    sortItems(items, SortField.itemCode, true);
    expect(items.map((e) => e.itemCode), ['A1', 'A2', 'A10']);
    sortItems(items, SortField.itemCode, false);
    expect(items.map((e) => e.itemCode), ['A10', 'A2', 'A1']);
  });
}

void digitTests() {
  test('Arabic-Indic digit display option', () {
    useArabicDigits = true;
    expect(formatMoney(1250.5), '١٬٢٥٠٫٥');
    useArabicDigits = false;
    expect(formatMoney(1250.5), '1,250.5');
  });
}
