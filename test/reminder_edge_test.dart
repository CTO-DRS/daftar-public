import 'package:daftar/utils/reminder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('phone with stray zero after country code', () {
    expect(waPhone('+966 0553405949'), '966553405949');
    expect(waPhone('0553405949'), '966553405949');
  });
  test('empty party greeting and late-day grammar', () {
    final due = DateTime(2026, 1, 1);
    String t(int days, String p) => reminderText(
        party: p, number: '1', remaining: 10, currency: 'ر.س',
        dueDate: due, now: due.add(Duration(days: days)));
    expect(t(3, ''), startsWith('السلام عليكم،'));
    expect(t(1, 'x'), contains('يوماً واحداً'));
    expect(t(2, 'x'), contains('يومين'));
    expect(t(5, 'x'), contains('5 أيام'));
    expect(t(30, 'x'), contains('30 يوماً'));
  });
}
