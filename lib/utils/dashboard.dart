import '../models/invoice.dart';

class DashboardStats {
  final double monthSales; // مبيعات الشهر الحالي (بعد الإشعارات)
  final double outstanding; // المتبقي على الفواتير غير المسددة
  final int overdueCount;
  final List<double> monthly; // آخر 6 أشهر، الأقدم أولاً
  final List<DateTime> months;
  const DashboardStats(
      this.monthSales, this.outstanding, this.overdueCount, this.monthly, this.months);

  bool get hasData => monthly.any((e) => e != 0) || outstanding > 0;
}

/// يحسب ملخص اللوحة. المسودات وجداول الجرد لا تدخل، والإشعار الدائن يطرح والمدين يضيف.
/// المستندات بعملة مختلفة عن [currency] تُستثنى كي لا تُخلط العملات.
DashboardStats computeDashboard(List<InvoiceSummary> all, DateTime now,
    {String currency = ''}) {
  final months = List.generate(
      6, (i) => DateTime(now.year, now.month - 5 + i, 1));
  final monthly = List<double>.filled(6, 0);
  var outstanding = 0.0;
  var overdue = 0;
  for (final s in all) {
    final inv = s.invoice;
    if (inv.kind != DocKind.invoice || inv.status == InvoiceStatus.draft) continue;
    final cur = inv.currency.trim();
    if (cur.isNotEmpty && currency.isNotEmpty && cur != currency) continue;
    final sign = inv.noteType == 'credit' ? -1.0 : 1.0;
    final idx = months.indexWhere(
        (m) => m.year == inv.date.year && m.month == inv.date.month);
    if (idx >= 0) monthly[idx] += sign * s.grandTotal;
    if (!inv.isNote) {
      final rem = paymentRemaining(s.grandTotal, inv.paidAmount, inv.status);
      if (rem > 0.005) {
        outstanding += rem;
        if (isOverdueFor(inv.kind, inv.dueDate, rem, s.grandTotal, now)) overdue++;
      }
    }
  }
  return DashboardStats(monthly.last, outstanding, overdue, monthly, months);
}

const arabicMonths = [
  'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
  'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
];
