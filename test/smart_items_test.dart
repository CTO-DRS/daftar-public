import 'package:flutter_test/flutter_test.dart';
import 'package:daftar/models/invoice_item.dart';
import 'package:daftar/utils/smart_items.dart';

ItemStat st(String d, double p, int c, {String unit = ''}) =>
    ItemStat(InvoiceItem(description: d, unitPrice: p, unit: unit), c);

void main() {
  final stats = [
    st('كولا صغير', 1.5, 3),
    st('كولا كبير', 4, 9),
    st('عصير كولا', 2, 20),
    st('ماء', 1, 50),
  ];
  test('prefix first, then contains, by frequency', () {
    final r = suggestItems('كولا', stats).map((e) => e.last.description).toList();
    expect(r, ['كولا كبير', 'كولا صغير', 'عصير كولا']);
  });
  test('too short or exact gives nothing', () {
    expect(suggestItems('ك', stats), isEmpty);
    expect(suggestItems('ماء', stats), isEmpty);
  });
  test('arabic normalisation (hamza, taa marbuta)', () {
    final s = [st('أنبوبة غاز', 10, 1), st('علبة', 2, 1)];
    expect(suggestItems('انبوبه', s).length, 1);
    expect(suggestItems('علبه', s), isEmpty); // exact after normalising
  });
  test('multi-word match any order', () {
    expect(suggestItems('صغير كولا', stats).length, 1);
  });
  test('applySuggestion fills blanks only and prefers customer price', () {
    final from = InvoiceItem(
        description: 'كولا كبير', unitPrice: 4, unit: 'حبة', costPrice: 3, itemCode: 'C1');
    final t = InvoiceItem(unit: 'كرتون');
    final special = applySuggestion(t, from, customerPrice: 3.5);
    expect(t.unitPrice, 3.5);
    expect(special, isTrue);
    expect(t.unit, 'كرتون');
    expect(t.costPrice, 3);
    final t2 = InvoiceItem(unitPrice: 9);
    expect(applySuggestion(t2, from, customerPrice: 3.5), isFalse);
    expect(t2.unitPrice, 9);
  });
}
