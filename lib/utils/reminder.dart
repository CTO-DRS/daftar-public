import 'number_utils.dart';

/// رقم هاتف بصيغة دولية بدون + (للسعودية افتراضياً) لاستخدامه في رابط واتساب.
String? waPhone(String raw, {String defaultCountry = '966'}) {
  var d = normalizeDigits(raw).replaceAll(RegExp(r'[^0-9+]'), '');
  if (d.isEmpty) return null;
  if (d.startsWith('+')) {
    d = d.substring(1);
  } else if (d.startsWith('00')) {
    d = d.substring(2);
  } else if (d.startsWith('0')) {
    d = defaultCountry + d.substring(1);
  } else if (d.length <= 9) {
    d = defaultCountry + d;
  }
  return d.length >= 8 && d.length <= 15 ? d : null;
}

/// نص تذكير عربي مهذب بالمبلغ المتبقي.
String reminderText({
  required String party,
  required String number,
  required double remaining,
  required String currency,
  required DateTime? dueDate,
  required DateTime now,
  String company = '',
}) {
  final late = dueDate != null && now.isAfter(dueDate)
      ? now.difference(dueDate).inDays
      : 0;
  final b = StringBuffer('السلام عليكم ${party.trim()}،\n');
  b.write('نذكّركم بخصوص الفاتورة رقم $number');
  if (dueDate != null) {
    final d = '${dueDate.year}/${dueDate.month.toString().padLeft(2, '0')}/${dueDate.day.toString().padLeft(2, '0')}';
    b.write(late > 0
        ? ' التي استحق سدادها بتاريخ $d (متأخرة $late يوماً)'
        : ' المستحقة بتاريخ $d');
  }
  b.write('، والمتبقي منها ${formatMoney(remaining)} $currency.\n');
  b.write('نرجو التكرم بالسداد في أقرب وقت، وإن كنتم سددتم فنعتذر عن الإزعاج وشاكرين لكم.');
  if (company.trim().isNotEmpty) b.write('\n${company.trim()}');
  return b.toString();
}

Uri waUri(String? phone, String text) => phone == null
    ? Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}')
    : Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(text)}');
