import 'package:daftar/models/invoice.dart';
import 'package:daftar/models/invoice_item.dart';
import 'package:daftar/utils/insights.dart';
import 'package:flutter_test/flutter_test.dart';

InvoiceSummary mk(String party, double total, DateTime date,
    {DateTime? due, double paid = 0, InvoiceStatus st = InvoiceStatus.confirmed, String note = '', String no = '1'}) {
  final inv = Invoice(
      number: no, date: date, party: party, dueDate: due, paidAmount: paid, status: st, noteType: note,
      items: [InvoiceItem(description: 'x', quantity: 1, unitPrice: total)]);
  return InvoiceSummary(inv, 1, 1, inv.grandTotal);
}

void main() {
  final now = DateTime(2026, 11, 26);
  test('aging buckets and forecast', () {
    final r = computeInsights([
      mk('أ', 100, DateTime(2026, 11, 1), due: DateTime(2026, 11, 20), no: 'a'), // 6 days late
      mk('أ', 200, DateTime(2026, 8, 1), due: DateTime(2026, 8, 20), no: 'b'), // >90
      mk('ب', 300, DateTime(2026, 11, 1), due: DateTime(2026, 12, 1), no: 'c'), // in 5 days
      mk('ب', 400, DateTime(2026, 11, 1), due: DateTime(2026, 12, 20), no: 'd'), // 24 days
      mk('ج', 999, DateTime(2026, 11, 1), st: InvoiceStatus.draft, no: 'e'), // draft ignored
      mk('ج', 50, DateTime(2026, 11, 2), st: InvoiceStatus.paid, no: 'f'),
    ], now, currency: 'ر.س');
    expect(r.aging.d30, 100);
    expect(r.aging.d90plus, 200);
    expect(r.aging.notDue, 700);
    expect(r.forecast.next7, 300);
    expect(r.forecast.next30, 400);
    expect(r.forecast.overdue, 300);
    expect(r.customers.first.name, 'ب');
    final a = r.customers.firstWhere((c) => c.name == 'أ');
    expect(a.risk, Risk.high);
    expect(a.maxDaysLate > 90, true);
    expect(r.alerts.any((x) => x.level == InsightLevel.risk), true);
  });
  test('credit notes reduce sales and trend', () {
    final r = computeInsights([
      mk('أ', 1000, DateTime(2026, 10, 5), st: InvoiceStatus.paid, no: 'a'),
      mk('أ', 1500, DateTime(2026, 11, 5), st: InvoiceStatus.paid, no: 'b'),
      mk('أ', 100, DateTime(2026, 11, 6), st: InvoiceStatus.confirmed, note: 'credit', no: 'c'),
    ], now);
    expect(r.thisMonth, 1400);
    expect(r.lastMonth, 1000);
    expect(r.trendPct, closeTo(40, 0.01));
    expect(r.alerts.any((x) => x.level == InsightLevel.good), true);
  });
  test('empty', () => expect(computeInsights([], now).isEmpty, true));
}
