import 'package:daftar/utils/dashboard.dart';
import 'package:flutter_test/flutter_test.dart';
void main() {
  test('dashboard on empty data', () {
    expect(() => computeDashboard([], DateTime(2026, 11, 28)), returnsNormally);
  });
}
