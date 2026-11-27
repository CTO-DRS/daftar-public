import 'package:flutter_test/flutter_test.dart';
import 'package:daftar/models/invoice.dart';
import 'package:daftar/models/invoice_item.dart';
import 'package:daftar/services/share_service.dart';

void main() {
  test('share snapshot has no cost or internal fields and splits wholesale', () {
    final inv = Invoice(number: 'A-1', party: 'x', vatRate: 15, items: [
      InvoiceItem(description: 'كولا', quantity: 2, unitPrice: 3, costPrice: 1, wholesaleQty: 1, wholesalePrice: 30, wholesaleUnit: 'كرتون'),
    ]);
    final s = shareSnapshot(inv, company: 'متجر', currency: 'ر.س');
    expect(s.toString().contains('cost'), isFalse);
    final items = s['items'] as List;
    expect(items.length, 2);
    expect((items[1] as Map)['t'], 30);
    expect(s['total'], inv.grandTotal);
    expect(s['currency'], 'ر.س');
  });
}
