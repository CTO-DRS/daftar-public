import 'package:flutter_test/flutter_test.dart';
import 'package:daftar/models/invoice.dart';
import 'package:daftar/utils/nl_query.dart';

InvoiceSummary inv(String no, String party, DateTime date,
    {DateTime? due, double total = 100, double paid = 0, InvoiceStatus st = InvoiceStatus.confirmed, DocKind kind = DocKind.invoice}) {
  final i = Invoice(number: no, party: party, date: date, dueDate: due, paidAmount: paid, status: st, kind: kind);
  return InvoiceSummary(i, 1, 1, total);
}

void main() {
  final now = DateTime(2026, 11, 28); // السبت
  const parties = ['أحمد العتيبي', 'سالم', 'محمد'];
  const items = ['أسمنت', 'بنابر بناتي'];
  final all = [
    inv('1', 'أحمد العتيبي', DateTime(2026, 11, 3), total: 200),
    inv('2', 'أحمد العتيبي', DateTime(2026, 11, 10), total: 300, paid: 300, st: InvoiceStatus.paid),
    inv('3', 'أحمد العتيبي', DateTime(2026, 10, 10), total: 50),
    inv('4', 'سالم', DateTime(2026, 11, 5), total: 80, due: DateTime(2026, 11, 10)),
    inv('5', 'محمد', DateTime(2026, 11, 6), total: 100, paid: 40),
    inv('6', 'محمد', DateTime(2026, 11, 8), total: 100),
  ];

  test('period parsing', () {
    expect(parsePeriod('هذا الشهر', now)!.from, DateTime(2026, 11, 1));
    expect(parsePeriod('الشهر الماضي', now)!.from, DateTime(2026, 10, 1));
    expect(parsePeriod('اليوم', now)!.to, DateTime(2026, 11, 29));
    // الأسبوع يبدأ السبت: 28 نوفمبر 2026 سبت.
    expect(parsePeriod('هذا الاسبوع', now)!.from, DateTime(2026, 11, 28));
    expect(parsePeriod('بدون فترة', now), isNull);
  });

  test('unpaid invoices of a customer this month', () {
    final q = parseNl('فواتير أحمد غير المدفوعة هذا الشهر', now, parties: parties, items: items);
    expect(q.intent, NlIntent.invoices);
    expect(q.party, 'أحمد العتيبي');
    expect(q.status, 'unpaid');
    final a = answerNl(q, all, [], now);
    expect(a.invoices.map((e) => e.invoice.number), ['1']);
    expect(a.headline, contains('أحمد'));
  });

  test('overdue only', () {
    final q = parseNl('الفواتير المتأخرة', now, parties: parties);
    final a = answerNl(q, all, [], now);
    expect(a.invoices.map((e) => e.invoice.number), ['4']);
  });

  test('item sales with Arabic prefix and period', () {
    final sold = [
      SoldRow('أسمنت', 10, 100, DateTime(2026, 11, 3), 'أحمد'),
      SoldRow('أسمنت', 5, 60, DateTime(2026, 10, 3), 'سالم'),
      SoldRow('بنابر بناتي', 1, 9, DateTime(2026, 11, 3), 'x'),
    ];
    final q = parseNl('كم بعت من الأسمنت هذا الشهر؟', now, parties: parties, items: items);
    expect(q.intent, NlIntent.itemSales);
    final a = answerNl(q, [], sold, now);
    expect(a.headline, contains('10'));
    final all2 = answerNl(parseNl('كم بعت من الاسمنت', now, items: items), [], sold, now);
    expect(all2.headline, contains('15'));
  });

  test('balance of a customer', () {
    final q = parseNl('كم على محمد؟', now, parties: parties);
    expect(q.intent, NlIntent.balance);
    final a = answerNl(q, all, [], now);
    expect(a.headline, contains('160'));
    expect(a.invoices.length, 2);
  });

  test('payment command allocates oldest first and flags excess', () {
    final q = parseNl('أضف دفعة 80 لمحمد', now, parties: parties);
    expect(q.intent, NlIntent.addPayment);
    expect(q.amount, 80);
    final a = answerNl(q, all, [], now);
    expect(a.payment.map((p) => p.invoice.invoice.number), ['5', '6']);
    expect(a.payment[0].apply, 60);
    expect(a.payment[1].apply, 20);
    final big = answerNl(parseNl('اضف دفعة ٥٠٠ لمحمد', now, parties: parties), all, [], now);
    expect(big.leftover, 340);
  });

  test('payment without a known customer or amount is not a command', () {
    expect(parseNl('أضف دفعة 500 لفلان', now, parties: parties).intent, isNot(NlIntent.addPayment));
    expect(parseNl('أضف دفعة لمحمد', now, parties: parties).intent, isNot(NlIntent.addPayment));
  });

  test('unknown gives examples', () {
    final a = answerNl(parseNl('كيف الطقس', now), [], [], now);
    expect(a.lines, isNotEmpty);
  });
}
