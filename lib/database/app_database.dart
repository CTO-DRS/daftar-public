import 'dart:io' show Platform;

import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/invoice.dart';
import '../models/invoice_item.dart';
import '../models/party.dart';
import '../services/settings_service.dart';

/// قاعدة بيانات SQLite المحلية (تعمل بدون إنترنت).
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  Future<Database> get db async => _db ??= await _open();

  static const _partiesDdl = '''
    CREATE TABLE IF NOT EXISTS parties(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL UNIQUE,
      phone TEXT NOT NULL DEFAULT '',
      address TEXT NOT NULL DEFAULT '',
      notes TEXT NOT NULL DEFAULT ''
    )''';

  static bool get isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  Future<Database> _open() async {
    // على سطح المكتب نستخدم SQLite عبر FFI، وعلى أندرويد sqflite العادي.
    final DatabaseFactory factory;
    if (isDesktop) {
      sqfliteFfiInit();
      factory = databaseFactoryFfi;
    } else {
      factory = databaseFactory;
    }
    final path = p.join(await factory.getDatabasesPath(), 'daftar.db');
    return factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
      version: 6,
      onUpgrade: (d, o, n) async {
        if (o < 2) {
          await d.execute("ALTER TABLE invoices ADD COLUMN status TEXT NOT NULL DEFAULT 'draft'");
        }
        if (o < 3) {
          await d.execute(_partiesDdl);
        }
        if (o < 4) {
          await d.execute('ALTER TABLE invoices ADD COLUMN due_date INTEGER');
          await d.execute('ALTER TABLE invoices ADD COLUMN paid_amount REAL NOT NULL DEFAULT 0');
          // الفواتير المدفوعة سابقاً تُسجَّل كمسددة بالكامل.
          await d.execute("UPDATE invoices SET paid_amount = grand_total WHERE status = 'paid'");
        }
        if (o < 5) {
          await d.execute("ALTER TABLE invoices ADD COLUMN currency TEXT NOT NULL DEFAULT ''");
        }
        if (o < 6) {
          await d.execute('ALTER TABLE invoices ADD COLUMN vat_rate REAL NOT NULL DEFAULT 0');
        }
      },
      onConfigure: (d) => d.execute('PRAGMA foreign_keys = ON'),
      onCreate: (d, v) async {
        await d.execute('''
          CREATE TABLE invoices(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            kind TEXT NOT NULL DEFAULT 'invoice',
            status TEXT NOT NULL DEFAULT 'draft',
            number TEXT NOT NULL,
            date INTEGER NOT NULL,
            party TEXT NOT NULL DEFAULT '',
            notes TEXT NOT NULL DEFAULT '',
            updated_at INTEGER NOT NULL,
            due_date INTEGER,
            paid_amount REAL NOT NULL DEFAULT 0,
            currency TEXT NOT NULL DEFAULT '',
            vat_rate REAL NOT NULL DEFAULT 0,
            item_count INTEGER NOT NULL DEFAULT 0,
            total_qty REAL NOT NULL DEFAULT 0,
            grand_total REAL NOT NULL DEFAULT 0
          )''');
        await d.execute('''
          CREATE TABLE items(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            invoice_id INTEGER NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
            position INTEGER NOT NULL,
            item_code TEXT NOT NULL DEFAULT '',
            ref_number TEXT NOT NULL DEFAULT '',
            description TEXT NOT NULL DEFAULT '',
            quantity REAL NOT NULL DEFAULT 0,
            unit_price REAL NOT NULL DEFAULT 0,
            notes TEXT NOT NULL DEFAULT ''
          )''');
        await d.execute(_partiesDdl);
        await d.execute('CREATE INDEX idx_items_invoice ON items(invoice_id, position)');
      },
      ),
    );
  }

  /// قائمة الفواتير مع إمكانية البحث بالرقم أو اسم العميل.
  Future<List<InvoiceSummary>> listInvoices({String query = ''}) async {
    final d = await db;
    final q = query.trim();
    final rows = await d.query(
      'invoices',
      where: q.isEmpty ? null : 'number LIKE ? OR party LIKE ? OR notes LIKE ?',
      whereArgs: q.isEmpty ? null : ['%$q%', '%$q%', '%$q%'],
      orderBy: 'updated_at DESC',
    );
    return rows
        .map((m) => InvoiceSummary(
              Invoice.fromMap(m),
              (m['item_count'] as int?) ?? 0,
              (m['total_qty'] as num?)?.toDouble() ?? 0,
              (m['grand_total'] as num?)?.toDouble() ?? 0,
            ))
        .toList();
  }

  Future<Invoice?> getInvoice(int id) async {
    final d = await db;
    final rows = await d.query('invoices', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    final items = await d.query('items',
        where: 'invoice_id = ?', whereArgs: [id], orderBy: 'position ASC');
    return Invoice.fromMap(rows.first, items.map(InvoiceItem.fromMap).toList());
  }

  /// يحفظ الفاتورة وأسطرها في معاملة واحدة ويعيد المعرف.
  Future<int> saveInvoice(Invoice inv) async {
    final d = await db;
    inv.updatedAt = DateTime.now();
    inv.items.removeWhere((e) => e.isEmpty);
    return d.transaction((txn) async {
      int id;
      final map = inv.toMap()..remove('id');
      if (inv.id == null) {
        id = await txn.insert('invoices', map);
      } else {
        id = inv.id!;
        await txn.update('invoices', map, where: 'id = ?', whereArgs: [id]);
        await txn.delete('items', where: 'invoice_id = ?', whereArgs: [id]);
      }
      final batch = txn.batch();
      for (var i = 0; i < inv.items.length; i++) {
        final it = inv.items[i];
        final m = it.toMap(i)
          ..remove('id')
          ..['invoice_id'] = id;
        batch.insert('items', m);
      }
      await batch.commit(noResult: true);
      inv.id = id;
      return id;
    });
  }

  Future<void> deleteInvoice(int id) async {
    final d = await db;
    await d.delete('invoices', where: 'id = ?', whereArgs: [id]);
  }

  /// نسخ فاتورة كاملة برقم جديد.
  Future<int> duplicateInvoice(int id) async {
    final src = await getInvoice(id);
    if (src == null) throw StateError('الفاتورة غير موجودة');
    final copy = Invoice(
      kind: src.kind,
      status: InvoiceStatus.draft,
      number: await nextNumber(src.kind),
      party: src.party,
      notes: src.notes,
      currency: src.currency,
      vatRate: src.vatRate,
      items: src.items.map((e) => e.copy()..id = null).toList(),
    );
    return saveInvoice(copy);
  }

  /// الرقم التالي حسب إعدادات الترقيم: بادئة + رقم متسلسل بعدد خانات ثابت.
  Future<String> nextNumber([DocKind kind = DocKind.invoice]) async {
    final d = await db;
    final st = SettingsService.instance;
    final prefix =
        kind == DocKind.inventory ? st.inventoryPrefix : st.numberPrefix;
    final rows = await d.query('invoices', columns: ['number']);
    var max = st.numberStart - 1;
    for (final r in rows) {
      final n = (r['number'] as String).trim();
      if (!n.startsWith(prefix)) continue;
      final v = int.tryParse(n.substring(prefix.length));
      if (v != null && v > max) max = v;
    }
    return formatInvoiceNumber(prefix, max + 1, st.numberPadding);
  }
}

