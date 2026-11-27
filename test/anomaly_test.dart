import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:daftar/database/app_database.dart';
import 'package:daftar/models/invoice.dart';
import 'package:daftar/models/invoice_item.dart';
import 'package:daftar/services/settings_service.dart';
import 'package:daftar/utils/anomaly.dart';

InvoiceItem it(String d, double q, double p, {double cost = 0, String code = ''}) =>
    InvoiceItem(description: d, quantity: q, unitPrice: p, costPrice: cost, itemCode: code);

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.instance.init();
  });
  test('price far from history warns; normal price does not', () {
    final h = it('رز', 2, 10);
    expect(itemWarnings(it('رز', 1, 100), history: h), isNotEmpty);
    expect(itemWarnings(it('رز', 1, 1), history: h), isNotEmpty);
    expect(itemWarnings(it('رز', 1, 12), history: h), isEmpty);
  });
  test('customer price is the reference when known', () {
    final h = it('رز', 2, 10);
    expect(itemWarnings(it('رز', 1, 12), history: h, customerPrice: 3), isNotEmpty);
  });
  test('below cost, huge quantity and duplicate line', () {
    expect(itemWarnings(it('س', 1, 3, cost: 5)).length, 1);
    expect(itemWarnings(it('س', 100, 3), history: it('س', 2, 3)).length, 1);
    final a = it('شاي', 1, 3);
    final b = it('شاي', 1, 3);
    expect(itemWarnings(a, others: [a, b]).length, 1);
    expect(itemWarnings(a, others: [a]), isEmpty);
  });
  test('findDuplicateInvoice: same party, total and day only', () async {
    final db = AppDatabase.instance;
    await (await db.db).delete('invoices');
    final a = Invoice(number: 'D-1', party: 'علي', items: [it('x', 2, 5)]);
    await db.saveInvoice(a);
    final same = Invoice(number: 'D-2', party: 'علي', items: [it('y', 1, 10)]);
    expect(await db.findDuplicateInvoice(same), 'D-1');
    expect(await db.findDuplicateInvoice(Invoice(number: 'D-3', party: 'علي', items: [it('y', 1, 11)])), isNull);
    expect(await db.findDuplicateInvoice(Invoice(number: 'D-4', party: 'غير', items: [it('y', 1, 10)])), isNull);
    final saved = (await db.getInvoice(a.id ?? (await (await db.db).query('invoices')).first['id'] as int))!;
    expect(await db.findDuplicateInvoice(saved), isNull); // itself excluded
  });
}
