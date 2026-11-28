import 'package:daftar/utils/cashflow.dart';
import 'package:daftar/utils/insights.dart';
import 'package:daftar/utils/digest.dart';
import 'package:flutter_test/flutter_test.dart';
void main() {
  test('empty data never throws', () {
    final now = DateTime(2026, 11, 28);
    buildCashOutlook([], now);
    computeInsights([], now);
    buildDigest([], [], now);
  });
}
