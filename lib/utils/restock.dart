import 'forecast.dart';
import 'number_utils.dart';

enum RestockUrgency { now, soon, later }

class RestockLine {
  final String name;
  final double onHand;
  final double rate; // المعدل المستخدم للتخطيط (قطعة/يوم)
  final double? daysLeft;
  final double qty; // الكمية المقترحة للشراء
  final double packs; // عدد العبوات إن عُرف حجمها (0 غير معروف)
  final double packSize;
  final bool rising; // الطلب في آخر أسبوعين أعلى من المعتاد
  final RestockUrgency urgency;
  const RestockLine(this.name, this.onHand, this.rate, this.daysLeft, this.qty,
      this.packs, this.packSize, this.rising, this.urgency);
}

/// معدل التخطيط: متوسط معدل 30 يوماً ومعدل آخر 14 يوماً (يلتقط الاتجاه صعوداً أو هبوطاً).
double planningRate(StockForecast f) =>
    f.recentPerDay == null ? f.perDay : (f.perDay + f.recentPerDay!) / 2;

/// خطة شراء: ما يكفي مدة التوريد [leadDays] + التغطية [coverDays]، مقرّباً لأعلى إلى كراتين كاملة
/// إن عُرف حجم العبوة. الأصناف التي لا تحتاج شراءً لا تظهر. الأعجل أولاً.
List<RestockLine> planRestock(List<StockForecast> forecast, {int leadDays = 7, int coverDays = 30}) {
  final out = <RestockLine>[];
  for (final f in forecast) {
    final rate = planningRate(f);
    if (rate <= 0) continue;
    final onHand = f.onHand < 0 ? 0.0 : f.onHand;
    final need = rate * (leadDays + coverDays) - onHand;
    if (need <= 0) continue;
    var qty = need.ceilToDouble();
    var packs = 0.0;
    if (f.packSize > 1) {
      packs = (qty / f.packSize).ceilToDouble();
      qty = packs * f.packSize;
    }
    final days = onHand / rate;
    final urgency = days <= leadDays
        ? RestockUrgency.now
        : days <= leadDays + 7
            ? RestockUrgency.soon
            : RestockUrgency.later;
    final rising = f.recentPerDay != null && f.perDay > 0 && f.recentPerDay! > f.perDay * 1.25;
    out.add(RestockLine(f.name, onHand, rate, days, qty, packs, f.packSize, rising, urgency));
  }
  out.sort((a, b) {
    final u = a.urgency.index.compareTo(b.urgency.index);
    return u != 0 ? u : (a.daysLeft ?? 1e9).compareTo(b.daysLeft ?? 1e9);
  });
  return out;
}

/// نص قائمة الشراء للمشاركة (واتساب أو غيره).
String restockText(List<RestockLine> lines, DateTime now,
    {String company = '', int leadDays = 7, int coverDays = 30}) {
  final b = StringBuffer('قائمة شراء ${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}');
  if (company.trim().isNotEmpty) b.write(' - ${company.trim()}');
  b.writeln('\n(تكفي ${localizeDigits('$coverDays')} يوماً بعد توريد ${localizeDigits('$leadDays')} أيام)\n');
  var i = 1;
  for (final l in lines) {
    b.write('${localizeDigits('$i')}. ${l.name}: ${formatQty(l.qty)}');
    if (l.packs > 0) b.write(' (${formatQty(l.packs)} × ${formatQty(l.packSize)})');
    if (l.urgency == RestockUrgency.now) b.write(' ⚠ عاجل');
    b.writeln();
    i++;
  }
  return b.toString().trimRight();
}
