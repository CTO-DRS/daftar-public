import '../models/invoice_item.dart';
import 'number_utils.dart';
import 'ocr_parsing.dart';

/// مسح قوائم المخزون المكتوبة بخط اليد (الصيغة الفعلية لقوائم المستخدم):
/// النوع | الحبة/العدد في الباكت (مثل 12 × 6) | الموديل (مثل W-2130) | العدد (مثل 56 × 1 (كرتون/باكت)).
const kHandwrittenPrompt = '''
أنت محرك قراءة قوائم مخزون مكتوبة بخط اليد (عربي). الصورة جدول بأربعة أعمدة بهذا الترتيب: النوع | الحبة/العدد في الباكت | الموديل | العدد، وقد تكون مدوّرة أو مائلة.
اقرأ كل صف بالترتيب، وأعد JSON فقط بدون أي شرح وبهذا الشكل:
{
  "party": "",
  "items": [
    {
      "item_type": "النوع كما كُتب (اسم الصنف)",
      "pack_text": "عمود الحبة/العدد في الباكت حرفياً مثل 12×6",
      "item_code": "الموديل كما كُتب مثل W-2130 أو C-64 أو A-299",
      "qty_text": "عمود العدد حرفياً مع الوحدة مثل 56×1 (كرتون/باكت)",
      "unclear": true إذا لم تكن متأكداً من قراءة الصف
    }
  ]
}
قواعد: حوّل الأرقام العربية والهندية إلى لاتينية. لا تحوّل ولا تحسب الكميات، انقل النصوص كما هي.
الموديل رمز دقيق (حرف ثم شرطة ثم أرقام غالباً): انسخه حرفاً حرفاً ولا تصحح. لا تخمّن اسماً أو رقماً غير واضح: اكتب ما تراه وضع unclear = true.
''';

/// عدد مكتوب بصيغة «56 × 1 (كرتون/باكت)»: العدد حاصل ضرب الأرقام، والوحدة من القوس.
class ListQty {
  final double count;
  final String unit;
  const ListQty(this.count, this.unit);
}

List<double> _nums(String raw) {
  final t = normalizeDigits(raw).replaceAll(RegExp(r'[,،]'), '.');
  return [for (final m in RegExp(r'\d+(?:\.\d+)?').allMatches(t)) double.parse(m.group(0)!)];
}

/// «56 × 1 (كرتون/باكت)» ← 56 كرتون. «294 ×» ← 294. null إن لم يوجد رقم.
ListQty? parseListQty(String raw) {
  final inParen = RegExp(r'[\(（]([^\)）]*)[\)）]').firstMatch(raw);
  final body = inParen == null ? raw : raw.replaceFirst(inParen.group(0)!, ' ');
  final n = _nums(body);
  if (n.isEmpty) return null;
  final unit = (inParen?.group(1) ?? '').split(RegExp(r'[/،,]')).first.trim();
  return ListQty(n.fold<double>(1, (a, b) => a * b), unit);
}

/// «12 × 6» ← 72 قطعة في الوحدة (الحبة × العدد في الباكت). 0 إن لم يُقرأ.
double parsePackPieces(String raw) {
  final n = _nums(raw);
  return n.isEmpty ? 0 : n.fold<double>(1, (a, b) => a * b);
}

int _lev(String a, String b) {
  var prev = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final cur = List<int>.filled(b.length + 1, 0)..[0] = i;
    for (var j = 1; j <= b.length; j++) {
      cur[j] = [prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1)]
          .reduce((x, y) => x < y ? x : y);
    }
    prev = cur;
  }
  return prev[b.length];
}

String _code(String s) => normalizeDigits(s).toUpperCase().replaceAll(RegExp(r'[^A-Z0-9\u0600-\u06FF]'), '');

/// يطابق كود الموديل المقروء مع الأصناف المعروفة: مطابق تماماً، أو يختلف بحرف واحد وحيد.
/// يعيد (الصنف المعروف، هل التطابق تقريبي) أو null.
(InvoiceItem, bool)? matchModelCode(String read, Iterable<InvoiceItem> catalog) {
  final c = _code(read);
  if (c.isEmpty) return null;
  InvoiceItem? near;
  var nearCount = 0;
  for (final k in catalog) {
    final kc = _code(k.itemCode);
    if (kc == c) return (k, false);
    if (c.length >= 3 && kc.length >= 3 && _lev(kc, c) == 1) {
      near = k;
      nearCount++;
    }
  }
  return nearCount == 1 ? (near!, true) : null;
}

/// يحوّل رد النموذج إلى أصناف: الكمية كما كُتبت (بوحدتها)، وحجم الوحدة بالقطع، والاسم من الصنف المعروف
/// إن طابق الموديل، وإلا يبقى الاسم المقروء ويُعلَّم الصف للمراجعة. لا أسعار: قوائم المخزون بلا أسعار.
List<InvoiceItem> buildHandwrittenItems(List<Map<String, dynamic>> raw, Map<String, InvoiceItem> catalog) {
  final out = <InvoiceItem>[];
  for (final e in raw) {
    final code = normalizeDigits((e['item_code'] ?? '').toString()).trim();
    final type = (e['item_type'] ?? '').toString().trim();
    final qtyText = normalizeDigits((e['qty_text'] ?? '').toString()).trim();
    final packText = normalizeDigits((e['pack_text'] ?? '').toString()).trim();
    if (code.isEmpty && type.isEmpty && qtyText.isEmpty) continue;
    final q = parseListQty(qtyText);
    final pack = parsePackPieces(packText);
    final hit = matchModelCode(code, catalog.values);
    var flagged = e['unclear'] == true || q == null || code.isEmpty;
    final notes = <String>[];
    if (q != null) {
      final unit = q.unit.isEmpty ? 'وحدة' : q.unit;
      notes.add(pack > 0
          ? '${formatQty(q.count)} $unit × ${formatQty(pack)} = ${formatQty(q.count * pack)} قطعة'
          : qtyText);
    } else if (qtyText.isNotEmpty) {
      notes.add('العدد المكتوب: $qtyText');
    }
    var name = type;
    var itemCode = code;
    if (hit != null) {
      final known = hit.$1;
      itemCode = known.itemCode;
      if (known.description.trim().isNotEmpty) name = known.description;
      if (hit.$2) {
        flagged = true;
        notes.add('الموديل المقروء «$code» قريب من «${known.itemCode}»، تأكد منه');
      }
    } else if (code.isNotEmpty) {
      flagged = true;
      notes.add('موديل غير معروف في أصنافك');
    }
    out.add(InvoiceItem(
      itemCode: itemCode,
      description: name,
      quantity: q?.count ?? 0,
      unit: q == null || q.unit.isEmpty ? '' : q.unit,
      packSize: pack,
      notes: notes.join(' • '),
    )..flagged = flagged);
  }
  return out;
}

List<Map<String, dynamic>> handwrittenRows(String modelText) {
  final j = extractJsonObject(modelText);
  return [
    for (final e in (j['items'] as List? ?? const []))
      if (e is Map) Map<String, dynamic>.from(e),
  ];
}