extension CatalogQueries on AppDatabase {
  /// أسماء العملاء/الموردين السابقة (للإكمال التلقائي).
  Future<List<String>> knownParties() async {
    final d = await db;
    final r = await d.rawQuery(
        "SELECT party FROM invoices WHERE party != '' GROUP BY party ORDER BY MAX(updated_at) DESC LIMIT 200");
    return r.map((e) => e['party'] as String).toList();
  }

  /// آخر استخدام لكل كود صنف: الوصف والسعر (كتالوج الأصناف المحفوظ تلقائياً).
  Future<Map<String, InvoiceItem>> itemCatalog() async {
    final d = await db;
    final r = await d.rawQuery(
        "SELECT i.item_code, i.ref_number, i.description, i.unit_price FROM items i "
        "JOIN (SELECT item_code, MAX(id) mid FROM items WHERE item_code != '' GROUP BY item_code) t ON i.id = t.mid");
    return {
      for (final m in r)
        m['item_code'] as String: InvoiceItem(
          itemCode: m['item_code'] as String,
          refNumber: (m['ref_number'] as String?) ?? '',
          description: (m['description'] as String?) ?? '',
          unitPrice: (m['unit_price'] as num?)?.toDouble() ?? 0,
        )
    };
  }
}

String formatInvoiceNumber(String prefix, int n, int padding) =>
    '$prefix${n.toString().padLeft(padding, '0')}';

extension PartyQueries on AppDatabase {
  Future<List<PartySummary>> listParties({String query = ''}) async {
    final d = await db;
    final q = query.trim();
    final rows = await d.query('parties',
        where: q.isEmpty ? null : 'name LIKE ? OR phone LIKE ?',
        whereArgs: q.isEmpty ? null : ['%$q%', '%$q%'],
        orderBy: 'name COLLATE NOCASE');
    final out = <PartySummary>[];
    for (final m in rows) {
      final p = Party.fromMap(m);
      final agg = await d.rawQuery(
          'SELECT COUNT(*) c, COALESCE(SUM(grand_total),0) t FROM invoices WHERE party = ?',
          [p.name]);
      out.add(PartySummary(p, (agg.first['c'] as int?) ?? 0,
          (agg.first['t'] as num?)?.toDouble() ?? 0));
    }
    return out;
  }

  /// الطرف المحفوظ بهذا الاسم (إن وُجد) لعرض هاتفه وعنوانه في الـ PDF.
  Future<Party?> partyByName(String name) async {
    final n = name.trim();
    if (n.isEmpty) return null;
    final d = await db;
    final rows = await d.query('parties',
        where: 'name = ? COLLATE NOCASE', whereArgs: [n], limit: 1);
    return rows.isEmpty ? null : Party.fromMap(rows.first);
  }

  Future<void> saveParty(Party p) async {
    final d = await db;
    final m = p.toMap()..remove('id');
    if (p.id == null) {
      p.id = await d.insert('parties', m, conflictAlgorithm: ConflictAlgorithm.replace);
    } else {
      await d.update('parties', m, where: 'id = ?', whereArgs: [p.id]);
    }
  }

  Future<void> deleteParty(int id) async {
    final d = await db;
    await d.delete('parties', where: 'id = ?', whereArgs: [id]);
  }

  /// أسماء العملاء: المحفوظون أولاً ثم الأسماء السابقة في الفواتير.
  Future<List<String>> partyNames() async {
    final d = await db;
    final saved = (await d.query('parties', columns: ['name'], orderBy: 'name COLLATE NOCASE'))
        .map((e) => e['name'] as String);
    final used = await knownParties();
    return {...saved, ...used}.toList();
  }
}
