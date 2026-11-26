import 'invoice_item.dart';

enum OcrSource { gemini, openrouter, offline }

extension OcrSourceX on OcrSource {
  String get label {
    switch (this) {
      case OcrSource.gemini:
        return 'Gemini';
      case OcrSource.openrouter:
        return 'OpenRouter';
      case OcrSource.offline:
        return 'مسح محلي (بدون إنترنت)';
    }
  }
}

class OcrResult {
  final OcrSource source;
  final String party;
  final String invoiceNumber;
  final DateTime? date;
  final List<InvoiceItem> items;

  /// الإجمالي النهائي المكتوب على الورقة إن وُجد.
  final double? statedGrandTotal;

  /// ملاحظات للمستخدم (فشل الاتصال، رجوع للمسح المحلي...).
  final List<String> warnings;

  OcrResult({
    required this.source,
    this.party = '',
    this.invoiceNumber = '',
    this.date,
    required this.items,
    this.statedGrandTotal,
    this.warnings = const [],
  });
}

class OcrException implements Exception {
  final String message;
  OcrException(this.message);
  @override
  String toString() => message;
}
