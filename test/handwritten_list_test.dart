import 'package:flutter_test/flutter_test.dart';
import 'package:daftar/models/invoice_item.dart';
import 'package:daftar/utils/handwritten_list.dart';

void main() {
  test('1x61 means 1 carton of 61 dozen, pieces x12', () {
    final q = parseCartonDozen('1×61')!;
    expect(q.cartons, 1);
    expect(q.dozens, 61);
    expect(q.pieces, 732);
    expect(parseCartonDozen('٢ x ١٥')!.pieces, 2 * 15 * 12);
    expect(parseCartonDozen('1*61')!.pieces, 732);
  });
  test('plain number is dozens and marked plain', () {
    final q = parseCartonDozen('61')!;
    expect(q.plain, isTrue);
    expect(q.pieces, 61 * 12);
    expect(parseCartonDozen('بدون رقم'), isNull);
  });
  final cat = {
    'A120': InvoiceItem(itemCode: 'A120', description: 'شنطة ظهر', unitPrice: 15),
    'B300': InvoiceItem(itemCode: 'B300', description: 'حقيبة سفر', unitPrice: 40),
  };
  test('known model fills name and last price', () {
    final r = buildHandwrittenItems([
      {'item_type': 'شنطه', 'item_code': 'A120', 'qty_text': '1×61'}
    ], cat);
    expect(r.single.description, 'شنطة ظهر');
    expect(r.single.unitPrice, 15);
    expect(r.single.quantity, 732);
    expect(r.single.flagged, isFalse);
  });
  test('one-letter model misread is matched but flagged', () {
    final r = buildHandwrittenItems([
      {'item_type': 'x', 'item_code': 'A12O', 'qty_text': '2×3'}
    ], cat);
    expect(r.single.itemCode, 'A120');
    expect(r.single.flagged, isTrue);
    expect(r.single.notes, contains('قريب'));
  });
  test('unknown model keeps read name and is flagged', () {
    final r = buildHandwrittenItems([
      {'item_type': 'اسم', 'item_code': 'Z999', 'qty_text': '1×5'}
    ], cat);
    expect(r.single.description, 'اسم');
    expect(r.single.flagged, isTrue);
  });
  test('ambiguous near matches are not guessed', () {
    final c2 = {
      'A121': InvoiceItem(itemCode: 'A121'),
      'A122': InvoiceItem(itemCode: 'A122'),
    };
    expect(matchModelCode('A120', c2.values), isNull);
  });
}
