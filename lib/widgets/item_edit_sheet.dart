import 'package:flutter/material.dart';

import '../models/invoice_item.dart';
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
}) {
  return showModalBottomSheet<ItemEditResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ItemEditSheet(
        item: item, isNew: isNew, pinPrice: pinPrice, pinType: pinType),
  );
}

class _ItemEditSheet extends StatefulWidget {
  final InvoiceItem item;
  final bool isNew;
  final bool pinPrice;
  final bool pinType;
  const _ItemEditSheet(
      {required this.item,
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
  late bool _pinPrice = widget.pinPrice;
  late bool _pinType = widget.pinType;

  double get _total =>
      (parseNumber(_qty.text) ?? 0) * (parseNumber(_price.text) ?? 0);

  @override
  void dispose() {
    for (final c in [_code, _ref, _type, _qty, _price, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit(bool addNext) {
    final it = widget.item.copy()
      ..itemCode = _code.text.trim()
      ..refNumber = _ref.text.trim()
      ..description = _type.text.trim()
      ..quantity = parseNumber(_qty.text) ?? 0
      ..unitPrice = parseNumber(_price.text) ?? 0
      ..notes = _notes.text.trim()
      ..flagged = false;
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
                    onChanged: (_) => setState(() {}),
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
