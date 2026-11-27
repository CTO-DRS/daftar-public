import '../models/invoice.dart';

String _q(String s) {
  final t = s.replaceAll('\r', ' ').replaceAll('\n', ' ');
  // حماية من حقن الصيغ عند الفتح في Excel.
  final safe = RegExp(r'^[=+\-@]').hasMatch(t) ? "'$t" : t;
  return '"${safe.replaceAll('"', '""')}"';
}

String _d(DateTime? d) => d == null
    ? ''
    : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
String _m(double v) => v.toStringAsFixed(2);

/// ملف CSV للمحاسب: الفواتير والإشعارات والمصروفات المعتمدة في الفترة [from, to).
/// الإشعار الدائن بقيم سالبة. المصروف بنوعه "مصروف". يبدأ بـ BOM ليفتح بالعربية في Excel.
String accountantCsv(List<InvoiceSummary> all, DateTime from, DateTime to) {
  final b = StringBuffer('\uFEFF');
  b.writeln('النوع,الرقم,التاريخ,الطرف,الحالة,المبلغ قبل الضريبة,الضريبة,الإجمالي,المدفوع,المتبقي,الاستحقاق,العملة');
  final rows = all.where((s) {
    final i = s.invoice;
    if (i.kind != DocKind.invoice && i.kind != DocKind.expense) return false;
    // المصروف المسجّل يُحتسب دائماً (كما في الذكاء المالي)؛ الفاتورة المسودة لا.
    if (i.kind == DocKind.invoice && i.status == InvoiceStatus.draft) return false;
    return !i.date.isBefore(from) && i.date.isBefore(to);
  }).toList()
    ..sort((a, b) => a.invoice.date.compareTo(b.invoice.date));
  for (final s in rows) {
    final i = s.invoice;
    final sign = i.noteType == 'credit' ? -1.0 : 1.0;
    final total = s.grandTotal * sign;
    final vat = i.vatRate > 0 ? (s.grandTotal - s.grandTotal / (1 + i.vatRate / 100)) * sign : 0.0;
    final isExp = i.kind == DocKind.expense;
    final rem = isExp || i.isNote ? 0.0 : paymentRemaining(s.grandTotal, i.paidAmount, i.status);
    final paid = isExp
        ? total
        : i.isNote
            ? 0.0
            : (i.status == InvoiceStatus.paid ? s.grandTotal : i.paidAmount);
    b.writeln([
      _q(isExp ? 'مصروف' : i.docLabel),
      _q(i.number),
      _d(i.date),
      _q(i.party),
      _q(i.status.label),
      _m(total - vat),
      _m(vat),
      _m(total),
      _m(paid),
      _m(rem),
      _d(i.dueDate),
      _q(i.currency),
    ].join(','));
  }
  return b.toString();
}
