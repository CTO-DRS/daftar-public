import 'package:daftar/models/invoice_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unit survives copy and map round trip', () {
    final it = InvoiceItem(description: 'x', quantity: 2, unitPrice: 5, unit: 'كرتون');
    expect(it.copy().unit, 'كرتون');
    expect(InvoiceItem.fromMap(it.toMap(0)).unit, 'كرتون');
    expect(InvoiceItem.fromMap({}).unit, '');
  });
}
