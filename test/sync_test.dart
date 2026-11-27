import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:daftar/database/app_database.dart';
import 'package:daftar/models/invoice.dart';
import 'package:daftar/models/invoice_item.dart';
import 'package:daftar/models/party.dart';
import 'package:daftar/services/settings_service.dart';
import 'package:daftar/services/sync_service.dart';

/// خادم وهمي يحاكي PostgREST (records) وGoTrue بالقدر اللازم.
class FakeServer {
  final rows = <String, Map<String, dynamic>>{};
  int clock = 0;
  http.Response handle(http.Request r) {
    final p = r.url.path;
    if (p.contains('/auth/v1/')) {
      return http.Response(
          jsonEncode({'access_token': 't', 'refresh_token': 'r', 'expires_in': 3600}), 200);
    }
    if (r.method == 'POST') {
      for (final e in (jsonDecode(r.body) as List)) {
        final m = Map<String, dynamic>.from(e as Map);
        m['deleted'] ??= false;
        m['updated_at'] = '2026-01-01T00:00:${(++clock).toString().padLeft(2, '0')}+00:00';
        rows['${m['entity']}:${m['id']}'] = m;
      }
      return http.Response('', 201);
    }
    final cur = r.url.queryParameters['updated_at']?.replaceFirst('gt.', '');
    final list = rows.values
        .where((m) => cur == null || (m['updated_at'] as String).compareTo(cur) > 0)
        .toList()
      ..sort((a, b) => (a['updated_at'] as String).compareTo(b['updated_at'] as String));
    return http.Response.bytes(utf8.encode(jsonEncode(list)), 200,
        headers: {'content-type': 'application/json; charset=utf-8'});
  }
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.instance.init();
  });

  test('sync pushes, restores on a fresh device, propagates delete and edits', () async {
    final srv = FakeServer();
    final sync = SyncService(client: MockClient((r) async => srv.handle(r)), url: 'http://x', anonKey: 'k');
    final db = AppDatabase.instance;
    final d = await db.db;
    await d.delete('invoices');
    await d.delete('parties');

    await sync.signIn('a@b.c', 'secret1');
    expect(sync.enabled, isTrue);

    final n = 'T-${DateTime.now().microsecondsSinceEpoch}';
    final id = await db.saveInvoice(Invoice(
        number: n, party: 'سالم', items: [InvoiceItem(description: 'شاي', quantity: 3, unitPrice: 5, costPrice: 2)]));
    await db.saveParty(Party(name: 'سالم', phone: '0555'));
    final r1 = await sync.sync();
    expect(r1.pushed, 2);
    expect(srv.rows.length, 2);

    // جهاز جديد: قاعدة فارغة ومؤشر صفري
    await d.delete('invoices');
    await d.delete('parties');
    SettingsService.instance.syncCursor = '';
    SettingsService.instance.syncPushTs = 0;
    final r2 = await sync.sync();
    expect(r2.pulled, 2);
    final back = (await db.listInvoices()).single.invoice;
    expect(back.number, n);
    final full = (await db.getInvoice(back.id!))!;
    expect(full.items.single.costPrice, 2);
    expect((await db.partyByName('سالم'))!.phone, '0555');
    expect(id, isNotNull);

    // لا صدى: دورة ثانية بلا تغيير لا ترفع ولا تنزل شيئاً
    final r3 = await sync.sync();
    expect(r3.pushed + r3.pulled, 0);

    // حذف محلي ينتقل كـ tombstone
    await db.deleteInvoice(back.id!);
    final r4 = await sync.sync();
    expect(r4.deleted, 1);
    expect(srv.rows.values.any((m) => m['deleted'] == true), isTrue);

    // تعديل من جهاز آخر (أحدث) يُطبّق محلياً
    final pk = srv.rows.keys.firstWhere((k) => k.startsWith('customer:'));
    final data = Map<String, dynamic>.from(srv.rows[pk]!['data'] as Map);
    data['u'] = DateTime.now().millisecondsSinceEpoch + 1000;
    (data['p'] as Map)['phone'] = '0999';
    srv.rows[pk]!['data'] = data;
    srv.rows[pk]!['updated_at'] = '2026-01-01T00:59:00+00:00';
    await sync.sync();
    expect((await db.partyByName('سالم'))!.phone, '0999');
  });
}
