import 'package:flutter/foundation.dart';

import '../models/invoice.dart';
import '../models/invoice_item.dart';
import '../utils/number_utils.dart';
import '../utils/pages.dart';
import '../utils/sort_utils.dart';

/// حالة شاشة تحرير المستند: الأسطر، التثبيت، الترتيب، البحث، الدفعات.
/// منطق نقي قابل للاختبار بدون واجهة.
class EditorController extends ChangeNotifier {
  EditorController(this.inv, {bool dirty = false})
      : _original = List<InvoiceItem>.of(inv.items) {
    _dirty = dirty;
  }

  final Invoice inv;

  bool _dirty = false;
  bool get dirty => _dirty;

  /// ترتيب الإدخال الأصلي للأسطر (للتراجع عن الفرز).
  final List<InvoiceItem> _original;

  // ---------- التثبيت ----------
  bool pinPrice = false;
  bool pinType = false;
  double pinnedPrice = 0;
  String pinnedType = '';
  bool get hasPins => pinPrice || pinType;

  // ---------- الترتيب والبحث ----------
  SortField? sortField;
  bool sortAsc = true;
  String _query = '';
  String get query => _query;

  void markDirty() {
    _dirty = true;
    notifyListeners();
  }

  void markSaved() {
    _dirty = false;
    notifyListeners();
  }

  /// سطر جديد يرث السعر والنوع المثبتين.
  InvoiceItem blank() => InvoiceItem(
        unitPrice: pinPrice ? pinnedPrice : 0,
        description: pinType ? pinnedType : '',
        page: pageTab,
      );

  // ---------- الصفحات ----------
  /// تبويب الصفحة المعروض: 0 = كل الأسطر، وإلا رقم الصفحة (والأسطر الجديدة تذهب إليها).
  int pageTab = 0;

  /// هل الفاتورة تستخدم صفحات يدوية.
  bool get manualPages => usesManualPages(inv.items);

  /// أرقام الصفحات المستخدمة.
  List<int> get pages => usedPages(inv.items);

  /// الصفحة الفعلية للسطر.
  int pageOf(InvoiceItem it) {
    final i = inv.items.indexOf(it);
    return i < 0 ? 1 : effectivePages(inv.items)[i];
  }

  void selectPageTab(int p) {
    pageTab = p;
    notifyListeners();
  }

  /// يثبّت الصفحة الفعلية على كل سطر ثم يرتّب بثبات حسب الصفحة (يُستدعى عند أي تعديل يدوي).
  void normalizePages() {
    if (!manualPages) return;
    final eff = effectivePages(inv.items);
    for (var i = 0; i < inv.items.length; i++) {
      inv.items[i].page = eff[i];
    }
    final idx = List<int>.generate(inv.items.length, (i) => i)
      ..sort((a, b) {
        final c = inv.items[a].page.compareTo(inv.items[b].page);
        return c != 0 ? c : a.compareTo(b);
      });
    final sorted = [for (final i in idx) inv.items[i]];
    inv.items
      ..clear()
      ..addAll(sorted);
  }

  /// ينقل سطراً إلى صفحة محددة (أو 0 = تلقائي مع السابق).
  void movePage(InvoiceItem item, int page) {
    materializePages();
    item.page = page == 0 ? item.page : page;
    normalizePages();
    markDirty();
  }

  /// يثبّت الصفحة الفعلية على كل سطر حتى لا ينتقل غير المقصود بالوراثة.
  void materializePages() {
    final eff = effectivePages(inv.items);
    for (var i = 0; i < inv.items.length; i++) {
      inv.items[i].page = eff[i];
    }
  }

  /// يطبق نتيجة نافذة السطر: التثبيت ثم الإضافة أو الاستبدال.
  void applyEdit(InvoiceItem? old, InvoiceItem edited,
      {required bool pinPrice, required bool pinType}) {
    this.pinPrice = pinPrice;
    this.pinType = pinType;
    if (pinPrice) pinnedPrice = edited.unitPrice;
    if (pinType) pinnedType = edited.description;
    if (old != null && edited.page != old.page) {
      final eff = effectivePages(inv.items);
      final oi = inv.items.indexOf(old);
      for (var i = 0; i < inv.items.length; i++) {
        if (i != oi) inv.items[i].page = eff[i];
      }
    }
    if (old == null) {
      inv.items.add(edited);
      _original.add(edited);
    } else {
      final i = inv.items.indexOf(old);
      if (i >= 0) inv.items[i] = edited;
      final j = _original.indexOf(old);
      if (j >= 0) _original[j] = edited;
    }
    normalizePages();
    markDirty();
  }

