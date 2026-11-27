import 'package:flutter_test/flutter_test.dart';
import 'package:daftar/models/invoice_item.dart';
import 'package:daftar/utils/quote_split.dart';

void main() {
  test('partial conversion keeps the rest open', () {
    final items = [
      InvoiceItem(description: 'a', quantity: 10, unitPrice: 2),
      InvoiceItem(description: 'b', quantity: 4, unitPrice: 3),
      InvoiceItem(description: 'c', wholesaleQty: 5, wholesalePrice: 48, packSize: 24),
    ];
    final s = splitQuote(items, {0: 4, 2: 5});
    expect(s.converted.map((e) => e.description), ['a', 'c']);
    expect(s.converted[0].quantity, 4);
    expect(s.remaining.map((e) => e.description), ['a', 'b']);
    expect(s.remaining[0].quantity, 6);
    expect(s.converted[1].wholesaleQty, 5);
  });
  test('over-asking is capped at the line quantity', () {
    final s = splitQuote([InvoiceItem(description: 'a', quantity: 3, unitPrice: 1)], {0: 9});
    expect(s.converted.single.quantity, 3);
    expect(s.remaining, isEmpty);
  });
}
