import 'package:daftar/utils/recurrence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('nextOccurrence', () {
    expect(nextOccurrence(DateTime(2026, 1, 31), Recurrence.monthly), DateTime(2026, 2, 28));
    expect(nextOccurrence(DateTime(2026, 12, 15), Recurrence.monthly), DateTime(2027, 1, 15));
    expect(nextOccurrence(DateTime(2024, 2, 29), Recurrence.yearly), DateTime(2025, 2, 28));
    expect(nextOccurrence(DateTime(2026, 11, 28), Recurrence.weekly), DateTime(2026, 12, 5));
  });
}
