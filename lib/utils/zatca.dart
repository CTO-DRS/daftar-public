import 'dart:convert';
import 'dart:typed_data';

/// رمز QR بصيغة المرحلة الأولى من الفوترة الإلكترونية (TLV ثم Base64):
/// 1 اسم البائع، 2 الرقم الضريبي، 3 الوقت، 4 الإجمالي شامل الضريبة، 5 الضريبة.
/// هذا تنسيق فقط، وليس اعتماداً أو ربطاً مع هيئة الزكاة والضريبة والجمارك.
String zatcaPhase1Qr({
  required String sellerName,
  required String vatNumber,
  required DateTime timestamp,
  required double totalWithVat,
  required double vatAmount,
}) {
  final out = BytesBuilder();
  void put(int tag, String v) {
    final b = utf8.encode(v);
    if (b.length > 255) {
      throw ArgumentError('القيمة أطول من 255 بايت (الوسم $tag)');
    }
    out.add([tag, b.length]);
    out.add(b);
  }

  put(1, sellerName);
  put(2, vatNumber);
  put(3, isoUtc(timestamp));
  put(4, totalWithVat.toStringAsFixed(2));
  put(5, vatAmount.toStringAsFixed(2));
  return base64.encode(out.toBytes());
}

String isoUtc(DateTime t) {
  final u = t.toUtc();
  String p(int n) => n.toString().padLeft(2, '0');
  return '${u.year.toString().padLeft(4, '0')}-${p(u.month)}-${p(u.day)}T${p(u.hour)}:${p(u.minute)}:${p(u.second)}Z';
}

/// الرقم الضريبي السعودي: 15 رقماً يبدأ بـ 3 وينتهي بـ 3.
bool isValidSaudiVat(String v) => RegExp(r'^3\d{13}3$').hasMatch(v.trim());
