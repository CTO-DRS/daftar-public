import 'dart:io';

import 'package:daftar/models/invoice.dart';
import 'package:daftar/models/invoice_item.dart';
import 'package:daftar/services/pdf_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('item totals include wholesale', () {
    final it = InvoiceItem(quantity: 2, unitPrice: 10, wholesaleQty: 3, wholesalePrice: 100, wholesaleUnit: 'كرتون');
    expect(it.total, 320);
    expect(it.hasWholesale, true);
    expect(InvoiceItem(quantity: 1, unitPrice: 5).total, 5);
    expect(InvoiceItem(wholesaleQty: 1, wholesalePrice: 9).isEmpty, false);
    final c = it.copy();
    expect(c.wholesaleUnit, 'كرتون');
    expect(InvoiceItem.fromMap(it.toMap(1)).wholesalePrice, 100);
  });

  test('invoice PDF with unit and wholesale columns, all templates', () async {
    List<int> f(String n) => File('assets/fonts/$n.ttf').readAsBytesSync();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler('flutter/assets', (m) async {
      final key = const StringCodec().decodeMessage(m)!;
      return ByteData.sublistView(Uint8List.fromList(f(key.split('/').last.replaceAll('.ttf', ''))));
    });
    final inv = Invoice(number: '1050', party: 'مؤسسة النور', date: DateTime(2026, 11, 26), vatRate: 15, status: InvoiceStatus.confirmed, items: [
      InvoiceItem(itemCode: 'A1', refNumber: 'R-9', description: 'مفتاح كهربائي مزدوج', quantity: 12, unitPrice: 12.5, unit: 'حبة', wholesaleQty: 5, wholesalePrice: 120, wholesaleUnit: 'درزن', notes: 'عاجل'),
      InvoiceItem(itemCode: 'B2', description: 'كيبل نحاس 2.5 مم', quantity: 30, unitPrice: 8, unit: 'متر'),
      InvoiceItem(description: 'لمبة LED 12 واط', wholesaleQty: 2, wholesalePrice: 340, wholesaleUnit: 'كرتون'),
    ]);
    final out = Platform.environment['SHOT_DIR'];
    for (final t in PdfTemplate.values) {
      final bytes = await PdfService.build(inv, template: t);
      expect(String.fromCharCodes(bytes.sublist(0, 4)), '%PDF');
      if (out != null) File('$out/inv_${t.name}.pdf').writeAsBytesSync(bytes);
    }
    // بدون جملة: لا أعمدة جملة.
    final plain = await PdfService.build(Invoice(number: '1', items: [InvoiceItem(description: 'x', quantity: 1, unitPrice: 1)]));
    expect(plain.isNotEmpty, true);
  });
}
