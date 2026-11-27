import 'package:flutter_test/flutter_test.dart';
import 'package:daftar/utils/forecast.dart';

void main() {
  test('forecast from last count and later sales', () {
    final now = DateTime(2026, 11, 27);
    final counts = [
      CountRow('كولا', 'كولا', 50, DateTime(2026, 11, 1)),
      CountRow('كولا', 'كولا', 100, DateTime(2026, 11, 17)), // latest
    ];
    final sales = [
      SaleRow('كولا', 5, DateTime(2026, 11, 10)), // before count: not deducted
      SaleRow('كولا', 30, DateTime(2026, 11, 20)),
    ];
    final f = computeStockForecast(counts, sales, now).single;
    expect(f.onHand, 70);
    // 35 sold in last 30 days, count is 10 days old -> window 10 -> 3.5/day
    expect(f.perDay, closeTo(3.5, 0.001));
    expect(f.daysLeft, closeTo(20, 0.001));
    expect(f.suggestedOrder(), 35);
  });
  test('items without recent sales are skipped', () {
    final out = computeStockForecast(
        [CountRow('x', 'x', 5, DateTime(2026, 1, 1))], [], DateTime(2026, 11, 27));
    expect(out, isEmpty);
  });
}
