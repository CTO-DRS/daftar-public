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
أمثلة صحيحة من قوائم صاحب المحل نفسه (للتعرف على أسلوب الكتابة والأسماء والموديلات الشائعة، لا تنسخها إن لم تكن في الصورة):
| بناجر بناتي أوميغا | 12 × 6 | W-2130 | 56 × 1 (كرتون/باكت) |
| بناجر بناتي أوميغا | 12 × 8 | W-2150 | 48 × 1 (كرتون/باكت) |
| بناجر نسائي أوميغا | 12 × 4 | W-291 | 44 × 1 (كرتون/باكت) |
| بناجر نسائي أوميغا | 12 × 2 | W-2150 | 48 × 1 (كرتون/باكت) |
| مثلج ذهبي + فضي | 48 × 1 | R-962 | 48 × 1 (كرتون/كيس) |
| مثلج ذهبي | 48 × 1 | X-648 | 42 × 1 (كرتون/كيس) |
| أبوجر صغير | 24 × 1 | C-77 | 93 × 1 (كرتون/كيس) |
| بناجر أبوجر كبير | 24 × 1 | C-64 | 50 × 1 (ك/كيس) |
| بناجر فضي كبير | 48 × 1 | W-1802 | 52 × 1 (ك/كيس) |
| بناجر صغير خفيف | 48 × 1 | W-1806 | 80 × 1 (ك/كيس) |
| بناجر نسائي أوميغا | 12 × 2 | 1074 | 30 × 1 (كرتون/باكت) |
| خواتم جوزر ذهبي + فضي | 12 × 1 | X-197 | 186 × 1 (كرتون/علبة) |
| بناجر عادي | 12 × 12 | W-641 | 50 × 1 |
| بناجر عادي | 12 × 12 | W-1521 | 52 × 1 (كرتون/درزن) |
| خواتم جوزر ذهبي | 24 × 1 | W-1949 | 120 × 1 (كرتون/علبة) |
| بناجر عادي | 12 × 12 | X-228 | 29 × 1 |
| بناجر عادي | 12 × 12 | T-1078 | 52 × 1 |
| خواتم ذهبي | 24 × 1 | A-299 | 294 × |
في الورقة الأصلية تُكتب وحدة العبوة بخط صغير فوق خانة العدد (باكتة، كيس، علبة، درزنة)، وتختلف من صف لآخر: اقرأها لكل صف على حدة وضعها بين قوسين في qty_text. رقما العدد هما عدد الكراتين (الصغير) × عدد الدزينات (الكبير)، وقد يُكتبان بأي ترتيب، فانقلهما كما تراهما.\nالوحدة بين قوسين مثل (كرتون/باكت) أو (ك/كيس) تكتب ضمن qty_text كما هي، وقد تغيب (مثل 50 × 1). الصف الذي ينقصه رقم يبقى كما كُتب (مثل 294 ×) مع unclear = true.
''';

/// عدد مكتوب بصيغة «56 × 1 (كرتون/باكت)»: العدد حاصل ضرب الأرقام، والوحدة من القوس.
class ListQty {
  final double dozens; // الرقم الأول: عدد الدزينات في الكرتون
  final double count; // الرقم الثاني: عدد الكراتين (1 إن لم يُكتب)
  final String unit;
  const ListQty(this.dozens, this.count, this.unit);
  double get piecesPerCarton => dozens * 12;
  double get pieces => piecesPerCarton * count;
}

List<double> _nums(String raw) {
  final t = normalizeDigits(raw).replaceAll(RegExp(r'[,،]'), '.');
  return [for (final m in RegExp(r'\d+(?:\.\d+)?').allMatches(t)) double.parse(m.group(0)!)];
}

/// «56 × 1» أو «1 × 56» ← 56 دزينة × 1 كرتون (672 قطعة). «294 ×» ← 294 دزينة × 1 كرتون. null إن لم يوجد رقم.
ListQty? parseListQty(String raw) {
  final inParen = RegExp(r'[\(（]([^\)）]*)[\)）]').firstMatch(raw);
  final body = inParen == null ? raw : raw.replaceFirst(inParen.group(0)!, ' ');
  final n = _nums(body);
  if (n.isEmpty) return null;
  var unit = (inParen?.group(1) ?? '').split(RegExp(r'[/،,]')).first.trim();
  if (unit == 'ك') unit = 'كرتون';
  // الرقم الصغير = الكراتين، الكبير = الدرزنات، مهما كان ترتيب الكتابة («56 × 1» أو «1 × 56»).
  if (n.length < 2) return ListQty(n.first, 1, unit);
  final hi = n.reduce((a, b) => a > b ? a : b), lo = n.reduce((a, b) => a < b ? a : b);
  return ListQty(hi, lo, unit);
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
      notes.add('${formatQty(q.dozens)} دزينة × ${formatQty(q.count)} كرتون = ${formatQty(q.pieces)} قطعة');
      if (pack > 0) notes.add('الباكت ${packText.isEmpty ? formatQty(pack) : packText}');
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
      quantity: 0,
      unit: q == null ? '' : 'كرتون',
      wholesaleQty: q?.count ?? 0,
      wholesaleUnit: q == null ? '' : 'كرتون',
      packSize: q?.piecesPerCarton ?? pack,
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
