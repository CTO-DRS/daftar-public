import 'dart:io';

import 'package:daftar/models/invoice.dart';
import 'package:daftar/models/invoice_item.dart';
import 'package:daftar/services/pdf_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('PDF with Arabic content is generated', () async {
    final inv = Invoice(
      number: '15',
      party: 'مؤسسة النور للتجارة',
      notes: 'تسليم خلال أسبوع',
      items: List.generate(
        40,
        (i) => InvoiceItem(
          itemCode: 'A${i + 1}',
          refNumber: '${100 + i}',
          description: 'مفتاح كهربائي مزدوج',
          quantity: 3.0 + i,
          unitPrice: 12.5,
          notes: i % 5 == 0 ? 'عاجل' : '',
        ),
      ),
    );
    final bytes = await PdfService.build(inv, company: 'شركة دفتر');
    expect(bytes.length, greaterThan(5000));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    final out = Platform.environment['PDF_OUT'];
    if (out != null) File(out).writeAsBytesSync(bytes);
  });
}
