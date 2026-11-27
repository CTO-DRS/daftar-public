import '../models/invoice.dart';
import 'nl_query.dart' show SoldRow;
import 'number_utils.dart';

class DriftingCustomer {
  final String party;
  final int usualGap;
  final int daysSince;
  const DriftingCustomer(this.party, this.usualGap, this.daysSince);
}

/// ملخص الأسبوع: آخر 7 أيام مقابل الـ7 قبلها.
class WeeklyDigest {
  final double sales;
  final double prevSales;
  final double? changePct; // null = لا أساس للمقارنة
  final int invoiceCount;
  final String? topItem;
  final double topItemPieces;
  final String? slowItem; // كان يُباع بانتظام وتوقف هذا الأسبوع
  final List<DriftingCustomer> drifting;
  final int overdueCount;
  final double overdueTotal;
  const WeeklyDigest({
    required this.sales,
    required this.prevSales,
    required this.changePct,
    required this.invoiceCount,
    required this.topItem,
    required this.topItemPieces,
    required this.slowItem,
    required this.drifting,
    required this.overdueCount,
    required this.overdueTotal,
  });

  bool get isEmpty => sales == 0 && prevSales == 0 && drifting.isEmpty && overdueCount == 0;

  /// عنوان من سطر واحد (للإشعار والبطاقة).
  String get headline {
    if (sales <= 0 && prevSales <= 0) return 'لا مبيعات مسجّلة هذا الأسبوع';
    final b = StringBuffer('مبيعات الأسبوع ${formatMoney(sales)}');
    if (changePct != null) {
      final p = localizeDigits(changePct!.abs().round().toString());
      b.write(changePct! >= 0 ? '، أعلى بـ$p% من الأسبوع الماضي' : '، أقل بـ$p% من الأسبوع الماضي');
    }
    return b.toString();
  }

  /// أسطر التفاصيل والإجراءات المقترحة.
  List<String> get lines => [
        if (topItem != null) 'الأسرع: $topItem (${plainNumber(topItemPieces)} قطعة)',
        if (slowItem != null) 'توقّف هذا الأسبوع: $slowItem',
        if (drifting.isNotEmpty)
          'عملاء بدأوا يبتعدون: ${drifting.take(3).map((e) => e.party).join('، ')}'
              '${drifting.length > 3 ? '…' : ''}',
        if (overdueCount > 0)
          'متأخرات ${localizeDigits('$overdueCount')} فواتير بمجموع ${formatMoney(overdueTotal)}',
      ];
}

int _day(DateTime d) => DateTime(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 86400000;

int _median(List<int> v) {
  final s = [...v]..sort();
  return s.length.isOdd ? s[s.length ~/ 2] : ((s[s.length ~/ 2 - 1] + s[s.length ~/ 2]) / 2).round();
}

WeeklyDigest buildDigest(List<InvoiceSummary> all, List<SoldRow> sold, DateTime now) {
  final today = _day(now);
  var sales = 0.0, prev = 0.0;
  var count = 0;
  var overdueN = 0;
  var overdueT = 0.0;
  final byParty = <String, Set<int>>{};
  for (final s in all) {
    final i = s.invoice;
    if (i.kind != DocKind.invoice || i.status == InvoiceStatus.draft) continue;
    final age = today - _day(i.date);
    final sign = i.noteType == 'credit' ? -1 : 1;
    if (age >= 0 && age < 7) {
      sales += sign * s.grandTotal;
      if (!i.isNote) count++;
    } else if (age >= 7 && age < 14) {
      prev += sign * s.grandTotal;
    }
    if (!i.isNote) {
      final rem = paymentRemaining(s.grandTotal, i.paidAmount, i.status);
      if (isOverdueFor(i.kind, i.dueDate, rem, s.grandTotal, now)) {
        overdueN++;
        overdueT += rem;
      }
      if (i.party.trim().isNotEmpty) byParty.putIfAbsent(i.party.trim(), () => <int>{}).add(_day(i.date));
    }
  }
  final change = prev > 0.005 ? (sales - prev) / prev * 100 : null;

  // الأصناف: الأعلى مبيعاً هذا الأسبوع، والمتوقف (بيع في 3 من آخر 4 أسابيع سابقة ولا شيء الآن).
  final thisWeek = <String, double>{};
  final weeksSold = <String, Set<int>>{};
  for (final r in sold) {
    final age = today - _day(r.date);
    if (age < 0 || age >= 35) continue;
    final key = r.description;
    if (age < 7) {
      thisWeek[key] = (thisWeek[key] ?? 0) + r.pieces;
    } else {
      weeksSold.putIfAbsent(key, () => <int>{}).add((age - 7) ~/ 7);
    }
  }
  String? top;
  var topQ = 0.0;
  thisWeek.forEach((k, v) {
    if (v > topQ) {
      top = k;
      topQ = v;
    }
  });
  String? slow;
  var slowWeeks = 0;
  weeksSold.forEach((k, w) {
    if (!thisWeek.containsKey(k) && w.length >= 3 && w.length > slowWeeks) {
      slow = k;
      slowWeeks = w.length;
    }
  });

  final drift = <DriftingCustomer>[];
  byParty.forEach((party, set) {
    if (set.length < 3) return;
    final days = set.toList()..sort();
    final gaps = [for (var k = 1; k < days.length; k++) days[k] - days[k - 1]];
    final med = _median(gaps);
    if (med < 3 || med > 120) return;
    final since = today - days.last;
    if (since > med * 1.5 && since <= med * 6) drift.add(DriftingCustomer(party, med, since));
  });
  drift.sort((a, b) => (b.daysSince / b.usualGap).compareTo(a.daysSince / a.usualGap));

  return WeeklyDigest(
    sales: sales,
    prevSales: prev,
    changePct: change,
    invoiceCount: count,
    topItem: top,
    topItemPieces: topQ,
    slowItem: slow,
    drifting: drift,
    overdueCount: overdueN,
    overdueTotal: overdueT,
  );
}
