import 'dart:io';

import 'package:flutter/material.dart';

import '../database/app_database.dart';
import '../models/invoice.dart';
import '../utils/auto_fill.dart';
import '../utils/smart_items.dart';
import '../utils/customer_defaults.dart';
import '../models/invoice_item.dart';
import '../models/ocr_result.dart';
import '../services/ocr_service.dart';
import '../services/settings_service.dart';
import '../utils/number_utils.dart';
import '../widgets/item_edit_sheet.dart';
import '../widgets/item_tile.dart';
import '../widgets/totals_bar.dart';

/// شاشة المراجعة: الصورة في النصف العلوي والجدول المستخرج القابل للتعديل في السفلي.
class ScanVerificationScreen extends StatefulWidget {
  final File image;
  final DocKind kind;
  final bool handwritten; // قائمة مكتوبة بخط اليد: النوع | الموديل | العدد
  const ScanVerificationScreen(
      {super.key, required this.image, this.kind = DocKind.invoice, this.handwritten = false});

  @override
  State<ScanVerificationScreen> createState() => _ScanVerificationScreenState();
}

class _ScanVerificationScreenState extends State<ScanVerificationScreen> {
  OcrResult? _result;
  List<InvoiceItem> _items = [];
  String? _error;
  bool _saving = false;
  int _smart = 0;
  List<ItemStat> _stats = [];
  Map<String, double> _cprices = {};
  final _party = TextEditingController();
  final _number = TextEditingController();

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void dispose() {
    _party.dispose();
    _number.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    setState(() {
      _result = null;
      _error = null;
    });
    try {
      final r = await OcrService().scan(widget.image,
          handwritten: widget.handwritten,
          catalog: widget.handwritten ? await AppDatabase.instance.itemCatalog() : const {});
      if (!mounted) return;
      final db = AppDatabase.instance;
      final known = await db.partyNames();
      _party.text = matchParty(r.party, known) ?? r.party;
      var smart = 0;
      if (widget.kind != DocKind.expense) {
        final hist = await db.itemHistory();
        smart += snapItemNames(r.items, hist.keys.toList());
        if (known.contains(_party.text)) {
          smart += applyCustomerPrices(r.items, await db.customerPrices(_party.text));
        }
        smart += enrichItems(r.items, hist);
      }
      _smart = smart;
      _stats = await db.itemStats();
      _cprices = await db.customerPrices(_party.text);
      _number.text = r.invoiceNumber.isNotEmpty
          ? r.invoiceNumber
          : await AppDatabase.instance.nextNumber();
      setState(() {
        _result = r;
        _items = r.items;
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  double get _sum => _items.fold(0.0, (s, i) => s + i.total);
  double get _qty => _items.fold(0.0, (s, i) => s + i.quantity);
  int get _flaggedCount => _items.where((e) => e.flagged).length;

  Future<void> _edit(InvoiceItem it) async {
    final r = await showItemEditSheet(context,
        item: it, isNew: false, pinPrice: false, pinType: false,
        stats: _stats, customerPrices: _cprices, others: _items, party: _party.text);
    if (r == null) return;
    setState(() {
      final i = _items.indexOf(it);
      r.item.statedTotal = null; // المستخدم صحّح: لا نقارن بالورقة بعد الآن
      _items[i] = r.item;
    });
  }

  Future<void> _addRow() async {
    final r = await showItemEditSheet(context,
        item: InvoiceItem(quantity: 1),
        isNew: true,
        pinPrice: false,
        pinType: false,
        stats: _stats,
        customerPrices: _cprices,
        others: _items,
        party: _party.text);
    if (r == null) return;
    setState(() => _items.add(r.item));
  }

  Future<void> _approve() async {
    if (_flaggedCount > 0) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('صفوف تحتاج مراجعة'),
          content: Text('يوجد $_flaggedCount صف مميز بالبرتقالي. هل تريد الاعتماد كما هي؟'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('مراجعة')),
            FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('اعتماد')),
          ],
        ),
      );
      if (ok != true) return;
    }
    setState(() => _saving = true);
    final db = AppDatabase.instance;
    final inv = Invoice(
      kind: widget.kind,
      number: _number.text.trim().isEmpty ? await db.nextNumber(widget.kind) : _number.text.trim(),
      date: _result?.date,
      party: _party.text.trim(),
      items: _items.map((e) => e.copy()..flagged = false..id = null).toList(),
    );
    if (widget.kind == DocKind.invoice && inv.party.isNotEmpty) {
      final d = computeDefaults(await db.recentInvoicesForParty(inv.party));
      if (d.dueDays != null) {
        inv.dueDate = DateTime(inv.date.year, inv.date.month, inv.date.day)
            .add(Duration(days: d.dueDays!));
      }
      if (d.vatRate != null) inv.vatRate = d.vatRate!;
      if (d.currency != null) inv.currency = d.currency!;
    }
    await db.saveInvoice(inv);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final cur = SettingsService.instance.currency;
    return Scaffold(
      appBar: AppBar(
        title: const Text('مراجعة المسح'),
        actions: [
          IconButton(
              tooltip: 'إعادة المسح',
              icon: const Icon(Icons.refresh),
              onPressed: _result == null && _error == null ? null : _run),
        ],
      ),
      body: Column(children: [
        // النصف العلوي: الصورة (تكبير بالقرص)
        Expanded(
          flex: 4,
          child: Container(
            color: Colors.black,
            width: double.infinity,
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: Image.file(widget.image, fit: BoxFit.contain),
            ),
          ),
        ),
        // النصف السفلي: الجدول المستخرج
        Expanded(flex: 5, child: _bottom()),
        if (_result != null)
          TotalsBar(
              itemCount: _items.length,
              totalQty: _qty,
              grandTotal: _sum,
              currency: cur),
        if (_result != null)
          Container(
            color: Theme.of(context).colorScheme.surface,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: _saving || _items.isEmpty ? null : _approve,
                  icon: const Icon(Icons.check),
                  label: const Text('اعتماد وحفظ الفاتورة'),
                ),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _bottom() {
    if (_error != null) {
      return Center(
          child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('فشل المسح: $_error', textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: _run, child: const Text('إعادة المحاولة')),
        ]),
      ));
    }
    final r = _result;
    if (r == null) {
      return const Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        CircularProgressIndicator(),
        SizedBox(height: 12),
        Text('جارٍ تحليل الفاتورة...'),
      ]));
    }
    final stated = r.statedGrandTotal;
    final mismatch = stated != null && (stated - _sum).abs() > 0.5;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _number,
              decoration: const InputDecoration(
                  labelText: 'رقم الفاتورة', isDense: true),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextField(
              controller: _party,
              decoration: const InputDecoration(
                  labelText: 'العميل / المورد', isDense: true),
            ),
          ),
        ]),
      ),
      if (r.warnings.isNotEmpty || mismatch || _flaggedCount > 0 || _smart > 0)
        _banner([
          'المصدر: ${r.source.label}',
          if (_smart > 0) 'أُكمل $_smart تلقائياً من سجلّك (أسماء/أسعار). راجعها قبل الاعتماد.',
          ...r.warnings,
          if (mismatch)
            'إجمالي الورقة (${formatMoney(stated)}) لا يطابق مجموع الصفوف (${formatMoney(_sum)}).',
          if (_flaggedCount > 0) '$_flaggedCount صف يحتاج مراجعة (ملوّن بالبرتقالي).',
        ]),
      Expanded(
        child: _items.isEmpty
            ? const Center(child: Text('لم تُستخرج أي صفوف'))
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                itemCount: _items.length,
                itemBuilder: (_, i) {
                  final it = _items[i];
                  return Dismissible(
                    key: ObjectKey(it),
                    direction: DismissDirection.startToEnd,
                    background: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                          color: Colors.red.shade400,
                          borderRadius: BorderRadius.circular(14)),
                      alignment: AlignmentDirectional.centerStart,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    onDismissed: (_) => setState(() => _items.remove(it)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: ItemTile(
                        index: i + 1,
                        item: it,
                        onTap: () => _edit(it),
                        onDuplicate: () => setState(
                            () => _items.insert(i + 1, it.copy()..id = null)),
                        onDelete: () => setState(() => _items.remove(it)),
                      ),
                    ),
                  );
                },
              ),
      ),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton.icon(
            onPressed: _addRow,
            icon: const Icon(Icons.add),
            label: const Text('إضافة سطر ناقص')),
      ),
    ]);
  }

  Widget _banner(List<String> lines) => Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF3A2E1A)
                : const Color(0xFFFFF4E5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.orange.shade300)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final l in lines) Text(l, style: const TextStyle(fontSize: 12.5)),
          ],
        ),
      );
}
