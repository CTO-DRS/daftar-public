/// دورية الفاتورة المتكررة.
enum Recurrence { weekly, monthly, yearly }

extension RecurrenceX on Recurrence {
  String get label => switch (this) {
        Recurrence.weekly => 'أسبوعياً',
        Recurrence.monthly => 'شهرياً',
        Recurrence.yearly => 'سنوياً',
      };
  static Recurrence fromDb(String? v) => Recurrence.values
      .firstWhere((e) => e.name == v, orElse: () => Recurrence.monthly);
}

/// التاريخ التالي (الشهري/السنوي يقصّ اليوم لآخر الشهر: 31 يناير ← 28 فبراير).
/// [anchorDay]: يوم الشهر الأصلي، حتى لا يضيع اليوم 31 بعد شهر فبراير (31 يناير ← 28 فبراير ← 31 مارس).
DateTime nextOccurrence(DateTime d, Recurrence r, {int? anchorDay}) {
  switch (r) {
    case Recurrence.weekly:
      return DateTime(d.year, d.month, d.day + 7);
    case Recurrence.monthly:
      return _addMonths(d, 1, anchorDay);
    case Recurrence.yearly:
      return _addMonths(d, 12, anchorDay);
  }
}

DateTime _addMonths(DateTime d, int m, [int? anchorDay]) {
  final total = d.year * 12 + (d.month - 1) + m;
  final y = total ~/ 12, mo = total % 12 + 1;
  final last = DateTime(y, mo + 1, 0).day;
  final day = anchorDay != null && anchorDay > d.day ? anchorDay : d.day;
  return DateTime(y, mo, day > last ? last : day);
}
