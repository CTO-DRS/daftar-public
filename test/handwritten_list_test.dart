import 'package:flutter_test/flutter_test.dart';
import 'package:daftar/models/invoice_item.dart';
import 'package:daftar/utils/handwritten_list.dart';
import 'package:daftar/utils/number_utils.dart';

void main() {
  test('count column: number x 1 with unit in parentheses', () {
    final q = parseListQty('56 × 1 (كرتون/باكت)')!;
    expect(q.count, 56);
    expect(q.unit, 'كرتون');
    expect(parseListQty('٥٢ x ١ (ك/كيس)')!.count, 52);
    expect(parseListQty('294 ×')!.count, 294);
    expect(parseListQty('بدون'), isNull);
  });
  test('pack column gives pieces per unit', () {
    expect(parsePackPieces('12 × 6'), 72);
    expect(parsePackPieces('48 × 1'), 48);
    expect(parsePackPieces('؟'), 0);
  });
  final cat = {
    'W-2130': InvoiceItem(itemCode: 'W-2130', description: 'بناجر بناتي أوميغا'),
    'C-64': InvoiceItem(itemCode: 'C-64', description: 'بناجر أبوجر كبير'),
  };
  test('known model fills the name; qty and pack kept', () {
    final r = buildHandwrittenItems([
      {'item_type': 'بناجر بناتي', 'pack_text': '12 × 6', 'item_code': 'W-2130', 'qty_text': '56 × 1 (كرتون/باكت)'}
    ], cat);
    expect(r.single.description, 'بناجر بناتي أوميغا');
    expect(r.single.quantity, 56);
    expect(r.single.unit, 'كرتون');
    expect(r.single.packSize, 72);
    expect(r.single.unitPrice, 0);
    expect(r.single.flagged, isFalse);
    expect(normalizeDigits(r.single.notes).replaceAll(RegExp('[,،٬]'), ''), contains('4032'));
  });
  test('model with hyphen differences still matches exactly', () {
    expect(matchModelCode('W2130', cat.values)!.$2, isFalse);
  });
  test('one-letter model misread is matched but flagged', () {
    final r = buildHandwrittenItems([
      {'item_type': 'x', 'item_code': 'C-46', 'qty_text': '50 × 1 (ك/كيس)', 'pack_text': '24×1'}
    ], cat);
    expect(r.single.itemCode, 'C-46');
    expect(r.single.flagged, isTrue);
  });
  test('unknown model keeps read name and is flagged', () {
    final r = buildHandwrittenItems([
      {'item_type': 'اسم', 'item_code': 'Z-999', 'qty_text': '5 × 1', 'pack_text': ''}
    ], cat);
    expect(r.single.description, 'اسم');
    expect(r.single.flagged, isTrue);
  });
  test('ambiguous near matches are not guessed', () {
    final c2 = {'A121': InvoiceItem(itemCode: 'A121'), 'A122': InvoiceItem(itemCode: 'A122')};
    expect(matchModelCode('A120', c2.values), isNull);
  });
}
