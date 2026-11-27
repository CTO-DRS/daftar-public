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
  test('itemHistory returns the latest use per item name, invoices only', () async {
    final db = AppDatabase.instance;
    await (await db.db).delete('invoices');
    await db.saveInvoice(Invoice(number: 'H-1', items: [InvoiceItem(description: 'شاي', quantity: 1, unitPrice: 4, costPrice: 2)]));
    await db.saveInvoice(Invoice(number: 'H-2', items: [InvoiceItem(description: 'شاي ', quantity: 1, unitPrice: 5, costPrice: 3, unit: 'علبة')]));
    await db.saveInvoice(Invoice(kind: DocKind.expense, number: 'E-1', items: [InvoiceItem(description: 'إيجار', quantity: 1, unitPrice: 9)]));
    final h = await db.itemHistory();
    expect(h.keys.toList(), ['شاي']);
    expect(h['شاي']!.unitPrice, 5);
    expect(h['شاي']!.unit, 'علبة');
  });
}
