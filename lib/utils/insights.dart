import '../models/invoice.dart';
import 'number_utils.dart';

enum InsightLevel { info, good, warn, risk }

class Insight {
  final InsightLevel level;
  final String title;
  final String body;
  /// اسم العميل المرتبط (لعرض زر تذكير/كشف حساب)، أو null.
  final String? party;
  const Insight(this.level, this.title, this.body, {this.party});
}

enum Risk { low, medium, high }

class CustomerInsight {
  final String name;
  final double sales; // صافي المبيعات (بعد الإشعارات)
  final double outstanding;
  final double overdue;
  final int maxDaysLate;
  final double share; // 0..1 من إجمالي المبيعات
  final Risk risk;
  const CustomerInsight(this.name, this.sales, this.outstanding, this.overdue,
      this.maxDaysLate, this.share, this.risk);
}

class ProductSales {
  final String name;
  final double qty;
  final double revenue;
  const ProductSales(this.name, this.qty, this.revenue);
}

/// أعمار الديون: كم مبلغاً لم يستحق بعد، وكم تأخر 1-30 / 31-60 / 61-90 / +90 يوماً.
class Aging {
  final double notDue, d30, d60, d90, d90plus;
  const Aging(this.notDue, this.d30, this.d60, this.d90, this.d90plus);
  double get total => notDue + d30 + d60 + d90 + d90plus;
  double get overdue => d30 + d60 + d90 + d90plus;
}

class Forecast {
  final double overdue; // متأخر: يُحصَّل الآن
  final double next7; // يستحق خلال 7 أيام
  final double next30; // يستحق بين 8 و30 يوماً
  final double later; // أبعد من 30 يوماً أو بدون استحقاق
  const Forecast(this.overdue, this.next7, this.next30, this.later);
}

class InsightsReport {
  final Aging aging;
  final Forecast forecast;
  final List<CustomerInsight> customers; // الأعلى مبيعاً أولاً
  final List<ProductSales> products;
  final double? trendPct; // تغيّر مبيعات هذا الشهر عن الماضي (null = لا أساس)
  final double thisMonth, lastMonth;
  final List<Insight> alerts;
  const InsightsReport(this.aging, this.forecast, this.customers, this.products,
      this.trendPct, this.thisMonth, this.lastMonth, this.alerts);

