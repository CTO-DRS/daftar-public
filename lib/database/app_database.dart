import 'dart:io' show Platform;

import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/invoice.dart';
import '../utils/forecast.dart';
import '../utils/quote_split.dart';
import '../utils/insights.dart';
import '../utils/pricing.dart';
import '../utils/recurrence.dart';
import '../models/invoice_item.dart';
import '../utils/smart_items.dart';
import '../utils/auto_fill.dart' show normArabic;
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

  static const _tombDdl = '''
    CREATE TABLE IF NOT EXISTS tombstones(
      entity TEXT NOT NULL,
      uid TEXT NOT NULL,
      ts INTEGER NOT NULL,
      PRIMARY KEY(entity, uid)
    )''';

  static const _tierSyncDdl = '''
    CREATE TABLE IF NOT EXISTS tier_sync(
      item_key TEXT PRIMARY KEY,
      updated_at INTEGER NOT NULL
    )''';

  static const _tiersDdl = '''
    CREATE TABLE IF NOT EXISTS price_tiers(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      item_key TEXT NOT NULL,
      min_qty REAL NOT NULL,
      price REAL NOT NULL
    )''';

  static const _auditDdl = '''
    CREATE TABLE IF NOT EXISTS audit_log(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      ts INTEGER NOT NULL,
      action TEXT NOT NULL,
      doc_id INTEGER,
      doc_number TEXT NOT NULL DEFAULT '',
      detail TEXT NOT NULL DEFAULT ''
    )''';

  static const _recurringDdl = '''
    CREATE TABLE IF NOT EXISTS recurring(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      invoice_id INTEGER NOT NULL,
      every TEXT NOT NULL,
      next_date INTEGER NOT NULL,
      active INTEGER NOT NULL DEFAULT 1
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
      version: 14,
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
        if (o < 8) {
          await d.execute("ALTER TABLE items ADD COLUMN unit TEXT NOT NULL DEFAULT ''");
        }
        if (o < 9) {
          await d.execute('ALTER TABLE items ADD COLUMN wholesale_qty REAL NOT NULL DEFAULT 0');
          await d.execute('ALTER TABLE items ADD COLUMN wholesale_price REAL NOT NULL DEFAULT 0');
          await d.execute("ALTER TABLE items ADD COLUMN wholesale_unit TEXT NOT NULL DEFAULT ''");
        }
        if (o < 14) {
          await d.execute(_tierSyncDdl);
        }
        if (o < 13) {
          await d.execute('ALTER TABLE invoices ADD COLUMN uid TEXT');
          await d.execute('ALTER TABLE parties ADD COLUMN uid TEXT');
          await d.execute('ALTER TABLE parties ADD COLUMN updated_at INTEGER NOT NULL DEFAULT 0');
          await d.execute(_tombDdl);
        }
        if (o < 12) {
          await d.execute('ALTER TABLE items ADD COLUMN cost_price REAL NOT NULL DEFAULT 0');
        }
        if (o < 11) {
          await d.execute(_auditDdl);
        }
        if (o < 10) {
          await d.execute('ALTER TABLE items ADD COLUMN pack_size REAL NOT NULL DEFAULT 0');
          await d.execute(_tiersDdl);
        }
        if (o < 7) {
          await d.execute(_recurringDdl);
          await d.execute("ALTER TABLE invoices ADD COLUMN note_type TEXT NOT NULL DEFAULT ''");
          await d.execute("ALTER TABLE invoices ADD COLUMN ref_number TEXT NOT NULL DEFAULT ''");
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
            uid TEXT,
            due_date INTEGER,
            paid_amount REAL NOT NULL DEFAULT 0,
            currency TEXT NOT NULL DEFAULT '',
            vat_rate REAL NOT NULL DEFAULT 0,
            note_type TEXT NOT NULL DEFAULT '',
            ref_number TEXT NOT NULL DEFAULT '',
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
            notes TEXT NOT NULL DEFAULT '',
            unit TEXT NOT NULL DEFAULT '',
            wholesale_qty REAL NOT NULL DEFAULT 0,
            wholesale_price REAL NOT NULL DEFAULT 0,
            wholesale_unit TEXT NOT NULL DEFAULT '',
            pack_size REAL NOT NULL DEFAULT 0,
            cost_price REAL NOT NULL DEFAULT 0
          )''');
        await d.execute(_tiersDdl);
        await d.execute(_auditDdl);
        await d.execute(_partiesDdl);
        await d.execute('ALTER TABLE parties ADD COLUMN uid TEXT');
        await d.execute('ALTER TABLE parties ADD COLUMN updated_at INTEGER NOT NULL DEFAULT 0');
        await d.execute(_tombDdl);
        await d.execute(_tierSyncDdl);
        await d.execute(_recurringDdl);
        await d.execute('CREATE INDEX idx_items_invoice ON items(invoice_id, position)');
      },
      ),
    );
  }

  /// شرائح أسعار صنف (حسب الكمية)، مرتبة بالكمية.
  Future<List<PriceTier>> tiersFor(String key) async {
    final d = await db;
    final r = await d.query('price_tiers', where: 'item_key = ?', whereArgs: [key], orderBy: 'min_qty');
    return r
        .map((m) => PriceTier((m['min_qty'] as num).toDouble(), (m['price'] as num).toDouble()))
        .toList();
  }

  /// يستبدل شرائح الصنف بالقائمة الجديدة (قائمة فارغة = حذف الشرائح).
  Future<void> saveTiers(String key, List<PriceTier> tiers) async {
    final d = await db;
    await d.transaction((tx) async {
      await tx.delete('price_tiers', where: 'item_key = ?', whereArgs: [key]);
      for (final t in tiers) {
        if (t.minQty > 0 && t.price > 0) {
          await tx.insert('price_tiers', {'item_key': key, 'min_qty': t.minQty, 'price': t.price});
        }
      }
      await tx.insert('tier_sync', {'item_key': key, 'updated_at': DateTime.now().millisecondsSinceEpoch},
          conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  /// مبيعات الأصناف (حسب الوصف) من الفواتير المعتمدة فقط، الأعلى إيراداً أولاً.
  /// الإشعار الدائن يطرح والمدين يضيف.
  Future<List<ProductSales>> topProducts({int limit = 5, String currency = ''}) async {
    final d = await db;
    final rows = await d.rawQuery('''
      SELECT TRIM(i.description) AS name,
             SUM(CASE WHEN v.note_type = 'credit' THEN -i.quantity ELSE i.quantity END) AS qty,
             SUM(CASE WHEN v.note_type = 'credit' THEN -1 ELSE 1 END * (i.quantity * i.unit_price + i.wholesale_qty * i.wholesale_price)) AS revenue
      FROM items i JOIN invoices v ON v.id = i.invoice_id
      WHERE v.kind = 'invoice' AND v.status != 'draft' AND TRIM(i.description) != ''
        AND (? = '' OR v.currency = '' OR v.currency = ?)
      GROUP BY LOWER(TRIM(i.description))
      HAVING revenue > 0
      ORDER BY revenue DESC LIMIT ?
    ''', [currency, currency, limit]);
    return rows
        .map((m) => ProductSales((m['name'] as String?) ?? '',
            (m['qty'] as num?)?.toDouble() ?? 0, (m['revenue'] as num?)?.toDouble() ?? 0))
        .toList();
  }

  /// ملخص الربح من [from] حتى الآن: المبيعات، الربح، ومبيعات الأسطر التي لها تكلفة.
  /// الفواتير المعتمدة فقط؛ الإشعار الدائن يطرح والمدين يضيف.
  Future<ProfitSummary> profitSince(DateTime from, {String currency = ''}) async {
    final d = await db;
    final rows = await d.rawQuery('''
      SELECT
        SUM(sgn * rev) AS sales,
        SUM(CASE WHEN cost_price > 0 THEN sgn * rev ELSE 0 END) AS costed_sales,
        SUM(CASE WHEN cost_price > 0 THEN sgn * (rev - cost_price * (quantity + wholesale_qty * CASE WHEN pack_size > 0 THEN pack_size ELSE 1 END)) ELSE 0 END) AS profit,
        COUNT(DISTINCT invoice_id) AS docs
      FROM (
        SELECT i.*, v.id AS invoice_id,
               CASE WHEN v.note_type = 'credit' THEN -1 ELSE 1 END AS sgn,
               (i.quantity * i.unit_price + i.wholesale_qty * i.wholesale_price) AS rev
        FROM items i JOIN invoices v ON v.id = i.invoice_id
        WHERE v.kind = 'invoice' AND v.status != 'draft' AND v.date >= ?
          AND (? = '' OR v.currency = '' OR v.currency = ?)
      )
    ''', [from.millisecondsSinceEpoch, currency, currency]);
    final m = rows.first;
    double n(String k) => (m[k] as num?)?.toDouble() ?? 0;
    return ProfitSummary(n('sales'), n('costed_sales'), n('profit'), (m['docs'] as num?)?.toInt() ?? 0);
  }

  /// مجموع المصروفات منذ [from] (كل مستندات المصروف المسجّلة).
  Future<double> expensesSince(DateTime from, {String currency = ''}) async {
    final d = await db;
    final r = await d.rawQuery('''
      SELECT SUM(grand_total) AS t FROM invoices
      WHERE kind = 'expense' AND date >= ?
        AND (? = '' OR currency = '' OR currency = ?)
    ''', [from.millisecondsSinceEpoch, currency, currency]);
    return (r.first['t'] as num?)?.toDouble() ?? 0;
  }

  /// توقع نفاد المخزون: آخر جرد لكل صنف ناقص مبيعاته بعده.
  Future<List<StockForecast>> stockForecast(DateTime now) async {
    final d = await db;
    final c = await d.rawQuery('''
      SELECT LOWER(TRIM(i.description)) AS k, TRIM(i.description) AS name,
             (i.quantity + i.wholesale_qty * CASE WHEN i.pack_size > 0 THEN i.pack_size ELSE 1 END) AS qty,
             v.date AS date
      FROM items i JOIN invoices v ON v.id = i.invoice_id
      WHERE v.kind = 'inventory' AND TRIM(i.description) != ''
    ''');
    final s = await d.rawQuery('''
      SELECT LOWER(TRIM(i.description)) AS k,
             (CASE WHEN v.note_type = 'credit' THEN -1 ELSE 1 END) *
             (i.quantity + i.wholesale_qty * CASE WHEN i.pack_size > 0 THEN i.pack_size ELSE 1 END) AS pieces,
             v.date AS date
      FROM items i JOIN invoices v ON v.id = i.invoice_id
      WHERE v.kind = 'invoice' AND v.status != 'draft' AND TRIM(i.description) != ''
    ''');
    DateTime dt(Object? v) => DateTime.fromMillisecondsSinceEpoch((v as int?) ?? 0);
    return computeStockForecast(
      [for (final m in c) CountRow(m['k'] as String, m['name'] as String, (m['qty'] as num).toDouble(), dt(m['date']))],
      [for (final m in s) SaleRow(m['k'] as String, (m['pieces'] as num).toDouble(), dt(m['date']))],
      now,
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
    String? before;
    if (inv.id != null) {
      final r = await d.query('invoices',
          columns: ['grand_total', 'status', 'party'],
          where: 'id = ?',
          whereArgs: [inv.id]);
      if (r.isNotEmpty) {
        before =
            '${(r.first['grand_total'] as num?)?.toStringAsFixed(2)}|${r.first['status']}|${r.first['party']}';
      }
    }
    final newId = await d.transaction((txn) async {
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
    final after =
        '${inv.grandTotal.toStringAsFixed(2)}|${inv.status.name}|${inv.party}';
    if (before == null) {
      await logAudit('create', newId, inv.number,
          'الإجمالي ${inv.grandTotal.toStringAsFixed(2)} • ${inv.party}');
    } else if (before != after) {
      final b = before.split('|');
      final parts = <String>[];
      if (b[0] != inv.grandTotal.toStringAsFixed(2)) {
        parts.add('الإجمالي ${b[0]} ← ${inv.grandTotal.toStringAsFixed(2)}');
      }
      if (b[1] != inv.status.name) {
        parts.add('الحالة ${b[1]} ← ${inv.status.name}');
      }
      if (b.length > 2 && b.sublist(2).join('|') != inv.party) {
        parts.add('العميل ${b.sublist(2).join('|')} ← ${inv.party}');
      }
      await logAudit('edit', newId, inv.number, parts.join(' • '));
    }
    return newId;
  }

  Future<void> logAudit(String action, int? docId, String number,
      [String detail = '']) async {
    final d = await db;
    await d.insert('audit_log', {
      'ts': DateTime.now().millisecondsSinceEpoch,
      'action': action,
      'doc_id': docId,
      'doc_number': number,
      'detail': detail,
    });
  }

  Future<List<Map<String, Object?>>> auditEntries({int limit = 300}) async {
    final d = await db;
    return d.query('audit_log', orderBy: 'id DESC', limit: limit);
  }

  /// سجل حذف للمزامنة (فقط لما سبق رفعه أي له uid).
  Future<void> _tomb(Database d, String entity, String? uid) async {
    if (uid == null || uid.isEmpty) return;
    await d.insert('tombstones',
        {'entity': entity, 'uid': uid, 'ts': DateTime.now().millisecondsSinceEpoch},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteInvoice(int id) async {
    final d = await db;
    final r = await d.query('invoices',
        columns: ['number', 'grand_total', 'uid'], where: 'id = ?', whereArgs: [id]);
    await d.delete('invoices', where: 'id = ?', whereArgs: [id]);
    await _tomb(d, 'invoice', r.isEmpty ? null : r.first['uid'] as String?);
    if (r.isNotEmpty) {
      await logAudit('delete', id, (r.first['number'] as String?) ?? '',
          'الإجمالي ${(r.first['grand_total'] as num?)?.toStringAsFixed(2)}');
    }
  }

  /// نسخ فاتورة كاملة برقم جديد.
  Future<int> duplicateInvoice(int id) async {
    final src = await getInvoice(id);
    if (src == null) throw StateError('الفاتورة غير موجودة');
    final copy = Invoice(
      kind: src.kind,
      status: InvoiceStatus.draft,
      number: await nextNumber(src.kind, src.isNote ? (src.noteType == 'credit' ? 'CN-' : 'DN-') : null),
      party: src.party,
      notes: src.notes,
      currency: src.currency,
      vatRate: src.vatRate,
      noteType: src.noteType,
      refNumber: src.refNumber,
      items: src.items.map((e) => e.copy()..id = null).toList(),
    );
    return saveInvoice(copy);
  }

  /// تحويل جزئي لعرض سعر: ينشئ فاتورة (مسودة) بالأسطر المختارة ويبقي الباقي في العرض.
  /// [chosen]: فهرس السطر ← الكمية المطلوب تحويلها. يعيد رقم الفاتورة الجديدة.
  Future<int> convertQuote(int quoteId, Map<int, double> chosen) async {
    final q = await getInvoice(quoteId);
    if (q == null || q.kind != DocKind.quote) throw StateError('عرض السعر غير موجود');
    final split = splitQuote(q.items, chosen);
    if (split.converted.isEmpty) throw StateError('لم يتم اختيار أي سطر');
    final inv = Invoice(
      kind: DocKind.invoice,
      number: await nextNumber(DocKind.invoice),
      party: q.party,
      notes: 'من عرض السعر ${q.number}',
      currency: q.currency,
      vatRate: q.vatRate,
      items: split.converted,
    );
    final id = await saveInvoice(inv);
    q.items = split.remaining;
    q.notes = q.notes.isEmpty
        ? 'حُوّل جزئياً إلى ${inv.number}'
        : '${q.notes}\nحُوّل جزئياً إلى ${inv.number}';
    if (q.items.isEmpty) q.status = InvoiceStatus.paid; // مُنجز بالكامل
    await saveInvoice(q);
    return id;
  }

  /// إشعار دائن/مدين بنقرة واحدة من فاتورة قائمة (مسودة بنفس الأسطر للمراجعة).
  Future<int> createNote(int id, String type) async {
    final src = await getInvoice(id);
    if (src == null) throw StateError('الفاتورة غير موجودة');
    final credit = type == 'credit';
    final note = Invoice(
      kind: DocKind.invoice,
      status: InvoiceStatus.draft,
      number: await nextNumber(DocKind.invoice, credit ? 'CN-' : 'DN-'),
      party: src.party,
      notes: '${credit ? 'إشعار دائن' : 'إشعار مدين'} عن الفاتورة رقم ${src.number}',
      currency: src.currency,
      vatRate: src.vatRate,
      noteType: type,
      refNumber: src.number,
      items: src.items.map((e) => e.copy()..id = null).toList(),
    );
    return saveInvoice(note);
  }

  Future<void> addRecurring(int invoiceId, Recurrence every, DateTime next) async {
    final d = await db;
    await d.insert('recurring', {
      'invoice_id': invoiceId,
      'every': every.name,
      'next_date': next.millisecondsSinceEpoch,
      'active': 1,
    });
  }

  Future<void> deleteRecurring(int id) async {
    final d = await db;
    await d.delete('recurring', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<RecurringInfo>> listRecurring() async {
    final d = await db;
    final r = await d.rawQuery('''
      SELECT r.id, r.every, r.next_date, i.number, i.party
      FROM recurring r JOIN invoices i ON i.id = r.invoice_id
      ORDER BY r.next_date ASC''');
    return r
        .map((m) => RecurringInfo(
              id: m['id'] as int,
              every: RecurrenceX.fromDb(m['every'] as String?),
              next: DateTime.fromMillisecondsSinceEpoch(m['next_date'] as int),
              number: m['number'] as String,
              party: m['party'] as String,
            ))
        .toList();
  }

  /// ينشئ مسودات للفواتير الدورية المستحقة (عند فتح التطبيق). يعيد عدد المسودات.
  /// تُحذف القوالب التي حُذفت فاتورتها الأصلية. أقصى 3 مسودات فائتة لكل قالب.
  Future<int> generateDueRecurring(DateTime now) async {
    final d = await db;
    await d.execute(
        'DELETE FROM recurring WHERE invoice_id NOT IN (SELECT id FROM invoices)');
    final rows = await d.query('recurring',
        where: 'active = 1 AND next_date <= ?',
        whereArgs: [now.millisecondsSinceEpoch]);
    var created = 0;
    for (final r in rows) {
      var next = DateTime.fromMillisecondsSinceEpoch(r['next_date'] as int);
      final every = RecurrenceX.fromDb(r['every'] as String?);
      final src = await getInvoice(r['invoice_id'] as int);
      if (src == null) continue;
      final offset = src.dueDate?.difference(src.date);
      var made = 0;
      while (!next.isAfter(now)) {
        if (made < 3) {
          final id = await duplicateInvoice(src.id!);
          final c = (await getInvoice(id))!;
          c.date = next;
          c.dueDate = offset == null ? null : next.add(offset);
          await saveInvoice(c);
          made++;
          created++;
        }
        next = nextOccurrence(next, every);
      }
      await d.update('recurring', {'next_date': next.millisecondsSinceEpoch},
          where: 'id = ?', whereArgs: [r['id']]);
    }
    return created;
  }

  /// الرقم التالي حسب إعدادات الترقيم: بادئة + رقم متسلسل بعدد خانات ثابت.
  Future<String> nextNumber([DocKind kind = DocKind.invoice, String? prefix]) async {
    final d = await db;
    final st = SettingsService.instance;
    prefix ??= switch (kind) {
      DocKind.inventory => st.inventoryPrefix,
      DocKind.quote => 'QT-',
      DocKind.expense => 'EXP-',
      DocKind.invoice => st.numberPrefix,
    };
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
  /// آخر استخدام لكل صنف بالاسم (الوصف) ← بياناته: للإكمال التلقائي بعد المسح.
  Future<Map<String, InvoiceItem>> itemHistory() async {
    final d = await db;
    final r = await d.rawQuery(
        "SELECT i.* FROM items i JOIN invoices v ON v.id = i.invoice_id "
        "JOIN (SELECT MAX(i2.id) mid FROM items i2 JOIN invoices v2 ON v2.id = i2.invoice_id "
        "WHERE TRIM(i2.description) != '' AND v2.kind IN ('invoice','quote') "
        "GROUP BY LOWER(TRIM(i2.description))) t ON i.id = t.mid");
    return {for (final m in r) (m['description'] as String).trim(): InvoiceItem.fromMap(m)};
  }

  /// كل صنف بالاسم مع آخر نسخة منه وعدد مرات استخدامه (للاقتراحات الذكية).
  Future<List<ItemStat>> itemStats() async {
    final d = await db;
    final r = await d.rawQuery(
        "SELECT i.*, t.cnt AS cnt FROM items i "
        "JOIN (SELECT MAX(i2.id) mid, COUNT(*) cnt FROM items i2 JOIN invoices v2 ON v2.id = i2.invoice_id "
        "WHERE TRIM(i2.description) != '' AND v2.kind IN ('invoice','quote') "
        "GROUP BY LOWER(TRIM(i2.description))) t ON i.id = t.mid");
    return [
      for (final m in r)
        ItemStat(InvoiceItem.fromMap(m), (m['cnt'] as num?)?.toInt() ?? 1)
    ];
  }

  /// آخر سعر بيع لكل صنف (بالاسم المطبّع) لعميل معيّن.
  Future<Map<String, double>> customerPrices(String party) async {
    final p = party.trim();
    if (p.isEmpty) return {};
    final d = await db;
    final r = await d.rawQuery(
        "SELECT i.description, i.unit_price FROM items i JOIN invoices v ON v.id = i.invoice_id "
        "WHERE v.party = ? AND v.kind IN ('invoice','quote') AND i.unit_price > 0 "
        "AND TRIM(i.description) != '' ORDER BY i.id ASC",
        [p]);
    final out = <String, double>{};
    for (final m in r) {
      out[normArabic(m['description'] as String)] =
          (m['unit_price'] as num).toDouble();
    }
    return out;
  }

  /// أكثر الأصناف التي يطلبها هذا العميل (الأكثر تكراراً ثم الأحدث)، بآخر سعر وكمية له.
  Future<List<InvoiceItem>> usualItems(String party,
      {int limit = 5, int? excludeInvoiceId}) async {
    final p = party.trim();
    if (p.isEmpty) return [];
    final d = await db;
    final r = await d.rawQuery(
        "SELECT i.* FROM items i JOIN invoices v ON v.id = i.invoice_id "
        "WHERE v.party = ? AND v.kind = 'invoice' AND TRIM(i.description) != '' "
        "AND (? IS NULL OR v.id != ?) ORDER BY i.id ASC",
        [p, excludeInvoiceId, excludeInvoiceId]);
    final count = <String, int>{};
    final last = <String, InvoiceItem>{};
    final lastId = <String, int>{};
    for (final m in r) {
      final it = InvoiceItem.fromMap(m);
      final k = normArabic(it.description);
      count[k] = (count[k] ?? 0) + 1;
      last[k] = it;
      lastId[k] = it.id ?? 0;
    }
    final keys = count.keys.toList()
      ..sort((a, b) {
        final c = count[b]!.compareTo(count[a]!);
        return c != 0 ? c : lastId[b]!.compareTo(lastId[a]!);
      });
    return [for (final k in keys.take(limit)) last[k]!.copy()..id = null..invoiceId = null];
  }

  /// أسطر آخر فاتورة لهذا العميل (نسخ جديدة بدون معرّفات) لزر «كرر آخر فاتورة».
  Future<List<InvoiceItem>> lastInvoiceItems(String party,
      {int? excludeInvoiceId}) async {
    final p = party.trim();
    if (p.isEmpty) return [];
    final d = await db;
    final r = await d.rawQuery(
        "SELECT id FROM invoices WHERE party = ? AND kind = 'invoice' "
        "AND (? IS NULL OR id != ?) ORDER BY id DESC LIMIT 1",
        [p, excludeInvoiceId, excludeInvoiceId]);
    if (r.isEmpty) return [];
    final inv = await getInvoice(r.first['id'] as int);
    if (inv == null) return [];
    return [for (final e in inv.items) e.copy()..id = null..invoiceId = null..flagged = false];
  }

  /// آخر فواتير العميل (الأحدث أولاً) لاستنتاج القيم المعتادة.
  Future<List<Invoice>> recentInvoicesForParty(String party,
      {int limit = 10, int? excludeInvoiceId}) async {
    final p = party.trim();
    if (p.isEmpty) return [];
    final d = await db;
    final r = await d.rawQuery(
        "SELECT id FROM invoices WHERE party = ? AND kind = 'invoice' "
        "AND (? IS NULL OR id != ?) ORDER BY id DESC LIMIT ?",
        [p, excludeInvoiceId, excludeInvoiceId, limit]);
    final out = <Invoice>[];
    for (final m in r) {
      final inv = await getInvoice(m['id'] as int);
      if (inv != null) out.add(inv);
    }
    return out;
  }

  Future<Map<String, InvoiceItem>> itemCatalog() async {
    final d = await db;
    final r = await d.rawQuery(
        "SELECT i.item_code, i.ref_number, i.description, i.unit_price, i.cost_price FROM items i "
        "JOIN (SELECT item_code, MAX(id) mid FROM items WHERE item_code != '' GROUP BY item_code) t ON i.id = t.mid");
    return {
      for (final m in r)
        m['item_code'] as String: InvoiceItem(
          itemCode: m['item_code'] as String,
          refNumber: (m['ref_number'] as String?) ?? '',
          description: (m['description'] as String?) ?? '',
          unitPrice: (m['unit_price'] as num?)?.toDouble() ?? 0,
          costPrice: (m['cost_price'] as num?)?.toDouble() ?? 0,
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
    final m = p.toMap()
      ..remove('id')
      ..['updated_at'] = DateTime.now().millisecondsSinceEpoch;
    if (p.id == null) {
      p.id = await d.insert('parties', m, conflictAlgorithm: ConflictAlgorithm.replace);
    } else {
      await d.update('parties', m, where: 'id = ?', whereArgs: [p.id]);
    }
  }

  Future<void> deleteParty(int id) async {
    final d = await db;
    final r = await d.query('parties', columns: ['uid'], where: 'id = ?', whereArgs: [id]);
    await d.delete('parties', where: 'id = ?', whereArgs: [id]);
    await _tomb(d, 'customer', r.isEmpty ? null : r.first['uid'] as String?);
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

class RecurringInfo {
  final int id;
  final Recurrence every;
  final DateTime next;
  final String number;
  final String party;
  RecurringInfo(
      {required this.id,
      required this.every,
      required this.next,
      required this.number,
      required this.party});
}

class ProfitSummary {
  final double sales, costedSales, profit;
  final int docs;
  const ProfitSummary(this.sales, this.costedSales, this.profit, this.docs);
  double get margin => costedSales > 0 ? profit / costedSales : 0;
  bool get hasCosts => costedSales > 0;
}
