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
import 'package:daftar/utils/pricing.dart';
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
    final raw = r.url.queryParameters['updated_at'];
    final strict = raw != null && raw.startsWith('gt.');
    final cur = raw?.replaceFirst('gte.', '').replaceFirst('gt.', '');
    final limit = int.tryParse(r.url.queryParameters['limit'] ?? '') ?? 100000;
    final list = (rows.values
        .where((m) => cur == null || (strict ? (m['updated_at'] as String).compareTo(cur) > 0 : (m['updated_at'] as String).compareTo(cur) >= 0))
        .toList()
      ..sort((a, b) => (a['updated_at'] as String).compareTo(b['updated_at'] as String)))
        .take(limit)
        .toList();
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
    await d.delete('tier_sync');
    await d.delete('price_tiers');

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

    // شرائح الأسعار تُزامَن أيضاً
    await db.saveTiers('شاي', [PriceTier(10, 4.5)]);
    expect((await sync.sync()).pushed, 1);
    await d.delete('price_tiers');
    await d.delete('tier_sync');
    SettingsService.instance.syncCursor = '';
    SettingsService.instance.syncPushTs = 0;
    await sync.sync();
    expect((await db.tiersFor('شاي')).single.price, 4.5);
    await sync.sync();

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

  test('pull does not skip rows that share one timestamp across a page boundary, and survives odd rows', () async {
    final srv = FakeServer();
    // 450 عميلاً من جهاز آخر: كل 200 في طلب واحد بنفس الوقت، والصفحة 300 تقطع وسط مجموعة.
    for (var g = 0; g < 3; g++) {
      final n = g < 2 ? 200 : 50;
      for (var k = 0; k < n; k++) {
        final i = g * 200 + k;
        srv.rows['customer:u$i'] = {
          'entity': 'customer',
          'id': 'u$i',
          'deleted': false,
          'updated_at': '2026-01-01T00:00:0${g + 1}+00:00',
          'data': {'u': 5, 'p': {'name': 'عميل $i', 'future_column': 'x'}},
        };
      }
    }
    srv.rows['customer:bad'] = {'entity': 'customer', 'id': 'bad', 'deleted': false, 'updated_at': '2026-01-01T00:00:09+00:00', 'data': 'not a map'};
    final sync = SyncService(client: MockClient((r) async => srv.handle(r)), url: 'http://x', anonKey: 'k');
    final d = await AppDatabase.instance.db;
    await d.delete('parties');
    await d.delete('invoices');
    await d.delete('tombstones');
    SettingsService.instance.syncRefresh = 'r';
    SettingsService.instance.syncCursor = '';
    SettingsService.instance.syncPushTs = 0;
    await sync.sync();
    final n = (await d.rawQuery('SELECT COUNT(*) c FROM parties WHERE name LIKE ?', ['عميل %'])).first['c'];
    expect(n, 450);
  });
}
