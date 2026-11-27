import '../models/invoice.dart';
import 'number_utils.dart';

/// لهجة رسالة التحصيل.
enum CollectionTone { gentle, normal, firm }

extension CollectionToneX on CollectionTone {
  String get label => switch (this) {
        CollectionTone.gentle => 'لطيفة',
        CollectionTone.normal => 'عادية',
        CollectionTone.firm => 'حازمة',
      };
}

/// حالة تحصيل لعميل واحد: فواتيره المتأخرة مجمّعة، مع درجة خطورة وأفضل يوم للتذكير.
class CollectionCase {
  final String party;
  final List<InvoiceSummary> invoices; // الأقدم تأخراً أولاً
  final double total; // المتبقي عليها
  final int maxLateDays;
  final int risk; // 0..100
  final CollectionTone tone;
  final int? bestWeekday; // DateTime.monday..sunday: اليوم الذي يسدد فيه عادةً
  final int? usualDaysToPay; // وسيط أيام السداد التاريخية (تقريبي)
  const CollectionCase({
    required this.party,
    required this.invoices,
    required this.total,
    required this.maxLateDays,
    required this.risk,
    required this.tone,
    this.bestWeekday,
    this.usualDaysToPay,
  });
}

const _weekdayNames = {
  DateTime.monday: 'الاثنين',
  DateTime.tuesday: 'الثلاثاء',
  DateTime.wednesday: 'الأربعاء',
  DateTime.thursday: 'الخميس',
  DateTime.friday: 'الجمعة',
  DateTime.saturday: 'السبت',
  DateTime.sunday: 'الأحد',
};

String weekdayNameAr(int w) => _weekdayNames[w] ?? '';

