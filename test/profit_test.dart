import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:daftar/database/app_database.dart';
import 'package:daftar/models/invoice.dart';
import 'package:daftar/models/invoice_item.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  test('line profit with pack conversion', () {
    final it = InvoiceItem(
        description: 'x', quantity: 2, unitPrice: 5, wholesaleQty: 1,
        wholesalePrice: 100, packSize: 24, costPrice: 3);
    // total 110, cost 3 * (2 + 24) = 78
    expect(it.profit, 32);
    expect(InvoiceItem(quantity: 1, unitPrice: 5).profit, 0);
  });

  test('profitSince only counts costed lines in profit', () async {
    final db = AppDatabase.instance;
    final since = DateTime.now().add(const Duration(days: 3650));
    final base = await db.profitSince(DateTime.now().subtract(const Duration(days: 1)));
    final inv = Invoice(number: 'PRF-${DateTime.now().microsecondsSinceEpoch}', status: InvoiceStatus.confirmed, items: [
      InvoiceItem(description: 'a', quantity: 10, unitPrice: 5, costPrice: 3),
      InvoiceItem(description: 'b', quantity: 1, unitPrice: 100),
    ]);
    await db.saveInvoice(inv);
    final after = await db.profitSince(DateTime.now().subtract(const Duration(days: 1)));
    expect(after.sales - base.sales, 150);
    expect(after.profit - base.profit, 20);
    expect(after.costedSales - base.costedSales, 50);
    expect((await db.profitSince(since)).sales, 0);
  });
}
