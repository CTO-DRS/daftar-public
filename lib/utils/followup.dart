import '../models/invoice.dart';

/// فواتير متأخرة تحتاج متابعة: لم تُذكَّر خلال [cooldownDays]، الأقدم تأخراً أولاً.
/// [reminded]: رقم الفاتورة ← وقت آخر تذكير (ms).
List<InvoiceSummary> dueForFollowUp(
  List<InvoiceSummary> all,
  DateTime now,
  Map<String, int> reminded, {
  int cooldownDays = 3,
}) {
  final out = <InvoiceSummary>[];
  for (final s in all) {
    final i = s.invoice;
    if (i.isNote) continue;
    final rem = paymentRemaining(s.grandTotal, i.paidAmount, i.status);
    if (!isOverdueFor(i.kind, i.dueDate, rem, s.grandTotal, now)) continue;
    final last = reminded[i.number];
    if (last != null &&
        now.difference(DateTime.fromMillisecondsSinceEpoch(last)).inDays <
            cooldownDays) {
      continue;
    }
    out.add(s);
  }
  out.sort((a, b) => a.invoice.dueDate!.compareTo(b.invoice.dueDate!));
  return out;
}
