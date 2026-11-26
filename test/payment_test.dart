import 'package:daftar/models/invoice.dart';
import 'package:daftar/models/invoice_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  emptyRowTests();
  currencyTests();
  Invoice mk({InvoiceStatus st = InvoiceStatus.confirmed, double paid = 0, DateTime? due}) =>
      Invoice(number: '1', status: st, paidAmount: paid, dueDate: due, items: [
        InvoiceItem(quantity: 2, unitPrice: 50),
      ]);

  test('remaining and paid', () {
    expect(mk().remaining, 100);
    expect(mk(paid: 40).remaining, 60);
    expect(mk(paid: 150).remaining, 0);
    expect(mk(st: InvoiceStatus.paid).isFullyPaid, isTrue);
  });

  test('overdue', () {
    final past = DateTime.now().subtract(const Duration(days: 3));
    final future = DateTime.now().add(const Duration(days: 3));
    expect(mk(due: past).isOverdue, isTrue);
    expect(mk(due: future).isOverdue, isFalse);
    expect(mk(due: past, paid: 100).isOverdue, isFalse);
    expect(mk().isOverdue, isFalse);
  });

  test('map round trip', () {
    final due = DateTime(2026, 12, 1);
    final i = Invoice.fromMap(mk(paid: 30, due: due).toMap());
    expect(i.paidAmount, 30);
    expect(i.dueDate, due);
  });
}

void emptyRowTests() {
  test('empty rows are detected and not counted', () {
    final inv = Invoice(number: '1', items: [
      InvoiceItem(),
      InvoiceItem(description: 'x', quantity: 2, unitPrice: 5),
      InvoiceItem(quantity: 3),
    ]);
    expect(inv.items[0].isEmpty, isTrue);
    expect(inv.items[2].isEmpty, isFalse);
    expect(inv.itemCount, 2);
  });
}

void currencyTests() {
  test('per-document currency falls back to settings and round-trips', () {
    final inv = Invoice(number: '1', currency: ' USD ');
    expect(inv.currencyOr('ر.س'), 'USD');
    expect(Invoice(number: '2').currencyOr('ر.س'), 'ر.س');
    expect(Invoice.fromMap(inv.toMap()).currency, ' USD ');
  });
}
