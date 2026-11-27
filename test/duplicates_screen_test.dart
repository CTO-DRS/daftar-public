import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:daftar/database/app_database.dart';
import 'package:daftar/models/invoice.dart';
import 'package:daftar/models/invoice_item.dart';
import 'package:daftar/screens/duplicates_screen.dart';
import 'package:daftar/services/settings_service.dart';

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 8; i++) {
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 60)));
    await t.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  testWidgets('screen lists a duplicate customer group and merges it', (t) async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.instance.init();
    await t.runAsync(() async {
      final db = AppDatabase.instance;
      await (await db.db).delete('invoices');
      await (await db.db).delete('parties');
      for (final (n, p) in [('M-1', 'سعد الغامدي'), ('M-2', 'سعد الغامدي'), ('M-3', 'سعد الغامد')]) {
        await db.saveInvoice(Invoice(number: n, party: p, items: [InvoiceItem(description: 'x', quantity: 1, unitPrice: 1)]));
      }
    });
    await t.pumpWidget(const MaterialApp(home: DuplicatesScreen()));
    await settle(t);
    expect(find.byKey(const ValueKey('dup-سعد الغامدي')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('merge-سعد الغامدي')));
    await settle(t);
    final names = await t.runAsync(() => AppDatabase.instance.partyDupEntries());
    expect(names!.map((e) => e.name), ['سعد الغامدي']);
  });
}
