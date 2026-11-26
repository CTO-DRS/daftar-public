import 'package:flutter/material.dart';
import '../database/app_database.dart';
import '../utils/number_utils.dart';

/// سجل التدقيق: كل إنشاء وتعديل وحذف للمستندات مع الوقت.
class AuditScreen extends StatelessWidget {
  const AuditScreen({super.key});

  static const _labels = {
    'create': ('إنشاء', Icons.add_circle_outline),
    'edit': ('تعديل', Icons.edit_outlined),
    'delete': ('حذف', Icons.delete_outline),
  };

  String _when(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    String t(int v) => v.toString().padLeft(2, '0');
    return localizeDigits(
        '${d.year}-${t(d.month)}-${t(d.day)}  ${t(d.hour)}:${t(d.minute)}');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('سجل التدقيق')),
      body: FutureBuilder<List<Map<String, Object?>>>(
        future: AppDatabase.instance.auditEntries(),
        builder: (c, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = snap.data!;
          if (rows.isEmpty) {
            return const Center(child: Text('لا توجد عمليات مسجلة بعد'));
          }
          return ListView.separated(
            itemCount: rows.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (c, i) {
              final r = rows[i];
              final l = _labels[r['action']] ??
                  (r['action'] as String, Icons.history);
              final isDel = r['action'] == 'delete';
              return ListTile(
                leading: Icon(l.$2, color: isDel ? cs.error : cs.primary),
                title: Text('${l.$1} • ${r['doc_number'] ?? ''}'),
                subtitle: Text(
                    '${_when(r['ts'] as int)}\n${r['detail'] ?? ''}'.trim()),
                isThreeLine: ((r['detail'] as String?) ?? '').isNotEmpty,
              );
            },
          );
        },
      ),
    );
  }
}
