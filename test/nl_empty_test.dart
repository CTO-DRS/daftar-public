import 'package:daftar/utils/nl_query.dart';
import 'package:flutter_test/flutter_test.dart';
void main() {
  test('nl empty', () {
    final now = DateTime(2026, 11, 28);
    for (final q in ['', '   ', 'كم مبيعات هذا الشهر', 'من عليه ديون', 'كم بعت من كولا', 'مصروفات الشهر الماضي', 'asdf', 'كم باقي من 0']) {
      final a = answerNl(parseNl(q, now), [], [], now);
      expect(a, isNotNull);
    }
  });
}
