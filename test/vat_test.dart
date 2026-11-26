import 'dart:convert';

import 'package:daftar/models/invoice.dart';
import 'package:daftar/models/invoice_item.dart';
import 'package:daftar/utils/zatca.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ZATCA phase-1 TLV matches the published sample', () {
    final qr = zatcaPhase1Qr(
      sellerName: 'Bobs Records',
      vatNumber: '310122393500003',
      timestamp: DateTime.utc(2022, 4, 25, 15, 30),
      totalWithVat: 1000,
      vatAmount: 150,
    );
    expect(qr,
        'AQxCb2JzIFJlY29yZHMCDzMxMDEyMjM5MzUwMDAwMwMUMjAyMi0wNC0yNVQxNTozMDowMFoEBzEwMDAuMDAFBjE1MC4wMA==');
  });

  test('TLV decodes back, Arabic seller name uses UTF-8 byte length', () {
    final qr = zatcaPhase1Qr(
      sellerName: 'شركة دفتر',
      vatNumber: '300000000000003',
      timestamp: DateTime.utc(2026, 11, 26, 10),
      totalWithVat: 115,
      vatAmount: 15,
    );
    final b = base64.decode(qr);
    expect(b[0], 1);
    expect(b[1], utf8.encode('شركة دفتر').length);
    expect(utf8.decode(b.sublist(2, 2 + b[1])), 'شركة دفتر');
  });

  test('VAT validation', () {
    expect(isValidSaudiVat('310122393500003'), isTrue);
    expect(isValidSaudiVat('123'), isFalse);
    expect(isValidSaudiVat('410122393500003'), isFalse);
  });

  test('invoice totals with 15% VAT', () {
    final inv = Invoice(number: '1', vatRate: 15, items: [
      InvoiceItem(quantity: 3, unitPrice: 33.33),
    ]);
    expect(inv.subtotal, closeTo(99.99, 1e-9));
    expect(inv.vatAmount, 15.0); // 14.9985 -> 15.00
    expect(inv.grandTotal, closeTo(114.99, 1e-9));
    expect(Invoice(number: '2', items: [InvoiceItem(quantity: 1, unitPrice: 10)]).grandTotal, 10);
    expect(Invoice.fromMap(inv.toMap()).vatRate, 15);
  });
}
