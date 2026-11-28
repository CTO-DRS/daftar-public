import 'package:flutter/material.dart';

import '../database/app_database.dart';
import '../services/settings_service.dart';
import '../utils/insights.dart';
import '../utils/forecast.dart';
import '../utils/restock.dart';
import '../utils/cashflow.dart';
import '../utils/expense_category.dart';
import '../utils/number_utils.dart';
import '../widgets/empty_state.dart';
import '../widgets/responsive.dart';
import 'statement_screen.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:share_plus/share_plus.dart';
import '../services/file_saver.dart';
import '../utils/csv_export.dart';
import '../utils/platform_utils.dart';

/// الذكاء المالي: تنبيهات ذكية، توقع التحصيل، أعمار الديون، تصنيف العملاء، أفضل الأصناف.
/// كل التحليل يتم على الجهاز بدون إنترنت.
class InsightsScreen extends StatefulWidget {
  final InsightsReport? preloaded;
  const InsightsScreen({super.key, this.preloaded});
  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  InsightsReport? _r;
  ProfitSummary? _today, _month;
  double _expMonth = 0;
  List<StockForecast> _stock = [];
  CashOutlook? _cash;
  Map<String, double> _expCats = {};

  @override
  void initState() {
    super.initState();
    _r = widget.preloaded;
    if (_r == null) _load();
  }

  Future<void> _load() async {
    final cur = SettingsService.instance.currency;
    final all = await AppDatabase.instance.listInvoices();
    final prods = await AppDatabase.instance.topProducts(currency: cur);
    final r = computeInsights(all, DateTime.now(), currency: cur, products: prods);
    final now = DateTime.now();
    final today = await AppDatabase.instance
        .profitSince(DateTime(now.year, now.month, now.day), currency: cur);
    final month = await AppDatabase.instance
        .profitSince(DateTime(now.year, now.month), currency: cur);
    final exp = await AppDatabase.instance.expensesSince(DateTime(now.year, now.month), currency: cur);
    final stock = await AppDatabase.instance.stockForecast(now);
    if (mounted) {
      setState(() {
        _stock = stock;
        _cash = buildCashOutlook(all, now);
        _expCats = expensesByCategory(all, DateTime(now.year, now.month),
            ExpenseClassifier.fromHistory(all.map((e) => e.invoice)));
        _r = r;
        _today = today;
        _month = month;
        _expMonth = exp;
      });
    }
  }

  Future<void> _exportCsv(String range) async {
    final m = ScaffoldMessenger.of(context);
    final now = DateTime.now();
    final (from, to) = switch (range) {
      'month' => (DateTime(now.year, now.month), DateTime(now.year, now.month + 1)),
      'last' => (DateTime(now.year, now.month - 1), DateTime(now.year, now.month)),
      'year' => (DateTime(now.year), DateTime(now.year + 1)),
      _ => (DateTime(2000), DateTime(2100)),
    };
    try {
      final all = await AppDatabase.instance.listInvoices();
      final csv = accountantCsv(all, from, to);
      final name = 'daftar-accountant-$range-${now.year}-${now.month.toString().padLeft(2, '0')}.csv';
      final bytes = Uint8List.fromList(utf8.encode(csv));
      final where = await FileSaver.saveToDownloads(bytes, name, mime: 'text/csv');
      m.showSnackBar(SnackBar(content: Text('تم حفظ الملف في $where')));
      if (!isDesktopPlatform) {
        await SharePlus.instance.share(ShareParams(
            files: [XFile.fromData(bytes, mimeType: 'text/csv', name: name)],
            fileNameOverrides: [name]));
      }
    } catch (e) {
      m.showSnackBar(SnackBar(content: Text('تعذر التصدير: $e')));
    }
  }