int _dayNum(DateTime d) => DateTime(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 86400000;

int _median(List<int> v) {
  final s = [...v]..sort();
  return s.length.isOdd ? s[s.length ~/ 2] : ((s[s.length ~/ 2 - 1] + s[s.length ~/ 2]) / 2).round();
}

/// يرتّب العملاء المتأخرين حسب احتمال تعثّرهم. السجل التاريخي تقريبي: وقت السداد هو
/// آخر تعديل للفاتورة المدفوعة (لا تُحفظ تواريخ الدفعات). [reminded]: رقم الفاتورة ← وقت
/// آخر تذكير (ms)، والفاتورة المذكَّرة خلال [cooldownDays] تُستبعد.
List<CollectionCase> buildCollection(
  List<InvoiceSummary> all,
  DateTime now,
  Map<String, int> reminded, {
  int cooldownDays = 3,
}) {
  final today = _dayNum(now);
  final overdue = <String, List<InvoiceSummary>>{};
  final late = <String, List<int>>{}; // تأخر السداد التاريخي بالأيام (سالب = مبكراً)
  final toPay = <String, List<int>>{};
  final payDays = <String, List<int>>{};
  var allOutstanding = 0.0;
  for (final s in all) {
    final i = s.invoice;
    if (i.kind != DocKind.invoice || i.isNote || i.party.trim().isEmpty) continue;
    final p = i.party.trim();
    final rem = paymentRemaining(s.grandTotal, i.paidAmount, i.status);
    if (i.status == InvoiceStatus.paid && s.grandTotal > 0) {
      final d = _dayNum(i.updatedAt) - _dayNum(i.date);
      if (d >= 0 && d <= 365) {
        toPay.putIfAbsent(p, () => []).add(d);
        payDays.putIfAbsent(p, () => []).add(i.updatedAt.weekday);
        if (i.dueDate != null) {
          late.putIfAbsent(p, () => []).add(_dayNum(i.updatedAt) - _dayNum(i.dueDate!));
        }
      }
      continue;
    }
    if (rem > 0.005 && i.dueDate != null) allOutstanding += rem;
    if (!isOverdueFor(i.kind, i.dueDate, rem, s.grandTotal, now)) continue;
    final last = reminded[i.number];
    if (last != null &&
        now.difference(DateTime.fromMillisecondsSinceEpoch(last)).inDays < cooldownDays) {
      continue;
    }
    overdue.putIfAbsent(p, () => []).add(s);
  }
  final out = <CollectionCase>[];
  overdue.forEach((party, list) {
    list.sort((a, b) => a.invoice.dueDate!.compareTo(b.invoice.dueDate!));
    var total = 0.0;
    var maxLate = 0;
    for (final s in list) {
      total += paymentRemaining(s.grandTotal, s.invoice.paidAmount, s.invoice.status);
      final l = today - _dayNum(s.invoice.dueDate!);
      if (l > maxLate) maxLate = l;
    }
    final lates = late[party] ?? const <int>[];
    var risk = (maxLate * 1.5).clamp(0, 55).toDouble();
    if (lates.length >= 2) {
      final lateShare = lates.where((x) => x > 0).length / lates.length;
      risk += lateShare * 25;
      final avgLate = lates.where((x) => x > 0).fold(0, (a, b) => a + b) /
          lates.length;
      risk += (avgLate / 2).clamp(0, 10);
    } else {
      risk += 8; // لا سجل كافٍ: حذر معتدل
    }
    if (allOutstanding > 0) risk += (total / allOutstanding * 10).clamp(0, 10);
    final r = risk.round().clamp(0, 100);
    final tone = (maxLate >= 30 || r >= 70)
        ? CollectionTone.firm
        : (maxLate <= 7 && r < 40)
            ? CollectionTone.gentle
            : CollectionTone.normal;
    int? best;
    final wd = payDays[party];
    if (wd != null && wd.length >= 3) {
      final cnt = <int, int>{};
      for (final w in wd) {
        cnt[w] = (cnt[w] ?? 0) + 1;
      }
      final top = cnt.entries.reduce((a, b) => a.value >= b.value ? a : b);
      if (top.value >= 2) best = top.key;
    }
    final tp = toPay[party];
    out.add(CollectionCase(
      party: party,
      invoices: list,
      total: total,
      maxLateDays: maxLate,
      risk: r,
      tone: tone,
      bestWeekday: best,
      usualDaysToPay: tp != null && tp.length >= 2 ? _median(tp) : null,
    ));
  });
  out.sort((a, b) {
    final c = b.risk.compareTo(a.risk);
    return c != 0 ? c : b.total.compareTo(a.total);
  });
  return out;
}

/// رسالة تحصيل جاهزة للعميل بلهجة تناسب درجة التأخر.
String collectionText(CollectionCase c, {String company = '', String currency = '', DateTime? now}) {
  final cur = currency.isEmpty ? c.invoices.first.invoice.currency : currency;
  final b = StringBuffer('السلام عليكم ${c.party.trim()}،\n');
  final single = c.invoices.length == 1;
  final nums = c.invoices.take(4).map((s) => localizeDigits(s.invoice.number)).join('، ');
  final more = c.invoices.length > 4 ? ' وغيرها' : '';
  switch (c.tone) {
    case CollectionTone.gentle:
      b.write(single
          ? 'تذكير ودّي بالفاتورة رقم $nums، والمتبقي منها ${formatMoney(c.total)} $cur.\n'
          : 'تذكير ودّي بالفواتير ($nums$more)، ومجموع المتبقي ${formatMoney(c.total)} $cur.\n');
      b.write('إن كان السداد قد تم فشكراً لكم، وإلا نقدّر تحويله متى تيسّر.');
    case CollectionTone.normal:
      b.write(single
          ? 'نفيدكم بأن الفاتورة رقم $nums متأخرة ${localizeDigits('${c.maxLateDays}')} يوماً، والمتبقي ${formatMoney(c.total)} $cur.\n'
          : 'نفيدكم بأن لديكم ${localizeDigits('${c.invoices.length}')} فواتير متأخرة ($nums$more) وأقدمها متأخرة ${localizeDigits('${c.maxLateDays}')} يوماً، ومجموع المتبقي ${formatMoney(c.total)} $cur.\n');
      b.write('نرجو السداد خلال هذا الأسبوع، وإن كان هناك ما يمنع فنرجو إبلاغنا لنرتّب معكم.');
    case CollectionTone.firm:
      b.write(single
          ? 'الفاتورة رقم $nums متأخرة ${localizeDigits('${c.maxLateDays}')} يوماً، والمتبقي ${formatMoney(c.total)} $cur.\n'
          : 'لديكم ${localizeDigits('${c.invoices.length}')} فواتير متأخرة ($nums$more)، أقدمها ${localizeDigits('${c.maxLateDays}')} يوماً، ومجموع المتبقي ${formatMoney(c.total)} $cur.\n');
      b.write('نأمل السداد خلال يومين، أو تزويدنا بموعد سداد محدد اليوم حتى لا نضطر لإيقاف التعامل الآجل.');
  }
  if (company.trim().isNotEmpty) b.write('\n${company.trim()}');
  return b.toString();
}
