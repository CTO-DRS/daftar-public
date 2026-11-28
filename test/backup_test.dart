import 'dart:convert';
import 'dart:io';

import 'package:daftar/database/app_database.dart';
import 'package:daftar/models/invoice.dart';
import 'package:daftar/models/invoice_item.dart';
import 'package:daftar/models/party.dart';
import 'package:daftar/services/backup_service.dart';
import 'package:daftar/utils/pricing.dart';
import 'package:daftar/services/settings_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test('backup export then restore round trip on a real database', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await SettingsService.instance.init();
    sqfliteFfiInit();
    final dir = Directory.systemTemp.createTempSync('daftar_bk');
    await databaseFactoryFfi.setDatabasesPath(dir.path);
    final db = AppDatabase.instance;
    await db.saveParty(Party(name: 'نور', phone: '0555'));
    final id = await db.saveInvoice(Invoice(
        number: '0001', party: 'نور', vatRate: 15, date: DateTime(2026, 8, 1),
        status: InvoiceStatus.confirmed, paidAmount: 50,
        items: [InvoiceItem(description: 'مفتاح', quantity: 2, unitPrice: 100, unit: 'درزن')]));
    await db.saveTiers('c:a1', [const PriceTier(10, 9), const PriceTier(50, 8)]);
    final json = await BackupService.exportJson();
    await db.saveTiers('c:a1', []);
    expect(await db.tiersFor('c:a1'), isEmpty);
    // غيّر البيانات بعد النسخ.
    await db.deleteInvoice(id);
    await db.saveInvoice(Invoice(number: '0099', party: 'آخر', items: [InvoiceItem(description: 'x', quantity: 1, unitPrice: 1)]));
    expect((await db.listInvoices()).single.invoice.number, '0099');

    final sum = await BackupService.restore(json);
    expect(sum.invoices, 1);
    expect(sum.items, 1);
    final back = await db.listInvoices();
    expect(back.single.invoice.number, '0001');
    final inv = await db.getInvoice(back.single.invoice.id!);
    expect(inv!.items.single.unit, 'درزن');
    expect(inv.paidAmount, 50);
    expect((await db.listParties()).single.party.phone, '0555');
    final tiers = await db.tiersFor('c:a1');
    expect(tiers.length, 2);
    expect(tiers.last.price, 8);
  });

  test('rejects bad files without touching data', () {
    expect(() => BackupService.parse('not json'), throwsFormatException);
    expect(() => BackupService.parse('{"format":"other"}'), throwsFormatException);
    expect(() => BackupService.parse('{"format":"daftar-backup","schema":9,"invoices":[],"items":[],"parties":[],"recurring":[]}'),
        throwsFormatException);
    expect(
        () => BackupService.parse('{"format":"daftar-backup","schema":1,"invoices":[],"items":[{"invoice_id":5}],"parties":[],"recurring":[]}'),
        throwsFormatException);
  });
  test('restore ignores unknown columns from another app version', () async {
    final db = AppDatabase.instance;
    final json = await BackupService.exportJson();
    final m = jsonDecode(json) as Map<String, dynamic>;
    for (final r in (m['invoices'] as List)) {
      (r as Map)['column_from_the_future'] = 'x';
    }
    for (final r in (m['parties'] as List)) {
      (r as Map)['another_future_column'] = 1;
    }
    final before = (await db.listInvoices()).length;
    final sum = await BackupService.restore(jsonEncode(m));
    expect(sum.invoices, before);
    expect((await db.listInvoices()).length, before);
  });
}
