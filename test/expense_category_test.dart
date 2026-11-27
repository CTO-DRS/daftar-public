import 'package:flutter_test/flutter_test.dart';
import 'package:daftar/models/invoice.dart';
import 'package:daftar/utils/expense_category.dart';

Invoice ex(String party, String notes, String cat, {DateTime? d}) =>
    Invoice(number: 'E$party$notes', kind: DocKind.expense, party: party, notes: notes, category: cat, date: d);

void main() {
  final empty = ExpenseClassifier.fromHistory(const []);
  test('keywords classify common Arabic expenses', () {
    expect(empty.suggest('', 'إيجار المحل شهر 11'), 'إيجار');
    expect(empty.suggest('محطة الوقود', 'بنزين للسيارة'), 'وقود ونقل');
    expect(empty.suggest('STC', 'باقة انترنت'), 'اتصالات وإنترنت');
    expect(empty.suggest('', 'شيء غير معروف'), isNull);
  });
  test('normalises hamza and taa marbuta', () {
    expect(empty.suggest('', 'ايجار'), 'إيجار');
    expect(empty.suggest('', 'فاتورة الكهرباء'), 'كهرباء وماء');
  });
  test('learns the supplier from corrections', () {
    final c = ExpenseClassifier.fromHistory([
      ex('مؤسسة الندى', 'دفعة', 'تسويق وإعلان'),
      ex('مؤسسة الندى', 'اخرى', 'تسويق وإعلان'),
    ]);
    expect(c.suggest('مؤسسة الندى', 'بنزين'), 'تسويق وإعلان');
  });
  test('learns notes words beyond keywords', () {
    final c = ExpenseClassifier.fromHistory([ex('', 'اشتراك برنامج المحاسبة', 'أخرى'), ex('', 'اشتراك برنامج', 'أخرى')]);
    expect(c.suggest('', 'اشتراك برنامج جديد'), 'أخرى');
  });
  test('breakdown sums by category and sorts', () {
    final now = DateTime(2026, 11, 28);
    final s = [
      InvoiceSummary(ex('', 'ايجار', ''), 1, 1, 3000),
      InvoiceSummary(ex('', 'بنزين', 'وقود ونقل'), 1, 1, 200),
      InvoiceSummary(ex('', 'بنزين', 'وقود ونقل', d: DateTime(2020)), 1, 1, 999),
      InvoiceSummary(ex('', '؟؟', ''), 1, 1, 50),
    ];
    final m = expensesByCategory(s, DateTime(2026, 11, 1), empty);
    expect(m.keys.toList(), ['إيجار', 'وقود ونقل', 'غير مصنف']);
    expect(m['إيجار'], 3000);
    expect(now.year, 2026);
  });
}
