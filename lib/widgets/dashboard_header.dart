import 'package:flutter/material.dart';

import '../utils/dashboard.dart';
import '../utils/number_utils.dart';

/// لوحة الرئيسية: بطاقات المبيعات والمستحقات والمتأخرات + رسم أعمدة لآخر 6 أشهر.
class DashboardHeader extends StatelessWidget {
  final DashboardStats stats;
  final String currency;
  const DashboardHeader({super.key, required this.stats, required this.currency});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(children: [
        Row(children: [
          Expanded(
              child: _StatCard(
                  label: 'مبيعات هذا الشهر',
                  value: formatMoney(stats.monthSales),
                  unit: currency,
                  icon: Icons.trending_up,
                  color: cs.primary)),
          const SizedBox(width: 10),
          Expanded(
              child: _StatCard(
                  label: 'مستحقات لم تُسدَّد',
                  value: formatMoney(stats.outstanding),
                  unit: currency,
                  icon: Icons.hourglass_bottom,
                  color: Colors.orange.shade800)),
          if (stats.overdueCount > 0) ...[
            const SizedBox(width: 10),
            Expanded(
                child: _StatCard(
                    label: 'متأخرة',
                    value: localizeDigits('${stats.overdueCount}'),
                    unit: 'فاتورة',
                    icon: Icons.warning_amber_rounded,
                    color: Colors.red.shade700)),
          ],
        ]),
        const SizedBox(height: 10),
        Container(
          height: 118,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: .5)),
          ),
          child: CustomPaint(
            size: Size.infinite,
            painter: _BarsPainter(
              values: stats.monthly,
              labels: [for (final m in stats.months) arabicMonths[m.month - 1]],
              bar: cs.primary,
              barDim: cs.primary.withValues(alpha: dark ? .45 : .35),
              text: cs.onSurfaceVariant,
              valueText: cs.onSurface,
              fmt: (v) => _short(v),
            ),
          ),
        ),
        const SizedBox(height: 6),
      ]),
    );
  }

  static String _short(double v) {
    final a = v.abs();
    final sign = v < 0 ? '-' : '';
    if (a >= 1e6) return localizeDigits('$sign${(a / 1e6).toStringAsFixed(1)}M');
    if (a >= 1e3) return localizeDigits('$sign${(a / 1e3).toStringAsFixed(1)}K');
    return localizeDigits('$sign${a.toStringAsFixed(0)}');
  }
}

class _StatCard extends StatelessWidget {
  final String label, value, unit;
  final IconData icon;
  final Color color;
  const _StatCard(
      {required this.label,
      required this.value,
      required this.unit,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: .5)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant))),
        ]),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text.rich(TextSpan(children: [
            TextSpan(
                text: value,
                style: TextStyle(
                    fontSize: 19, fontWeight: FontWeight.w700, color: color)),
            TextSpan(
                text: ' $unit',
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
          ])),
        ),
      ]),
    );
  }
}

class _BarsPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final Color bar, barDim, text, valueText;
  final String Function(double) fmt;
  _BarsPainter(
      {required this.values,
      required this.labels,
      required this.bar,
      required this.barDim,
      required this.text,
      required this.valueText,
      required this.fmt});

  void _label(Canvas c, String s, Offset center, Color col, double size,
      {FontWeight w = FontWeight.w400}) {
    final tp = TextPainter(
      text: TextSpan(
          text: s,
          style: TextStyle(
              fontFamily: 'IBMPlexSansArabic', fontSize: size, color: col, fontWeight: w)),
      textDirection: TextDirection.rtl,
    )..layout();
    tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    const labelH = 16.0, topH = 14.0;
    final chartH = size.height - labelH - topH;
    final maxV = values.fold<double>(0, (m, v) => v.abs() > m ? v.abs() : m);
    final n = values.length;
    // RTL: الأقدم يمين والأحدث يسار.
    final slot = size.width / n;
    final bw = slot * .5;
    for (var i = 0; i < n; i++) {
      final cx = size.width - slot * (i + .5);
      final h = maxV == 0 ? 0.0 : (values[i].abs() / maxV) * chartH;
      final r = RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - bw / 2, topH + chartH - h.clamp(2, chartH), bw,
              h.clamp(2, chartH)),
          const Radius.circular(5));
      canvas.drawRRect(r, Paint()..color = i == n - 1 ? bar : barDim);
      if (values[i] != 0) {
        _label(canvas, fmt(values[i]), Offset(cx, topH + chartH - h.clamp(2, chartH) - 7),
            valueText, 10, w: FontWeight.w600);
      }
      _label(canvas, labels[i], Offset(cx, size.height - labelH / 2), text, 10);
    }
  }

  @override
  bool shouldRepaint(_BarsPainter o) =>
      o.values != values || o.bar != bar || o.text != text;
}
