import 'package:daftar/models/invoice.dart';
import 'package:daftar/models/invoice_item.dart';
import 'package:daftar/services/editor_controller.dart';
import 'package:daftar/utils/sort_utils.dart';
import 'package:flutter_test/flutter_test.dart';

InvoiceItem it(String code, double q, [double p = 10, String d = '']) =>
    InvoiceItem(itemCode: code, quantity: q, unitPrice: p, description: d);

EditorController make(List<InvoiceItem> items) =>
    EditorController(Invoice(number: '1', items: items));

void main() {
  test('pins feed blank rows and edits', () {
    final c = make([]);
    c.applyEdit(null, it('A1', 2, 7.5, 'مفتاح'), pinPrice: true, pinType: true);
    expect(c.inv.items.length, 1);
    final b = c.blank();
    expect(b.unitPrice, 7.5);
    expect(b.description, 'مفتاح');
    c.clearPinPrice();
    expect(c.blank().unitPrice, 0);
    expect(c.dirty, isTrue);
  });

  test('addBlanks respects pins and the 200 cap', () {
    final c = make([]);
    c.applyEdit(null, it('', 1, 3, 'x'), pinPrice: true, pinType: false);
    c.addBlanks(500);
    expect(c.inv.items.length, 201);
    expect(c.inv.items.last.unitPrice, 3);
  });

  test('remove and restore keep position', () {
    final a = it('A', 1), b = it('B', 1), d = it('C', 1);
    final c = make([a, b, d]);
    final i = c.remove(b);
    expect(i, 1);
    expect(c.inv.items, [a, d]);
    c.restore(i, b);
    expect(c.inv.items, [a, b, d]);
  });

  test('duplicate N copies fields, blank quantity, inserted below', () {
    final a = it('A', 5, 4, 'نوع'), b = it('B', 1);
    final c = make([a, b]);
    c.duplicate(a, times: 3, keepQuantity: false);
    expect(c.inv.items.length, 5);
    expect(c.inv.items[1].itemCode, 'A');
    expect(c.inv.items[1].quantity, 0);
    expect(c.inv.items[3].unitPrice, 4);
    expect(c.inv.items[4], b);
    c.duplicate(a, times: 1);
    expect(c.inv.items[1].quantity, 5);
    c.duplicate(a, times: 1000);
    expect(c.inv.items.length, 5 + 1 + 100);
  });

  test('sort then restore original entry order', () {
    final a = it('C-10', 1), b = it('C-2', 3), d = it('C-1', 2);
    final c = make([a, b, d]);
    c.sortBy(SortField.itemCode, true);
    expect(c.inv.items.map((e) => e.itemCode), ['C-1', 'C-2', 'C-10']);
    c.sortBy(SortField.quantity, false);
    expect(c.inv.items.map((e) => e.quantity), [3, 2, 1]);
    c.restoreOriginalOrder();
    expect(c.inv.items, [a, b, d]);
    expect(c.sortField, isNull);
  });

  test('restore keeps rows added after sorting at the end of entry order', () {
    final a = it('B', 1), b = it('A', 1);
    final c = make([a, b]);
    c.sortBy(SortField.itemCode, true);
    final n = it('Z', 1);
    c.applyEdit(null, n, pinPrice: false, pinType: false);
    c.restoreOriginalOrder();
    expect(c.inv.items, [a, b, n]);
  });

  test('query filters visible indices including numbers', () {
    final c = make([it('A1', 12, 7.5), it('B2', 3, 4), it('C3', 1, 9)]);
    c.setQuery('b2');
    expect(c.visibleIndices, [1]);
    c.setQuery('٧٫٥');
    expect(c.visibleIndices, [0]);
    c.setQuery('');
    expect(c.visibleIndices, [0, 1, 2]);
  });

  test('payments: paid amount drives status, status drives paid amount', () {
    final c = make([it('A', 2, 50)]);
    c.setStatus(InvoiceStatus.confirmed);
    c.setPaidAmount(40);
    expect(c.inv.remaining, 60);
    c.setPaidAmount(100);
    expect(c.inv.status, InvoiceStatus.paid);
    c.setPaidAmount(10);
    expect(c.inv.status, InvoiceStatus.confirmed);
    c.setStatus(InvoiceStatus.paid);
    expect(c.inv.paidAmount, 100);
    c.setStatus(InvoiceStatus.draft);
    expect(c.inv.paidAmount, 0);
  });

  test('listeners fire on change', () {
    final c = make([it('A', 1)]);
    var n = 0;
    c.addListener(() => n++);
    c.setQuery('a');
    c.markSaved();
    expect(n, 2);
    expect(c.dirty, isFalse);
  });
}
