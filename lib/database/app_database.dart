import 'dart:io' show Platform;

import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/invoice.dart';
import '../models/invoice_item.dart';

/// قاعدة بيانات SQLite المحلية (تعمل بدون إنترنت).
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  Future<Database> get db async => _db ??= await _open();

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
      version: 2,
      onUpgrade: (d, o, n) async {
        if (o < 2) {
          await d.execute("ALTER TABLE invoices ADD COLUMN status TEXT NOT NULL DEFAULT 'draft'");
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
      number: await nextNumber(),
      party: src.party,
      notes: src.notes,
      items: src.items.map((e) => e.copy()..id = null).toList(),
    );
    return saveInvoice(copy);
  }

  /// الرقم التالي: أكبر رقم عددي موجود + 1.
  Future<String> nextNumber() async {
    final d = await db;
    final rows = await d.query('invoices', columns: ['number']);
    var max = 0;
    for (final r in rows) {
      final n = int.tryParse((r['number'] as String).trim());
      if (n != null && n > max) max = n;
    }
    return '${max + 1}';
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
