import 'number_utils.dart';
import '../models/invoice_item.dart';

enum SortField { itemCode, refNumber, quantity }

extension SortFieldX on SortField {
  String get label {
    switch (this) {
      case SortField.itemCode:
        return 'كود الصنف';
      case SortField.refNumber:
        return 'الرقم المرجعي';
      case SortField.quantity:
        return 'العدد';
    }
  }
}

/// مقارنة طبيعية: الأرقام داخل النص تقارن كأرقام ("A2" قبل "A10").
int naturalCompare(String a, String b) {
  final re = RegExp(r'(\d+|\D+)');
  final pa = re.allMatches(a.toLowerCase()).map((m) => m.group(0)!).toList();
  final pb = re.allMatches(b.toLowerCase()).map((m) => m.group(0)!).toList();
  for (var i = 0; i < pa.length && i < pb.length; i++) {
    final x = pa[i], y = pb[i];
    final nx = int.tryParse(x), ny = int.tryParse(y);
    final c = (nx != null && ny != null) ? nx.compareTo(ny) : x.compareTo(y);
    if (c != 0) return c;
  }
  return pa.length.compareTo(pb.length);
}

void sortItems(List<InvoiceItem> items, SortField field, bool ascending) {
  int cmp(InvoiceItem a, InvoiceItem b) {
    switch (field) {
      case SortField.itemCode:
        return naturalCompare(a.itemCode, b.itemCode);
      case SortField.refNumber:
        return naturalCompare(a.refNumber, b.refNumber);
      case SortField.quantity:
        return a.quantity.compareTo(b.quantity);
    }
  }

  // ترتيب مستقر: نحافظ على الترتيب الأصلي عند التساوي.
  final indexed = items.asMap().entries.toList();
  indexed.sort((x, y) {
    final c = cmp(x.value, y.value);
    final r = ascending ? c : -c;
    return r != 0 ? r : x.key.compareTo(y.key);
  });
  final sorted = indexed.map((e) => e.value).toList();
  items
    ..clear()
    ..addAll(sorted);
}

/// بحث الأسطر: الكود والمرجع والنوع والملاحظات، وكذلك العدد والسعر والإجمالي.
/// [q] مُطبَّع (أرقام لاتينية وحروف صغيرة).
bool itemMatchesQuery(InvoiceItem it, String q) {
  if (q.isEmpty) return true;
  if ('${it.itemCode} ${it.refNumber} ${it.description} ${it.notes}'
      .toLowerCase()
      .contains(q)) {
    return true;
  }
  return plainNumber(it.quantity).contains(q) ||
      plainNumber(it.unitPrice).contains(q) ||
      plainNumber(it.total).contains(q);
}
