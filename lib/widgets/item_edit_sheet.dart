import 'package:flutter/material.dart';

import '../database/app_database.dart';
import '../models/invoice_item.dart';
import '../utils/pricing.dart';
import '../utils/number_utils.dart';

class ItemEditResult {
  final InvoiceItem item;
  final bool addNext;
  final bool pinPrice;
  final bool pinType;
  ItemEditResult(this.item, this.addNext, this.pinPrice, this.pinType);
}

/// ورقة تعديل/إضافة سطر مع أزرار تثبيت السعر والنوع.
Future<ItemEditResult?> showItemEditSheet(
  BuildContext context, {
  required InvoiceItem item,
  required bool isNew,
  required bool pinPrice,
  required bool pinType,
  Map<String, InvoiceItem> catalog = const {},
}) {
  return showModalBottomSheet<ItemEditResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ItemEditSheet(
        item: item,
        isNew: isNew,
        pinPrice: pinPrice,
        pinType: pinType,
        catalog: catalog),
  );
}

class _ItemEditSheet extends StatefulWidget {
  final InvoiceItem item;
  final bool isNew;
  final bool pinPrice;
  final bool pinType;
  final Map<String, InvoiceItem> catalog;
  const _ItemEditSheet(
      {required this.catalog,
      required this.item,
      required this.isNew,
      required this.pinPrice,
      required this.pinType});

  @override
  State<_ItemEditSheet> createState() => _ItemEditSheetState();
}

class _ItemEditSheetState extends State<_ItemEditSheet> {
  late final _code = TextEditingController(text: widget.item.itemCode);
  late final _ref = TextEditingController(text: widget.item.refNumber);
  late final _type = TextEditingController(text: widget.item.description);
  late final _qty = TextEditingController(
      text: widget.item.quantity == 0 ? '' : plainNumber(widget.item.quantity));
  late final _price = TextEditingController(
      text: widget.item.unitPrice == 0 ? '' : plainNumber(widget.item.unitPrice));
  late final _notes = TextEditingController(text: widget.item.notes);
  late final _unit = TextEditingController(text: widget.item.unit);
  late final _wQty = TextEditingController(
      text: widget.item.wholesaleQty == 0 ? '' : plainNumber(widget.item.wholesaleQty));
  late final _wPrice = TextEditingController(
      text: widget.item.wholesalePrice == 0 ? '' : plainNumber(widget.item.wholesalePrice));
  late final _wUnit = TextEditingController(text: widget.item.wholesaleUnit);
  late final _cost = TextEditingController(
      text: widget.item.costPrice == 0 ? '' : plainNumber(widget.item.costPrice));
  late final _pack = TextEditingController(
      text: widget.item.packSize == 0 ? '' : plainNumber(widget.item.packSize));
  late bool _showWholesale = widget.item.hasWholesale || widget.item.packSize > 0;
  List<PriceTier> _tiers = [];
  bool _tiersDirty = false;
  bool _showTiers = false;
  final _tMin = TextEditingController();
  final _tPrice = TextEditingController();
  String? _tierNote;

  @override
  void initState() {
    super.initState();
    _loadTiers();
  }

  String get _key => tierKey(_code.text, _type.text);

  Future<void> _loadTiers() async {
    try {
      final t = await AppDatabase.instance.tiersFor(_key);
      if (mounted && !_tiersDirty) {
        setState(() {
          _tiers = t;
          if (t.isNotEmpty) _showTiers = true;
        });
      }
    } catch (_) {}
  }

  /// يطبّق شريحة السعر المناسبة للكمية الحالية.
  void _applyTier() {
    final q = parseNumber(_qty.text) ?? 0;
    final p = tierPrice(_tiers, q);
    if (p != null && q > 0) {
      _price.text = plainNumber(p);
      _tierNote = 'شريحة الكمية: ${formatMoney(p)} للوحدة';
    } else {
      _tierNote = null;
    }
  }

  void _addTier() {
    final m = parseNumber(_tMin.text) ?? 0;
    final pr = parseNumber(_tPrice.text) ?? 0;
    if (m <= 0 || pr <= 0) return;
    setState(() {
      _tiers = [..._tiers.where((t) => t.minQty != m), PriceTier(m, pr)]
        ..sort((a, b) => a.minQty.compareTo(b.minQty));
      _tiersDirty = true;
      _tMin.clear();
      _tPrice.clear();
      _applyTier();
    });
  }
  static const _unitPresets = [
    'عدد', 'حبة', 'درزن', 'كرتون', 'علبة', 'باكت', 'كيس', 'صندوق', 'رزمة', 'حزمة', 'لفة', 'طقم',
    'زجاجة', 'قارورة', 'برميل', 'جالون', 'كجم', 'جم', 'طن', 'رطل', 'أونصة', 'لتر', 'مل',
    'متر', 'سم', 'متر مربع', 'إنش', 'قدم', 'ياردة', 'ساعة', 'يوم', 'خدمة',
  ];
  late bool _pinPrice = widget.pinPrice;
  late bool _pinType = widget.pinType;

