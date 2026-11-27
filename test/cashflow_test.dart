import 'package:flutter_test/flutter_test.dart';
import 'package:daftar/models/invoice.dart';
import 'package:daftar/utils/cashflow.dart';

InvoiceSummary mk(DocKind k, double total, DateTime date,
    {DateTime? due, InvoiceStatus st = InvoiceStatus.confirmed, String party = 'أحمد', DateTime? upd}) {
  final i = Invoice(
    number: 'N${date.microsecondsSinceEpoch % 9973}$total',
    kind: k,
    party: party,
    date: date,
    dueDate: due,
    status: st,
    updatedAt: upd ?? date,
  );
  return InvoiceSummary(i, 1, 1, total);
}

void main() {
  final now = DateTime(2026, 11, 28);
  test('future due invoice lands on its due day', () {
    final o = buildCashOutlook([mk(DocKind.invoice, 1000, now, due: DateTime(2026, 12, 5))], now);
    expect(o.days[7].inflow, 1000);
    expect(o.expectedIn, 1000);
  });
  test('customer who pays late shifts the expected day', () {
    final hist = [
      for (var k = 0; k < 3; k++)
        mk(DocKind.invoice, 100, DateTime(2026, 6, 1 + k),
            due: DateTime(2026, 6, 10 + k), st: InvoiceStatus.paid, upd: DateTime(2026, 6, 15 + k)),
    ];
    final o = buildCashOutlook([...hist, mk(DocKind.invoice, 500, now, due: DateTime(2026, 12, 5))], now);
    expect(o.days[12].inflow, 500); // +5 أيام تأخر معتاد
  });
  test('overdue is discounted and expected soon', () {
    final o = buildCashOutlook([mk(DocKind.invoice, 1000, DateTime(2026, 9, 1), due: DateTime(2026, 10, 1))], now);
    expect(o.expectedIn, 250); // متأخر 58 يوماً: 25%
    expect(o.expectedIn, lessThan(1000));
  });
  test('expenses run-rate creates a shortfall and a lowest day', () {
    final o = buildCashOutlook([mk(DocKind.expense, 6000, DateTime(2026, 11, 1))], now);
    expect(o.expectedOut, closeTo(3000, 0.01));
    expect(o.lowest, isNotNull);
    expect(o.lowest!.cumulative, closeTo(-3000, 0.01));
  });
  test('undated invoices are reported not counted', () {
    final o = buildCashOutlook([mk(DocKind.invoice, 700, now)], now);
    expect(o.notDated, 700);
    expect(o.isEmpty, isTrue);
  });
}
