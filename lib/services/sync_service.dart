import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import 'settings_service.dart';
import 'sync_config.dart';

class SyncResult {
  final int pushed, pulled, deleted;
  const SyncResult(this.pushed, this.pulled, this.deleted);
  @override
  String toString() => 'رفع $pushed • تنزيل $pulled • حذف $deleted';
}

class SyncException implements Exception {
  final String message;
  SyncException(this.message);
  @override
  String toString() => message;
}

String newUid() {
  final r = Random.secure();
  return List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}

/// مزامنة اختيارية: SQLite المحلية هي المصدر، والخادم طبقة مزامنة.
/// الفاتورة بأسطرها وثيقة واحدة؛ الأحدث (updated_at) يفوز؛ الحذف عبر tombstones.
class SyncService {
  SyncService({http.Client? client, String? url, String? anonKey})
      : _c = client ?? http.Client(),
        _url = url ?? syncUrl,
        _key = anonKey ?? syncAnonKey;

  static final SyncService instance = SyncService();

  final http.Client _c;
  final String _url, _key;
  String get baseUrl => _url;
  String get anonKey => _key;
  http.Client get client => _c;
  bool _busy = false;

  bool get enabled => SettingsService.instance.syncRefresh.isNotEmpty;

  Map<String, String> headers([String? token, String? profile, bool write = false]) => _h(token, profile, write);

  Map<String, String> _h([String? token, String? profile, bool write = false]) => <String, String>{
        'apikey': _key,
        'Authorization': 'Bearer ${token ?? _key}',
        'Content-Type': 'application/json',
      }..addAll(profile == null
          ? const {}
          : {write ? 'Content-Profile' : 'Accept-Profile': profile});

  String _err(http.Response r) {
    try {
      final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map;
      final m = (j['msg'] ?? j['message'] ?? j['error_description'] ?? j['error'] ?? '').toString();
      if (m.contains('Invalid login')) return 'البريد أو كلمة المرور غير صحيحة';
      if (m.contains('already')) return 'الحساب موجود، سجّل الدخول بدلاً من إنشاء حساب';
      if (m.contains('Password should')) return 'كلمة المرور قصيرة (6 أحرف على الأقل)';
      if (m.isNotEmpty) return m;
    } catch (_) {}
    return 'خطأ ${r.statusCode}';
  }

  Future<void> _storeSession(Map j, String email) async {
    final s = SettingsService.instance;
    final t = j['access_token'] as String?;
    final rt = j['refresh_token'] as String?;
    if (t == null || rt == null) {
      throw SyncException('تعذر تسجيل الدخول (قد يتطلب الحساب تأكيد البريد)');
    }
    s.syncToken = t;
    s.syncRefresh = rt;
    s.syncExpires = DateTime.now().millisecondsSinceEpoch ~/ 1000 +
        ((j['expires_in'] as num?)?.toInt() ?? 3600);
    s.syncEmail = email;
  }

  Future<void> signIn(String email, String password, {bool create = false}) async {
    final e = email.trim().toLowerCase();
    final r = create
        ? await _c.post(Uri.parse('$_url/auth/v1/signup'),
            headers: _h(), body: jsonEncode({'email': e, 'password': password}))
        : await _c.post(Uri.parse('$_url/auth/v1/token?grant_type=password'),
            headers: _h(), body: jsonEncode({'email': e, 'password': password}));
    if (r.statusCode >= 300) throw SyncException(_err(r));
    await _storeSession(jsonDecode(utf8.decode(r.bodyBytes)) as Map, e);
  }

  void signOut() {
    final s = SettingsService.instance;
    s.syncToken = '';
    s.syncRefresh = '';
    s.syncCursor = '';
    s.syncPushTs = 0;
  }

  /// للاستخدام الخارجي (روابط المشاركة): توكن صالح ومعرّفات uid مضمونة.
  Future<String> accessToken() => _token();
  Future<void> ensureUids() async => _assignUids(await AppDatabase.instance.db);