  double get _total =>
      (parseNumber(_qty.text) ?? 0) * (parseNumber(_price.text) ?? 0) +
      (parseNumber(_wQty.text) ?? 0) * (parseNumber(_wPrice.text) ?? 0);

  @override
  void dispose() {
    for (final c in [_code, _ref, _type, _qty, _price, _notes, _unit, _wQty, _wPrice, _wUnit, _pack, _cost, _tMin, _tPrice]) {
      c.dispose();
    }
    super.dispose();
  }

  /// كتالوج تلقائي: عند كتابة كود سبق استخدامه نملأ النوع والسعر والمرجع إن كانت فارغة.
  void _fromCatalog(String code) {
    final hit = widget.catalog[code.trim()];
    if (hit == null) return;
    setState(() {
      if (_type.text.isEmpty) _type.text = hit.description;
      if (_ref.text.isEmpty) _ref.text = hit.refNumber;
      if (_price.text.isEmpty && hit.unitPrice > 0) {
        _price.text = plainNumber(hit.unitPrice);
      }
    });
  }

  void _submit(bool addNext) {
    final it = widget.item.copy()
      ..itemCode = _code.text.trim()
      ..refNumber = _ref.text.trim()
      ..description = _type.text.trim()
      ..quantity = parseNumber(_qty.text) ?? 0
      ..unitPrice = parseNumber(_price.text) ?? 0
      ..notes = _notes.text.trim()
      ..unit = _unit.text.trim()
      ..wholesaleQty = parseNumber(_wQty.text) ?? 0
      ..wholesalePrice = parseNumber(_wPrice.text) ?? 0
      ..wholesaleUnit = _wUnit.text.trim()
      ..packSize = parseNumber(_pack.text) ?? 0
      ..costPrice = parseNumber(_cost.text) ?? 0
      ..flagged = false;
    if (_tiersDirty) {
      AppDatabase.instance.saveTiers(_key, _tiers);
    }
    Navigator.pop(context, ItemEditResult(it, addNext, _pinPrice, _pinType));
  }

