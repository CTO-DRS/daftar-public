import '../models/invoice.dart';

/// تصنيفات المصروفات الجاهزة.
const expenseCategories = <String>[
  'مشتريات بضاعة',
  'إيجار',
  'رواتب وأجور',
  'كهرباء وماء',
  'اتصالات وإنترنت',
  'وقود ونقل',
  'صيانة',
  'تسويق وإعلان',
  'رسوم حكومية وبنكية',
  'ضيافة ومستلزمات',
  'أخرى',
];

const _keywords = <String, List<String>>{
  'إيجار': ['ايجار', 'إيجار', 'اجار', 'rent'],
  'رواتب وأجور': ['راتب', 'رواتب', 'اجور', 'أجور', 'عمال', 'عامل', 'مكافأة', 'مكافاة', 'سلفة', 'salary'],
  'كهرباء وماء': ['كهرباء', 'الكهرباء', 'ماء', 'مياه', 'فاتورة كهرباء', 'water', 'electric'],
  'اتصالات وإنترنت': ['انترنت', 'إنترنت', 'اتصالات', 'stc', 'زين', 'موبايلي', 'جوال', 'شريحة', 'باقة', 'internet'],
  'وقود ونقل': ['بنزين', 'وقود', 'ديزل', 'نقل', 'شحن', 'توصيل', 'سطحة', 'مواصلات', 'تاكسي', 'اوبر', 'fuel'],
  'صيانة': ['صيانة', 'اصلاح', 'إصلاح', 'تصليح', 'سباك', 'كهربائي', 'سيارة', 'قطع غيار'],
  'تسويق وإعلان': ['اعلان', 'إعلان', 'تسويق', 'دعاية', 'سناب', 'انستقرام', 'جوجل', 'مطبوعات', 'ميتا', 'ads'],
  'رسوم حكومية وبنكية': ['رسوم', 'غرامة', 'مخالفة', 'بلدي', 'بلدية', 'رخصة', 'سجل تجاري', 'جوازات', 'زكاة', 'ضريبة', 'بنك', 'عمولة', 'تأمين', 'تامين', 'مكتب العمل', 'قوى', 'مقيم'],
  'ضيافة ومستلزمات': ['ضيافة', 'قهوة', 'شاي', 'مياه شرب', 'ماء شرب', 'مستلزمات', 'قرطاسية', 'تنظيف', 'مناديل', 'اكياس', 'أكياس', 'كراتين تغليف'],
  'مشتريات بضاعة': ['بضاعة', 'بضائع', 'مشتريات', 'مورد', 'توريد', 'شراء'],
};

String _norm(String s) => s
    .toLowerCase()
    .replaceAll(RegExp('[\u064B-\u0652\u0640]'), '')
    .replaceAll(RegExp('[أإآ]'), 'ا')
    .replaceAll('ة', 'ه')
    .replaceAll('ى', 'ي')
    .trim();

Set<String> _words(String s) => _norm(s).split(RegExp(r'[^\w\u0600-\u06FF]+')).where((w) => w.length >= 3).toSet();

/// مصنِّف مصروفات على الجهاز: يتعلم من تصنيفاتك السابقة (المورد أولاً ثم كلمات الملاحظات)،
/// ثم الكلمات المفتاحية الجاهزة. تصحيحك لتصنيف يُحفظ في المصروف نفسه فيتعلم منه تلقائياً.
class ExpenseClassifier {
  final Map<String, Map<String, int>> _byParty = {};
  final Map<String, Map<String, int>> _byWord = {};

  ExpenseClassifier.fromHistory(Iterable<Invoice> history) {
    for (final i in history) {
      if (i.kind != DocKind.expense || i.category.isEmpty) continue;
      final p = _norm(i.party);
      if (p.isNotEmpty) {
        final m = _byParty.putIfAbsent(p, () => {});
        m[i.category] = (m[i.category] ?? 0) + 1;
      }
      for (final w in _words(i.notes)) {
        final m = _byWord.putIfAbsent(w, () => {});
        m[i.category] = (m[i.category] ?? 0) + 1;
      }
    }
  }

  static String? _top(Map<String, int>? m) {
    if (m == null || m.isEmpty) return null;
    return m.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  /// أفضل تصنيف مقترح، أو null إذا لم تتوفر أي إشارة.
  String? suggest(String party, String notes, [String items = '']) {
    final byP = _top(_byParty[_norm(party)]);
    if (byP != null) return byP;
    final text = _norm('$party $notes $items');
    final score = <String, int>{};
    for (final w in _words('$notes $items')) {
      _byWord[w]?.forEach((c, n) => score[c] = (score[c] ?? 0) + n * 2);
    }
    _keywords.forEach((cat, kws) {
      for (final k in kws) {
        if (text.contains(_norm(k))) score[cat] = (score[cat] ?? 0) + 3;
      }
    });
    if (score.isEmpty) return null;
    return score.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }
}

/// مجموع المصروفات لكل تصنيف منذ [from] (غير المصنف يُحسب «غير مصنف»).
Map<String, double> expensesByCategory(List<InvoiceSummary> all, DateTime from, ExpenseClassifier cls) {
  final out = <String, double>{};
  for (final s in all) {
    final i = s.invoice;
    if (i.kind != DocKind.expense || i.date.isBefore(from)) continue;
    final c = i.category.isNotEmpty ? i.category : (cls.suggest(i.party, i.notes) ?? 'غير مصنف');
    out[c] = (out[c] ?? 0) + s.grandTotal;
  }
  return Map.fromEntries(out.entries.toList()..sort((a, b) => b.value.compareTo(a.value)));
}