  Future<String> _token() async {
    final s = SettingsService.instance;
    if (s.syncRefresh.isEmpty) throw SyncException('سجّل الدخول أولاً');
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (s.syncToken.isNotEmpty && s.syncExpires - 60 > now) return s.syncToken;
    final r = await _c.post(Uri.parse('$_url/auth/v1/token?grant_type=refresh_token'),
        headers: _h(), body: jsonEncode({'refresh_token': s.syncRefresh}));
    if (r.statusCode >= 300) throw SyncException('انتهت الجلسة، سجّل الدخول مرة أخرى');
    await _storeSession(jsonDecode(utf8.decode(r.bodyBytes)) as Map, s.syncEmail);
    return s.syncToken;
  }

  /// دورة مزامنة كاملة: سحب ثم رفع. تتجاهل الطلب إذا كانت دورة جارية.
  Future<SyncResult> sync() async {
    if (_busy) return const SyncResult(0, 0, 0);
    _busy = true;
    try {
      final token = await _token();
      final d = await AppDatabase.instance.db;
      final start = DateTime.now().millisecondsSinceEpoch;
      await _assignUids(d);
      final applied = <String>{};
      final pulled = await _pull(d, token, applied);
      final pushed = await _push(d, token, applied);
      SettingsService.instance.syncPushTs = start;
      SettingsService.instance.syncLast = DateTime.now().millisecondsSinceEpoch;
      return SyncResult(pushed.$1, pulled.$1, pulled.$2 + pushed.$2);
    } on SyncException {
      rethrow;
    } catch (_) {
      throw SyncException('تعذرت المزامنة (تحقق من الاتصال)');
    } finally {
      _busy = false;
    }
  }

  Future<void> _assignUids(Database d) async {
    for (final t in ['invoices', 'parties']) {
      final rows = await d.query(t, columns: ['id'], where: "uid IS NULL OR uid = ''");
      for (final r in rows) {
        await d.update(t, {'uid': newUid()}, where: 'id = ?', whereArgs: [r['id']]);
      }
    }
  }

  // ---- push ----

  Future<(int, int)> _push(Database d, String token, Set<String> applied) async {
    final since = SettingsService.instance.syncPushTs;
    final recs = <Map<String, Object?>>[];

    final invs = await d.query('invoices', where: 'updated_at > ?', whereArgs: [since]);
    for (final m in invs) {
      final uid = m['uid'] as String;
      if (applied.contains('invoice:$uid')) continue;
      final items = await d.query('items',
          where: 'invoice_id = ?', whereArgs: [m['id']], orderBy: 'position ASC');
      recs.add({
        'entity': 'invoice',
        'id': uid,
        'data': {
          'u': m['updated_at'],
          'inv': (Map<String, Object?>.from(m)..remove('id')..remove('uid')),
          'items': [for (final i in items) Map<String, Object?>.from(i)..remove('id')..remove('invoice_id')],
        },
      });
    }
    final ps = await d.query('parties', where: 'updated_at > ?', whereArgs: [since]);
    for (final m in ps) {
      final uid = m['uid'] as String;
      if (applied.contains('customer:$uid')) continue;
      recs.add({
        'entity': 'customer',
        'id': uid,
        'data': {
          'u': m['updated_at'],
          'p': (Map<String, Object?>.from(m)..remove('id')..remove('uid')),
        },
      });
    }
    final tombs = await d.query('tombstones');
    for (final t in tombs) {
      recs.add({
        'entity': t['entity'],
        'id': t['uid'],
        'deleted': true,
        'data': {'u': t['ts']},
      });
    }
    var n = 0;
    for (var i = 0; i < recs.length; i += 200) {
      final chunk = recs.sublist(i, min(i + 200, recs.length));
      final r = await _c.post(
          Uri.parse('$_url/rest/v1/records?on_conflict=user_id,entity,id'),
          headers: {
            ..._h(token, 'daftar', true),
            'Prefer': 'resolution=merge-duplicates,return=minimal',
          },
          body: jsonEncode(chunk));
      if (r.statusCode >= 300) throw SyncException(_err(r));
      n += chunk.length;
    }
    if (tombs.isNotEmpty) await d.delete('tombstones');
    return (n - tombs.length, tombs.length);
  }

