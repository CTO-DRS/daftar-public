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
  test('numbering continues after a number typed with Arabic-Indic digits (no duplicates)', () async {
    final db = AppDatabase.instance;
    await (await db.db).delete('invoices');
    final prefix = SettingsService.instance.inventoryPrefix; // JRD-
    await db.saveInvoice(Invoice(kind: DocKind.inventory, number: '${prefix}٠٠٠٧', items: [InvoiceItem(description: 'x', quantity: 1, unitPrice: 1)]));
    final n = await db.nextNumber(DocKind.inventory);
    expect(n.replaceAll(RegExp(r'\D'), '').replaceFirst(RegExp(r'^0+'), ''), '8');
  });
}
