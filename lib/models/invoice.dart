import 'invoice_item.dart';

/// نوع المستند: فاتورة أو جدول جرد.
enum DocKind { invoice, inventory }

extension DocKindX on DocKind {
  String get label => this == DocKind.invoice ? 'فاتورة' : 'جرد';
  String get dbValue => name;
  static DocKind fromDb(String? v) =>
      v == 'inventory' ? DocKind.inventory : DocKind.invoice;
}

/// حالة المستند.
enum InvoiceStatus { draft, confirmed, paid }

extension InvoiceStatusX on InvoiceStatus {
  String get label {
    switch (this) {
      case InvoiceStatus.draft:
        return 'مسودة';
      case InvoiceStatus.confirmed:
        return 'معتمدة';
      case InvoiceStatus.paid:
        return 'مدفوعة';
    }
  }

  static InvoiceStatus fromDb(String? v) => InvoiceStatus.values
      .firstWhere((e) => e.name == v, orElse: () => InvoiceStatus.draft);
}

class Invoice {
  int? id;
  DocKind kind;
  InvoiceStatus status;
  String number;
  DateTime date;
  String party; // اسم العميل / المورد
  String notes;
  DateTime updatedAt;
  DateTime? dueDate; // تاريخ الاستحقاق
  double paidAmount; // المبلغ المدفوع
  double vatRate; // نسبة ضريبة القيمة المضافة % (0 = بدون)
  String currency; // عملة هذا المستند (فارغ = عملة الإعدادات)
  List<InvoiceItem> items;

  Invoice({
    this.id,
    this.kind = DocKind.invoice,
    this.status = InvoiceStatus.draft,
    required this.number,
    DateTime? date,
    this.party = '',
    this.notes = '',
    DateTime? updatedAt,
    this.dueDate,
    this.paidAmount = 0,
    this.currency = '',
    this.vatRate = 0,
    List<InvoiceItem>? items,
  })  : date = date ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        items = items ?? [];

  /// إجمالي عدد الأصناف (عدد الأسطر).
  int get itemCount => items.where((e) => !e.isEmpty).length;

  /// إجمالي القطع.
  double get totalQuantity => items.fold(0.0, (s, i) => s + i.quantity);

  /// المبلغ الإجمالي النهائي.
  double get subtotal => items.fold(0.0, (s, i) => s + i.total);

  /// ضريبة القيمة المضافة مقرّبة إلى خانتين.
  double get vatAmount =>
      vatRate <= 0 ? 0 : (subtotal * vatRate / 100 * 100).roundToDouble() / 100;

  double get grandTotal => subtotal + vatAmount;

  String currencyOr(String fallback) =>
      currency.trim().isEmpty ? fallback : currency.trim();

  /// المتبقي بعد الدفعات.
  double get remaining => paymentRemaining(grandTotal, paidAmount, status);

  bool get isFullyPaid => remaining <= 0.005;

  /// متأخرة: فاتورة لها تاريخ استحقاق مضى وما زال عليها متبقٍ.
  bool get isOverdue => isOverdueFor(kind, dueDate, remaining, grandTotal);

  Map<String, Object?> toMap() => {
        'id': id,
        'kind': kind.dbValue,
        'status': status.name,
        'number': number,
        'date': date.millisecondsSinceEpoch,
        'party': party,
        'notes': notes,
        'updated_at': updatedAt.millisecondsSinceEpoch,
        'due_date': dueDate?.millisecondsSinceEpoch,
        'paid_amount': paidAmount,
        'currency': currency,
        'vat_rate': vatRate,
        'item_count': itemCount,
        'total_qty': totalQuantity,
        'grand_total': grandTotal,
      };

  factory Invoice.fromMap(Map<String, Object?> m, [List<InvoiceItem>? items]) =>
      Invoice(
        id: m['id'] as int?,
        kind: DocKindX.fromDb(m['kind'] as String?),
        status: InvoiceStatusX.fromDb(m['status'] as String?),
        number: (m['number'] as String?) ?? '',
        date: DateTime.fromMillisecondsSinceEpoch((m['date'] as int?) ?? 0),
        party: (m['party'] as String?) ?? '',
        notes: (m['notes'] as String?) ?? '',
        updatedAt:
            DateTime.fromMillisecondsSinceEpoch((m['updated_at'] as int?) ?? 0),
        dueDate: m['due_date'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(m['due_date'] as int),
        paidAmount: (m['paid_amount'] as num?)?.toDouble() ?? 0,
        currency: (m['currency'] as String?) ?? '',
        vatRate: (m['vat_rate'] as num?)?.toDouble() ?? 0,
        items: items,
      );
}

/// ملخص خفيف لعرض القائمة بدون تحميل الأسطر.
class InvoiceSummary {
  final Invoice invoice;
  final int itemCount;
  final double totalQty;
  final double grandTotal;
  InvoiceSummary(this.invoice, this.itemCount, this.totalQty, this.grandTotal);
}

/// المتبقي: الفاتورة بحالة "مدفوعة" تُعدّ مسددة بالكامل حتى لو لم يُسجَّل مبلغ.
double paymentRemaining(double total, double paid, InvoiceStatus status) {
  if (status == InvoiceStatus.paid) return 0;
  final r = total - paid;
  return r < 0 ? 0 : r;
}

bool isOverdueFor(DocKind kind, DateTime? due, double remaining, double total,
    [DateTime? now]) {
  if (kind != DocKind.invoice || due == null || total <= 0) return false;
  if (remaining <= 0.005) return false;
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  return DateTime(due.year, due.month, due.day).isBefore(today);
}
