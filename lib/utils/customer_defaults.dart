import '../models/invoice.dart';

/// القيم المعتادة لعميل، مستنتجة من فواتيره السابقة.
class CustomerDefaults {
  final int? dueDays;
  final double? vatRate;
  final String? currency;
  final int sample;
  const CustomerDefaults({this.dueDays, this.vatRate, this.currency, this.sample = 0});
  bool get isEmpty => dueDays == null && vatRate == null && currency == null;
}

T? _mode<T>(Iterable<T> xs) {
  final c = <T, int>{};
  T? best;
  for (final x in xs) {
    c[x] = (c[x] ?? 0) + 1;
    if (best == null || c[x]! >= c[best]!) best = x;
  }
  return best;
}

/// القيمة الأكثر تكراراً في آخر الفواتير (الأحدث أولاً في [past]). عند التعادل يفوز الأحدث.
CustomerDefaults computeDefaults(List<Invoice> past, {int window = 10}) {
  final inv = [
    for (final i in past)
      if (i.kind == DocKind.invoice && !i.isNote) i
  ].take(window).toList();
  if (inv.isEmpty) return const CustomerDefaults();
  // الأحدث أولاً: نعكس ليصبح الأحدث آخر من يُحسب فيفوز عند التعادل.
  final ordered = inv.reversed.toList();
  final due = [
    for (final i in ordered)
      if (i.dueDate != null)
        i.dueDate!.difference(DateTime(i.date.year, i.date.month, i.date.day)).inDays
  ].where((d) => d > 0 && d <= 365);
  final vat = ordered.map((i) => i.vatRate);
  final cur = ordered.map((i) => i.currency).where((c) => c.isNotEmpty);
  return CustomerDefaults(
    dueDays: _mode(due),
    vatRate: _mode(vat),
    currency: _mode(cur),
    sample: inv.length,
  );
}
