import 'package:flutter_test/flutter_test.dart';
import 'package:daftar/models/invoice.dart';
import 'package:daftar/utils/csv_export.dart';

InvoiceSummary s(Invoice i, double total) => InvoiceSummary(i, 1, 1, total);

void main() {
  test('accountant csv: range, drafts out, credit negative, vat split, formula guard', () {
    final d = DateTime(2026, 11, 10);
    final all = [
      s(Invoice(number: 'A-1', date: d, party: 'أحمد', status: InvoiceStatus.confirmed, vatRate: 15, paidAmount: 50), 115),
      s(Invoice(number: 'A-2', date: d, status: InvoiceStatus.draft), 10),
      s(Invoice(number: 'A-3', date: DateTime(2026, 10, 1), status: InvoiceStatus.confirmed), 10),
      s(Invoice(number: 'CN-1', date: d, status: InvoiceStatus.confirmed, noteType: 'credit'), 23),
      s(Invoice(kind: DocKind.expense, number: 'EXP-1', date: d, party: '=cmd', status: InvoiceStatus.draft), 40),
      s(Invoice(kind: DocKind.quote, number: 'QT-1', date: d, status: InvoiceStatus.confirmed), 5),
    ];
    final csv = accountantCsv(all, DateTime(2026, 11), DateTime(2026, 12));
    final lines = csv.trim().split('\n');
    expect(csv.startsWith('\uFEFF'), isTrue);
    expect(csv.contains('A-2'), isFalse);
    expect(csv.contains('A-3'), isFalse);
    expect(csv.contains('QT-1'), isFalse);
    expect(csv.contains('EXP-1'), isTrue); // recorded expenses always count
    final a1 = lines.firstWhere((l) => l.contains('A-1'));
    expect(a1.contains('100.00,15.00,115.00,50.00,65.00'), isTrue);
    final cn = lines.firstWhere((l) => l.contains('CN-1'));
    expect(cn.contains('-20.00') || cn.contains('-23.00'), isTrue);
    final all2 = [s(Invoice(kind: DocKind.expense, number: 'E', date: d, party: '=cmd', status: InvoiceStatus.confirmed), 40)];
    expect(accountantCsv(all2, DateTime(2026), DateTime(2027)).contains('"\'=cmd"'), isTrue);
  });
}
