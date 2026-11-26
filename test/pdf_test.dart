import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:daftar/services/logo_service.dart';
import 'dart:io';

import 'package:daftar/models/invoice.dart';
import 'package:daftar/models/invoice_item.dart';
import 'package:daftar/services/pdf_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('PDF with Arabic content is generated', () async {
    final inv = Invoice(vatRate: 15,
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
    final logoImg = img.Image(width: 600, height: 300);
    img.fill(logoImg, color: img.ColorRgb8(15, 118, 110));
    final logo = LogoService.normalize(Uint8List.fromList(img.encodePng(logoImg)));
    expect(img.decodePng(logo)!.width, 400);
    final bytes = await PdfService.build(inv, company: 'شركة دفتر', logo: logo, partyPhone: '0551234567', partyAddress: 'المدينة المنورة', sellerVat: '310122393500003');
    expect(bytes.length, greaterThan(5000));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    final out = Platform.environment['PDF_OUT'];
    if (out != null) File(out).writeAsBytesSync(bytes);
  });
}
