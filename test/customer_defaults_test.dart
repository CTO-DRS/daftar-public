import 'package:flutter_test/flutter_test.dart';
import 'package:daftar/models/invoice.dart';
import 'package:daftar/utils/customer_defaults.dart';

Invoice inv(int dueDays, {double vat = 15, String cur = '', DocKind k = DocKind.invoice}) {
  final d = DateTime(2026, 5, 1);
  return Invoice(number: 'x', kind: k, date: d, dueDate: dueDays > 0 ? d.add(Duration(days: dueDays)) : null, vatRate: vat, currency: cur);
}

void main() {
  test('mode of due days, vat and currency; newest wins ties', () {
    final d = computeDefaults([inv(30), inv(30), inv(14, vat: 0), inv(30, cur: 'USD')]);
    expect(d.dueDays, 30);
    expect(d.vatRate, 15);
    expect(d.currency, 'USD');
    expect(d.sample, 4);
    final tie = computeDefaults([inv(14), inv(30)]); // newest first: 14
    expect(tie.dueDays, 14);
  });
  test('ignores quotes and nothing known gives empty', () {
    expect(computeDefaults([]).isEmpty, isTrue);
    final d = computeDefaults([inv(30, k: DocKind.quote)]);
    expect(d.sample, 0);
    final none = computeDefaults([inv(0, vat: 0)]);
    expect(none.dueDays, isNull);
    expect(none.vatRate, 0);
  });
}
