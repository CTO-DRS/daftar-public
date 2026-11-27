import 'package:flutter_test/flutter_test.dart';
import 'package:daftar/utils/price_hints.dart';

PricePoint pt(double price, String party, int d, {double cost = 0}) =>
    PricePoint(price, cost, party, DateTime(2026, 1, d));

void main() {
  test('trend over last 3 invoices', () {
    final h = priceHints(description: 'اسمنت', price: 0, cost: 0, party: 'A',
        points: [pt(100, 'A', 1), pt(105, 'B', 2), pt(112, 'C', 3)]);
    expect(h.any((x) => x.text.contains('ارتفع') && x.text.contains('12')), isTrue);
  });
  test('other customers range and below-min warning with median suggestion', () {
    final pts = [pt(100, 'B', 1), pt(110, 'C', 2), pt(105, 'D', 3)];
    final h = priceHints(description: 'x', price: 80, cost: 0, party: 'A', points: pts);
    expect(h.any((x) => x.text.contains('3 عملاء')), isTrue);
    final w = h.firstWhere((x) => x.warn);
    expect(w.suggested, 105);
  });
  test('own previous prices are not counted as other customers', () {
    final h = priceHints(description: 'x', price: 100, cost: 0, party: 'A',
        points: [pt(100, 'A', 1), pt(101, 'A', 2), pt(102, 'B', 3)]);
    expect(h.any((x) => x.text.contains('عملاء آخرين')), isFalse);
  });
  test('margin below usual suggests price', () {
    final pts = [for (var i = 1; i <= 4; i++) pt(100, 'P$i', i, cost: 70)]; // 30%
    final h = priceHints(description: 'x', price: 80, cost: 70, party: 'Z', points: pts);
    final m = h.firstWhere((x) => x.text.contains('الهامش'));
    expect(m.suggested, 100); // 70/0.7
    // لا تحذير إن كان الهامش معتاداً
    final ok = priceHints(description: 'x', price: 100, cost: 70, party: 'Z', points: pts);
    expect(ok.any((x) => x.text.contains('الهامش')), isFalse);
  });
  test('rounding suggestion and empty description', () {
    final h = priceHints(description: 'x', price: 12.37, cost: 0, party: '', points: [pt(12, 'B', 1)]);
    expect(h.single.suggested, 12.5);
    expect(priceHints(description: '', price: 1, cost: 0, party: '', points: []), isEmpty);
  });
}
