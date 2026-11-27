import 'package:flutter_test/flutter_test.dart';
import 'package:daftar/models/invoice.dart';
import 'package:daftar/utils/collection.dart';

InvoiceSummary inv(String no, String party, DateTime date,
    {DateTime? due, double total = 100, double paid = 0, InvoiceStatus st = InvoiceStatus.confirmed, DateTime? upd}) {
  final i = Invoice(number: no, party: party, date: date, dueDate: due, paidAmount: paid, status: st, updatedAt: upd);
  return InvoiceSummary(i, 1, 1, total);
}

void main() {
  final now = DateTime(2026, 11, 28);
  test('groups by customer and ranks riskier first', () {
    final all = [
      inv('1', 'A', DateTime(2026, 11, 1), due: DateTime(2026, 11, 25), total: 100),
      inv('2', 'B', DateTime(2026, 8, 1), due: DateTime(2026, 9, 1), total: 100),
      inv('3', 'B', DateTime(2026, 8, 5), due: DateTime(2026, 9, 5), total: 50, paid: 20),
    ];
    final r = buildCollection(all, now, {});
    expect(r.map((e) => e.party), ['B', 'A']);
    expect(r[0].invoices.length, 2);
    expect(r[0].total, 130);
    expect(r[0].tone, CollectionTone.firm);
    expect(r[1].tone, CollectionTone.gentle);
    expect(r[1].maxLateDays, 3);
  });
  test('history raises risk and finds best weekday', () {
    final hist = [
      for (var k = 0; k < 4; k++)
        inv('h$k', 'C', DateTime(2026, 5, 1 + k * 7),
            due: DateTime(2026, 5, 8 + k * 7), st: InvoiceStatus.paid, upd: DateTime(2026, 5, 20 + k * 7)),
    ];
    final cur = inv('9', 'C', DateTime(2026, 11, 1), due: DateTime(2026, 11, 20));
    final plain = buildCollection([cur], now, {}).first.risk;
    final withHist = buildCollection([...hist, cur], now, {}).first;
    expect(withHist.risk, greaterThan(plain - 9));
    expect(withHist.usualDaysToPay, isNotNull);
    expect(withHist.bestWeekday, DateTime(2026, 5, 20).weekday);
  });
  test('cooldown hides reminded invoices; notes and unpaid-not-due skipped', () {
    final all = [
      inv('1', 'A', DateTime(2026, 11, 1), due: DateTime(2026, 11, 20)),
      inv('2', 'Z', DateTime(2026, 11, 1), due: DateTime(2026, 12, 20)),
    ];
    final ms = now.subtract(const Duration(days: 1)).millisecondsSinceEpoch;
    expect(buildCollection(all, now, {'1': ms}), isEmpty);
    expect(buildCollection(all, now, {}).length, 1);
  });
  test('message tone and content', () {
    final all = [inv('7', 'سالم', DateTime(2026, 8, 1), due: DateTime(2026, 9, 1), total: 500)];
    final c = buildCollection(all, now, {}).first;
    final t = collectionText(c, company: 'شركتي', currency: 'ر.س');
    expect(t, contains('سالم'));
    expect(t, contains('خلال يومين'));
    expect(t, contains('شركتي'));
    final g = buildCollection([inv('8', 'X', DateTime(2026, 11, 20), due: DateTime(2026, 11, 25))], now, {}).first;
    expect(collectionText(g), contains('ودّي'));
  });
}
