import 'package:flutter_test/flutter_test.dart';
import 'package:daftar/utils/forecast.dart';
import 'package:daftar/utils/restock.dart';

void main() {
  test('planning rate blends 30-day and recent 14-day rates', () {
    expect(planningRate(const StockForecast('a', 10, 2, recentPerDay: 4)), 3);
    expect(planningRate(const StockForecast('a', 10, 2)), 2);
  });

  test('quantity covers lead + cover days minus stock, urgent first', () {
    final l = planRestock([
      const StockForecast('بطيء', 20, 1),
      const StockForecast('عاجل', 5, 2),
      const StockForecast('كافٍ', 1000, 1),
    ]);
    expect(l.map((e) => e.name), ['عاجل', 'بطيء']);
    expect(l.first.qty, 2 * 37 - 5);
    expect(l.first.urgency, RestockUrgency.now);
    expect(l.last.qty, 17);
    expect(l.last.urgency, RestockUrgency.later);
  });

  test('rounds up to whole cartons when pack size is known', () {
    final l = planRestock([const StockForecast('كرتون', 0, 1, packSize: 12)], leadDays: 7, coverDays: 30);
    expect(l.single.packs, 4); // 37 قطعة → 4 كراتين
    expect(l.single.qty, 48);
  });

  test('negative stock counts as zero and rising demand is flagged', () {
    final l = planRestock([const StockForecast('x', -5, 1, recentPerDay: 2)]);
    expect(l.single.onHand, 0);
    expect(l.single.rising, isTrue);
  });

  test('share text lists urgent marker and carton breakdown', () {
    final l = planRestock([const StockForecast('كرتون', 0, 1, packSize: 12)]);
    final t = restockText(l, DateTime(2026, 11, 28), company: 'شركتي');
    expect(t, contains('شركتي'));
    expect(t, contains('عاجل'));
    expect(t, contains('كرتون'));
  });
}
