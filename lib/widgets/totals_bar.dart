import 'package:flutter/material.dart';

import '../utils/number_utils.dart';

/// الشريط السفلي الثابت: عدد الأصناف، إجمالي القطع، المبلغ النهائي.
class TotalsBar extends StatelessWidget {
  final int itemCount;
  final double totalQty;
  final double grandTotal;
  final String currency;

  const TotalsBar({
    super.key,
    required this.itemCount,
    required this.totalQty,
    required this.grandTotal,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.primary,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            _Stat(label: 'الأصناف', value: localizeDigits('$itemCount')),
            _divider(),
            _Stat(label: 'القطع', value: formatQty(totalQty)),
            _divider(),
            Expanded(
              flex: 2,
              child: _Stat(
                  label: 'الإجمالي ($currency)',
                  value: formatMoney(grandTotal),
                  big: true),
            ),
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
