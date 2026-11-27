import 'package:flutter_test/flutter_test.dart';
import 'package:daftar/models/invoice.dart';
import 'package:daftar/utils/digest.dart';
import 'package:daftar/utils/nl_query.dart';

InvoiceSummary inv(String no, String party, DateTime date,
    {double total = 100, InvoiceStatus st = InvoiceStatus.confirmed, DateTime? due, String note = ''}) {
  return InvoiceSummary(
      Invoice(number: no, party: party, date: date, status: st, dueDate: due, noteType: note), 1, 1, total);
}

void main() {
  final now = DateTime(2026, 11, 28);
  DateTime ago(int d) => now.subtract(Duration(days: d));

  test('week vs previous week, notes and drafts', () {
    final all = [
      inv('1', 'A', ago(1), total: 300),
      inv('2', 'B', ago(3), total: 100),
      inv('3', 'A', ago(2), total: 50, note: 'credit'),
      inv('4', 'A', ago(2), total: 999, st: InvoiceStatus.draft),
      inv('5', 'C', ago(9), total: 200),
    ];
    final d = buildDigest(all, [], now);
    expect(d.sales, 350);
    expect(d.prevSales, 200);
    expect(d.changePct, 75);
    expect(d.invoiceCount, 2);
    expect(d.headline, contains('أعلى'));
  });

  test('no previous week gives no percentage', () {
    final d = buildDigest([inv('1', 'A', ago(1))], [], now);
    expect(d.changePct, isNull);
    expect(d.headline, isNot(contains('%')));
  });

  test('top item and stopped item', () {
    final sold = [
      SoldRow('رز', 10, 100, ago(2), 'A'),
      SoldRow('سكر', 3, 30, ago(1), 'A'),
      for (final k in [9, 16, 23]) SoldRow('شاي', 2, 20, ago(k), 'A'),
    ];
    final d = buildDigest([], sold, now);
    expect(d.topItem, 'رز');
    expect(d.slowItem, 'شاي');
  });

  test('drifting customer: regular 10-day orders, silent for 20 days', () {
    final all = [for (final k in [60, 50, 40, 30, 20]) inv('d$k', 'سالم', ago(k))];
    final d = buildDigest(all, [], now);
    expect(d.drifting.single.party, 'سالم');
    expect(d.drifting.single.usualGap, 10);
    // عميل منتظم ولم يتأخر
    final ok = buildDigest([for (final k in [30, 20, 10, 2]) inv('o$k', 'علي', ago(k))], [], now);
    expect(ok.drifting, isEmpty);
  });

  test('overdue count and empty digest', () {
    final d = buildDigest([inv('1', 'A', ago(40), due: ago(20))], [], now);
    expect(d.overdueCount, 1);
    expect(d.lines.any((l) => l.contains('متأخرات')), isTrue);
    expect(buildDigest([], [], now).isEmpty, isTrue);
  });
}
