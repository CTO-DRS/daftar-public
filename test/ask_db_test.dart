import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:daftar/database/app_database.dart';
import 'package:daftar/models/invoice.dart';
import 'package:daftar/models/invoice_item.dart';
import 'package:daftar/services/settings_service.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.instance.init();
  });
  test('soldRows and addPaymentTo', () async {
    final db = AppDatabase.instance;
    await (await db.db).delete('invoices');
    final id = await db.saveInvoice(Invoice(
        number: 'A-1', party: 'سالم', status: InvoiceStatus.confirmed,
        items: [InvoiceItem(description: 'أسمنت', quantity: 4, unitPrice: 25)]));
    final rows = await db.soldRows();
    expect(rows.single.pieces, 4);
    expect(rows.single.total, 100);
    await db.addPaymentTo(id, 60);
    var inv = (await db.getInvoice(id))!;
    expect(inv.paidAmount, 60);
    expect(inv.status, InvoiceStatus.confirmed);
    await db.addPaymentTo(id, 500);
    inv = (await db.getInvoice(id))!;
    expect(inv.paidAmount, 100);
    expect(inv.status, InvoiceStatus.paid);
  });
}
