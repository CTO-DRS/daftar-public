import 'package:flutter/material.dart';

import '../database/app_database.dart';
import '../models/invoice.dart';
import '../models/invoice_item.dart';
import '../services/editor_controller.dart';
import '../services/settings_service.dart';
import '../utils/date_utils.dart';
import '../utils/number_utils.dart';
import '../utils/sort_utils.dart';
import '../widgets/item_edit_sheet.dart';
import '../widgets/item_tile.dart';
import '../widgets/responsive.dart';
import '../widgets/totals_bar.dart';
import 'pdf_preview_screen.dart';

/// محرر الفاتورة: رأس الفاتورة + جدول أصناف ديناميكي + شريط إجماليات ثابت.
class InvoiceEditorScreen extends StatefulWidget {
  final int? invoiceId;
  final DocKind newKind;
  /// فاتورة جاهزة (من المسح) لم تُحفظ بعد.
  final Invoice? draft;

  const InvoiceEditorScreen(
      {super.key, this.invoiceId, this.newKind = DocKind.invoice, this.draft});

  @override
  State<InvoiceEditorScreen> createState() => _InvoiceEditorScreenState();
}

class _InvoiceEditorScreenState extends State<InvoiceEditorScreen> {
  final _db = AppDatabase.instance;
  Invoice? _inv;
  EditorController? _c;
  bool _headerOpen = true;
  Map<String, InvoiceItem> _catalog = {};
  List<String> _partyNames = [];

  final _number = TextEditingController();
  final _party = TextEditingController();
  final _notes = TextEditingController();
  final _paid = TextEditingController();
  final _currencyCtl = TextEditingController();
  final _vatCtl = TextEditingController();
  final _filter = TextEditingController();
  final _partyFocus = FocusNode();

  bool get _dirty => _c?.dirty ?? false;
  bool get _pinPrice => _c?.pinPrice ?? false;
  bool get _pinType => _c?.pinType ?? false;
  double get _pinnedPrice => _c?.pinnedPrice ?? 0;
  String get _pinnedType => _c?.pinnedType ?? '';

