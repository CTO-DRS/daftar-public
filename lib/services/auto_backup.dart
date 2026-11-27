import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../database/app_database.dart';
import 'backup_service.dart';
import 'settings_service.dart';

/// نسخ احتياطي تلقائي يومي داخل مجلد التطبيق، يحتفظ بآخر [keep] نسخة.
/// لا يعمل إذا كانت البيانات فارغة. ملاحظة: يُحذف مع حذف التطبيق، فالمزامنة
/// السحابية أو "تصدير نسخة" هما الحماية من فقدان الجهاز.
class AutoBackup {
  AutoBackup._();
  static const prefix = 'auto-';

  static String nameFor(DateTime d) =>
      '$prefix${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}.json';

  static Future<Directory> defaultDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'backups'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// الملفات من الأحدث للأقدم.
  static Future<List<File>> list([Directory? dir]) async {
    final d = dir ?? await defaultDir();
    final files = d
        .listSync()
        .whereType<File>()
        .where((f) => p.basename(f.path).startsWith(prefix))
        .toList()
      ..sort((a, b) => p.basename(b.path).compareTo(p.basename(a.path)));
    return files;
  }

  /// ينشئ نسخة اليوم إن لم توجد. يعيد الملف الجديد أو null.
  static Future<File?> runIfDue({Directory? dir, DateTime? now, int keep = 7}) async {
    if (!SettingsService.instance.autoBackup) return null;
    final t = now ?? DateTime.now();
    final d = dir ?? await defaultDir();
    final file = File(p.join(d.path, nameFor(t)));
    if (await file.exists()) return null;
    final db = await AppDatabase.instance.db;
    final n = (await db.rawQuery('SELECT (SELECT COUNT(*) FROM invoices) + (SELECT COUNT(*) FROM parties) AS c'))
        .first['c'] as int;
    if (n == 0) return null;
    await file.writeAsString(await BackupService.exportJson(now: t), flush: true);
    final all = await list(d);
    for (final old in all.skip(keep)) {
      try {
        await old.delete();
      } catch (_) {}
    }
    return file;
  }
}
