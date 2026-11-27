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
  test('expenses are counted separately and never as sales', () async {
    final db = AppDatabase.instance;
    final d = await db.db;
    await d.delete('invoices');
    final from = DateTime(2000);
    final n = await db.nextNumber(DocKind.expense);
    expect(n.startsWith('EXP-'), isTrue);
    await db.saveInvoice(Invoice(kind: DocKind.expense, number: n, party: 'مورد',
        items: [InvoiceItem(description: 'إيجار', quantity: 1, unitPrice: 500)]));
    await db.saveInvoice(Invoice(number: 'I-1', status: InvoiceStatus.confirmed,
        items: [InvoiceItem(description: 'شاي', quantity: 10, unitPrice: 20, costPrice: 5)]));
    expect(await db.expensesSince(from), 500);
    final p = await db.profitSince(from);
    expect(p.sales, 200);
    expect(p.profit, 150);
    expect(DocKindX.fromDb('expense'), DocKind.expense);
  });
}
