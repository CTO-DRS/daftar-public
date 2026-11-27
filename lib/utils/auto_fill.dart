import '../models/invoice_item.dart';

String _n(String s) => s
    .replaceAll(RegExp('[\u064B-\u0652\u0640]'), '')
    .replaceAll(RegExp('[أإآ]'), 'ا')
    .replaceAll('ة', 'ه')
    .replaceAll('ى', 'ي')
    .toLowerCase()
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

int _lev(String a, String b) {
  if (a == b) return 0;
  var prev = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final cur = List<int>.filled(b.length + 1, 0)..[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final c = a[i - 1] == b[j - 1] ? 0 : 1;
      cur[j] = [prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + c].reduce((x, y) => x < y ? x : y);
    }
    prev = cur;
  }
  return prev[b.length];
}

/// يطابق اسم عميل قرأه OCR/الصوت مع عميل معروف (تجاهل الهمزات والتشكيل، وخطأ حرف
/// واحد للأسماء الطويلة). يعيد null إذا لم يوجد تطابق واضح (لا يخمّن).
String? matchParty(String name, List<String> known) {
  final q = _n(name);
  if (q.isEmpty) return null;
  String? best;
  var bestD = 99;
  for (final k in known) {
    final nk = _n(k);
    if (nk == q) return k;
    if (q.length >= 5 && nk.length >= 5) {
      final d = _lev(q, nk);
      if (d <= 1 && d < bestD) {
        best = k;
        bestD = d;
      }
    }
  }
  return best;
}

/// يكمل الحقول الناقصة (سعر، تكلفة، وحدة، حجم عبوة، كود) من آخر استخدام للصنف بنفس الاسم.
/// لا يغيّر أي قيمة موجودة. يعيد عدد الأسطر التي أُكملت.
int enrichItems(List<InvoiceItem> items, Map<String, InvoiceItem> history) {
  final byName = {for (final e in history.entries) _n(e.key): e.value};
  var filled = 0;
  for (final it in items) {
    final h = byName[_n(it.description)];
    if (h == null) continue;
    var changed = false;
    if (it.unitPrice == 0 && h.unitPrice > 0) {
      it.unitPrice = h.unitPrice;
      changed = true;
    }
    if (it.costPrice == 0 && h.costPrice > 0) {
      it.costPrice = h.costPrice;
      changed = true;
    }
    if (it.unit.isEmpty && h.unit.isNotEmpty) {
      it.unit = h.unit;
      changed = true;
    }
    if (it.packSize == 0 && h.packSize > 0) {
      it.packSize = h.packSize;
      changed = true;
    }
    if (it.itemCode.isEmpty && h.itemCode.isNotEmpty) {
      it.itemCode = h.itemCode;
      changed = true;
    }
    if (changed) filled++;
  }
  return filled;
}

/// تطبيع عربي للمطابقة (همزات، تشكيل، ة/ه، ى/ي، مسافات).
String normArabic(String s) => _n(s);

/// يصحّح أسماء الأصناف المقروءة (OCR) إلى أسماء معروفة عند تطابق واضح فقط
/// (نفس الاسم بعد التطبيع أو خطأ حرف واحد). يعيد عدد ما صُحّح فعلاً.
int snapItemNames(List<InvoiceItem> items, List<String> known) {
  var n = 0;
  for (final it in items) {
    final hit = matchParty(it.description, known);
    if (hit != null && hit != it.description) {
      it.description = hit;
      n++;
    }
  }
  return n;
}

/// يملأ سعر الوحدة الفارغ من آخر سعر لهذا العميل (مفتاح: الاسم المطبّع). يعيد العدد.
int applyCustomerPrices(List<InvoiceItem> items, Map<String, double> prices) {
  var n = 0;
  for (final it in items) {
    if (it.unitPrice != 0) continue;
    final p = prices[_n(it.description)];
    if (p != null && p > 0) {
      it.unitPrice = p;
      n++;
    }
  }
  return n;
}
