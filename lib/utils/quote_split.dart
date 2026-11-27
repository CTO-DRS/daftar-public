import '../models/invoice_item.dart';

class QuoteSplit {
  final List<InvoiceItem> converted, remaining;
  QuoteSplit(this.converted, this.remaining);
}

double _primary(InvoiceItem it) => it.quantity > 0 ? it.quantity : it.wholesaleQty;

/// يقسم أسطر عرض السعر: [chosen] فهرس السطر ← كمية التحويل.
/// الكمية الأساسية للسطر هي العدد الفردي، أو عدد الجملة إن لم يوجد فردي.
/// السطر المختلط (فردي + جملة) يُقسم بنفس النسبة. ما تبقى يبقى في العرض.
QuoteSplit splitQuote(List<InvoiceItem> items, Map<int, double> chosen) {
  final conv = <InvoiceItem>[];
  final rest = <InvoiceItem>[];
  for (var i = 0; i < items.length; i++) {
    final it = items[i];
    final want = chosen[i] ?? 0;
    final base = _primary(it);
    if (want <= 0 || base <= 0) {
      rest.add(it.copy()..id = null);
      continue;
    }
    final take = want >= base ? base : want;
    final f = take / base;
    final c = it.copy()
      ..id = null
      ..quantity = it.quantity * f
      ..wholesaleQty = it.wholesaleQty * f;
    conv.add(c);
    if (f < 0.999999) {
      rest.add(it.copy()
        ..id = null
        ..quantity = it.quantity * (1 - f)
        ..wholesaleQty = it.wholesaleQty * (1 - f));
    }
  }
  return QuoteSplit(conv, rest);
}
