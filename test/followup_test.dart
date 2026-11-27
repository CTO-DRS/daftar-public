import 'package:flutter_test/flutter_test.dart';
import 'package:daftar/models/invoice.dart';
import 'package:daftar/utils/followup.dart';

InvoiceSummary mk(String n, DateTime due, {double paid = 0}) => InvoiceSummary(
    Invoice(number: n, status: InvoiceStatus.confirmed, dueDate: due, paidAmount: paid),
    1, 1, 100);

void main() {
  test('overdue unpaid invoices need follow-up, cooldown respected', () {
    final now = DateTime(2026, 11, 27, 12);
    final all = [
      mk('A', DateTime(2026, 11, 1)),
      mk('B', DateTime(2026, 11, 20)),
      mk('C', DateTime(2026, 12, 5)), // not due
      mk('D', DateTime(2026, 11, 1), paid: 100), // paid
    ];
    final r = dueForFollowUp(all, now, {
      'B': now.subtract(const Duration(days: 1)).millisecondsSinceEpoch,
    });
    expect(r.map((e) => e.invoice.number), ['A']);
    final r2 = dueForFollowUp(all, now, {
      'B': now.subtract(const Duration(days: 4)).millisecondsSinceEpoch,
    });
    expect(r2.map((e) => e.invoice.number), ['A', 'B']);
  });
}
