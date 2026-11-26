import 'package:flutter/material.dart';

import '../database/app_database.dart';
import '../models/invoice.dart';
import '../models/invoice_item.dart';
import '../services/settings_service.dart';
import '../utils/date_utils.dart';
import '../utils/number_utils.dart';
import '../utils/sort_utils.dart';
import '../widgets/item_edit_sheet.dart';
import '../widgets/item_tile.dart';
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
  bool _dirty = false;
  bool _headerOpen = true;

  final _number = TextEditingController();
  final _party = TextEditingController();
  final _notes = TextEditingController();
  final _filter = TextEditingController();

  // تثبيت السعر والنوع
  bool _pinPrice = false;
  bool _pinType = false;
  double _pinnedPrice = 0;
  String _pinnedType = '';

  SortField _sortField = SortField.itemCode;
  bool _asc = true;

  String get _cur => SettingsService.instance.currency;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    Invoice inv;
    if (widget.draft != null) {
      inv = widget.draft!;
      _dirty = true;
    } else if (widget.invoiceId != null) {
      inv = (await _db.getInvoice(widget.invoiceId!))!;
      _headerOpen = false;
    } else {
      inv = Invoice(kind: widget.newKind, number: await _db.nextNumber());
    }
    _number.text = inv.number;
    _party.text = inv.party;
    _notes.text = inv.notes;
    if (!mounted) return;
    setState(() => _inv = inv);
  }

  @override
  void dispose() {
    for (final c in [_number, _party, _notes, _filter]) {
      c.dispose();
    }
    super.dispose();
  }

  void _touch() => setState(() => _dirty = true);

  void _syncHeader() {
    final inv = _inv!;
    inv.number = _number.text.trim().isEmpty ? inv.number : _number.text.trim();
    inv.party = _party.text.trim();
    inv.notes = _notes.text.trim();
  }

  Future<bool> _save({bool quiet = false}) async {
    final inv = _inv!;
    _syncHeader();
    await _db.saveInvoice(inv);
    if (mounted) {
      setState(() => _dirty = false);
      if (!quiet) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('تم الحفظ')));
      }
    }
    return true;
  }

  InvoiceItem _blank() => InvoiceItem(
        quantity: 1,
        unitPrice: _pinPrice ? _pinnedPrice : 0,
        description: _pinType ? _pinnedType : '',
      );

  Future<void> _editItem(InvoiceItem? existing) async {
    var current = existing;
    var isNew = current == null;
    while (true) {
      final item = current ?? _blank();
      final r = await showItemEditSheet(
        context,
        item: item,
        isNew: isNew,
        pinPrice: _pinPrice,
        pinType: _pinType,
      );
      if (r == null || !mounted) return;
      setState(() {
        _pinPrice = r.pinPrice;
        _pinType = r.pinType;
        if (r.pinPrice) _pinnedPrice = r.item.unitPrice;
        if (r.pinType) _pinnedType = r.item.description;
        if (isNew) {
          _inv!.items.add(r.item);
        } else {
          final i = _inv!.items.indexOf(item);
          if (i >= 0) _inv!.items[i] = r.item;
        }
        _dirty = true;
      });
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
    setState(() {
      for (var i = 0; i < n; i++) {
        _inv!.items.add(_blank());
      }
      _dirty = true;
    });
  }

  void _delete(InvoiceItem item) {
    final i = _inv!.items.indexOf(item);
    if (i < 0) return;
    setState(() {
      _inv!.items.removeAt(i);
      _dirty = true;
    });
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: const Text('تم حذف السطر'),
        action: SnackBarAction(
          label: 'تراجع',
          onPressed: () => setState(() {
            _inv!.items.insert(i.clamp(0, _inv!.items.length), item);
            _dirty = true;
          }),
        ),
      ));
  }

  void _duplicate(InvoiceItem item) {
    final i = _inv!.items.indexOf(item);
    setState(() {
      _inv!.items.insert(i + 1, item.copy()..id = null);
      _dirty = true;
    });
  }

  Future<void> _sortSheet() async {
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
                selected: _sortField == f && _asc == asc,
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _sortField = f;
                    _asc = asc;
                    sortItems(_inv!.items, f, asc);
                    _dirty = true;
                  });
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
    final q = normalizeDigits(_filter.text).trim().toLowerCase();
    final visible = <int>[];
    for (var i = 0; i < inv.items.length; i++) {
      final it = inv.items[i];
      if (q.isEmpty ||
          '${it.itemCode} ${it.refNumber} ${it.description} ${it.notes}'
              .toLowerCase()
              .contains(q)) {
        visible.add(i);
      }
    }

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
        body: Column(children: [
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
            currency: _cur,
          ),
        ]),
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
              TextField(
                controller: _party,
                onChanged: (_) => _touch(),
                decoration:
                    const InputDecoration(labelText: 'اسم العميل / المورد'),
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
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'فلترة الأسطر (كود، مرجع، نوع)',
            prefixIcon: const Icon(Icons.filter_list),
            isDense: true,
            suffixIcon: _filter.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() => _filter.clear())),
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
                  onDeleted: () => setState(() => _pinType = false),
                ),
              if (_pinPrice)
                InputChip(
                  avatar: const Icon(Icons.push_pin, size: 16),
                  label: Text('السعر: ${formatMoney(_pinnedPrice)}'),
                  onDeleted: () => setState(() => _pinPrice = false),
                ),
            ]),
          ),
      ]),
    );
  }
}
