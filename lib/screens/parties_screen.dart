import 'package:flutter/material.dart';
import '../widgets/empty_state.dart';

import '../database/app_database.dart';
import '../models/party.dart';
import '../services/settings_service.dart';
import '../utils/number_utils.dart';
import '../widgets/responsive.dart';

/// العملاء والموردون: إضافة وتعديل وحذف، مع عدد فواتير كل طرف وإجماليه.
class PartiesScreen extends StatefulWidget {
  const PartiesScreen({super.key});
  @override
  State<PartiesScreen> createState() => _PartiesScreenState();
}

class _PartiesScreenState extends State<PartiesScreen> {
  final _search = TextEditingController();
  List<PartySummary> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final l = await AppDatabase.instance.listParties(query: _search.text);
    if (!mounted) return;
    setState(() {
      _items = l;
      _loading = false;
    });
  }

  Future<void> _edit(Party? existing) async {
    final p = existing ?? Party(name: '');
    final name = TextEditingController(text: p.name);
    final phone = TextEditingController(text: p.phone);
    final addr = TextEditingController(text: p.address);
    final notes = TextEditingController(text: p.notes);
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(c).viewInsets.bottom + 16),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, autofocus: existing == null, decoration: const InputDecoration(labelText: 'الاسم')),
            const SizedBox(height: 10),
            TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'الجوال')),
            const SizedBox(height: 10),
            TextField(controller: addr, decoration: const InputDecoration(labelText: 'العنوان')),
            const SizedBox(height: 10),
            TextField(controller: notes, decoration: const InputDecoration(labelText: 'ملاحظات')),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('حفظ')),
            ),
          ]),
        ),
      ),
    );
    if (ok == true && name.text.trim().isNotEmpty) {
      p
        ..name = name.text.trim()
        ..phone = phone.text.trim()
        ..address = addr.text.trim()
        ..notes = notes.text.trim();
      await AppDatabase.instance.saveParty(p);
      _load();
    }
    for (final c in [name, phone, addr, notes]) {
      c.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cur = SettingsService.instance.currency;
    return Scaffold(
      appBar: AppBar(title: const Text('العملاء والموردون')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(null),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('إضافة'),
      ),
      body: ContentWidth(
        maxWidth: 760,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _search,
              onChanged: (_) => _load(),
              decoration: const InputDecoration(hintText: 'بحث بالاسم أو الجوال', prefixIcon: Icon(Icons.search)),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? const EmptyState(
                        title: 'لا يوجد عملاء أو موردون بعد',
                        hint: 'أضف عميلاً ليظهر اسمه ورقمه في الفواتير\nوتصلك تذكيرات السداد بضغطة.',
                        badge: Icons.person_add_alt_1)
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                        itemCount: _items.length,
                        itemBuilder: (_, i) {
                          final s = _items[i];
                          return Card(
                            child: ListTile(
                              minTileHeight: 64,
                              leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                              title: Text(s.party.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                              subtitle: Text([
                                if (s.party.phone.isNotEmpty) s.party.phone,
                                '${localizeDigits('${s.invoiceCount}')} فاتورة | ${formatMoney(s.total)} $cur',
                              ].join('  |  ')),
                              onTap: () => _edit(s.party),
                              trailing: IconButton(
                                tooltip: 'حذف',
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () async {
                                  await AppDatabase.instance.deleteParty(s.party.id!);
                                  _load();
                                },
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ]),
      ),
    );
  }
}