  String get _cur =>
      _inv?.currencyOr(SettingsService.instance.currency) ??
      SettingsService.instance.currency;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    Invoice inv;
    if (widget.draft != null) {
      inv = widget.draft!;
    } else if (widget.invoiceId != null) {
      inv = (await _db.getInvoice(widget.invoiceId!))!;
      _headerOpen = false;
    } else {
      inv = Invoice(
        kind: widget.newKind,
        number: await _db.nextNumber(widget.newKind),
        vatRate: widget.newKind == DocKind.invoice
            ? SettingsService.instance.defaultVatRate
            : 0,
      );
    }
    _catalog = await _db.itemCatalog();
    _partyNames = await _db.partyNames();
    _number.text = inv.number;
    _party.text = inv.party;
    _notes.text = inv.notes;
    _currencyCtl.text = inv.currency;
    _vatCtl.text = inv.vatRate == 0 ? '' : formatQty(inv.vatRate);
    _paid.text = _paidText(inv.status == InvoiceStatus.paid ? inv.grandTotal : inv.paidAmount);
    if (!mounted) return;
    final c = EditorController(inv, dirty: widget.draft != null)
      ..addListener(() {
        if (mounted) setState(() {});
      });
    setState(() {
      _inv = inv;
      _c = c;
    });
  }

  @override
  void dispose() {
    for (final c in [_number, _party, _notes, _paid, _currencyCtl, _vatCtl, _filter]) {
      c.dispose();
    }
    _partyFocus.dispose();
    _c?.dispose();
    super.dispose();
  }

  void _touch() => _c!.markDirty();

  void _syncHeader() {
    final inv = _inv!;
    inv.number = _number.text.trim().isEmpty ? inv.number : _number.text.trim();
    inv.party = _party.text.trim();
    inv.notes = _notes.text.trim();
    inv.currency = _currencyCtl.text.trim();
    if (inv.status == InvoiceStatus.paid) inv.paidAmount = inv.grandTotal;
  }

  String _paidText(double v) => v == 0 ? '' : formatQty(v);

  void _onPaidChanged(String t) => _c!.setPaidAmount(parseNumber(t) ?? 0);

  Future<void> _pickDue() async {
    final inv = _inv!;
    final d = await showDatePicker(
      context: context,
      initialDate: inv.dueDate ?? inv.date.add(const Duration(days: 30)),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d != null) {
      setState(() => inv.dueDate = d);
      _touch();
    }
  }

  Future<bool> _save({bool quiet = false}) async {
    final inv = _inv!;
    _syncHeader();
    await _db.saveInvoice(inv);
    if (mounted) {
      _c!.markSaved();
      if (!quiet) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('تم الحفظ')));
      }
    }
    return true;
  }

  Future<void> _editItem(InvoiceItem? existing) async {
    var current = existing;
    var isNew = current == null;
    while (true) {
      final item = current ?? _c!.blank();
      final r = await showItemEditSheet(
        context,
        item: item,
        isNew: isNew,
        pinPrice: _pinPrice,
        pinType: _pinType,
        catalog: _catalog,
      );
      if (r == null || !mounted) return;
      _c!.applyEdit(isNew ? null : item, r.item,
          pinPrice: r.pinPrice, pinType: r.pinType);
      if (r.addNext) {
        current = null;
        isNew = true;
        continue;
      }
      return;
    }
  }

  Future<void> _quickAdd() async {
    final c = TextEditingController(text: '15');
    final n = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة أسطر دفعة واحدة'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            _pinPrice || _pinType
                ? 'تُنسخ القيم المثبتة (${_pinType ? 'النوع: $_pinnedType' : ''}'
                    '${_pinType && _pinPrice ? '، ' : ''}'
                    '${_pinPrice ? 'السعر: ${formatMoney(_pinnedPrice)}' : ''}) في كل سطر.'
                : 'ثبّت السعر أو النوع من نافذة السطر ليُنسخ في الأسطر الجديدة.',
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: c,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'عدد الأسطر'),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            for (final v in [5, 10, 15, 20])
              ActionChip(label: Text('$v'), onPressed: () => c.text = '$v'),
          ]),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              final v = parseNumber(c.text)?.toInt() ?? 0;
              Navigator.pop(ctx, v.clamp(0, 200));
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
    c.dispose();
    if (n == null || n <= 0) return;
    _c!.addBlanks(n);
  }

  void _delete(InvoiceItem item) {
    final i = _c!.remove(item);
    if (i < 0) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: const Text('تم حذف السطر'),
        action: SnackBarAction(
          label: 'تراجع',
          onPressed: () => _c!.restore(i, item),
        ),
      ));
  }

  void _duplicate(InvoiceItem item) => _c!.duplicate(item);

  /// تكرار السطر N مرة (الكود والمرجع والنوع والسعر) والعدد فارغ لكل نسخة.
  Future<void> _duplicateMany(InvoiceItem item) async {
    final ctl = TextEditingController(text: '5');
    final n = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تكرار السطر'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('تُنسخ بيانات السطر (الكود، المرجع، النوع، السعر) ويُترك العدد فارغاً.',
              style: TextStyle(fontSize: 13)),
          const SizedBox(height: 12),
          TextField(
            controller: ctl,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'عدد النسخ (حتى 100)'),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            for (final v in [2, 5, 10, 15])
              ActionChip(label: Text('$v'), onPressed: () => ctl.text = '$v'),
          ]),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () => Navigator.pop(
                ctx, (parseNumber(ctl.text)?.toInt() ?? 0).clamp(0, 100)),
            child: const Text('تكرار'),
          ),
        ],
      ),
    );
    ctl.dispose();
    if (n == null || n <= 0 || !mounted) return;
    _c!.duplicate(item, times: n, keepQuantity: false);
  }

  Future<void> _sortSheet() async {
    final c = _c!;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final f in SortField.values)
            for (final asc in [true, false])
              ListTile(
                minTileHeight: 52,
                leading: Icon(asc ? Icons.arrow_upward : Icons.arrow_downward),
                title: Text('${f.label} ${asc ? 'تصاعدياً' : 'تنازلياً'}'),
                selected: c.sortField == f && c.sortAsc == asc,
                onTap: () {
                  Navigator.pop(ctx);
                  c.sortBy(f, asc);
                },
              ),
          const Divider(height: 1),
          ListTile(
            minTileHeight: 52,
            leading: const Icon(Icons.restore),
            title: const Text('استعادة ترتيب الإدخال الأصلي'),
            enabled: c.canRestoreOrder,
            onTap: () {
              Navigator.pop(ctx);
              c.restoreOriginalOrder();
            },
          ),
        ]),
      ),
    );
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _inv!.date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d != null) {
      setState(() => _inv!.date = d);
      _touch();
    }
  }

  Future<void> _openPdf() async {
    _syncHeader();
    await _save(quiet: true);
    if (!mounted) return;
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => PdfPreviewScreen(invoice: _inv!)));
  }

  bool get _worthSaving {
    final inv = _inv!;
    return inv.id != null ||
        inv.items.isNotEmpty ||
        _party.text.trim().isNotEmpty ||
        _notes.text.trim().isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final inv = _inv;
    if (inv == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final visible = _c!.visibleIndices;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        if (_dirty) {
          _syncHeader();
          if (_worthSaving) await _save(quiet: true);
        }
        nav.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('${inv.kind.label} ${_number.text}'),
          actions: [
            IconButton(
                tooltip: 'ترتيب',
                icon: const Icon(Icons.sort),
                onPressed: _sortSheet),
            IconButton(
                tooltip: 'PDF',
                icon: const Icon(Icons.picture_as_pdf_outlined),
                onPressed: _openPdf),
            IconButton(
                tooltip: 'حفظ',
                icon: Icon(_dirty ? Icons.save : Icons.check),
                onPressed: () => _save()),
          ],
        ),
        body: ContentWidth(
            child: Column(children: [
          _header(inv),
          _toolbar(),
          Expanded(
            child: inv.items.isEmpty
                ? Center(
                    child: Text('لا توجد أصناف. اضغط "إضافة سطر".',
                        style: TextStyle(color: Colors.grey.shade600)))
                : visible.isEmpty
                    ? const Center(child: Text('لا نتائج مطابقة'))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                        itemCount: visible.length,
                        itemBuilder: (_, k) {
                          final idx = visible[k];
                          final it = inv.items[idx];
                          return Dismissible(
                            key: ObjectKey(it),
                            background: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              decoration: BoxDecoration(
                                  color: Colors.red.shade400,
                                  borderRadius: BorderRadius.circular(14)),
                              alignment: AlignmentDirectional.centerStart,
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: const Icon(Icons.delete, color: Colors.white),
                            ),
                            direction: DismissDirection.startToEnd,
                            onDismissed: (_) => _delete(it),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: ItemTile(
                                index: idx + 1,
                                item: it,
                                onTap: () => _editItem(it),
                                onDuplicate: () => _duplicate(it),
                                onDuplicateMany: () => _duplicateMany(it),
                                onDelete: () => _delete(it),
                              ),
                            ),
                          );
                        },
                      ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: () => _editItem(null),
                    icon: const Icon(Icons.add),
                    label: const Text('إضافة سطر'),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 48,
                child: FilledButton.tonalIcon(
                  onPressed: _quickAdd,
                  icon: const Icon(Icons.playlist_add),
                  label: const Text('أسطر متعددة'),
                ),
              ),
            ]),
          ),
          TotalsBar(
            itemCount: inv.itemCount,
            totalQty: inv.totalQuantity,
            grandTotal: inv.grandTotal,
            subtotal: inv.subtotal,
            vatAmount: inv.vatAmount,
            vatRate: inv.vatRate,
            currency: _cur,
          ),
        ])),
      ),
    );
  }

  Widget _header(Invoice inv) {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Column(children: [
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => _headerOpen = !_headerOpen),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              const Icon(Icons.info_outline, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${formatDate(inv.date)}  |  ${_party.text.isEmpty ? 'بدون اسم عميل/مورد' : _party.text}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(_headerOpen ? Icons.expand_less : Icons.expand_more),
            ]),
          ),
        ),
        if (_headerOpen)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Column(children: [
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _number,
                    onChanged: (_) => _touch(),
                    decoration: const InputDecoration(labelText: 'رقم الفاتورة'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.event),
                      label: Text(formatDate(inv.date)),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Wrap(spacing: 8, children: [
                  for (final st in InvoiceStatus.values)
                    ChoiceChip(
                      label: Text(st.label),
                      selected: inv.status == st,
                      onSelected: (_) {
                        _c!.setStatus(st);
                        _paid.text = _paidText(inv.paidAmount);
                      },
                    ),
                ]),
              ),
              const SizedBox(height: 10),
              RawAutocomplete<String>(
                textEditingController: _party,
                focusNode: _partyFocus,
                optionsBuilder: (v) {
                  final q = v.text.trim();
                  if (q.isEmpty) return const Iterable<String>.empty();
                  return _partyNames.where((n) => n.contains(q) && n != q).take(6);
                },
                onSelected: (_) => _touch(),
                fieldViewBuilder: (c, ctl, fn, _) => TextField(
                  controller: ctl,
                  focusNode: fn,
                  onChanged: (_) => _touch(),
                  decoration: const InputDecoration(labelText: 'اسم العميل / المورد'),
                ),
                optionsViewBuilder: (c, onSel, opts) => Align(
                  alignment: AlignmentDirectional.topStart,
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(12),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 240, maxWidth: 420),
                      child: ListView(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        children: [
                          for (final o in opts)
                            ListTile(title: Text(o), onTap: () => onSel(o)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (inv.kind == DocKind.invoice) ...[
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: _pickDue,
                        onLongPress: inv.dueDate == null
                            ? null
                            : () {
                                setState(() => inv.dueDate = null);
                                _touch();
                              },
                        icon: const Icon(Icons.event_busy),
                        label: Text(inv.dueDate == null
                            ? 'تاريخ الاستحقاق'
                            : 'الاستحقاق: ${formatDate(inv.dueDate!)}'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _paid,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: _onPaidChanged,
                      decoration: InputDecoration(
                          labelText: 'المدفوع', suffixText: _cur),
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                TextField(
                  controller: _vatCtl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (t) => _c!.setVatRate(parseNumber(t) ?? 0),
                  decoration: const InputDecoration(
                      labelText: 'ضريبة القيمة المضافة %',
                      hintText: '0 = بدون ضريبة',
                      suffixText: '%'),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    inv.isOverdue
                        ? 'متأخرة - المتبقي ${formatMoney(inv.remaining)} $_cur'
                        : 'المتبقي ${formatMoney(inv.remaining)} $_cur',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: inv.isOverdue
                            ? Colors.red.shade700
                            : inv.isFullyPaid
                                ? Colors.green.shade700
                                : null),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              TextField(
                controller: _currencyCtl,
                onChanged: (_) {
                  _syncHeader();
                  _touch();
                },
                decoration: InputDecoration(
                    labelText: 'العملة (اختياري)',
                    hintText: SettingsService.instance.currency),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _notes,
                onChanged: (_) => _touch(),
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'ملاحظات عامة'),
              ),
            ]),
          ),
      ]),
    );
  }

  Widget _toolbar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Column(children: [
        TextField(
          controller: _filter,
          onChanged: (v) => _c!.setQuery(v),
          decoration: InputDecoration(
            hintText: 'بحث في الأسطر (كود، مرجع، نوع، رقم)',
            prefixIcon: const Icon(Icons.filter_list),
            isDense: true,
            suffixIcon: _filter.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _filter.clear();
                      _c!.setQuery('');
                    }),
          ),
        ),
        if (_pinPrice || _pinType)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Wrap(spacing: 8, children: [
              if (_pinType)
                InputChip(
                  avatar: const Icon(Icons.push_pin, size: 16),
                  label: Text('النوع: $_pinnedType'),
                  onDeleted: () => _c!.clearPinType(),
                ),
              if (_pinPrice)
                InputChip(
                  avatar: const Icon(Icons.push_pin, size: 16),
                  label: Text('السعر: ${formatMoney(_pinnedPrice)}'),
                  onDeleted: () => _c!.clearPinPrice(),
                ),
            ]),
          ),
      ]),
    );
  }
}
