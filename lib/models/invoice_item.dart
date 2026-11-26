/// سطر صنف داخل الفاتورة.
class InvoiceItem {
  int? id;
  int? invoiceId;
  String itemCode;
  String refNumber;
  String description;
  double quantity;
  double unitPrice;
  String notes;

  /// يُضبط عندما يكتشف التدقيق خللاً في الصف (مسح OCR).
  bool flagged;

  /// الإجمالي كما قرأه OCR من الورقة (للمقارنة فقط، لا يُحفظ).
  double? statedTotal;

  InvoiceItem({
    this.id,
    this.invoiceId,
    this.itemCode = '',
    this.refNumber = '',
    this.description = '',
    this.quantity = 0,
    this.unitPrice = 0,
    this.notes = '',
    this.flagged = false,
    this.statedTotal,
  });

  /// الإجمالي = العدد × سعر الفردي.
  double get total => quantity * unitPrice;

  /// سطر فارغ تماماً: يُحذف تلقائياً عند الحفظ.
  bool get isEmpty =>
      itemCode.trim().isEmpty &&
      refNumber.trim().isEmpty &&
      description.trim().isEmpty &&
      notes.trim().isEmpty &&
      quantity == 0 &&
      unitPrice == 0;

  InvoiceItem copy() => InvoiceItem(
        id: id,
        invoiceId: invoiceId,
        itemCode: itemCode,
        refNumber: refNumber,
        description: description,
        quantity: quantity,
        unitPrice: unitPrice,
        notes: notes,
        flagged: flagged,
        statedTotal: statedTotal,
      );

  Map<String, Object?> toMap(int position) => {
        'id': id,
        'invoice_id': invoiceId,
        'position': position,
        'item_code': itemCode,
        'ref_number': refNumber,
        'description': description,
        'quantity': quantity,
        'unit_price': unitPrice,
        'notes': notes,
      };

  factory InvoiceItem.fromMap(Map<String, Object?> m) => InvoiceItem(
        id: m['id'] as int?,
        invoiceId: m['invoice_id'] as int?,
        itemCode: (m['item_code'] as String?) ?? '',
        refNumber: (m['ref_number'] as String?) ?? '',
        description: (m['description'] as String?) ?? '',
        quantity: (m['quantity'] as num?)?.toDouble() ?? 0,
        unitPrice: (m['unit_price'] as num?)?.toDouble() ?? 0,
        notes: (m['notes'] as String?) ?? '',
      );
}
