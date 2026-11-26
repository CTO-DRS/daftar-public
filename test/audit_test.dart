import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:daftar/database/app_database.dart';
import 'package:daftar/models/invoice.dart';
import 'package:daftar/models/invoice_item.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  test('create, edit and delete are logged', () async {
    final db = AppDatabase.instance;
    final inv = Invoice(number: 'AUD-1', party: 'أحمد', items: [
      InvoiceItem(description: 'كولا', quantity: 2, unitPrice: 5)
    ]);
    final id = await db.saveInvoice(inv);
    inv.items.first.quantity = 4;
    await db.saveInvoice(inv);
    await db.deleteInvoice(id);
    final log = (await db.auditEntries()).where((e) => e['doc_number'] == 'AUD-1').toList();
    expect(log.map((e) => e['action']).toList().reversed, ['create', 'edit', 'delete']);
    expect((log[1]['detail'] as String).contains('←'), isTrue);
  });
}