  Future<void> _restockSheet() async {
    var lead = 7, cover = 30;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => StatefulBuilder(builder: (c, setS) {
        final lines = planRestock(_stock, leadDays: lead, coverDays: cover);
        return SafeArea(
          child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), children: [
            const Text('خطة الشراء', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 8),
            const Text('مدة التوريد'),
            Wrap(spacing: 8, children: [
              for (final d in const [3, 7, 14])
                ChoiceChip(
                    key: ValueKey('lead-$d'),
                    label: Text('${localizeDigits('$d')} أيام'),
                    selected: lead == d,
                    onSelected: (_) => setS(() => lead = d)),
            ]),
            const SizedBox(height: 8),
            const Text('أريد تغطية'),
            Wrap(spacing: 8, children: [
              for (final d in const [14, 30, 60])
                ChoiceChip(
                    key: ValueKey('cover-$d'),
                    label: Text('${localizeDigits('$d')} يوماً'),
                    selected: cover == d,
                    onSelected: (_) => setS(() => cover = d)),
            ]),
            const Divider(height: 24),
            if (lines.isEmpty) const Text('المخزون كافٍ، لا شراء مطلوب بهذه المدة.'),
            for (final l in lines)
              ListTile(
                dense: true,
                leading: Icon(
                    l.urgency == RestockUrgency.now ? Icons.priority_high : Icons.circle_outlined,
                    color: l.urgency == RestockUrgency.now ? Colors.red : null,
                    size: 20),
                title: Text(l.name),
                subtitle: Text(
                    'المتبقي ${formatQty(l.onHand)} • يُباع ${formatQty(double.parse(l.rate.toStringAsFixed(1)))} باليوم'
                    '${l.rising ? ' • الطلب في ارتفاع' : ''}'),
                trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(formatQty(l.qty), style: const TextStyle(fontWeight: FontWeight.w800)),
                  if (l.packs > 0)
                    Text('${formatQty(l.packs)} × ${formatQty(l.packSize)}', style: const TextStyle(fontSize: 11)),
                ]),
              ),
            if (lines.isNotEmpty)
              FilledButton.icon(
                key: const ValueKey('share-restock'),
                onPressed: () => Share.share(restockText(lines, DateTime.now(),
                    company: SettingsService.instance.companyName, leadDays: lead, coverDays: cover)),
                icon: const Icon(Icons.share_outlined),
                label: const Text('مشاركة القائمة'),
              ),
            const SizedBox(height: 8),
            const Text('الكمية = معدل البيع (متوسط 30 يوماً وآخر 14) × (التوريد + التغطية) − المتبقي، مقرّبة لكراتين كاملة عند معرفة حجم العبوة. تقدير وليس وعداً.',
                style: TextStyle(fontSize: 11)),
          ]),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = _r;
    return Scaffold(
      appBar: AppBar(title: const Text('الذكاء المالي'), actions: [
        PopupMenuButton<String>(
          tooltip: 'تصدير للمحاسب (CSV)',
          icon: const Icon(Icons.table_view_outlined),
          onSelected: _exportCsv,
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'month', child: Text('تصدير هذا الشهر (CSV)')),
            PopupMenuItem(value: 'last', child: Text('تصدير الشهر الماضي (CSV)')),
            PopupMenuItem(value: 'year', child: Text('تصدير هذه السنة (CSV)')),
            PopupMenuItem(value: 'all', child: Text('تصدير الكل (CSV)')),
          ],
        ),
      ]),
      body: r == null
          ? const Center(child: CircularProgressIndicator())
          : r.isEmpty
              ? const EmptyState(
                  badge: Icons.psychology_outlined,
                  title: 'لا توجد بيانات كافية بعد',
                  hint: 'أنشئ واعتمد بعض الفواتير وسيحلّلها دفتر لك هنا: تنبيهات، توقع تحصيل، وتصنيف عملاء.')
              : ContentWidth(
                  child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
                  _Alerts(r.alerts),
                  if (_today != null && _month != null) _ProfitCard(_today!, _month!, _expMonth),
                  if (_cash != null && !_cash!.isEmpty) _CashCard(_cash!),
                  if (_expCats.isNotEmpty) _ExpCatCard(_expCats),
                  _Section('توقع التحصيل', Icons.event_available_outlined),
                  _ForecastGrid(r.forecast),
                  _Section('أعمار الديون', Icons.timelapse),
                  _AgingBar(r.aging),
                  if (r.customers.isNotEmpty) ...[
                    _Section('العملاء ومخاطر السداد', Icons.groups_2_outlined),
                    for (final c in r.customers.take(8)) _CustomerTile(c),
                  ],
                  if (_stock.isNotEmpty) ...[
                    _Section('المخزون المتوقع', Icons.inventory_2_outlined),
                    for (final f in _stock.take(8)) _StockTile(f),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: FilledButton.tonalIcon(
                        key: const ValueKey('open-restock'),
                        onPressed: _restockSheet,
                        icon: const Icon(Icons.shopping_cart_checkout),
                        label: const Text('خطة الشراء'),
                      ),
                    ),
                  ],
                  if (r.products.isNotEmpty) ...[
                    _Section('أفضل الأصناف إيراداً', Icons.workspace_premium_outlined),
                    _Products(r.products),
                  ],
                  const SizedBox(height: 12),
                  Text('التحليل تقديري ويعتمد على بياناتك المسجلة. لا يُحتسب إلا الفواتير المعتمدة بعملة ${SettingsService.instance.currency}.',
                      style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.outline)),
                ])),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  const _Section(this.title, this.icon);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 10),
        child: Row(children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ]),
      );
}

