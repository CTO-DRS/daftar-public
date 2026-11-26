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
  String unit; // الوحدة: حبة، كرتون، كجم... أو نص حر
  double wholesaleQty; // عدد الجملة (اختياري)
  double wholesalePrice; // سعر الجملة للوحدة الواحدة (اختياري)
  String wholesaleUnit; // وحدة الجملة: كرتون، درزن...
  double packSize; // كم قطعة في وحدة الجملة (1 كرتون = 24 حبة)، 0 = غير محدد

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
    this.unit = '',
    this.wholesaleQty = 0,
    this.wholesalePrice = 0,
    this.wholesaleUnit = '',
    this.packSize = 0,
    this.flagged = false,
    this.statedTotal,
  });

  /// الإجمالي = العدد × سعر الفردي.
  /// إجمالي الجملة = عدد الجملة × سعر الجملة.
  double get wholesaleTotal => wholesaleQty * wholesalePrice;

  /// إجمالي القطع: الفردي + (عدد الجملة × حجم العبوة) عند تحديد حجم العبوة.
  double get pieces => quantity + (packSize > 0 ? wholesaleQty * packSize : 0);

  bool get hasWholesale => wholesaleQty != 0 || wholesalePrice != 0;

  /// الإجمالي = (العدد × سعر الفردي) + (عدد الجملة × سعر الجملة).
  double get total => quantity * unitPrice + wholesaleTotal;

  /// سطر فارغ تماماً: يُحذف تلقائياً عند الحفظ.
  bool get isEmpty =>
      itemCode.trim().isEmpty &&
      refNumber.trim().isEmpty &&
      description.trim().isEmpty &&
      notes.trim().isEmpty &&
      quantity == 0 &&
      unitPrice == 0 &&
      !hasWholesale;

  InvoiceItem copy() => InvoiceItem(
        id: id,
        invoiceId: invoiceId,
        itemCode: itemCode,
        refNumber: refNumber,
        description: description,
        quantity: quantity,
        unitPrice: unitPrice,
        notes: notes,
        unit: unit,
        wholesaleQty: wholesaleQty,
        wholesalePrice: wholesalePrice,
        wholesaleUnit: wholesaleUnit,
        packSize: packSize,
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
        'unit': unit,
        'wholesale_qty': wholesaleQty,
        'wholesale_price': wholesalePrice,
        'wholesale_unit': wholesaleUnit,
        'pack_size': packSize,
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
        unit: (m['unit'] as String?) ?? '',
        wholesaleQty: (m['wholesale_qty'] as num?)?.toDouble() ?? 0,
        wholesalePrice: (m['wholesale_price'] as num?)?.toDouble() ?? 0,
        wholesaleUnit: (m['wholesale_unit'] as String?) ?? '',
        packSize: (m['pack_size'] as num?)?.toDouble() ?? 0,
      );
}
