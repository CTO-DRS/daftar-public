import 'package:flutter/material.dart';

import '../database/app_database.dart';
import '../utils/duplicates.dart';
import '../utils/number_utils.dart';

/// منظّف التكرارات: يكشف العملاء والأصناف المتشابهة ويدمجها بضغطة، مع تراجع.
class DuplicatesScreen extends StatefulWidget {
  const DuplicatesScreen({super.key});
  @override
  State<DuplicatesScreen> createState() => _DuplicatesScreenState();
}

class _DuplicatesScreenState extends State<DuplicatesScreen> with SingleTickerProviderStateMixin {
  late final _tabs = TabController(length: 2, vsync: this);
  List<DupGroup> _parties = [];
  List<DupGroup> _items = [];
  final _keep = <DupGroup, String>{};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final db = AppDatabase.instance;
    final p = findDuplicateGroups(await db.partyDupEntries());
    final i = findDuplicateGroups(await db.itemDupEntries(), byPhone: false, byCode: true);
    if (!mounted) return;
    setState(() {
      _parties = p;
      _items = i;
      _keep.clear();
      _loading = false;
    });
  }

  Future<void> _merge(DupGroup g, bool isParty) async {
    final keep = _keep[g] ?? g.entries.first.name;
    final from = [for (final e in g.entries) e.name];
    final db = AppDatabase.instance;
    final keepCode = g.entries.firstWhere((e) => e.name == keep).code;
    final undo = isParty
        ? await db.mergeParties(keep, from)
        : await db.mergeItems(keep, from, keepCode: keepCode);
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('دُمجت ${localizeDigits('${from.length}')} أسماء في «$keep»'),
      duration: const Duration(seconds: 12),
      action: SnackBarAction(
        label: 'تراجع',
        onPressed: () async {
          await db.undoMerge(undo);
          await _load();
        },
      ),
    ));
  }

  Widget _list(List<DupGroup> groups, bool isParty) {
    if (groups.isEmpty) {
      return Center(
          child: Text(isParty ? 'لا عملاء مكررين 👌' : 'لا أصناف مكررة 👌',
              key: const ValueKey('dup-none')));
    }
    return ListView(padding: const EdgeInsets.all(12), children: [
      for (final g in groups)
        Card(
          key: ValueKey('dup-${g.entries.first.name}'),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(g.reason, style: const TextStyle(fontSize: 12, color: Color(0xFF0F766E))),
              RadioGroup<String>(
                groupValue: _keep[g] ?? g.entries.first.name,
                onChanged: (v) => setState(() => _keep[g] = v!),
                child: Column(children: [
                  for (final e in g.entries)
                    RadioListTile<String>(
                      dense: true,
                      value: e.name,
                      title: Text(e.name),
                      subtitle: Text(
                          '${localizeDigits('${e.count}')} ${isParty ? 'فاتورة' : 'سطر'}'
                          '${e.phone.isNotEmpty ? ' • ${e.phone}' : ''}'
                          '${e.code.isNotEmpty ? ' • ${e.code}' : ''}'),
                    ),
                ]),
              ),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: FilledButton.icon(
                  key: ValueKey('merge-${g.entries.first.name}'),
                  onPressed: () => _merge(g, isParty),
                  icon: const Icon(Icons.merge_type),
                  label: Text('ادمج في «${_keep[g] ?? g.entries.first.name}»'),
                ),
              ),
            ]),
          ),
        ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('منظّف التكرارات'),
        bottom: TabBar(controller: _tabs, tabs: [
          Tab(text: 'العملاء (${localizeDigits('${_parties.length}')})'),
          Tab(text: 'الأصناف (${localizeDigits('${_items.length}')})'),
        ]),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                    'اختر الاسم الذي يبقى (الأكثر استخداماً مقترح)، فتنتقل إليه كل الفواتير. التراجع متاح بعد الدمج مباشرة.',
                    style: TextStyle(fontSize: 12)),
              ),
              Expanded(
                  child: TabBarView(controller: _tabs, children: [
                _list(_parties, true),
                _list(_items, false),
              ])),
            ]),
    );
  }
}