Color _levelColor(InsightLevel l) => switch (l) {
      InsightLevel.good => const Color(0xFF12B886),
      InsightLevel.info => const Color(0xFF3B82F6),
      InsightLevel.warn => const Color(0xFFF59E0B),
      InsightLevel.risk => const Color(0xFFEF4444),
    };

IconData _levelIcon(InsightLevel l) => switch (l) {
      InsightLevel.good => Icons.trending_up,
      InsightLevel.info => Icons.info_outline,
      InsightLevel.warn => Icons.warning_amber_rounded,
      InsightLevel.risk => Icons.error_outline,
    };

class _Alerts extends StatelessWidget {
  final List<Insight> items;
  const _Alerts(this.items);
  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _Tint(
          color: Color(0xFF12B886),
          child: Row(children: [
            Icon(Icons.verified_outlined, color: Color(0xFF12B886)),
            SizedBox(width: 10),
            Expanded(child: Text('كل شيء على ما يرام: لا متأخرات ولا مخاطر ظاهرة الآن.')),
          ]));
    }
    return Column(children: [
      for (final a in items)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _Tint(
              color: _levelColor(a.level),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(_levelIcon(a.level), color: _levelColor(a.level)),
                const SizedBox(width: 10),
                Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(a.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(a.body, style: const TextStyle(fontSize: 13)),
                ])),
              ])),
        ),
    ]);
  }
}

class _Tint extends StatelessWidget {
  final Color color;
  final Widget child;
  const _Tint({required this.color, required this.child});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: .35)),
        ),
        child: child,
      );
}

class _ForecastGrid extends StatelessWidget {
  final Forecast f;
  const _ForecastGrid(this.f);
  @override
  Widget build(BuildContext context) {
    final cur = SettingsService.instance.currency;
    Widget tile(String label, double v, Color c) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.withValues(alpha: .5)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TextStyle(fontSize: 12, color: c, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(formatMoney(v), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              Text(cur, style: const TextStyle(fontSize: 11)),
            ]),
          ),
        );
    return Column(children: [
      Row(children: [
        tile('متأخر (حصّله الآن)', f.overdue, const Color(0xFFEF4444)),
        const SizedBox(width: 10),
        tile('خلال 7 أيام', f.next7, const Color(0xFF12B886)),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        tile('8 إلى 30 يوماً', f.next30, const Color(0xFF3B82F6)),
        const SizedBox(width: 10),
        tile('لاحقاً / بلا استحقاق', f.later, const Color(0xFF64748B)),
      ]),
    ]);
  }
}

class _AgingBar extends StatelessWidget {
  final Aging a;
  const _AgingBar(this.a);
  @override
  Widget build(BuildContext context) {
    final parts = <(String, double, Color)>[
      ('لم يستحق', a.notDue, const Color(0xFF12B886)),
      ('1-30 يوماً', a.d30, const Color(0xFFF59E0B)),
      ('31-60', a.d60, const Color(0xFFF97316)),
      ('61-90', a.d90, const Color(0xFFEF4444)),
      ('+90', a.d90plus, const Color(0xFF991B1B)),
    ];
    if (a.total <= 0.005) {
      return const Text('لا ديون مفتوحة.');
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 14,
          child: Row(children: [
            for (final p in parts)
              if (p.$2 > 0.005) Expanded(flex: (p.$2 / a.total * 1000).round().clamp(1, 1000), child: Container(color: p.$3)),
          ]),
        ),
      ),
      const SizedBox(height: 10),
      Wrap(spacing: 14, runSpacing: 6, children: [
        for (final p in parts)
          if (p.$2 > 0.005)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: p.$3, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text('${p.$1}: ${formatMoney(p.$2)}', style: const TextStyle(fontSize: 12)),
            ]),
      ]),
    ]);
  }
}

