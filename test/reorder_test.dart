import 'package:flutter_test/flutter_test.dart';
import 'package:daftar/models/invoice.dart';
import 'package:daftar/utils/reorder.dart';

InvoiceSummary s(String party, DateTime d,
        {InvoiceStatus st = InvoiceStatus.confirmed, DocKind k = DocKind.invoice}) =>
    InvoiceSummary(Invoice(number: 'n', party: party, date: d, status: st, kind: k), 1, 1, 10);

void main() {
  final now = DateTime(2026, 6, 30);
  List<InvoiceSummary> every(String p, int gap, int n, {int lastAgo = 0}) => [
        for (var k = 0; k < n; k++)
          s(p, now.subtract(Duration(days: lastAgo + gap * k)))
      ];
  test('regular 20-day customer is due after ~18 days', () {
    final r = reorderDue(every('أحمد', 20, 4, lastAgo: 19), now);
    expect(r.single.party, 'أحمد');
    expect(r.single.intervalDays, 20);
    expect(r.single.daysSince, 19);
  });
  test('not yet due, gone cold, too few orders, drafts, irregular', () {
    expect(reorderDue(every('أ', 20, 4, lastAgo: 5), now), isEmpty);
    expect(reorderDue(every('أ', 20, 4, lastAgo: 70), now), isEmpty);
    expect(reorderDue(every('أ', 20, 2, lastAgo: 19), now), isEmpty);
    expect(
        reorderDue([for (var k = 0; k < 4; k++) s('أ', now.subtract(Duration(days: 19 + 20 * k)), st: InvoiceStatus.draft)], now),
        isEmpty);
    final irregular = [for (final g in [19, 21, 60, 120]) s('أ', now.subtract(Duration(days: g)))];
    expect(reorderDue(irregular, now), isEmpty);
  });
  test('quotes ignored, snooze hides for 7 days', () {
    expect(reorderDue([for (var k = 0; k < 4; k++) s('أ', now.subtract(Duration(days: 19 + 20 * k)), k: DocKind.quote)], now), isEmpty);
    final list = every('أحمد', 20, 4, lastAgo: 19);
    final sn = {'أحمد': now.subtract(const Duration(days: 2)).millisecondsSinceEpoch};
    expect(reorderDue(list, now, snoozed: sn), isEmpty);
    final old = {'أحمد': now.subtract(const Duration(days: 8)).millisecondsSinceEpoch};
    expect(reorderDue(list, now, snoozed: old), hasLength(1));
  });
}
