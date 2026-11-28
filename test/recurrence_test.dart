import 'package:daftar/utils/recurrence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('nextOccurrence', () {
    expect(nextOccurrence(DateTime(2026, 1, 31), Recurrence.monthly), DateTime(2026, 2, 28));
    expect(nextOccurrence(DateTime(2026, 12, 15), Recurrence.monthly), DateTime(2027, 1, 15));
    expect(nextOccurrence(DateTime(2024, 2, 29), Recurrence.yearly), DateTime(2025, 2, 28));
    expect(nextOccurrence(DateTime(2026, 11, 28), Recurrence.weekly), DateTime(2026, 12, 5));
  });
  test('monthly chain keeps the original day after a short month (31 Jan -> 28 Feb -> 31 Mar)', () {
    var d = DateTime(2026, 1, 31);
    d = nextOccurrence(d, Recurrence.monthly, anchorDay: 31);
    expect(d, DateTime(2026, 2, 28));
    d = nextOccurrence(d, Recurrence.monthly, anchorDay: 31);
    expect(d, DateTime(2026, 3, 31));
    d = nextOccurrence(d, Recurrence.monthly, anchorDay: 31);
    expect(d, DateTime(2026, 4, 30));
  });
}
