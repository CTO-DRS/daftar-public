import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../utils/reminder.dart';

import '../database/app_database.dart';
import '../models/invoice.dart';
import '../services/settings_service.dart';
import '../utils/platform_utils.dart';
import '../widgets/responsive.dart';
import '../utils/date_utils.dart';
import '../utils/number_utils.dart';
import 'invoice_editor_screen.dart';
import 'scan_flow.dart';
import 'parties_screen.dart';
import 'settings_screen.dart';

/// الشاشة الرئيسية: قائمة الفواتير وجداول الجرد.
class InvoicesListScreen extends StatefulWidget {
  const InvoicesListScreen({super.key});

  @override
  State<InvoicesListScreen> createState() => _InvoicesListScreenState();
}

class _InvoicesListScreenState extends State<InvoicesListScreen> {
  final _search = TextEditingController();
  List<InvoiceSummary> _items = [];
  bool _loading = true;

  Future<void> _remind(InvoiceSummary s) async {
    final inv = s.invoice;
    final party = await AppDatabase.instance.partyByName(inv.party);
    final rem = paymentRemaining(s.grandTotal, inv.paidAmount, inv.status);
    final text = reminderText(
      party: inv.party.isEmpty ? 'عميلنا الكريم' : inv.party,
      number: localizeDigits(inv.number),
      remaining: rem,
      currency: inv.currency,
      dueDate: inv.dueDate,
      now: DateTime.now(),
      company: SettingsService.instance.companyName,
    );
    final phone = waPhone(party?.phone ?? '');
    if (!mounted) return;
    final ok = await launchUrl(waUri(phone, text),
            mode: LaunchMode.externalApplication)
        .catchError((_) => false);
    if (!ok) await Share.share(text);
  }

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
    final list = await AppDatabase.instance.listInvoices(query: _search.text);
    if (!mounted) return;
    setState(() {
      _items = list;
      _loading = false;
    });
  }

  Future<void> _open(Invoice? inv, {DocKind kind = DocKind.invoice}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => InvoiceEditorScreen(invoiceId: inv?.id, newKind: kind)),
    );
    _load();
  }

  Future<void> _scan() async {
    final saved = await startScanFlow(context);
    if (saved) _load();
  }

  Future<void> _newDialog() async {
    final kind = await showModalBottomSheet<DocKind>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            minTileHeight: 56,
            leading: const Icon(Icons.receipt_long),
            title: const Text('فاتورة جديدة'),
            onTap: () => Navigator.pop(c, DocKind.invoice),
          ),
          ListTile(
            minTileHeight: 56,
            leading: const Icon(Icons.inventory_2_outlined),
            title: const Text('جدول جرد جديد'),
            onTap: () => Navigator.pop(c, DocKind.inventory),
          ),
        ]),
      ),
    );
    if (kind != null) _open(null, kind: kind);
  }

  Future<void> _delete(InvoiceSummary s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('حذف'),
        content: Text('حذف ${s.invoice.kind.label} رقم ${s.invoice.number}؟ لا يمكن التراجع.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('حذف')),
        ],
      ),
    );
    if (ok == true) {
      await AppDatabase.instance.deleteInvoice(s.invoice.id!);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cur = SettingsService.instance.currency;
    return Scaffold(
      appBar: AppBar(
        title: const Text('دفتر'),
        actions: [
          IconButton(
            tooltip: 'العملاء والموردون',
            icon: const Icon(Icons.people_outline),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const PartiesScreen())),
          ),
          IconButton(
            tooltip: 'الإعدادات',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: ContentWidth(
          child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            controller: _search,
            onChanged: (_) => _load(),
            decoration: const InputDecoration(
              hintText: 'بحث برقم الفاتورة أو اسم العميل',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _items.isEmpty
                  ? const _Empty()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 140),
                      itemCount: _items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final s = _items[i];
                        final inv = s.invoice;
                        return Card(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => _open(inv),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(children: [
                                CircleAvatar(
                                  backgroundColor: Theme.of(context)
                                      .colorScheme
                                      .primaryContainer,
                                  child: Icon(inv.kind == DocKind.invoice
                                      ? Icons.receipt_long
                                      : Icons.inventory_2_outlined),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${inv.kind.label} ${localizeDigits(inv.number)}'
                                        '${inv.party.isEmpty ? '' : ' - ${inv.party}'}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 16),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${inv.status.label}  |  ${formatDate(inv.date)}  |  ${localizeDigits('${s.itemCount}')} صنف  |  ${formatQty(s.totalQty)} قطعة',
                                        style: TextStyle(
                                            color: Colors.grey.shade700,
                                            fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('${formatMoney(s.grandTotal)} ${inv.currencyOr(cur)}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800)),
                                    if (inv.kind == DocKind.invoice &&
                                        s.grandTotal > 0)
                                      Builder(builder: (_) {
                                        final rem = paymentRemaining(
                                            s.grandTotal,
                                            inv.paidAmount,
                                            inv.status);
                                        final overdue = isOverdueFor(inv.kind,
                                            inv.dueDate, rem, s.grandTotal);
                                        if (rem <= 0.005) {
                                          return Text('مسددة',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.green.shade700));
                                        }
                                        return Text(
                                            '${overdue ? 'متأخرة · ' : ''}متبقي ${formatMoney(rem)}',
                                            style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: overdue
                                                    ? Colors.red.shade700
                                                    : Colors.orange.shade800));
                                      }),
                                    SizedBox(
                                      height: 40,
                                      child: PopupMenuButton<String>(
                                        onSelected: (v) async {
                                          if (v == 'del') {
                                            _delete(s);
                                          } else if (v == 'remind') {
                                            _remind(s);
                                          } else if (v == 'dup') {
                                            await AppDatabase.instance
                                                .duplicateInvoice(inv.id!);
                                            _load();
                                          }
                                        },
                                        itemBuilder: (_) => [
                                          if (inv.kind == DocKind.invoice &&
                                              paymentRemaining(s.grandTotal,
                                                      inv.paidAmount, inv.status) >
                                                  0.005)
                                            const PopupMenuItem(
                                                value: 'remind',
                                                child: Text('تذكير بالسداد (واتساب)')),
                                          const PopupMenuItem(
                                              value: 'dup', child: Text('نسخ')),
                                          const PopupMenuItem(
                                              value: 'del', child: Text('حذف')),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ]),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ])),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'scan',
            onPressed: _scan,
            icon: const Icon(Icons.document_scanner_outlined),
            label: Text(isMobilePlatform ? 'مسح بالكاميرا' : 'مسح صورة فاتورة'),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'new',
            onPressed: _newDialog,
            icon: const Icon(Icons.add),
            label: const Text('جديد'),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.receipt_long, size: 72, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text('لا توجد فواتير بعد', style: TextStyle(fontSize: 18)),
          const SizedBox(height: 4),
          Text('اضغط "جديد" أو امسح فاتورة ورقية بالكاميرا',
              style: TextStyle(color: Colors.grey.shade600)),
        ]),
      );
}
