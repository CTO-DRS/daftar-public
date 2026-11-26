import 'dart:convert';

import '../models/invoice_item.dart';
import 'number_utils.dart';

/// يستخرج كائن JSON من رد النموذج (يتجاوز أسوار ```json وأي نص زائد).
Map<String, dynamic> extractJsonObject(String raw) {
  var s = raw.trim();
  final fence = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(s);
  if (fence != null) s = fence.group(1)!.trim();
  final start = s.indexOf('{');
  final end = s.lastIndexOf('}');
  if (start < 0 || end <= start) {
    throw const FormatException('لا يوجد JSON في الرد');
  }
  final decoded = jsonDecode(s.substring(start, end + 1));
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('صيغة JSON غير متوقعة');
  }
  return decoded;
}

String _str(dynamic v) {
  if (v == null) return '';
  return normalizeDigitsKeepText(v.toString()).trim();
}

/// نص قد يحتوي أرقاماً هندية: نحولها للاتينية ونبقي بقية النص.
String normalizeDigitsKeepText(String s) => normalizeDigits(s);

double? _num(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return parseNumber(v.toString());
}

/// يحول عنصر JSON إلى سطر صنف مع تمييز الأسطر المشكوك فيها.
InvoiceItem itemFromJson(Map<String, dynamic> j) {
  final q = _num(j['quantity']);
  final p = _num(j['unit_price']);
  final item = InvoiceItem(
    itemCode: _str(j['item_code']),
    refNumber: _str(j['ref_number']),
    description: _str(j['item_type']),
    quantity: q ?? 0,
    unitPrice: p ?? 0,
    notes: _str(j['notes']),
    statedTotal: _num(j['line_total']),
  );
  // قيمة غير مقروءة (null) أو نص غير رقمي = مشكوك فيها
  if (q == null || p == null || j['unclear'] == true) item.flagged = true;
  return item;
}

/// تدقيق عام: صف بعدد/سعر غير منطقي أو إجمالي لا يطابق العدد × الفردي.
bool rowLooksWrong(InvoiceItem it) {
  if (it.quantity <= 0 || it.unitPrice <= 0) return true;
  if (it.itemCode.isEmpty && it.refNumber.isEmpty && it.description.isEmpty) {
    return true;
  }
  final st = it.statedTotal;
  if (st != null && (st - it.total).abs() > 0.011 + st.abs() * 0.001) {
    return true;
  }
  return false;
}

void verifyItems(List<InvoiceItem> items) {
  for (final it in items) {
    if (rowLooksWrong(it)) it.flagged = true;
  }
}

/// تحليل نصوص المسح المحلي: كل سطر نص = صف محتمل.
/// القاعدة: آخر ثلاثة أرقام (عدد، فردي، إجمالي) إن تحقق عدد×فردي=إجمالي، وإلا آخر رقمين.
List<InvoiceItem> parseOfflineLines(List<String> lines) {
  final out = <InvoiceItem>[];
  final numRe = RegExp(r'\d+(?:[.,]\d+)?');
  for (final raw in lines) {
    final line = normalizeDigits(raw).trim();
    if (line.isEmpty) continue;
    final matches = numRe.allMatches(line).toList();
    if (matches.length < 2) continue;
    final nums = matches.map((m) => parseNumber(m.group(0)!) ?? 0).toList();

    double qty, price;
    double? stated;
    int firstNumIdx; // موضع أول رقم ضمن القيم التي استهلكناها
    var exact = false;
    if (nums.length >= 3) {
      final a = nums[nums.length - 3], b = nums[nums.length - 2];
      final c = nums[nums.length - 1];
      if ((a * b - c).abs() < 0.011 + c * 0.001) {
        qty = a;
        price = b;
        stated = c;
        firstNumIdx = matches.length - 3;
        exact = true;
      } else {
        qty = b;
        price = c;
        firstNumIdx = matches.length - 2;
      }
    } else {
      qty = nums[0];
      price = nums[1];
      firstNumIdx = 0;
    }

    final head = line.substring(0, matches[firstNumIdx].start).trim();
    final tokens = head.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    String code = '', ref = '';
    final descParts = <String>[];
    for (final t in tokens) {
      final isCodey = RegExp(r'^[A-Za-z]*\d+[A-Za-z0-9\-/]*$').hasMatch(t);
      if (isCodey && code.isEmpty) {
        code = t;
      } else if (isCodey && ref.isEmpty) {
        ref = t;
      } else {
        descParts.add(t);
      }
    }
    final item = InvoiceItem(
      itemCode: code,
      refNumber: ref,
      description: descParts.join(' '),
      quantity: qty,
      unitPrice: price,
      statedTotal: stated,
    );
    // المسح المحلي أقل دقة: أي صف لم يتطابق حسابياً يُميّز للمراجعة.
    if (!exact) item.flagged = true;
    out.add(item);
  }
  return out;
}
