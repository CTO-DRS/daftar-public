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
DateTime nextOccurrence(DateTime d, Recurrence r) {
  switch (r) {
    case Recurrence.weekly:
      return DateTime(d.year, d.month, d.day + 7);
    case Recurrence.monthly:
      return _addMonths(d, 1);
    case Recurrence.yearly:
      return _addMonths(d, 12);
  }
}

DateTime _addMonths(DateTime d, int m) {
  final total = d.year * 12 + (d.month - 1) + m;
  final y = total ~/ 12, mo = total % 12 + 1;
  final last = DateTime(y, mo + 1, 0).day;
  return DateTime(y, mo, d.day > last ? last : d.day);
}
