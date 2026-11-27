import 'auto_fill.dart' show normArabic;
import 'number_utils.dart';

/// نقطة سعر تاريخية لصنف: سعر البيع والتكلفة في فاتورة ما.
class PricePoint {
  final double price;
  final double cost;
  final String party;
  final DateTime date;
  const PricePoint(this.price, this.cost, this.party, this.date);
}

class PriceHint {
  final String text;
  final bool warn;
  final double? suggested; // سعر مقترح يُطبَّق بضغطة
  final String? suggestedLabel;
  const PriceHint(this.text, {this.warn = false, this.suggested, this.suggestedLabel});
}

double _median(List<double> v) {
  final s = [...v]..sort();
  return s.length.isOdd ? s[s.length ~/ 2] : (s[s.length ~/ 2 - 1] + s[s.length ~/ 2]) / 2;
}

String _pct(double v) => localizeDigits(v.abs().round().toString());

/// تلميحات تسعير لسطر: اتجاه السعر، سعر باقي العملاء، الهامش، وتقريب مقترح.
/// [points] مرتبة من الأقدم للأحدث. لا شيء يُفرض: كلها اقتراحات.
List<PriceHint> priceHints({
  required String description,
  required double price,
  required double cost,
  required String party,
  required List<PricePoint> points,
}) {
  final out = <PriceHint>[];
  if (normArabic(description).isEmpty) return out;
  final pts = points.where((p) => p.price > 0).toList();

  // اتجاه السعر عبر آخر 3 فواتير (كل العملاء).
  if (pts.length >= 3) {
    final last3 = pts.sublist(pts.length - 3);
    final first = last3.first.price;
    final lastP = last3.last.price;
    final ch = (lastP - first) / first * 100;
    if (ch.abs() >= 5 && last3[1].price >= (first < lastP ? first : lastP) * 0.999) {
      out.add(PriceHint(ch > 0
          ? 'السعر ارتفع ${_pct(ch)}% خلال آخر 3 فواتير (من ${plainNumber(first)} إلى ${plainNumber(lastP)}).'
          : 'السعر انخفض ${_pct(ch)}% خلال آخر 3 فواتير (من ${plainNumber(first)} إلى ${plainNumber(lastP)}).'));
    }
  }

  // سعر باقي العملاء: آخر سعر لكل عميل آخر.
  final p = party.trim();
  final latest = <String, double>{};
  for (final x in pts) {
    if (x.party.trim().isEmpty || x.party.trim() == p) continue;
    latest[x.party.trim()] = x.price;
  }
  if (latest.length >= 2) {
    final v = latest.values.toList();
    final lo = v.reduce((a, b) => a < b ? a : b);
    final hi = v.reduce((a, b) => a > b ? a : b);
    final med = _median(v);
    out.add(PriceHint(
        'عند ${localizeDigits('${latest.length}')} عملاء آخرين: من ${plainNumber(lo)} إلى ${plainNumber(hi)} (الوسيط ${plainNumber(med)}).'));
    if (price > 0 && price < lo * 0.9) {
      out.add(PriceHint('سعرك أقل من أدنى سعر عند باقي العملاء (${plainNumber(lo)}).',
          warn: true, suggested: med, suggestedLabel: 'الوسيط ${plainNumber(med)}'));
    }
  }

  // الهامش مقابل المعتاد (يلزم تكلفة في 3 فواتير سابقة على الأقل).
  final margins = [
    for (final x in pts)
      if (x.cost > 0 && x.price > x.cost) (x.price - x.cost) / x.price * 100
  ];
  if (price > 0 && cost > 0 && margins.length >= 3) {
    final usual = _median(margins);
    final now = (price - cost) / price * 100;
    if (now < usual - 5) {
      final target = cost / (1 - usual / 100);
      final rounded = (target * 2).ceil() / 2;
      out.add(PriceHint(
          'الهامش ${_pct(now)}% أقل من هامشك المعتاد ${_pct(usual)}% لهذا الصنف.',
          warn: true,
          suggested: rounded,
          suggestedLabel: 'للوصول للمعتاد: ${plainNumber(rounded)}'));
    }
  }

  // تقريب: سعر بكسور غريبة.
  if (price >= 10) {
    final r = (price * 2).round() / 2;
    if ((price - r).abs() > 0.004 && (price - r).abs() < 1) {
      out.add(PriceHint('السعر ${plainNumber(price)} بكسور غير معتادة.',
          suggested: r, suggestedLabel: 'قرّب إلى ${plainNumber(r)}'));
    }
  }
  return out;
}