  void clearPinPrice() {
    pinPrice = false;
    notifyListeners();
  }

  void clearPinType() {
    pinType = false;
    notifyListeners();
  }

  /// يضيف [n] سطراً فارغاً بالقيم المثبتة (حد أقصى 200).
  void addBlanks(int n) {
    final count = n.clamp(0, 200);
    for (var i = 0; i < count; i++) {
      final it = blank();
      inv.items.add(it);
      _original.add(it);
    }
    if (count > 0) markDirty();
  }

  /// يضيف أسطراً جاهزة (من «طلبه المعتاد» أو «كرر آخر فاتورة»).
  void addItems(List<InvoiceItem> items) {
    for (final it in items) {
      inv.items.add(it);
      _original.add(it);
    }
    if (items.isNotEmpty) {
      normalizePages();
      markDirty();
    }
  }

  /// يحذف سطراً ويعيد موضعه للتراجع (-1 إن لم يوجد).
  int remove(InvoiceItem item) {
    final i = inv.items.indexOf(item);
    if (i < 0) return -1;
    inv.items.removeAt(i);
    markDirty();
    return i;
  }

  void restore(int index, InvoiceItem item) {
    inv.items.insert(index.clamp(0, inv.items.length), item);
    if (!_original.contains(item)) _original.add(item);
    markDirty();
  }

  /// يكرر السطر [times] مرة مباشرة تحته بنفس الكود والمرجع والنوع والسعر.
  /// بالنسخة الواحدة ([times] = 1 مع [keepQuantity]) تُنسخ الكمية أيضاً.
  void duplicate(InvoiceItem item, {int times = 1, bool keepQuantity = true}) {
    final i = inv.items.indexOf(item);
    if (i < 0) return;
    final n = times.clamp(0, 100);
    for (var k = 0; k < n; k++) {
      final copy = item.copy()
        ..id = null
        ..flagged = false;
      if (!keepQuantity) copy.quantity = 0;
      inv.items.insert(i + 1 + k, copy);
      _original.add(copy);
    }
    if (n > 0) markDirty();
  }

  // ---------- الترتيب ----------
  void sortBy(SortField f, bool asc) {
    sortField = f;
    sortAsc = asc;
    sortItems(inv.items, f, asc);
    markDirty();
  }

  /// يعيد ترتيب الإدخال الأصلي بعد الفرز.
  void restoreOriginalOrder() {
    final rank = <InvoiceItem, int>{
      for (var i = 0; i < _original.length; i++) _original[i]: i,
    };
    final indexed = inv.items.asMap().entries.toList()
      ..sort((a, b) {
        final ra = rank[a.value] ?? (1 << 30) + a.key;
        final rb = rank[b.value] ?? (1 << 30) + b.key;
        return ra.compareTo(rb);
      });
    final sorted = indexed.map((e) => e.value).toList();
    inv.items
      ..clear()
      ..addAll(sorted);
    sortField = null;
    markDirty();
  }

  bool get canRestoreOrder => sortField != null;

  // ---------- البحث ----------
  void setQuery(String q) {
    _query = q;
    notifyListeners();
  }

  /// مواضع الأسطر المطابقة للبحث الحالي.
  List<int> get visibleIndices {
    final q = normalizeDigits(_query).trim().toLowerCase();
    final eff = pageTab > 0 ? effectivePages(inv.items) : const <int>[];
    return [
      for (var i = 0; i < inv.items.length; i++)
        if ((pageTab == 0 || eff[i] == pageTab) &&
            (q.isEmpty || itemMatchesQuery(inv.items[i], q)))
          i,
    ];
  }

  // ---------- الدفعات ----------
  void setPaidAmount(double v) {
    inv.paidAmount = v < 0 ? 0 : v;
    if (inv.grandTotal > 0 && inv.paidAmount >= inv.grandTotal - 0.005) {
      inv.status = InvoiceStatus.paid;
    } else if (inv.status == InvoiceStatus.paid) {
      inv.status = InvoiceStatus.confirmed;
    }
    markDirty();
  }

  void setVatRate(double r) {
    inv.vatRate = r < 0 ? 0 : (r > 100 ? 100 : r);
    markDirty();
  }

  void setStatus(InvoiceStatus st) {
    final wasPaid = inv.status == InvoiceStatus.paid;
    inv.status = st;
    if (st == InvoiceStatus.paid) {
      inv.paidAmount = inv.grandTotal;
    } else if (wasPaid) {
      inv.paidAmount = 0;
    }
    markDirty();
  }
}
