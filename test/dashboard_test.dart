import 'package:daftar/models/invoice.dart';
import 'package:daftar/utils/dashboard.dart';
import 'package:flutter_test/flutter_test.dart';

InvoiceSummary s(Invoice i, double total) => InvoiceSummary(i, 1, 1, total);

void main() {
  test('dashboard totals', () {
    final now = DateTime(2026, 11, 26);
    final list = [
      s(Invoice(number: '1', status: InvoiceStatus.confirmed, date: DateTime(2026, 11, 3), dueDate: DateTime(2026, 11, 10), paidAmount: 100), 500),
      s(Invoice(number: '2', status: InvoiceStatus.paid, date: DateTime(2026, 10, 5)), 300),
      s(Invoice(number: '3', status: InvoiceStatus.draft, date: DateTime(2026, 11, 5)), 999),
      s(Invoice(number: 'CN-1', status: InvoiceStatus.confirmed, noteType: 'credit', date: DateTime(2026, 11, 6)), 50),
      s(Invoice(number: '4', status: InvoiceStatus.confirmed, currency: 'USD', date: DateTime(2026, 11, 6)), 70),
      s(Invoice(number: '5', status: InvoiceStatus.confirmed, date: DateTime(2025, 1, 6)), 70),
    ];
    final d = computeDashboard(list, now, currency: 'ر.س');
    expect(d.monthSales, 450);
    expect(d.monthly[4], 300);
    expect(d.outstanding, 400 + 70);
    expect(d.overdueCount, 1);
    expect(d.months.first, DateTime(2026, 6, 1));
  });
}
