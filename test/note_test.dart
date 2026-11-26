import 'package:daftar/models/invoice.dart';
import 'package:daftar/models/invoice_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('credit note labels, round trip, no payment tracking', () {
    final n = Invoice(
        number: 'CN-0001',
        noteType: 'credit',
        refNumber: '0007',
        dueDate: DateTime(2020),
        items: [InvoiceItem(quantity: 2, unitPrice: 50)]);
    expect(n.docLabel, 'إشعار دائن');
    expect(n.remaining, 0);
    expect(n.isOverdue, isFalse);
    final r = Invoice.fromMap(n.toMap());
    expect(r.noteType, 'credit');
    expect(r.refNumber, '0007');
    expect(Invoice(number: '1', noteType: 'debit').docLabel, 'إشعار مدين');
    expect(Invoice(number: '1').docLabel, 'فاتورة');
  });
}
