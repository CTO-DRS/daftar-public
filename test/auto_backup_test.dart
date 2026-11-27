import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:daftar/database/app_database.dart';
import 'package:daftar/models/invoice.dart';
import 'package:daftar/models/invoice_item.dart';
import 'package:daftar/services/auto_backup.dart';
import 'package:daftar/services/backup_service.dart';
import 'package:daftar/services/settings_service.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.instance.init();
  });
  test('daily backup: once per day, rotates, skips empty, restorable', () async {
    final db = AppDatabase.instance;
    final d = await db.db;
    final dir = Directory.systemTemp.createTempSync('bk');
    await d.delete('invoices');
    await d.delete('parties');
    expect(await AutoBackup.runIfDue(dir: dir, now: DateTime(2026, 1, 1)), isNull);
    await db.saveInvoice(Invoice(number: 'B-1', items: [InvoiceItem(description: 'x', quantity: 1, unitPrice: 2)]));
    expect(await AutoBackup.runIfDue(dir: dir, now: DateTime(2026, 1, 1)), isNotNull);
    expect(await AutoBackup.runIfDue(dir: dir, now: DateTime(2026, 1, 1)), isNull);
    for (var i = 2; i <= 10; i++) {
      await AutoBackup.runIfDue(dir: dir, now: DateTime(2026, 1, i));
    }
    final files = await AutoBackup.list(dir);
    expect(files.length, 7);
    expect(files.first.path.endsWith('auto-2026-01-10.json'), isTrue);
    await d.delete('invoices');
    final sum = await BackupService.restore(await files.first.readAsString());
    expect(sum.invoices, 1);
    SettingsService.instance.autoBackup = false;
    expect(await AutoBackup.runIfDue(dir: dir, now: DateTime(2026, 2, 1)), isNull);
    SettingsService.instance.autoBackup = true;
  });
}