class _CustomerTile extends StatelessWidget {
  final CustomerInsight c;
  const _CustomerTile(this.c);
  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (c.risk) {
      Risk.low => ('منتظم', const Color(0xFF12B886)),
      Risk.medium => ('متأخر', const Color(0xFFF59E0B)),
      Risk.high => ('خطر', const Color(0xFFEF4444)),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => StatementScreen(party: c.name))),
      child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .5)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(color: color.withValues(alpha: .15), borderRadius: BorderRadius.circular(20)),
            child: Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: c.share.clamp(0, 1).toDouble(), minHeight: 6, color: color, backgroundColor: color.withValues(alpha: .12)),
        ),
        const SizedBox(height: 6),
        Text(
          'مبيعات ${formatMoney(c.sales)} (${localizeDigits((c.share * 100).round().toString())}٪)'
          '${c.outstanding > 0.005 ? ' • مستحق ${formatMoney(c.outstanding)}' : ''}'
          '${c.maxDaysLate > 0 ? ' • أقدم تأخير ${localizeDigits('${c.maxDaysLate}')} يوماً' : ''}',
          style: const TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text('اضغط لعرض كشف الحساب', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.primary)),
      ]),
    ),
    ),
    );
  }
}

class _Products extends StatelessWidget {
  final List<ProductSales> items;
  const _Products(this.items);
  @override
  Widget build(BuildContext context) {
    final max = items.first.revenue;
    final cs = Theme.of(context).colorScheme;
    return Column(children: [
      for (var i = 0; i < items.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('${localizeDigits('${i + 1}')}. ', style: TextStyle(color: cs.primary, fontWeight: FontWeight.w800)),
              Expanded(child: Text(items[i].name, overflow: TextOverflow.ellipsis)),
              Text(formatMoney(items[i].revenue), style: const TextStyle(fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: max <= 0 ? 0.0 : (items[i].revenue / max).clamp(0.0, 1.0), minHeight: 6, color: cs.primary, backgroundColor: cs.primary.withValues(alpha: .12)),
            ),
            Text('الكمية ${formatQty(items[i].qty)}', style: TextStyle(fontSize: 11, color: cs.outline)),
          ]),
        ),
    ]);
  }
}

class _ProfitCard extends StatelessWidget {
  final ProfitSummary today, month;
  final double expenses;
  const _ProfitCard(this.today, this.month, this.expenses);

  Widget _col(BuildContext c, String title, ProfitSummary p) {
    final cs = Theme.of(c).colorScheme;
    return Expanded(
      child: Column(children: [
        Text(title, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
        const SizedBox(height: 4),
        Text(formatMoney(p.sales),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        const Text('مبيعات', style: TextStyle(fontSize: 11)),
        const SizedBox(height: 6),
        Text(p.hasCosts ? formatMoney(p.profit) : '—',
            style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: p.profit >= 0 ? cs.primary : cs.error)),
        Text(
            p.hasCosts
                ? 'ربح • هامش ${localizeDigits((p.margin * 100).toStringAsFixed(0))}%'
                : 'ربح',
            style: const TextStyle(fontSize: 11)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final noCost = !today.hasCosts && !month.hasCosts;
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Row(children: [
            _col(context, 'اليوم', today),
            _col(context, 'هذا الشهر', month),
          ]),
          if (expenses > 0) ...[
            const Divider(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('مصروفات الشهر: ${formatMoney(expenses)}',
                  style: const TextStyle(fontSize: 13)),
              if (month.hasCosts)
                Text('الصافي: ${formatMoney(month.profit - expenses)}',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: month.profit - expenses >= 0
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.error)),
            ]),
          ],
          if (noCost) ...[
            const SizedBox(height: 10),
            Text(
                'أدخل «سعر التكلفة» في الأصناف ليحسب دفتر الربح والهامش تلقائياً.',
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.outline)),
          ],
        ]),
      ),
    );
  }
}

class _StockTile extends StatelessWidget {
  final StockForecast f;
  const _StockTile(this.f);
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final days = f.daysLeft;
    final low = days != null && days <= 7;
    final order = f.suggestedOrder();
    return Card(
      child: ListTile(
        leading: Icon(low ? Icons.warning_amber_rounded : Icons.inventory_2_outlined,
            color: low ? cs.error : cs.primary),
        title: Text(f.name),
        subtitle: Text(
            'المتبقي تقديرياً ${formatQty(f.onHand < 0 ? 0 : f.onHand)} • يُباع ${formatQty(double.parse(f.perDay.toStringAsFixed(1)))} باليوم'
            '${order > 0 ? '\nيقترح شراء ${formatQty(order)} لتغطية 30 يوماً' : ''}'),
        trailing: Text(
            days == null ? '' : (days < 1 ? 'نفد' : 'يكفي ${localizeDigits(days.floor().toString())} يوم'),
            style: TextStyle(fontWeight: FontWeight.w800, color: low ? cs.error : null)),
        isThreeLine: order > 0,
      ),
    );
  }
}

