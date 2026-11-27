import 'package:flutter_test/flutter_test.dart';
import 'package:daftar/models/invoice.dart';
import 'package:daftar/models/invoice_item.dart';
import 'package:daftar/services/editor_controller.dart';
import 'package:daftar/utils/pages.dart';

InvoiceItem it(String d, [int page = 0]) =>
    InvoiceItem(description: d, quantity: 1, unitPrice: 1, page: page);

void main() {
  test('no manual pages: one slice, original behaviour', () {
    final s = pageSlices([it('a'), it('b')]);
    expect(s.length, 1);
    expect(usesManualPages([it('a')]), isFalse);
  });
  test('auto lines inherit the previous line page; pages ordered; empty skipped', () {
    final items = [it('a'), it('b', 3), it('c'), it('d', 1)];
    expect(effectivePages(items), [1, 3, 3, 1]);
    final s = pageSlices(items);
    expect([for (final p in s) [for (final i in p) i.description]], [['a', 'd'], ['b', 'c']]);
    expect(usedPages(items), [1, 3]);
  });
  test('movePage moves only that line and keeps others where they were', () {
    final inv = Invoice(number: 'x', items: [it('a'), it('b'), it('c')]);
    final c = EditorController(inv);
    c.movePage(inv.items[1], 2);
    expect([for (final i in inv.items) '${i.description}${i.page}'], ['a1', 'c1', 'b2']);
    expect(c.manualPages, isTrue);
    expect(c.pages, [1, 2]);
    c.movePage(inv.items[0], 3); // a -> new page 3
    expect([for (final i in inv.items) '${i.description}${i.page}'], ['c1', 'b2', 'a3']);
  });
  test('applyEdit with a changed page does not drag later auto lines', () {
    final inv = Invoice(number: 'x', items: [it('a'), it('b'), it('c')]);
    final c = EditorController(inv);
    final b = inv.items[1];
    c.applyEdit(b, b.copy()..page = 2, pinPrice: false, pinType: false);
    expect([for (final i in inv.items) '${i.description}${i.page}'], ['a1', 'c1', 'b2']);
  });
  test('new items follow the selected page tab; tab filters the list', () {
    final inv = Invoice(number: 'x', items: [it('a', 1), it('b', 2)]);
    final c = EditorController(inv);
    c.selectPageTab(2);
    expect(c.blank().page, 2);
    expect(c.visibleIndices, [1]);
    c.selectPageTab(0);
    expect(c.visibleIndices, [0, 1]);
  });
}
