import '../models/invoice_item.dart';
import 'auto_fill.dart';
import 'number_utils.dart';

/// تحذيرات لطيفة على سطر (لا تمنع الحفظ أبداً).
List<String> itemWarnings(
  InvoiceItem it, {
  InvoiceItem? history,
  double? customerPrice,
  List<InvoiceItem> others = const [],
}) {
  final out = <String>[];
  final price = it.unitPrice;
  final ref = (customerPrice != null && customerPrice > 0)
      ? customerPrice
      : (history != null && history.unitPrice > 0 ? history.unitPrice : null);
  if (price > 0 && ref != null) {
    final r = price / ref;
    if (r >= 3 || r <= 1 / 3) {
      out.add(
          'السعر ${plainNumber(price)} بعيد عن المعتاد (${plainNumber(ref)}). تأكد من الفاصلة العشرية.');
    }
  }
  if (price > 0 && it.costPrice > 0 && price < it.costPrice) {
    out.add('السعر أقل من التكلفة (${plainNumber(it.costPrice)}): خسارة في هذا الصنف.');
  }
  final lastQty = history?.quantity ?? 0;
  if (it.quantity > 0 && lastQty > 0 && it.quantity / lastQty >= 20) {
    out.add(
        'الكمية ${plainNumber(it.quantity)} أكبر بكثير من آخر مرة (${plainNumber(lastQty)}).');
  }
  final n = normArabic(it.description);
  if (n.isNotEmpty) {
    final dup = others.any((o) =>
        !identical(o, it) &&
        normArabic(o.description) == n &&
        o.itemCode.trim() == it.itemCode.trim());
    if (dup) out.add('هذا الصنف موجود في الفاتورة بالفعل.');
  }
  return out;
}
