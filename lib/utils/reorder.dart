import '../models/invoice.dart';

/// عميل حان وقت طلبه المعتاد.
class ReorderDue {
  final String party;
  final int intervalDays; // الوسيط بين طلباته
  final int daysSince; // منذ آخر طلب
  final int orders;
  const ReorderDue(this.party, this.intervalDays, this.daysSince, this.orders);
}

int _day(DateTime d) => DateTime(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 86400000;

/// عملاء لهم نمط طلب منتظم (3 فواتير مختلفة الأيام فأكثر، ووسيط الفاصل بين 3 و120 يوماً،
/// ونصف الفواصل على الأقل قريبة من الوسيط) وقد حان وقتهم: مرّ 90% من الفاصل المعتاد،
/// ولم يمرّ أكثر من 3 أضعافه (بعدها نعتبره توقف). [snoozed]: العميل ← وقت التأجيل (ms).
List<ReorderDue> reorderDue(
  List<InvoiceSummary> all,
  DateTime now, {
  Map<String, int> snoozed = const {},
  int snoozeDays = 7,
}) {
  final byParty = <String, Set<int>>{};
  for (final s in all) {
    final i = s.invoice;
    if (i.kind != DocKind.invoice || i.isNote || i.status == InvoiceStatus.draft) continue;
    final p = i.party.trim();
    if (p.isEmpty) continue;
    byParty.putIfAbsent(p, () => <int>{}).add(_day(i.date));
  }
  final today = _day(now);
  final out = <ReorderDue>[];
  byParty.forEach((party, set) {
    if (set.length < 3) return;
    final days = set.toList()..sort();
    final gaps = [for (var k = 1; k < days.length; k++) days[k] - days[k - 1]]..sort();
    final median = gaps.length.isOdd
        ? gaps[gaps.length ~/ 2]
        : ((gaps[gaps.length ~/ 2 - 1] + gaps[gaps.length ~/ 2]) / 2).round();
    if (median < 3 || median > 120) return;
    final regular = gaps.where((g) => (g - median).abs() <= median * 0.5).length;
    if (regular * 2 < gaps.length) return;
    final since = today - days.last;
    if (since < (median * 0.9).floor() || since > median * 3) return;
    final sn = snoozed[party];
    if (sn != null &&
        now.difference(DateTime.fromMillisecondsSinceEpoch(sn)).inDays < snoozeDays) {
      return;
    }
    out.add(ReorderDue(party, median, since, set.length));
  });
  // الأكثر تأخراً عن موعده أولاً.
  out.sort((a, b) => (b.daysSince / b.intervalDays).compareTo(a.daysSince / a.intervalDays));
  return out;
}
