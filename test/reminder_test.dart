import 'package:daftar/utils/reminder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('waPhone normalizes Saudi numbers', () {
    expect(waPhone('0551234567'), '966551234567');
    expect(waPhone('٠٥٥١٢٣٤٥٦٧'), '966551234567');
    expect(waPhone('+966 55 123 4567'), '966551234567');
    expect(waPhone('00966551234567'), '966551234567');
    expect(waPhone('551234567'), '966551234567');
    expect(waPhone(''), isNull);
  });
  test('reminder text mentions amount and days late', () {
    final t = reminderText(
        party: 'مؤسسة النور',
        number: '15',
        remaining: 500,
        currency: 'ر.س',
        dueDate: DateTime(2026, 11, 1),
        now: DateTime(2026, 11, 11));
    expect(t, contains('متأخرة 10 أيام'));
    expect(t, contains('500.00'));
    expect(waUri('966551234567', t).toString(),
        startsWith('https://wa.me/966551234567?text='));
  });
}