  // ---- pull ----

  Future<(int, int)> _pull(Database d, String token, Set<String> applied) async {
    final s = SettingsService.instance;
    var cursor = s.syncCursor;
    var upserts = 0, dels = 0;
    while (true) {
      final q = <String, String>{
        'select': 'entity,id,data,deleted,updated_at',
        'order': 'updated_at.asc',
        'limit': '300',
        if (cursor.isNotEmpty) 'updated_at': 'gt.$cursor',
      };
      final r = await _c.get(
          Uri.parse('$_url/rest/v1/records').replace(queryParameters: q),
          headers: _h(token, 'daftar'));
      if (r.statusCode >= 300) throw SyncException(_err(r));
      final rows = (jsonDecode(utf8.decode(r.bodyBytes)) as List).cast<Map<String, dynamic>>();
      if (rows.isEmpty) break;
      for (final row in rows) {
        final res = await _apply(d, row, applied);
        if (res == 1) upserts++;
        if (res == 2) dels++;
      }
      cursor = rows.last['updated_at'] as String;
      s.syncCursor = cursor;
      if (rows.length < 300) break;
    }
    return (upserts, dels);
  }

  /// 0 = تجاهل، 1 = كتابة، 2 = حذف.
  Future<int> _apply(Database d, Map<String, dynamic> row, Set<String> applied) async {
    final entity = row['entity'] as String;
    final uid = row['id'] as String;
    final data = Map<String, dynamic>.from(row['data'] as Map);
    final u = (data['u'] as num?)?.toInt() ?? 0;
    final table = entity == 'invoice' ? 'invoices' : entity == 'customer' ? 'parties' : null;
    if (table == null) return 0;
    final local = await d.query(table, where: 'uid = ?', whereArgs: [uid], limit: 1);
    final localU = local.isEmpty ? -1 : (local.first['updated_at'] as num?)?.toInt() ?? 0;

    if (row['deleted'] == true) {
      if (local.isEmpty || localU > u) return 0;
      await d.delete(table, where: 'uid = ?', whereArgs: [uid]);
      applied.add('$entity:$uid');
      return 2;
    }
    if (localU >= u) return 0;
    if (entity == 'invoice') {
      final inv = Map<String, Object?>.from(data['inv'] as Map)..['uid'] = uid;
      final items = (data['items'] as List? ?? const [])
          .map((e) => Map<String, Object?>.from(e as Map))
          .toList();
      await d.transaction((tx) async {
        int id;
        if (local.isEmpty) {
          id = await tx.insert('invoices', inv);
        } else {
          id = local.first['id'] as int;
          await tx.update('invoices', inv, where: 'id = ?', whereArgs: [id]);
          await tx.delete('items', where: 'invoice_id = ?', whereArgs: [id]);
        }
        for (final it in items) {
          await tx.insert('items', it..['invoice_id'] = id);
        }
      });
    } else {
      final p = Map<String, Object?>.from(data['p'] as Map)..['uid'] = uid;
      if (local.isNotEmpty) {
        await d.update('parties', p, where: 'uid = ?', whereArgs: [uid]);
      } else {
        // نفس الاسم موجود محلياً بلا uid (جهاز آخر) فنتبنى الـ uid بدل التكرار.
        final byName = await d.query('parties',
            where: 'name = ? COLLATE NOCASE', whereArgs: [p['name']], limit: 1);
        if (byName.isNotEmpty) {
          await d.update('parties', p, where: 'id = ?', whereArgs: [byName.first['id']]);
        } else {
          await d.insert('parties', p);
        }
      }
    }
    applied.add('$entity:$uid');
    return 1;
  }
}