/// التدفق النقدي المتوقع خلال 30 يوماً: مخطط تراكمي صغير + أدنى نقطة.
class _CashCard extends StatelessWidget {
  final CashOutlook o;
  const _CashCard(this.o);
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cur = SettingsService.instance.currency;
    final neg = o.lowest != null;
    return Card(
      key: const ValueKey('cash-card'),
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.show_chart, size: 20, color: cs.primary),
            const SizedBox(width: 8),
            const Text('التدفق النقدي (30 يوماً)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 10),
          Text('متوقع قبضه ${formatMoney(o.expectedIn)} $cur • متوقع صرفه ${formatMoney(o.expectedOut)} $cur',
              style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 10),
          SizedBox(height: 70, width: double.infinity, child: CustomPaint(painter: _CashPainter(o, cs.primary, const Color(0xFFEF4444), cs.outlineVariant))),
          const SizedBox(height: 8),
          Text(
            neg
                ? 'تنبيه: قد يتجاوز الصرف المقبوضات حتى ${formatMoney(-o.lowest!.cumulative)} $cur عند يوم ${o.lowest!.date.day}/${o.lowest!.date.month}. فعّل التحصيل قبله.'
                : 'المقبوضات المتوقعة تغطي المصروفات المعتادة خلال الفترة.',
            style: TextStyle(fontSize: 12, color: neg ? const Color(0xFFEF4444) : cs.outline),
          ),
          if (o.notDated > 0)
            Text('فواتير بلا تاريخ استحقاق (${formatMoney(o.notDated)} $cur) غير محسوبة.',
                style: TextStyle(fontSize: 11, color: cs.outline)),
          Text('تقدير: يعتمد على سلوك سداد كل عميل ومتوسط مصروفاتك، بلا رصيد الصندوق.',
              style: TextStyle(fontSize: 11, color: cs.outline)),
        ]),
      ),
    );
  }
}

class _CashPainter extends CustomPainter {
  final CashOutlook o;
  final Color good, bad, axis;
  _CashPainter(this.o, this.good, this.bad, this.axis);
  @override
  void paint(Canvas canvas, Size size) {
    final v = o.days.map((d) => d.cumulative).toList();
    if (v.length < 2) return;
    var lo = v.reduce((a, b) => a < b ? a : b), hi = v.reduce((a, b) => a > b ? a : b);
    if (lo > 0) lo = 0;
    if (hi < 0) hi = 0;
    final span = (hi - lo) == 0 ? 1 : hi - lo;
    double y(double x) => size.height - (x - lo) / span * size.height;
    canvas.drawLine(Offset(0, y(0)), Offset(size.width, y(0)), Paint()..color = axis..strokeWidth = 1);
    for (var k = 0; k < v.length - 1; k++) {
      final x1 = size.width * k / (v.length - 1), x2 = size.width * (k + 1) / (v.length - 1);
      canvas.drawLine(Offset(x1, y(v[k])), Offset(x2, y(v[k + 1])),
          Paint()..color = v[k + 1] < 0 ? bad : good..strokeWidth = 2.5..strokeCap = StrokeCap.round);
    }
  }

  @override
  bool shouldRepaint(_CashPainter old) => old.o != o;
}

/// مصروفات هذا الشهر حسب التصنيف.
class _ExpCatCard extends StatelessWidget {
  final Map<String, double> m;
  const _ExpCatCard(this.m);
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cur = SettingsService.instance.currency;
    final total = m.values.fold(0.0, (a, b) => a + b);
    return Card(
      key: const ValueKey('expcat-card'),
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.category_outlined, size: 20, color: cs.primary),
            const SizedBox(width: 8),
            const Text('مصروفات الشهر حسب التصنيف', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 10),
          for (final e in m.entries.take(7)) ...[
            Row(children: [
              Expanded(child: Text(e.key, style: const TextStyle(fontSize: 13))),
              Text('${formatMoney(e.value)} $cur', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 3),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: total <= 0 ? 0.0 : (e.value / total).clamp(0.0, 1.0), minHeight: 6, color: cs.primary, backgroundColor: cs.surfaceContainerHighest),
            ),
            const SizedBox(height: 8),
          ],
          Text('التصنيف المقترح تلقائياً من المورد والملاحظات، وتصحيحك يعلّم دفتر.', style: TextStyle(fontSize: 11, color: cs.outline)),
        ]),
      ),
    );
  }
}
