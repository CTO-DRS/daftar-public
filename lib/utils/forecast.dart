/// توقع نفاد المخزون من آخر جرد ومبيعات ما بعده.
class StockForecast {
  final String name;
  final double onHand; // المقدر الآن
  final double perDay; // معدل البيع اليومي (آخر 30 يوماً)
  final double? recentPerDay; // معدل آخر 14 يوماً (للاتجاه)
  final double packSize; // حجم العبوة/الكرتونة إن عُرف (0 = غير معروف)
  const StockForecast(this.name, this.onHand, this.perDay, {this.recentPerDay, this.packSize = 0});

  /// عدد الأيام المتبقية، أو null إن لم يكن هناك بيع.
  double? get daysLeft => perDay > 0 ? (onHand <= 0 ? 0 : onHand / perDay) : null;

  /// كمية الشراء المقترحة لتغطية [days] يوماً.
  double suggestedOrder({int days = 30}) {
    final need = perDay * days - onHand;
    return need <= 0 ? 0 : need.ceilToDouble();
  }
}

class CountRow {
  final String key, name;
  final double qty;
  final DateTime date;
  final double packSize;
  const CountRow(this.key, this.name, this.qty, this.date, {this.packSize = 0});
}

class SaleRow {
  final String key;
  final double pieces;
  final DateTime date;
  const SaleRow(this.key, this.pieces, this.date);
}

/// [counts]: كل أسطر الجرد (أي ترتيب). [sales]: كل أسطر البيع المعتمد.
/// الصنف يدخل التوقع فقط إن كان له جرد ومبيعات خلال آخر 30 يوماً.
List<StockForecast> computeStockForecast(
    List<CountRow> counts, List<SaleRow> sales, DateTime now) {
  final latest = <String, CountRow>{};
  for (final c in counts) {
    final cur = latest[c.key];
    if (cur == null || c.date.isAfter(cur.date)) latest[c.key] = c;
  }
  final out = <StockForecast>[];
  final from30 = now.subtract(const Duration(days: 30));
  for (final c in latest.values) {
    var soldSince = 0.0, sold30 = 0.0, sold14 = 0.0;
    final from14 = now.subtract(const Duration(days: 14));
    for (final s in sales) {
      if (s.key != c.key) continue;
      if (s.date.isAfter(c.date)) soldSince += s.pieces;
      if (s.date.isAfter(from30)) sold30 += s.pieces;
      if (s.date.isAfter(from14)) sold14 += s.pieces;
    }
    if (sold30 <= 0) continue;
    // نافذة المعدل: أقصر من 30 يوماً إن كان الجرد أحدث.
    final days = now.difference(c.date).inDays.clamp(1, 30);
    final window = days < 30 ? days : 30;
    final w14 = days < 14 ? days : 14;
    out.add(StockForecast(c.name, c.qty - soldSince, sold30 / window,
        recentPerDay: sold14 / w14, packSize: c.packSize));
  }
  out.sort((a, b) => (a.daysLeft ?? 1e9).compareTo(b.daysLeft ?? 1e9));
  return out;
}

/// مفتاح موحّد للصنف: كود الموديل إن وُجد (يتجاهل الشرطة والمسافات وحالة الأحرف)،
/// وإلا الاسم. يُستخدم لربط الجرد بالمبيعات حتى لو اختلف كتابة الاسم.
String stockKey(String name, String code, Map<String, String> nameToCode) {
  String norm(String c) => c.toUpperCase().replaceAll(RegExp(r'[\s\-_/.]'), '');
  final c = norm(code.trim());
  final n = name.trim().toLowerCase();
  if (c.isNotEmpty) return 'c:$c';
  final alias = nameToCode[n];
  if (alias != null && alias.isNotEmpty) return 'c:${norm(alias)}';
  return 'n:$n';
}

/// يبني خريطة اسم ← كود من كل الأسطر المعروفة (الاسم الذي ظهر مرة مع كود).
Map<String, String> buildNameToCode(Iterable<(String, String)> rows) {
  final m = <String, String>{};
  for (final r in rows) {
    final n = r.$1.trim().toLowerCase();
    if (n.isNotEmpty && r.$2.trim().isNotEmpty) m[n] = r.$2;
  }
  return m;
}
