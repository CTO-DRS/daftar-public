import 'package:flutter/material.dart';

import '../utils/number_utils.dart';

/// الشريط السفلي الثابت: عدد الأصناف، إجمالي القطع، المبلغ النهائي.
class TotalsBar extends StatelessWidget {
  final int itemCount;
  final double totalQty;
  final double grandTotal;
  final String currency;
  final double subtotal;
  final double vatAmount;
  final double vatRate;

  const TotalsBar({
    super.key,
    required this.itemCount,
    required this.totalQty,
    required this.grandTotal,
    required this.currency,
    this.subtotal = 0,
    this.vatAmount = 0,
    this.vatRate = 0,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF0E4F4B)
          : cs.primary,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (vatAmount > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  'قبل الضريبة ${formatMoney(subtotal)}  +  ضريبة ${formatQty(vatRate)}% ${formatMoney(vatAmount)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            Row(children: [
            _Stat(label: 'الأصناف', value: localizeDigits('$itemCount')),
            _divider(),
            _Stat(label: 'العدد الكلي', value: formatQty(totalQty)),
            _divider(),
            Expanded(
              flex: 2,
              child: _Stat(
                  label: 'الإجمالي ($currency)',
                  value: formatMoney(grandTotal),
                  big: true),
            ),
          ]),
          ]),
        ),
      ),
    );
  }

  Widget _divider() => Container(
      width: 1,
      height: 32,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: Colors.white24);
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final bool big;
  const _Stat({required this.label, required this.value, this.big = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(value,
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: big ? 22 : 18)),
        ),
      ],
    );
  }
}
