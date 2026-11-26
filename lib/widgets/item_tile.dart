import 'package:flutter/material.dart';

import '../models/invoice_item.dart';
import '../utils/number_utils.dart';

/// بطاقة سطر صنف: م، كود، مرجع، نوع، العدد × الفردي = الإجمالي، ملاحظات.
class ItemTile extends StatelessWidget {
  final int index; // رقم م (يبدأ من 1)
  final InvoiceItem item;
  final VoidCallback onTap;
  final VoidCallback onDuplicate;
  final VoidCallback? onDuplicateMany;
  final VoidCallback onDelete;

  const ItemTile({
    super.key,
    required this.index,
    required this.item,
    required this.onTap,
    required this.onDuplicate,
    this.onDuplicateMany,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final flagged = item.flagged;
    return Card(
      color: flagged ? const Color(0xFFFFF4E5) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
            color: flagged
                ? Colors.orange.shade400
                : cs.outlineVariant.withValues(alpha: .5)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: cs.primaryContainer, shape: BoxShape.circle),
              child: Text(localizeDigits('$index'),
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(spacing: 8, runSpacing: 2, children: [
                    if (item.itemCode.isNotEmpty)
                      _Tag(Icons.tag, item.itemCode),
                    if (item.refNumber.isNotEmpty)
                      _Tag(Icons.radio_button_unchecked, item.refNumber),
                  ]),
                  Text(
                    item.description.isEmpty ? 'بدون وصف' : item.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: item.description.isEmpty
                            ? Colors.grey
                            : Colors.black87),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${formatQty(item.quantity)}${item.unit.trim().isEmpty ? '' : ' ${item.unit.trim()}'} × ${formatMoney(item.unitPrice)}',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                  ),
                  if (item.notes.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(item.notes,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 12)),
                    ),
                ],
              ),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(formatMoney(item.total),
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 16)),
              SizedBox(
                width: 48,
                height: 48,
                child: PopupMenuButton<String>(
                  tooltip: 'خيارات السطر',
                  onSelected: (v) => v == 'dup'
                      ? onDuplicate()
                      : v == 'dupn'
                          ? onDuplicateMany!()
                          : onDelete(),
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'dup', child: Text('تكرار السطر')),
                    if (onDuplicateMany != null)
                      const PopupMenuItem(
                          value: 'dupn', child: Text('تكرار عدة مرات...')),
                    const PopupMenuItem(value: 'del', child: Text('حذف السطر')),
                  ],
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Tag(this.icon, this.text);
  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.grey.shade600),
          const SizedBox(width: 3),
          Text(text,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
        ],
      );
}
