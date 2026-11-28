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
import 'quick_invoice_screen.dart';
import '../services/sync_service.dart';
import '../services/share_service.dart';
import '../services/auto_backup.dart';
import '../utils/forecast.dart';
import '../utils/reorder.dart';
import '../utils/collection.dart';
import 'ask_screen.dart';
import '../utils/digest.dart';
import '../utils/customer_defaults.dart';
import 'scan_flow.dart';
import 'parties_screen.dart';
import 'insights_screen.dart';
import 'recurring_screen.dart';
import '../utils/recurrence.dart';
import '../utils/dashboard.dart';
import '../widgets/dashboard_header.dart';
import '../widgets/empty_state.dart';
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
  List<CollectionCase> _collect = [];
  WeeklyDigest? _digest;
  Map<String, ShareView> _views = {};
  List<StockForecast> _low = [];
  List<ReorderDue> _reorder = [];
  Map<int, String> _uids = {};
  bool _loading = true;
  DashboardStats? _stats;

  Future<void> _followUpSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('مساعد التحصيل: لمن أطالب أولاً؟',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ),
          for (final k in _collect)
            ListTile(
              key: ValueKey('collect-${k.party}'),
              leading: CircleAvatar(
                backgroundColor: k.risk >= 70
                    ? Colors.red.shade100
                    : k.risk >= 40
                        ? Colors.orange.shade100
                        : Colors.green.shade100,
                child: Text(localizeDigits('${k.risk}'),
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
              title: Text(k.party),
              subtitle: Text(
                  '${formatMoney(k.total)} • ${localizeDigits('${k.invoices.length}')} فواتير • أقدمها ${localizeDigits('${k.maxLateDays}')} يوماً • رسالة ${k.tone.label}'
                  '${k.bestWeekday != null ? '\nيسدد عادةً يوم ${weekdayNameAr(k.bestWeekday!)}' : ''}'
                  '${k.usualDaysToPay != null ? ' (حوالي ${localizeDigits('${k.usualDaysToPay}')} يوماً)' : ''}'),
              isThreeLine: k.bestWeekday != null,
              trailing: const Icon(Icons.send_outlined),
              onTap: () async {
                Navigator.pop(c);
                await _remindCase(k);
                for (final s in k.invoices) {
                  SettingsService.instance.markReminded(s.invoice.number);
                }
                _load();
              },
            ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('الرقم هو درجة الخطورة (٠ إلى ١٠٠) من تأخر الفواتير وسجل السداد. السجل تقريبي لأن التطبيق لا يحفظ تواريخ الدفعات. بعد التذكير يختفي العميل 3 أيام.',
                style: TextStyle(fontSize: 12)),
          ),
        ]),
      ),
    );
  }

  Future<void> _remindCase(CollectionCase k) async {
    final party = await AppDatabase.instance.partyByName(k.party);
    final text = collectionText(k, company: SettingsService.instance.companyName);
    final phone = waPhone(party?.phone ?? '');
    if (!mounted) return;
    final ok = await launchUrl(waUri(phone, text), mode: LaunchMode.externalApplication)
        .catchError((_) => false);
    if (!ok) await Share.share(text);
  }

  Future<void> _newFromLast(ReorderDue r) async {
    final db = AppDatabase.instance;
    final items = await db.lastInvoiceItems(r.party);
    final d = computeDefaults(await db.recentInvoicesForParty(r.party));
    final inv = Invoice(
      number: await db.nextNumber(),
      party: r.party,
      items: items,
      vatRate: d.vatRate ?? SettingsService.instance.defaultVatRate,
      currency: d.currency ?? '',
    );
    if (d.dueDays != null) {
      final t = DateTime.now();
      inv.dueDate = DateTime(t.year, t.month, t.day).add(Duration(days: d.dueDays!));
    }
    if (!mounted) return;
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => InvoiceEditorScreen(draft: inv)));
    _load();
  }

  Future<void> _reorderSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('حان وقت طلبهم المعتاد',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ),
          for (final r in _reorder)
            ListTile(
              key: ValueKey('reorder-${r.party}'),
              title: Text(r.party),
              subtitle: Text(
                  'يطلب كل ~${localizeDigits('${r.intervalDays}')} يوم • آخر طلب قبل ${localizeDigits('${r.daysSince}')} يوم'),
              leading: const Icon(Icons.replay_circle_filled_outlined),
              trailing: TextButton(
                  onPressed: () {
                    SettingsService.instance.snoozeReorder(r.party);
                    Navigator.pop(c);
                    _load();
                  },
                  child: const Text('لاحقاً')),
              onTap: () {
                Navigator.pop(c);
                _newFromLast(r);
              },
            ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('اضغط اسم العميل لتجهيز فاتورة بأصناف آخر طلب. «لاحقاً» تخفيه 7 أيام.',
                style: TextStyle(fontSize: 12)),
          ),
        ]),
      ),
    );
  }

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
    _runRecurring();
    _autoSync();
    AutoBackup.runIfDue().catchError((_) => null);
  }

  Future<void> _runRecurring() async {
    final n = await AppDatabase.instance.generateDueRecurring(DateTime.now());
    if (n > 0 && mounted) {
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('أُنشئت $n مسودة من الفواتير الدورية، راجعها قبل الإرسال')));
    }
  }

  Future<void> _makeRecurring(Invoice inv) async {
    final every = await showModalBottomSheet<Recurrence>(
      context: context,
      builder: (c) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        const ListTile(
            title: Text('تكرار هذه الفاتورة',
                style: TextStyle(fontWeight: FontWeight.w800))),
        for (final r in Recurrence.values)
          ListTile(title: Text(r.label), onTap: () => Navigator.pop(c, r)),
      ])),
    );
    if (every == null) return;
    var first = nextOccurrence(inv.date, every);
    while (!first.isAfter(DateTime.now())) {
      first = nextOccurrence(first, every, anchorDay: inv.date.day);
    }
    await AppDatabase.instance.addRecurring(inv.id!, every, first);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('تم. ستُنشأ مسودة ${every.label} وأول موعد ${formatDate(first)}')));
    await _runRecurring();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _syncFailShown = false;

  /// مزامنة صامتة إن كانت مفعّلة، ثم إعادة التحميل إذا نزل شيء.
  Future<void> _autoSync() async {
    if (!SyncService.instance.enabled) return;
    try {
      final r = await SyncService.instance.sync();
      _syncFailShown = false;
      if (r.pulled + r.deleted > 0 && mounted) _load();
    } catch (_) {
      // أخبر المستخدم مرة واحدة فقط (بدون إزعاج) أن المزامنة التلقائية فشلت.
      if (mounted && !_syncFailShown) {
        _syncFailShown = true;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('تعذّرت المزامنة التلقائية. بياناتك محفوظة على الجهاز وستُعاد المحاولة لاحقاً.')));
      }
    }
    _loadViews();
  }

  String _viewLabel(Invoice inv) {
    final v = _views[_uids[inv.id]];
    if (v == null) return '';
    if (v.views == 0) return '  |  أُرسل الرابط، لم يُفتح بعد';
    final w = v.last == null ? '' : ' ${formatDate(v.last!)}';
    return '  |  👁 شاهدها العميل$w (${localizeDigits('${v.views}')})';
  }

  Future<void> _loadViews() async {
    if (!SyncService.instance.enabled) return;
    final v = await ShareService.instance.views();
    final u = await ShareService.instance.uidsById();
    if (!mounted) return;
    setState(() {
      _views = v;
      _uids = u;
    });
  }

  Future<void> _shareLink(Invoice inv) async {
    final msg = ScaffoldMessenger.of(context);
    try {
      final full = await AppDatabase.instance.getInvoice(inv.id!);
      if (full == null) return;
      final url = await ShareService.instance.link(full);
      final party = await AppDatabase.instance.partyByName(inv.party);
      final text = 'السلام عليكم ${inv.party.isEmpty ? '' : inv.party}\n'
          'فاتورتكم رقم ${localizeDigits(inv.number)}:\n$url'
          '${SettingsService.instance.companyName.isEmpty ? '' : '\n${SettingsService.instance.companyName}'}';
      _loadViews();
      final ok = await launchUrl(waUri(waPhone(party?.phone ?? ''), text),
              mode: LaunchMode.externalApplication)
          .catchError((_) => false);
      if (!ok) await Share.share(text);
    } on SyncException catch (e) {
      msg.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _load() async {
    final list = await AppDatabase.instance.listInvoices(query: _search.text);
    final all = _search.text.trim().isEmpty
        ? list
        : await AppDatabase.instance.listInvoices();
    final stats = computeDashboard(all, DateTime.now(),
        currency: SettingsService.instance.currency);
    final low = (await AppDatabase.instance.stockForecast(DateTime.now()))
        .where((e) => e.daysLeft != null && e.daysLeft! <= 7)
        .toList();
    final ro = reorderDue(all, DateTime.now(), snoozed: SettingsService.instance.reorderSnooze);
    final digest = buildDigest(all, await AppDatabase.instance.soldRows(), DateTime.now());
    if (!mounted) return;
    setState(() {
      _reorder = ro;
      _digest = digest;
      _collect = buildCollection(all, DateTime.now(), SettingsService.instance.reminded);
      _low = low;
      _stats = stats;
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
    _autoSync();
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
            leading: const Icon(Icons.payments_outlined),
            title: const Text('مصروف جديد'),
            onTap: () => Navigator.pop(c, DocKind.expense),
          ),
          ListTile(
            minTileHeight: 56,
            leading: const Icon(Icons.document_scanner_outlined),
            title: const Text('مسح إيصال مصروف'),
            onTap: () async {
              Navigator.pop(c);
              final saved = await startScanFlow(context, kind: DocKind.expense);
              if (saved) _load();
            },
          ),
          ListTile(
            minTileHeight: 56,
            leading: const Icon(Icons.draw_outlined),
            title: const Text('مسح قائمة بخط اليد'),
            subtitle: const Text('النوع | الموديل | العدد (كراتين×دزن)'),
            onTap: () async {
              Navigator.pop(c);
              final saved = await startScanFlow(context, handwritten: true);
              if (saved) _load();
            },
          ),
          ListTile(
            minTileHeight: 56,
            leading: const Icon(Icons.request_quote_outlined),
            title: const Text('عرض سعر جديد'),
            onTap: () => Navigator.pop(c, DocKind.quote),
          ),
          ListTile(
            minTileHeight: 56,
            leading: const Icon(Icons.bolt),
            title: const Text('فاتورة سريعة (كتابة أو صوت)'),
            onTap: () async {
              Navigator.pop(c);
              await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const QuickInvoiceScreen()));
              _load();
            },
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

  Future<void> _convertQuote(int id) async {
    final q = await AppDatabase.instance.getInvoice(id);
    if (q == null || !mounted) return;
    final items = q.items;
    final ctl = [
      for (final it in items)
        TextEditingController(
            text: plainNumber(it.quantity > 0 ? it.quantity : it.wholesaleQty))
    ];
    final picked = List<bool>.filled(items.length, true);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: const Text('تحويل إلى فاتورة'),
          content: SizedBox(
            width: 420,
            child: ListView(shrinkWrap: true, children: [
              for (var i = 0; i < items.length; i++)
                Row(children: [
                  Checkbox(
                      value: picked[i],
                      onChanged: (v) => set(() => picked[i] = v ?? false)),
                  Expanded(child: Text(items[i].description)),
                  SizedBox(
                    width: 70,
                    child: TextField(
                      controller: ctl[i],
                      enabled: picked[i],
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ]),
              const SizedBox(height: 8),
              const Text('الباقي يبقى مفتوحاً في عرض السعر.',
                  style: TextStyle(fontSize: 12)),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('إنشاء الفاتورة')),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final chosen = <int, double>{
      for (var i = 0; i < items.length; i++)
        if (picked[i]) i: parseNumber(ctl[i].text) ?? 0
    };
    try {
      final newId = await AppDatabase.instance.convertQuote(id, chosen);
      await _load();
      if (!mounted) return;
      final inv = await AppDatabase.instance.getInvoice(newId);
      if (inv != null) _open(inv);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _delete(InvoiceSummary s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('حذف'),
        content: Text('حذف ${s.invoice.docLabel} رقم ${s.invoice.number}؟ لا يمكن التراجع.'),
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
            key: const ValueKey('open-ask'),
            tooltip: 'اسأل دفتر',
            icon: const Icon(Icons.auto_awesome),
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const AskScreen())),
          ),
          IconButton(
            tooltip: 'الذكاء المالي',
            icon: const Icon(Icons.psychology_outlined),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const InsightsScreen())),
          ),
          IconButton(
            tooltip: 'الفواتير الدورية',
            icon: const Icon(Icons.autorenew),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const RecurringScreen())),
          ),
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
        if (_stats != null && _stats!.hasData)
          DashboardHeader(
              stats: _stats!, currency: SettingsService.instance.currency),
        if (_low.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Card(
              color: Theme.of(context).colorScheme.tertiaryContainer,
              child: ListTile(
                leading: const Icon(Icons.inventory_2_outlined),
                title: Text('${localizeDigits('${_low.length}')} أصناف توشك أن تنفد'),
                subtitle: Text(
                    _low.take(3).map((e) => e.name).join('، ') + (_low.length > 3 ? '…' : ''),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const InsightsScreen())),
              ),
            ),
          ),
        if (_digest != null && !_digest!.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Card(
              key: const ValueKey('weekly-digest'),
              child: ExpansionTile(
                leading: const Icon(Icons.insights_outlined),
                title: const Text('ملخص الأسبوع', style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(_digest!.headline),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final l in _digest!.lines)
                    Padding(padding: const EdgeInsets.only(top: 4), child: Text(l)),
                  if (_digest!.lines.isEmpty) const Text('لا شيء يحتاج انتباهك هذا الأسبوع.'),
                ],
              ),
            ),
          ),
        if (_reorder.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Card(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: ListTile(
                leading: const Icon(Icons.replay_circle_filled_outlined),
                title: Text('${localizeDigits('${_reorder.length}')} عملاء حان وقت طلبهم'),
                subtitle: Text(
                    _reorder.take(3).map((e) => e.party).join('، ') + (_reorder.length > 3 ? '…' : ''),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                trailing: const Icon(Icons.chevron_left),
                onTap: _reorderSheet,
              ),
            ),
          ),
        if (_collect.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: ListTile(
                leading: const Icon(Icons.notifications_active_outlined),
                title: Text(
                    '${localizeDigits('${_collect.length}')} عملاء متأخرون: لمن أطالب؟'),
                subtitle: Text(
                    'الأول: ${_collect.first.party} • ${formatMoney(_collect.first.total)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                trailing: const Icon(Icons.chevron_left),
                onTap: _followUpSheet,
              ),
            ),
          ),
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
                                  child: Icon(switch (inv.kind) {
                                    DocKind.invoice => Icons.receipt_long,
                                    DocKind.quote => Icons.request_quote_outlined,
                                    DocKind.expense => Icons.payments_outlined,
                                    DocKind.inventory => Icons.inventory_2_outlined,
                                  }),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${inv.docLabel} ${localizeDigits(inv.number)}'
                                        '${inv.party.isEmpty ? '' : ' - ${inv.party}'}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 16),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${inv.status.label}  |  ${formatDate(inv.date)}  |  ${localizeDigits('${s.itemCount}')} صنف  |  ${formatQty(s.totalQty)} قطعة'
                                        '${_viewLabel(inv)}',
                                        style: TextStyle(
                                            color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                                        !inv.isNote &&
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
                                          } else if (v == 'link') {
                                            _shareLink(inv);
                                          } else if (v == 'credit' || v == 'debit') {
                                            final id = await AppDatabase.instance
                                                .createNote(inv.id!, v);
                                            await _load();
                                            if (!mounted) return;
                                            final n = await AppDatabase.instance
                                                .getInvoice(id);
                                            if (n != null) _open(n);
                                          } else if (v == 'recur') {
                                            _makeRecurring(inv);
                                          } else if (v == 'convert') {
                                            await _convertQuote(inv.id!);
                                          } else if (v == 'dup') {
                                            await AppDatabase.instance
                                                .duplicateInvoice(inv.id!);
                                            _load();
                                          }
                                        },
                                        itemBuilder: (_) => [
                                          if (inv.kind == DocKind.invoice &&
                                              !inv.isNote &&
                                              paymentRemaining(s.grandTotal,
                                                      inv.paidAmount, inv.status) >
                                                  0.005)
                                            const PopupMenuItem(
                                                value: 'remind',
                                                child: Text('تذكير بالسداد (واتساب)')),
                                          if (inv.kind == DocKind.invoice && !inv.isNote)
                                            const PopupMenuItem(
                                                value: 'link',
                                                child: Text('إرسال رابط للعميل (مع حالة المشاهدة)')),
                                          if (inv.kind == DocKind.invoice && !inv.isNote) ...const [
                                            PopupMenuItem(
                                                value: 'credit',
                                                child: Text('إشعار دائن (مرتجع/خصم)')),
                                            PopupMenuItem(
                                                value: 'debit',
                                                child: Text('إشعار مدين (زيادة)')),
                                          ],
                                          if (inv.kind == DocKind.quote)
                                            const PopupMenuItem(
                                                value: 'convert',
                                                child: Text('تحويل إلى فاتورة (جزئي أو كامل)')),
                                          if (inv.kind == DocKind.invoice && !inv.isNote)
                                            const PopupMenuItem(
                                                value: 'recur',
                                                child: Text('جعلها دورية')),
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
  Widget build(BuildContext context) => const EmptyState(
        title: 'ابدأ بأول فاتورة',
        hint: 'اضغط «جديد» لإنشاء فاتورة أو جدول جرد،\nأو صوّر فاتورة ورقية وسنكتبها لك.',
        badge: Icons.add,
      );
}
