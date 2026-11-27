import '../models/invoice_item.dart';

/// الصفحة الفعلية لكل سطر: الصريحة إن حُددت (> 0)، وإلا ترث من السطر السابق (تبدأ من 1).
List<int> effectivePages(List<InvoiceItem> items) {
  var cur = 1;
  return [
    for (final it in items) cur = it.page > 0 ? it.page : cur,
  ];
}

/// هل حدّد المستخدم صفحات يدوياً لأي سطر؟
bool usesManualPages(List<InvoiceItem> items) => items.any((e) => e.page > 0);

/// أرقام الصفحات المستخدمة مرتبة وبدون تكرار.
List<int> usedPages(List<InvoiceItem> items) =>
    (effectivePages(items).toSet().toList()..sort());

/// تقسيم الأسطر إلى صفحات بالترتيب (الصفحات الفارغة تُتخطى، وترتيب الأسطر داخل الصفحة محفوظ).
/// بدون صفحات يدوية تعود شريحة واحدة (السلوك الأصلي: تدفق تلقائي).
List<List<InvoiceItem>> pageSlices(List<InvoiceItem> items) {
  if (items.isEmpty) return const [];
  final eff = effectivePages(items);
  final pages = eff.toSet().toList()..sort();
  return [
    for (final p in pages)
      [for (var i = 0; i < items.length; i++) if (eff[i] == p) items[i]]
  ];
}
