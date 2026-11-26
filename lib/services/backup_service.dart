import 'dart:convert';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../app_info.dart';
import '../database/app_database.dart';

const backupFormat = 'daftar-backup';
const backupSchema = 1;

class BackupSummary {
  final int invoices, items, parties, recurring;
  const BackupSummary(this.invoices, this.items, this.parties, this.recurring);
}

/// نسخة احتياطية JSON كاملة: الفواتير والأصناف والعملاء والفواتير الدورية.
class BackupService {
  BackupService._();

  static Future<String> exportJson({DateTime? now}) async {
    final d = await AppDatabase.instance.db;
    Future<List<Map<String, Object?>>> all(String t) => d.query(t, orderBy: 'id');
    final data = {
      'format': backupFormat,
      'schema': backupSchema,
      'app': appName,
      'appVersion': appVersionName,
      'exportedAt': (now ?? DateTime.now()).toIso8601String(),
      'invoices': await all('invoices'),
      'items': await all('items'),
      'parties': await all('parties'),
      'recurring': await all('recurring'),
      'price_tiers': await all('price_tiers'),
    };
    return const JsonEncoder.withIndent(' ').convert(data);
  }

  /// يتحقق من الملف ويرمي FormatException برسالة عربية إذا لم يكن نسخة دفتر صالحة.
  static Map<String, Object?> parse(String text) {
    Object? j;
    try {
      j = jsonDecode(text);
    } catch (_) {
      throw const FormatException('الملف ليس بصيغة JSON صالحة');
    }
    if (j is! Map || j['format'] != backupFormat) {
      throw const FormatException('هذا الملف ليس نسخة احتياطية من دفتر');
    }
    final schema = j['schema'];
    if (schema is! int || schema > backupSchema) {
      throw const FormatException('النسخة أحدث من هذا الإصدار. حدّث التطبيق أولاً');
    }
    for (final k in ['invoices', 'items', 'parties', 'recurring']) {
      if (j[k] is! List) throw FormatException('النسخة ناقصة: $k');
    }
    final ids = {for (final r in j['invoices'] as List) if (r is Map) r['id']};
    for (final r in j['items'] as List) {
      if (r is! Map || !ids.contains(r['invoice_id'])) {
        throw const FormatException('النسخة تالفة: أصناف بلا فاتورة');
      }
    }
    return Map<String, Object?>.from(j);
  }

  static BackupSummary summarize(Map<String, Object?> b) => BackupSummary(
      (b['invoices'] as List).length,
      (b['items'] as List).length,
      (b['parties'] as List).length,
      (b['recurring'] as List).length);

  /// يستبدل كل البيانات الحالية بمحتوى النسخة في معاملة واحدة (إما يكتمل كله أو لا شيء).
  static Future<BackupSummary> restore(String text) async {
    final b = parse(text);
    final d = await AppDatabase.instance.db;
    await d.transaction((tx) async {
      for (final t in ['recurring', 'items', 'invoices', 'parties', 'price_tiers']) {
        await tx.delete(t);
      }
      for (final t in ['parties', 'invoices', 'items', 'recurring', 'price_tiers']) {
        for (final r in (b[t] as List? ?? const [])) {
          await tx.insert(t, Map<String, Object?>.from(r as Map),
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    });
    return summarize(b);
  }
}
