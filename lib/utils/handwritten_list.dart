import '../models/invoice_item.dart';
import 'number_utils.dart';
import 'ocr_parsing.dart';

/// مسح قوائم المخزون/التعبئة المكتوبة بخط اليد: أعمدة النوع | الموديل | العدد.
/// الموديل هو كود الصنف. العدد يُكتب غالباً «كراتين×دزن» (1×61 = كرتون واحد و61 دزن).
const kHandwrittenPrompt = '''
أنت محرك قراءة قوائم مخزون مكتوبة بخط اليد (عربي). الصورة جدول بثلاثة أعمدة: النوع | الموديل | العدد، وقد تكون مدوّرة أو مائلة.
اقرأ كل صف بالترتيب، وأعد JSON فقط بدون أي شرح وبهذا الشكل:
{
  "party": "",
  "items": [
    {
      "item_type": "النوع كما كُتب (اسم الصنف)",
      "item_code": "الموديل كما كُتب (حروف وأرقام)",
      "qty_text": "العدد كما كُتب حرفياً مثل 1×61 أو 61",
      "unclear": true إذا لم تكن متأكداً من قراءة الصف
    }
  ]
}
قواعد: حوّل الأرقام العربية والهندية إلى لاتينية. لا تحوّل ولا تحسب الكميات، انقل qty_text كما هو.
الموديل رمز دقيق: انسخه حرفاً حرفاً ولا تصحح. لا تخمّن اسماً غير واضح: اكتب ما تراه وضع unclear = true.
''';

/// عدد مكتوب بصيغة كراتين×دزن.
class CartonQty {
  final double cartons;
  final double dozens;
  final bool plain; // رقم واحد بدون ×: يُفسَّر دزناً
  const CartonQty(this.cartons, this.dozens, {this.plain = false});

  /// القطع = كراتين × دزن × 12.
  double get pieces => cartons * dozens * 12;
}

/// يقرأ «1×61» أو «1x61» أو «١ * ٦١» أو «61». null إن لم يوجد رقم.
CartonQty? parseCartonDozen(String raw) {
  final t = normalizeDigits(raw).replaceAll(RegExp(r'[,،]'), '.');
  final m = RegExp(r'(\d+(?:\.\d+)?)\s*[x×X*✕✖]\s*(\d+(?:\.\d+)?)').firstMatch(t);
  if (m != null) {
    return CartonQty(double.parse(m.group(1)!), double.parse(m.group(2)!));
  }
  final one = RegExp(r'\d+(?:\.\d+)?').firstMatch(t);
  if (one == null) return null;
  return CartonQty(1, double.parse(one.group(0)!), plain: true);
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

/// يحوّل رد النموذج إلى أصناف: الكمية بالقطع (كراتين×دزن×12)، والاسم والسعر من الصنف المعروف إن وُجد
/// الموديل، وإلا يبقى الاسم المقروء ويُعلَّم الصف للمراجعة.
List<InvoiceItem> buildHandwrittenItems(List<Map<String, dynamic>> raw, Map<String, InvoiceItem> catalog) {
  final out = <InvoiceItem>[];
  for (final e in raw) {
    final code = normalizeDigits((e['item_code'] ?? '').toString()).trim();
    final type = (e['item_type'] ?? '').toString().trim();
    final qtyText = normalizeDigits((e['qty_text'] ?? '').toString()).trim();
    if (code.isEmpty && type.isEmpty && qtyText.isEmpty) continue;
    final q = parseCartonDozen(qtyText);
    final hit = matchModelCode(code, catalog.values);
    var flagged = e['unclear'] == true || q == null || code.isEmpty;
    final notes = <String>[];
    if (q != null) {
      notes.add(q.plain ? '$qtyText دزن = ${formatQty(q.pieces)} قطعة' : '$qtyText = ${formatQty(q.pieces)} قطعة');
    } else if (qtyText.isNotEmpty) {
      notes.add('العدد المكتوب: $qtyText');
    }
    var name = type;
    var price = 0.0;
    var itemCode = code;
    if (hit != null) {
      final known = hit.$1;
      itemCode = known.itemCode;
      if (known.description.trim().isNotEmpty) name = known.description;
      price = known.unitPrice;
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
      quantity: q?.pieces ?? 0,
      unitPrice: price,
      unit: 'قطعة',
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
