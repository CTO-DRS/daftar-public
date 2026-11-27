import '../models/invoice_item.dart';
import 'auto_fill.dart';

/// إحصاء استخدام صنف: آخر نسخة منه، وعدد مرات ظهوره في الفواتير.
class ItemStat {
  final InvoiceItem last;
  final int count;
  const ItemStat(this.last, this.count);
}

/// اقتراحات أسماء الأصناف أثناء الكتابة. الترتيب: يبدأ بالنص ثم يحتويه ثم تطابق كلمات،
/// وبينها الأكثر استخداماً أولاً. لا يقترح الاسم المطابق تماماً لما كُتب.
List<ItemStat> suggestItems(String query, List<ItemStat> stats,
    {int limit = 5, int minChars = 2}) {
  final q = normArabic(query);
  if (q.length < minChars) return const [];
  final words = q.split(' ').where((w) => w.isNotEmpty).toList();
  final scored = <MapEntry<ItemStat, int>>[];
  for (final s in stats) {
    final n = normArabic(s.last.description);
    if (n.isEmpty || n == q) continue;
    int tier;
    if (n.startsWith(q)) {
      tier = 0;
    } else if (n.contains(q)) {
      tier = 1;
    } else if (words.length > 1 && words.every(n.contains)) {
      tier = 2;
    } else {
      continue;
    }
    scored.add(MapEntry(s, tier));
  }
  scored.sort((a, b) {
    final t = a.value.compareTo(b.value);
    return t != 0 ? t : b.key.count.compareTo(a.key.count);
  });
  return [for (final e in scored.take(limit)) e.key];
}

/// يطبّق صنفاً مقترحاً على سطر: يملأ الفارغ فقط، ويفضّل آخر سعر لهذا العميل إن وُجد.
/// يعيد true إذا استُخدم سعر العميل الخاص.
bool applySuggestion(InvoiceItem target, InvoiceItem from,
    {double? customerPrice}) {
  target.description = from.description;
  if (target.itemCode.isEmpty) target.itemCode = from.itemCode;
  if (target.refNumber.isEmpty) target.refNumber = from.refNumber;
  if (target.unit.isEmpty) target.unit = from.unit;
  if (target.packSize == 0) target.packSize = from.packSize;
  if (target.costPrice == 0) target.costPrice = from.costPrice;
  if (target.wholesaleUnit.isEmpty) target.wholesaleUnit = from.wholesaleUnit;
  var special = false;
  if (target.unitPrice == 0) {
    if (customerPrice != null && customerPrice > 0) {
      target.unitPrice = customerPrice;
      special = customerPrice != from.unitPrice;
    } else {
      target.unitPrice = from.unitPrice;
    }
  }
  return special;
}
