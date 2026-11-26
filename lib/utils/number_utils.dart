import 'package:intl/intl.dart';

const _arabicIndic = '٠١٢٣٤٥٦٧٨٩';
const _persian = '۰۱۲۳۴۵۶۷۸۹';

/// يحول الأرقام العربية/الهندية/الفارسية إلى أرقام لاتينية.
String normalizeDigits(String input) {
  final sb = StringBuffer();
  for (final r in input.runes) {
    final ch = String.fromCharCode(r);
    final a = _arabicIndic.indexOf(ch);
    final p = _persian.indexOf(ch);
    if (a >= 0) {
      sb.write(a);
    } else if (p >= 0) {
      sb.write(p);
    } else if (ch == '٫') {
      sb.write('.');
    } else if (ch == '٬' || ch == '،') {
      // فاصل الآلاف: يُهمل
    } else {
      sb.write(ch);
    }
  }
  return sb.toString();
}

/// يحلل رقماً مكتوباً بأي نظام أرقام. يعيد null إن لم يكن رقماً صالحاً.
double? parseNumber(String? input) {
  if (input == null) return null;
  var s = normalizeDigits(input).trim().replaceAll(' ', '');
  if (s.isEmpty) return null;
  // 1,250.50 أو 1250,50
  if (s.contains(',') && s.contains('.')) {
    s = s.replaceAll(',', '');
  } else if (s.contains(',')) {
    final parts = s.split(',');
    if (parts.length == 2 && parts[1].length <= 2) {
      s = '${parts[0]}.${parts[1]}';
    } else {
      s = s.replaceAll(',', '');
    }
  }
  return double.tryParse(s);
}

final NumberFormat _money = NumberFormat('#,##0.##', 'en');
final NumberFormat _qty = NumberFormat('#,##0.###', 'en');

String formatMoney(double v) => _money.format(v);
String formatQty(double v) => _qty.format(v);

/// نص قابل للتحرير: بدون أصفار زائدة ولا فواصل آلاف.
String plainNumber(double v) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toString();
}
