import 'invoice_item.dart';

/// نوع المستند: فاتورة أو جدول جرد.
enum DocKind { invoice, inventory }

extension DocKindX on DocKind {
  String get label => this == DocKind.invoice ? 'فاتورة' : 'جرد';
  String get dbValue => name;
  static DocKind fromDb(String? v) =>
      v == 'inventory' ? DocKind.inventory : DocKind.invoice;
}

class Invoice {
  int? id;
  DocKind kind;
  String number;
  DateTime date;
  String party; // اسم العميل / المورد
  String notes;
  DateTime updatedAt;
  List<InvoiceItem> items;

  Invoice({
    this.id,
    this.kind = DocKind.invoice,
    required this.number,
    DateTime? date,
    this.party = '',
    this.notes = '',
    DateTime? updatedAt,
    List<InvoiceItem>? items,
  })  : date = date ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        items = items ?? [];

  /// إجمالي عدد الأصناف (عدد الأسطر).
  int get itemCount => items.length;

  /// إجمالي القطع.
  double get totalQuantity => items.fold(0.0, (s, i) => s + i.quantity);

  /// المبلغ الإجمالي النهائي.
  double get grandTotal => items.fold(0.0, (s, i) => s + i.total);

  Map<String, Object?> toMap() => {
        'id': id,
        'kind': kind.dbValue,
        'number': number,
        'date': date.millisecondsSinceEpoch,
        'party': party,
        'notes': notes,
        'updated_at': updatedAt.millisecondsSinceEpoch,
        'item_count': itemCount,
        'total_qty': totalQuantity,
        'grand_total': grandTotal,
      };

  factory Invoice.fromMap(Map<String, Object?> m, [List<InvoiceItem>? items]) =>
      Invoice(
        id: m['id'] as int?,
        kind: DocKindX.fromDb(m['kind'] as String?),
        number: (m['number'] as String?) ?? '',
        date: DateTime.fromMillisecondsSinceEpoch((m['date'] as int?) ?? 0),
        party: (m['party'] as String?) ?? '',
        notes: (m['notes'] as String?) ?? '',
        updatedAt:
            DateTime.fromMillisecondsSinceEpoch((m['updated_at'] as int?) ?? 0),
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