  bool get isEmpty => customers.isEmpty && aging.total <= 0;
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// يحلّل الفواتير على الجهاز (بدون إنترنت). المسودات والجرد لا تدخل،
/// والعملات المختلفة عن [currency] تُستثنى كي لا تُخلط.
InsightsReport computeInsights(List<InvoiceSummary> all, DateTime now,
    {String currency = '', List<ProductSales> products = const []}) {
  final today = _day(now);
  var notDue = 0.0, d30 = 0.0, d60 = 0.0, d90 = 0.0, d90p = 0.0;
  var f7 = 0.0, f30 = 0.0, fLater = 0.0;
  var thisM = 0.0, lastM = 0.0;
  final sales = <String, double>{};
  final out = <String, double>{};
  final over = <String, double>{};
  final late = <String, int>{};
  final overdueInvoices = <(String, String, double, int)>[];

  for (final s in all) {
    final inv = s.invoice;
    if (inv.kind != DocKind.invoice || inv.status == InvoiceStatus.draft) continue;
    final cur = inv.currency.trim();
    if (cur.isNotEmpty && currency.isNotEmpty && cur != currency) continue;
    final sign = inv.noteType == 'credit' ? -1.0 : 1.0;
    final who = inv.party.trim().isEmpty ? 'بدون اسم' : inv.party.trim();
    sales[who] = (sales[who] ?? 0) + sign * s.grandTotal;
    final d = inv.date;
    if (d.year == now.year && d.month == now.month) thisM += sign * s.grandTotal;
    final prev = DateTime(now.year, now.month - 1, 1);
    if (d.year == prev.year && d.month == prev.month) lastM += sign * s.grandTotal;
    if (inv.isNote) continue;
    final rem = paymentRemaining(s.grandTotal, inv.paidAmount, inv.status);
    if (rem <= 0.005) continue;
    out[who] = (out[who] ?? 0) + rem;
    final due = inv.dueDate == null ? null : _day(inv.dueDate!);
    if (due == null) {
      notDue += rem;
      fLater += rem;
    } else {
      final days = today.difference(due).inDays; // موجب = متأخر
      if (days <= 0) {
        notDue += rem;
        final left = -days;
        if (left <= 7) {
          f7 += rem;
        } else if (left <= 30) {
          f30 += rem;
        } else {
          fLater += rem;
        }
      } else {
        if (days <= 30) {
          d30 += rem;
        } else if (days <= 60) {
          d60 += rem;
        } else if (days <= 90) {
          d90 += rem;
        } else {
          d90p += rem;
        }
        over[who] = (over[who] ?? 0) + rem;
        if (days > (late[who] ?? 0)) late[who] = days;
        overdueInvoices.add((who, inv.number, rem, days));
      }
    }
  }

  final totalSales = sales.values.where((v) => v > 0).fold(0.0, (a, b) => a + b);
  final customers = <CustomerInsight>[];
  for (final e in sales.entries) {
    final o = over[e.key] ?? 0;
    final days = late[e.key] ?? 0;
    final ratio = e.value > 0 ? o / e.value : (o > 0 ? 1.0 : 0.0);
    final risk = o <= 0.005
        ? Risk.low
        : (days > 60 || ratio >= .5)
            ? Risk.high
            : Risk.medium;
    customers.add(CustomerInsight(e.key, e.value, out[e.key] ?? 0, o, days,
        totalSales > 0 && e.value > 0 ? e.value / totalSales : 0, risk));
  }
  // يظهر من عليه متأخرات حتى لو مبيعاته صفر، ثم الأعلى مبيعاً.
  customers.sort((a, b) => b.sales.compareTo(a.sales));

  final aging = Aging(notDue, d30, d60, d90, d90p);
  final forecast = Forecast(aging.overdue, f7, f30, fLater);
  final trend = lastM > 0.005 ? (thisM - lastM) / lastM * 100 : null;

  final alerts = <Insight>[];
  // أخطر المتأخرات أولاً.
  overdueInvoices.sort((a, b) => b.$4.compareTo(a.$4));
  for (final o in overdueInvoices.take(3)) {
    alerts.add(Insight(
        o.$4 > 60 ? InsightLevel.risk : InsightLevel.warn,
        'فاتورة ${localizeDigits(o.$2)} متأخرة ${localizeDigits('${o.$4}')} يوماً',
        '${o.$1}: متبقٍ ${formatMoney(o.$3)} $currency. أرسل تذكيراً بالواتساب من القائمة.',
        party: o.$1));
  }
  if (aging.d90plus > 0.005) {
    alerts.add(Insight(InsightLevel.risk, 'ديون متأخرة أكثر من 90 يوماً',
        'مبلغ ${formatMoney(aging.d90plus)} $currency مرّ عليه أكثر من 3 أشهر، والتحصيل يصعب كلما طال الوقت.'));
  }
  if (customers.length >= 3 && customers.first.share >= .4) {
    final c = customers.first;
    alerts.add(Insight(InsightLevel.warn, 'اعتماد كبير على عميل واحد',
        '${c.name} يمثل ${localizeDigits((c.share * 100).round().toString())}٪ من مبيعاتك. تنويع العملاء يقلل المخاطر.',
        party: c.name));
  }
  if (trend != null) {
    final p = localizeDigits(trend.abs().round().toString());
    if (trend >= 10) {
      alerts.add(Insight(InsightLevel.good, 'مبيعاتك في نمو',
          'مبيعات هذا الشهر أعلى من الشهر الماضي بنحو $p٪.'));
    } else if (trend <= -10) {
      alerts.add(Insight(InsightLevel.warn, 'انخفاض في المبيعات',
          'مبيعات هذا الشهر أقل من الشهر الماضي بنحو $p٪ (قد يكون الشهر لم يكتمل بعد).'));
    }
  }
  if (forecast.next7 > 0.005) {
    alerts.add(Insight(InsightLevel.info, 'تحصيلات متوقعة هذا الأسبوع',
        'يستحق خلال 7 أيام نحو ${formatMoney(forecast.next7)} $currency.'));
  }
  return InsightsReport(aging, forecast, customers, products, trend, thisM, lastM, alerts);
}
