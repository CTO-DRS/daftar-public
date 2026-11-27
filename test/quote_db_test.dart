import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daftar/services/settings_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:daftar/database/app_database.dart';
import 'package:daftar/models/invoice.dart';
import 'package:daftar/models/invoice_item.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.instance.init();
  });
  test('quote converts partially into an invoice and keeps the rest', () async {
    final db = AppDatabase.instance;
    final q = Invoice(
        kind: DocKind.quote,
        number: 'QT-T${DateTime.now().microsecondsSinceEpoch}',
        party: 'أحمد',
        items: [
          InvoiceItem(description: 'كولا', quantity: 10, unitPrice: 2, costPrice: 1),
          InvoiceItem(description: 'ماء', quantity: 5, unitPrice: 1),
        ]);
    final qid = await db.saveInvoice(q);
    final newId = await db.convertQuote(qid, {0: 4});
    final inv = (await db.getInvoice(newId))!;
    expect(inv.kind, DocKind.invoice);
    expect(inv.items.single.quantity, 4);
    expect(inv.items.single.costPrice, 1);
    final left = (await db.getInvoice(qid))!;
    expect(left.items.map((e) => e.quantity), [6, 5]);
    expect(left.notes.contains(inv.number), isTrue);
    // convert everything that remains: quote is marked done
    await db.convertQuote(qid, {0: 6, 1: 5});
    expect((await db.getInvoice(qid))!.status, InvoiceStatus.paid);
  });
}