  Widget _pin(bool on, VoidCallback toggle, String tip) => SizedBox(
        width: 48,
        height: 48,
        child: IconButton(
          tooltip: tip,
          isSelected: on,
          icon: const Icon(Icons.push_pin_outlined),
          selectedIcon: const Icon(Icons.push_pin),
          onPressed: toggle,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    const numKb = TextInputType.numberWithOptions(decimal: true);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottom + 16),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Expanded(
                child: TextField(
                    controller: _code,
                    onChanged: (v) {
                      _fromCatalog(v);
                      _loadTiers();
                    },
                    decoration: const InputDecoration(labelText: 'كود الصنف'))),
            const SizedBox(width: 10),
            Expanded(
                child: TextField(
                    controller: _ref,
                    decoration:
                        const InputDecoration(labelText: 'الرقم المرجعي'))),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
                child: TextField(
                    controller: _type,
                    onChanged: (_) => _loadTiers(),
                    decoration:
                        const InputDecoration(labelText: 'النوع / الوصف'))),
            _pin(_pinType, () => setState(() => _pinType = !_pinType),
                'تثبيت النوع'),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
                child: TextField(
                    controller: _qty,
                    keyboardType: numKb,
                    autofocus: widget.isNew,
                    onChanged: (_) => setState(_applyTier),
                    decoration: const InputDecoration(labelText: 'العدد'))),
            const SizedBox(width: 10),
            Expanded(
                child: TextField(
                    controller: _price,
                    keyboardType: numKb,
                    onChanged: (_) => setState(() {}),
                    decoration:
                        const InputDecoration(labelText: 'سعر الفردي'))),
            _pin(_pinPrice, () => setState(() => _pinPrice = !_pinPrice),
                'تثبيت السعر الفردي'),
          ]),
          const SizedBox(height: 10),
          TextField(
              controller: _cost,
              keyboardType: numKb,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                  labelText: 'سعر التكلفة للقطعة (اختياري)',
                  helperText: 'يُستخدم لحساب الربح في الذكاء المالي')),
          const SizedBox(height: 10),
          TextField(
              controller: _unit,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                  labelText: 'الوحدة', hintText: 'اختر أو اكتب وحدة أخرى')),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 0, children: [
            for (final u in _unitPresets)
              ChoiceChip(
                label: Text(u),
                visualDensity: VisualDensity.compact,
                selected: _unit.text.trim() == u,
                onSelected: (on) => setState(() => _unit.text = on ? u : ''),
              ),
          ]),
          const SizedBox(height: 4),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () => setState(() => _showWholesale = !_showWholesale),
              icon: Icon(_showWholesale ? Icons.expand_less : Icons.add_box_outlined, size: 18),
              label: Text(_showWholesale ? 'إخفاء الجملة' : 'إضافة بيع بالجملة'),
            ),
          ),
          if (_showWholesale) ...[
            Row(children: [
              Expanded(
                  child: TextField(
                      controller: _wQty,
                      keyboardType: numKb,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(labelText: 'عدد الجملة'))),
              const SizedBox(width: 10),
              Expanded(
                  child: TextField(
                      controller: _wPrice,
                      keyboardType: numKb,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(labelText: 'سعر الجملة'))),
            ]),
            const SizedBox(height: 10),
            TextField(
                controller: _wUnit,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                    labelText: 'وحدة الجملة', hintText: 'كرتون، درزن، كيس...')),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 0, children: [
              for (final u in const ['كرتون', 'درزن', 'كيس', 'صندوق', 'باكت', 'رزمة'])
                ChoiceChip(
                  label: Text(u),
                  visualDensity: VisualDensity.compact,
                  selected: _wUnit.text.trim() == u,
                  onSelected: (on) => setState(() => _wUnit.text = on ? u : ''),
                ),
            ]),
            const SizedBox(height: 10),
            TextField(
                controller: _pack,
                keyboardType: numKb,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                    labelText: 'حجم العبوة (كم قطعة في وحدة الجملة)',
                    hintText: 'مثال: 24',
                    helperText: (parseNumber(_pack.text) ?? 0) > 0 && (parseNumber(_wQty.text) ?? 0) > 0
                        ? '${formatQty(parseNumber(_wQty.text)!)} ${_wUnit.text.trim()} = ${formatQty(parseNumber(_wQty.text)! * parseNumber(_pack.text)!)} قطعة'
                        : null)),
            if ((parseNumber(_pack.text) ?? 0) > 0)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Wrap(spacing: 8, children: [
                  if ((parseNumber(_price.text) ?? 0) > 0)
                    ActionChip(
                      avatar: const Icon(Icons.calculate_outlined, size: 16),
                      label: const Text('سعر الجملة = الفردي × العبوة'),
                      onPressed: () => setState(() => _wPrice.text =
                          plainNumber((parseNumber(_price.text)! * parseNumber(_pack.text)!))),
                    ),
                  if ((parseNumber(_wPrice.text) ?? 0) > 0)
                    ActionChip(
                      avatar: const Icon(Icons.calculate_outlined, size: 16),
                      label: const Text('الفردي = سعر الجملة ÷ العبوة'),
                      onPressed: () => setState(() => _price.text =
                          plainNumber((parseNumber(_wPrice.text)! / parseNumber(_pack.text)!))),
                    ),
                ]),
              ),
          ],
          const SizedBox(height: 4),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () => setState(() => _showTiers = !_showTiers),
              icon: Icon(_showTiers ? Icons.expand_less : Icons.stacked_bar_chart, size: 18),
              label: Text(_showTiers ? 'إخفاء شرائح السعر' : 'شرائح السعر حسب الكمية'),
            ),
          ),
          if (_showTiers) ...[
            for (final t in _tiers)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.arrow_circle_down_outlined),
                title: Text('من ${formatQty(t.minQty)} فأكثر: ${formatMoney(t.price)} للوحدة'),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() {
                    _tiers = _tiers.where((e) => e != t).toList();
                    _tiersDirty = true;
                    _applyTier();
                  }),
                ),
              ),
            Row(children: [
              Expanded(
                  child: TextField(
                      controller: _tMin,
                      keyboardType: numKb,
                      decoration: const InputDecoration(labelText: 'من كمية'))),
              const SizedBox(width: 10),
              Expanded(
                  child: TextField(
                      controller: _tPrice,
                      keyboardType: numKb,
                      decoration: const InputDecoration(labelText: 'السعر للوحدة'))),
              IconButton.filledTonal(onPressed: _addTier, icon: const Icon(Icons.add)),
            ]),
            if (_tierNote != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(_tierNote!, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 12)),
              ),
          ],
          const SizedBox(height: 10),
          TextField(
              controller: _notes,
              decoration: const InputDecoration(labelText: 'ملاحظات')),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12)),
            child: Text('الإجمالي: ${formatMoney(_total)}',
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 18)),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: SizedBox(
                    height: 52,
                    child: FilledButton(
                        onPressed: () => _submit(false),
                        child: const Text('حفظ')))),
            if (widget.isNew) ...[
              const SizedBox(width: 10),
              Expanded(
                  child: SizedBox(
                      height: 52,
                      child: FilledButton.tonal(
                          onPressed: () => _submit(true),
                          child: const Text('حفظ وإضافة التالي')))),
            ],
          ]),
        ]),
      ),
    );
  }
}
