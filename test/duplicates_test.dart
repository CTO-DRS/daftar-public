import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:daftar/database/app_database.dart';
import 'package:daftar/models/invoice.dart';
import 'package:daftar/models/invoice_item.dart';
import 'package:daftar/models/party.dart';
import 'package:daftar/services/settings_service.dart';
import 'package:daftar/utils/duplicates.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.instance.init();
  });

  test('detects spelling, word order, one-letter and phone duplicates', () {
    final g = findDuplicateGroups([
      const DupEntry('أحمد محمد', count: 5),
      const DupEntry('احمد محمد', count: 2),
      const DupEntry('محمد أحمد', count: 1),
      const DupEntry('خالد العتيبي', phone: '0551234567', count: 3),
      const DupEntry('أبو خالد', phone: '+966 55 123 4567', count: 1),
      const DupEntry('سالم', count: 4),
      const DupEntry('عبدالرحمن', count: 2),
      const DupEntry('عبدالرحمان', count: 1),
    ]);
    expect(g.length, 3);
    final first = g.firstWhere((x) => x.entries.any((e) => e.name == 'أحمد محمد'));
    expect(first.entries.length, 3);
    expect(first.entries.first.name, 'أحمد محمد'); // الأكثر استخداماً أولاً
    expect(g.any((x) => x.reason == 'نفس رقم الجوال'), isTrue);
    expect(g.any((x) => x.entries.any((e) => e.name == 'سالم')), isFalse);
  });

  test('code matching only when asked', () {
    final l = [const DupEntry('بنابر كبير', code: 'W-1802'), const DupEntry('فضي كبير', code: 'w-1802')];
    expect(findDuplicateGroups(l), isEmpty);
    expect(findDuplicateGroups(l, byCode: true).single.reason, 'نفس كود الموديل');
  });

  test('merge parties moves invoices, fills phone, and undo restores', () async {
    final db = AppDatabase.instance;
    await (await db.db).delete('invoices');
    await (await db.db).delete('parties');
    await db.saveParty(Party(name: 'أحمد محمد'));
    await db.saveParty(Party(name: 'احمد محمد', phone: '0551111111'));
    final a = await db.saveInvoice(Invoice(number: 'M-1', party: 'احمد محمد', items: [InvoiceItem(description: 'x', quantity: 1, unitPrice: 1)]));
    final b = await db.saveInvoice(Invoice(number: 'M-2', party: 'أحمد محمد', items: [InvoiceItem(description: 'x', quantity: 1, unitPrice: 1)]));
    final undo = await db.mergeParties('أحمد محمد', ['أحمد محمد', 'احمد محمد']);
    expect((await db.getInvoice(a))!.party, 'أحمد محمد');
    expect((await db.getInvoice(b))!.party, 'أحمد محمد');
    final rows = await (await db.db).query('parties');
    expect(rows.length, 1);
    expect(rows.first['phone'], '0551111111');
    await db.undoMerge(undo);
    expect((await db.getInvoice(a))!.party, 'احمد محمد');
    final back = await (await db.db).query('parties', orderBy: 'name');
    expect(back.length, 2);
    expect(back.firstWhere((m) => m['name'] == 'أحمد محمد')['phone'], '');
  });

  test('merge items renames lines, fills code, undo restores', () async {
    final db = AppDatabase.instance;
    await (await db.db).delete('invoices');
    final id = await db.saveInvoice(Invoice(number: 'I-1', items: [
      InvoiceItem(description: 'بنابر كبير', itemCode: 'W-1', quantity: 1, unitPrice: 5),
      InvoiceItem(description: 'بنابر كبيره', quantity: 1, unitPrice: 5),
    ]));
    final undo = await db.mergeItems('بنابر كبير', ['بنابر كبير', 'بنابر كبيره'], keepCode: 'W-1');
    var inv = (await db.getInvoice(id))!;
    expect(inv.items.map((e) => e.description).toSet(), {'بنابر كبير'});
    expect(inv.items.map((e) => e.itemCode), ['W-1', 'W-1']);
    await db.undoMerge(undo);
    inv = (await db.getInvoice(id))!;
    expect(inv.items.map((e) => e.description), ['بنابر كبير', 'بنابر كبيره']);
    expect(inv.items[1].itemCode, '');
  });
}
