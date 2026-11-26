import 'dart:io';

import 'package:daftar/database/app_database.dart';
import 'package:daftar/models/invoice.dart';
import 'package:daftar/models/invoice_item.dart';
import 'package:daftar/services/settings_service.dart';
import 'package:daftar/utils/recurrence.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test('recurring drafts and credit note on a real database', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await SettingsService.instance.init();
    sqfliteFfiInit();
    final dir = Directory.systemTemp.createTempSync('daftar_db');
    await databaseFactoryFfi.setDatabasesPath(dir.path);
    final db = AppDatabase.instance;
    final id = await db.saveInvoice(Invoice(
        number: '0001',
        party: 'نور',
        vatRate: 15,
        date: DateTime(2026, 8, 1),
        dueDate: DateTime(2026, 8, 15),
        items: [InvoiceItem(quantity: 2, unitPrice: 100)]));

    await db.addRecurring(id, Recurrence.monthly, DateTime(2026, 9, 1));
    final n = await db.generateDueRecurring(DateTime(2026, 11, 26));
    expect(n, 3); // 9/1, 10/1, 11/1
    final next = (await db.listRecurring()).single.next;
    expect(next, DateTime(2026, 12, 1));
    expect(await db.generateDueRecurring(DateTime(2026, 11, 27)), 0);
    final all = await db.listInvoices();
    final copy = all.map((e) => e.invoice).firstWhere((i) => i.date == DateTime(2026, 11, 1));
    expect(copy.dueDate, DateTime(2026, 11, 15));
    expect(copy.status, InvoiceStatus.draft);

    final cn = await db.getInvoice(await db.createNote(id, 'credit'));
    expect(cn!.number, 'CN-1');
    expect(cn.refNumber, '0001');
    expect(cn.vatRate, 15);
    expect(cn.items.length, 1);
    final cn2 = await db.getInvoice(await db.createNote(id, 'credit'));
    expect(cn2!.number, 'CN-2');
  });
}
