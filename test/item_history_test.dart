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
  test('itemStats counts uses; customerPrices returns that customer\'s last price', () async {
    final db = AppDatabase.instance;
    await (await db.db).delete('invoices');
    await db.saveInvoice(Invoice(number: 'S-1', party: 'أحمد', items: [InvoiceItem(description: 'سكر', quantity: 1, unitPrice: 4)]));
    await db.saveInvoice(Invoice(number: 'S-2', party: 'خالد', items: [InvoiceItem(description: 'سكر', quantity: 1, unitPrice: 6)]));
    await db.saveInvoice(Invoice(number: 'S-3', party: 'أحمد', items: [InvoiceItem(description: 'سكر', quantity: 1, unitPrice: 3.5)]));
    final st = await db.itemStats();
    expect(st.length, 1);
    expect(st.first.count, 3);
    expect(st.first.last.unitPrice, 3.5);
    final cp = await db.customerPrices('خالد');
    expect(cp.values.single, 6);
    expect((await db.customerPrices('أحمد')).values.single, 3.5);
    expect(await db.customerPrices(''), isEmpty);
  });
  test('usualItems ranks by frequency; lastInvoiceItems copies latest invoice', () async {
    final db = AppDatabase.instance;
    await (await db.db).delete('invoices');
    await db.saveInvoice(Invoice(number: 'U-1', party: 'سعد', items: [
      InvoiceItem(description: 'رز', quantity: 2, unitPrice: 10),
      InvoiceItem(description: 'سكر', quantity: 1, unitPrice: 4)]));
    await db.saveInvoice(Invoice(number: 'U-2', party: 'سعد', items: [
      InvoiceItem(description: 'رز', quantity: 5, unitPrice: 11)]));
    await db.saveInvoice(Invoice(number: 'U-3', party: 'غيره', items: [
      InvoiceItem(description: 'شاي', quantity: 1, unitPrice: 3)]));
    final u = await db.usualItems('سعد');
    expect(u.map((e) => e.description).toList(), ['رز', 'سكر']);
    expect(u.first.unitPrice, 11);
    expect(u.first.quantity, 5);
    expect(u.first.id, isNull);
    final l = await db.lastInvoiceItems('سعد');
    expect(l.length, 1);
    expect(l.first.quantity, 5);
    expect(await db.usualItems('مجهول'), isEmpty);
    expect(await db.lastInvoiceItems(''), isEmpty);
  });
}
