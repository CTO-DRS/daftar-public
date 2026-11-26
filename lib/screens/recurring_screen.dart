import 'package:flutter/material.dart';

import '../database/app_database.dart';
import '../utils/date_utils.dart';
import '../utils/number_utils.dart';
import '../utils/recurrence.dart';

/// الفواتير الدورية: تُنشأ مسودة جديدة تلقائياً عند فتح التطبيق بعد حلول الموعد.
class RecurringScreen extends StatefulWidget {
  const RecurringScreen({super.key});

  @override
  State<RecurringScreen> createState() => _RecurringScreenState();
}

class _RecurringScreenState extends State<RecurringScreen> {
  List<RecurringInfo> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final l = await AppDatabase.instance.listRecurring();
    if (mounted) setState(() => _items = l);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الفواتير الدورية')),
      body: _items.isEmpty
          ? const Center(
              child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                  'لا توجد فواتير دورية. من قائمة أي فاتورة اختر «جعلها دورية».',
                  textAlign: TextAlign.center),
            ))
          : ListView.separated(
              itemCount: _items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final r = _items[i];
                return ListTile(
                  leading: const Icon(Icons.autorenew),
                  title: Text(
                      'من الفاتورة ${localizeDigits(r.number)}${r.party.isEmpty ? '' : ' · ${r.party}'}'),
                  subtitle: Text(
                      '${r.every.label} · الموعد القادم ${formatDate(r.next)}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'إيقاف',
                    onPressed: () async {
                      await AppDatabase.instance.deleteRecurring(r.id);
                      _load();
                    },
                  ),
                );
              },
            ),
    );
  }
}
