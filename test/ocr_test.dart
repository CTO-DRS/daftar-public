import 'package:daftar/models/ocr_result.dart';
import 'package:daftar/services/ocr_service.dart';
import 'package:daftar/utils/ocr_parsing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses fenced JSON with Arabic-Indic digits and flags bad rows', () {
    const raw = '''```json
{"invoice_number":"٤٥","date":"2026-11-20","party":"مؤسسة الأمل","grand_total":330,
 "items":[
  {"item_code":"A1","ref_number":"٧","item_type":"مفتاح","quantity":"١٥","unit_price":"١٢٫٥","line_total":187.5},
  {"item_code":"A2","ref_number":"8","item_type":"قاطع","quantity":10,"unit_price":14,"line_total":150},
  {"item_code":"A3","ref_number":null,"item_type":"سلك","quantity":null,"unit_price":5,"unclear":true}
 ]}
```''';
    final r = OcrService.parseOnlineResponse(raw, OcrSource.gemini);
    verifyItems(r.items);
    expect(r.invoiceNumber, '45');
    expect(r.items.length, 3);
    expect(r.items[0].quantity, 15);
    expect(r.items[0].unitPrice, 12.5);
    expect(r.items[0].flagged, false);
    expect(r.items[1].flagged, true); // 10*14=140 != 150
    expect(r.items[2].flagged, true); // quantity unreadable
    expect(r.date, DateTime(2026, 11, 20));
  });

  test('offline line parser finds qty/price/total', () {
    final items = parseOfflineLines([
      'A12 345 Switch double 5 20 100',
      'garbage line',
      'B7 Cable 3 9',
    ]);
    expect(items.length, 2);
    expect(items[0].itemCode, 'A12');
    expect(items[0].refNumber, '345');
    expect(items[0].quantity, 5);
    expect(items[0].unitPrice, 20);
    expect(items[0].flagged, false);
    expect(items[1].quantity, 3);
    expect(items[1].flagged, true);
  });

  test('no json throws FormatException', () {
    expect(() => extractJsonObject('sorry'), throwsFormatException);
  });
}
