import '../models/invoice.dart';

/// يوم واحد في توقع التدفق النقدي.
class CashDay {
  final DateTime date;
  final double inflow;
  final double outflow;
  final double cumulative; // صافي تراكمي منذ اليوم (بدون رصيد افتتاحي)
  const CashDay(this.date, this.inflow, this.outflow, this.cumulative);
}

/// توقع التدفق النقدي للأيام القادمة: المقبوضات من الفواتير غير المسددة حسب نمط كل عميل،
/// والمدفوعات من متوسط المصروفات اليومي. تقديري ولا يشمل رصيد الصندوق.
class CashOutlook {
  final List<CashDay> days;
  final double expectedIn;
  final double expectedOut;
  final double notDated; // فواتير بلا تاريخ استحقاق: غير محتسبة
  final CashDay? lowest; // أدنى نقطة تراكمية إن كانت سالبة
  const CashOutlook(this.days, this.expectedIn, this.expectedOut, this.notDated, this.lowest);

  double get net => expectedIn - expectedOut;
  bool get isEmpty => expectedIn == 0 && expectedOut == 0;
}

DateTime _d(DateTime t) => DateTime(t.year, t.month, t.day);
int _n(DateTime t) => _d(t).millisecondsSinceEpoch ~/ 86400000;

int _median(List<int> v) {
  final s = [...v]..sort();
  return s.length.isOdd ? s[s.length ~/ 2] : ((s[s.length ~/ 2 - 1] + s[s.length ~/ 2]) / 2).round();
}

/// [horizon] أيام قادمة. المتأخر فعلاً يُتوقع قبضه خلال أسبوع تقريباً مع خصم احتمال التعثر
/// (كلما طال التأخر قلّ ما نعدّه مقبوضاً داخل الأفق).
CashOutlook buildCashOutlook(List<InvoiceSummary> all, DateTime now, {int horizon = 30, int expenseWindow = 60}) {
  final today = _n(now);
  // تأخر السداد المعتاد لكل عميل (وسيط) من الفواتير المدفوعة.
  final lateBy = <String, List<int>>{};
  for (final s in all) {
    final i = s.invoice;
    if (i.kind != DocKind.invoice || i.isNote || i.status != InvoiceStatus.paid || i.dueDate == null) continue;
    final d = _n(i.updatedAt) - _n(i.dueDate!);
    if (d > -60 && d < 180) lateBy.putIfAbsent(i.party.trim(), () => []).add(d);
  }
  final inflow = List<double>.filled(horizon, 0);
  var notDated = 0.0;
  for (final s in all) {
    final i = s.invoice;
    if (i.kind != DocKind.invoice || i.isNote) continue;
    final rem = paymentRemaining(s.grandTotal, i.paidAmount, i.status);
    if (rem <= 0.005) continue;
    if (i.dueDate == null) {
      notDated += rem;
      continue;
    }
    final hist = lateBy[i.party.trim()];
    final shift = hist != null && hist.length >= 2 ? _median(hist).clamp(0, 60) : 0;
    var at = _n(i.dueDate!) + shift - today;
    var amount = rem;
    if (at < 0) {
      final late = -at;
      // متأخر: ينتظر قبضه خلال أيام، بنسبة تتناقص مع طول التأخر.
      at = 3 + (late ~/ 10);
      amount = rem * (late <= 14 ? 0.8 : late <= 45 ? 0.5 : 0.25);
    }
    if (at >= horizon) continue;
    inflow[at] += amount;
  }
  var expTotal = 0.0;
  final from = today - expenseWindow;
  for (final s in all) {
    final i = s.invoice;
    if (i.kind != DocKind.expense) continue;
    final n = _n(i.date);
    if (n > from && n <= today) expTotal += s.grandTotal;
  }
  final perDay = expTotal / expenseWindow;
  final days = <CashDay>[];
  var cum = 0.0, sumIn = 0.0;
  CashDay? low;
  for (var k = 0; k < horizon; k++) {
    cum += inflow[k] - perDay;
    sumIn += inflow[k];
    final day = CashDay(_d(now).add(Duration(days: k)), inflow[k], perDay, cum);
    days.add(day);
    if (cum < 0 && (low == null || cum < low.cumulative)) low = day;
  }
  return CashOutlook(days, sumIn, perDay * horizon, notDated, low);
}
