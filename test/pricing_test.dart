import 'package:daftar/models/invoice.dart';
import 'package:daftar/models/invoice_item.dart';
import 'package:daftar/utils/pricing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tier price picks the highest threshold reached', () {
    const t = [PriceTier(10, 9), PriceTier(50, 8), PriceTier(100, 7)];
    expect(tierPrice(t, 5), null);
    expect(tierPrice(t, 10), 9);
    expect(tierPrice(t, 49), 9);
    expect(tierPrice(t, 50), 8);
    expect(tierPrice(t, 500), 7);
    expect(tierPrice(const [], 5), null);
  });
  test('tier key prefers code then description', () {
    expect(tierKey(' A1 ', 'x'), 'c:a1');
    expect(tierKey('', ' كولا '), 'd:كولا');
  });
  test('pack size converts wholesale to pieces', () {
    final it = InvoiceItem(quantity: 6, unitPrice: 2, wholesaleQty: 3, wholesalePrice: 40, wholesaleUnit: 'كرتون', packSize: 24);
    expect(it.pieces, 6 + 72);
    expect(it.total, 12 + 120);
    final noPack = InvoiceItem(quantity: 6, wholesaleQty: 3, wholesalePrice: 40);
    expect(noPack.pieces, 6);
    final inv = Invoice(number: '1', items: [it, noPack]);
    expect(inv.totalQuantity, 78 + 6);
    expect(InvoiceItem.fromMap(it.toMap(1)).packSize, 24);
  });
}
