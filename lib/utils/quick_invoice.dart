import '../models/invoice_item.dart';
import 'number_utils.dart';

/// نتيجة تحليل جملة مثل: «فاتورة لأحمد، 5 درزن كولا، 3 كرتون عصير بسعر 20».
class QuickInvoice {
  final String party;
  final List<InvoiceItem> items;

  /// «نفس الفاتورة السابقة»: انسخ أسطر آخر فاتورة لهذا العميل.
  final bool repeatLast;

  /// ضريبة ذكرها المتحدث («ضريبة 15» أو «بدون ضريبة» = 0)، أو null.
  final double? vatRate;
  QuickInvoice(this.party, this.items, {this.repeatLast = false, this.vatRate});
}

const _units = <String, String>{
  'حبة': 'حبة', 'حبه': 'حبة', 'حبات': 'حبة', 'قطعة': 'حبة', 'قطع': 'حبة',
  'كرتون': 'كرتون', 'كراتين': 'كرتون', 'كرتونة': 'كرتون',
  'درزن': 'درزن', 'دزينة': 'درزن', 'دزن': 'درزن', 'درزنة': 'درزن',
  'علبة': 'علبة', 'علب': 'علبة', 'كيس': 'كيس', 'اكياس': 'كيس', 'أكياس': 'كيس',
  'كجم': 'كجم', 'كيلو': 'كجم', 'كغ': 'كجم', 'لتر': 'لتر', 'متر': 'متر',
  'رزمة': 'رزمة', 'صندوق': 'صندوق', 'صناديق': 'صندوق', 'باكت': 'باكت',
  'حزمة': 'رزمة', 'زجاجة': 'زجاجة', 'قارورة': 'زجاجة',
};

const _words = <String, double>{
  'واحد': 1, 'واحدة': 1, 'اثنين': 2, 'اثنان': 2, 'ثنتين': 2, 'ثلاث': 3,
  'ثلاثة': 3, 'اربع': 4, 'أربع': 4, 'اربعة': 4, 'أربعة': 4, 'خمس': 5,
  'خمسة': 5, 'ست': 6, 'ستة': 6, 'سبع': 7, 'سبعة': 7, 'ثمان': 8, 'ثمانية': 8,
  'تسع': 9, 'تسعة': 9, 'عشر': 10, 'عشرة': 10, 'عشرين': 20, 'ثلاثين': 30,
  'اربعين': 40, 'أربعين': 40, 'خمسين': 50, 'ستين': 60, 'سبعين': 70,
  'ثمانين': 80, 'تسعين': 90, 'مية': 100, 'مائة': 100, 'ميه': 100,
  'نص': 0.5, 'نصف': 0.5,
};

String _norm(String s) => normalizeDigits(s)
    .replaceAll(RegExp('[\u064B-\u0652\u0640]'), '')
    .replaceAll('أ', 'ا')
    .replaceAll('إ', 'ا')
    .replaceAll('آ', 'ا')
    .replaceAll('ة', 'ه')
    .replaceAll('ى', 'ي')
    .toLowerCase();

double? _num(String w) {
  final d = parseNumber(w);
  if (d != null) return d;
  for (final e in _words.entries) {
    if (_norm(e.key) == _norm(w)) return e.value;
  }
  return null;
}

String? _unit(String w) {
  for (final e in _units.entries) {
    if (_norm(e.key) == _norm(w)) return e.value;
  }
  return null;
}

/// يحلل نصاً حراً (كتابة أو إملاء صوتي) إلى عميل وأسطر.
/// [catalog]: أصناف سابقة لإكمال السعر والوحدة تلقائياً بمطابقة الاسم.
QuickInvoice parseQuickInvoice(String text,
    {List<InvoiceItem> catalog = const [], List<String> parties = const []}) {
  var t = normalizeDigits(text.replaceAll('،', ',')).replaceAll('\n', ',').trim();
  t = t.replaceFirst(
      RegExp(r'^(?:من فضلك\s+)?(?:سوي|سوّي|اعمل|اكتب|سجل|أنشئ|انشئ)?\s*(?:لي\s+)?فاتورة\s*(?:جديدة\s*)?'),
      '');
  // «نفس الفاتورة السابقة» / «كرر آخر فاتورة».
  var repeatLast = false;
  final rep = RegExp(
      r'(?:(?:نفس|كرر|كرّر|اعد|أعد|مثل)\s+(?:آخر\s+|اخر\s+)?(?:ال)?فاتورة(?:\s+(?:ال)?(?:سابقة|اخيرة|أخيرة|الماضية|الاخيرة|الأخيرة))?|(?:ال)?فاتورة\s+(?:ال)?(?:سابقة|اخيرة|أخيرة|الماضية))');
  if (rep.hasMatch(t)) {
    repeatLast = true;
    t = t.replaceFirst(rep, ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    t = t.replaceFirst(RegExp(r'^[\s،,:-]+'), '');
  }
  // الضريبة المذكورة صوتياً.
  double? vat;
  final noVat = RegExp(r'(?:بدون|من غير|بلا)\s+ضريبة');
  final withVat = RegExp(
      r'(?:مع\s+)?ضريبة\s*(\d+(?:\.\d+)?)\s*(?:%|٪|بالمية|بالمائة)?');
  if (noVat.hasMatch(t)) {
    vat = 0;
    t = t.replaceFirst(noVat, ' ').trim();
  } else {
    final vm = withVat.firstMatch(t);
    if (vm != null) {
      vat = double.tryParse(vm.group(1)!);
      t = t.replaceFirst(withVat, ' ').trim();
    }
  }
  t = t.replaceAll(RegExp(r'\s+'), ' ').replaceFirst(RegExp(r'^[\s،,:-]+'), '').replaceFirst(RegExp(r'[\s،,:-]+$'), '');
  String party = '';
  final pm = RegExp(r'^(للعميل|للسيد|للمورد|الى|إلى|لـ|ل)\s*').firstMatch(t);
  if (pm != null && pm.end < t.length) {
    final body = t.substring(pm.end);
    final m = RegExp(r'[،,;]').firstMatch(body);
    final head = m == null ? body : body.substring(0, m.start);
    final toks = head.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    final name = <String>[];
    var k = 0;
    for (; k < toks.length; k++) {
      if (_num(toks[k]) != null || (toks[k] == 'و' && k > 0)) break;
      name.add(toks[k]);
    }
    party = name.join(' ');
    var rest = toks.sublist(k).join(' ');
    if (m != null) rest = '$rest${body.substring(m.start)}';
    t = rest.replaceFirst(RegExp(r'^[\s،,:-]+'), '');
  }
  // أكمل اسم العميل من الأسماء المعروفة (مطابقة تقريبية).
  if (party.isNotEmpty) {
    final np = _norm(party);
    for (final p in parties) {
      final n = _norm(p);
      if (n == np || n.startsWith(np) || np.startsWith(n)) {
        party = p;
        break;
      }
    }
  }
  // قسّم الأسطر على الفواصل أو على «و» تليها رقم.
  final chunks = t
      .split(RegExp(r'\s*[،,;]\s*|\s+و(?=\s*(?:\d|' +
          _words.keys.join('|') +
          r')(?=\s|$|[,،;]))\s*'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty);
  final items = <InvoiceItem>[];
  for (final c in chunks) {
    final it = _parseLine(c, catalog);
    if (it != null) items.add(it);
  }
  return QuickInvoice(party, items, repeatLast: repeatLast, vatRate: vat);
}

String _codeKey(String s) => normalizeDigits(s).toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

/// سطر منظَّم من قائمة مسح/جرد: «النوع – موديل W-2130 – عدد 56 كرتون/باكت – الباكت 12 × 6 حبات».
/// النوع ← الوصف، الموديل ← كود الصنف، العدد ← الكمية بوحدتها، حجم العبوة ← packSize.
/// الأسعار من آخر صنف بنفس الكود (أو الاسم) في الكتالوج.
InvoiceItem? _parseStructuredLine(String chunk, List<InvoiceItem> catalog) {
  final segs = chunk
      .split(RegExp(r'\s+[–—-]\s+|\s*[–—]\s*'))
      .map((e) => e.trim().replaceFirst(RegExp(r'[.。]+$'), '').trim())
      .where((e) => e.isNotEmpty)
      .toList();
  if (segs.length < 2) return null;
  final modelSeg = segs.indexWhere((e) => RegExp(r'^(?:ال)?موديل(?=\s|$)').hasMatch(e));
  final qtySeg = segs.indexWhere((e) => RegExp(r'^عدد(?=\s|$)').hasMatch(e));
  if (modelSeg < 0 && qtySeg < 0) return null;
  final name = segs.first;
  if (RegExp(r'^(?:ال)?موديل(?=\s|$)|^عدد(?=\s|$)').hasMatch(name)) return null;
  var code = '';
  if (modelSeg >= 0) {
    code = segs[modelSeg].replaceFirst(RegExp(r'^(?:ال)?موديل\s*'), '').trim();
  }
  var qty = 1.0, qtyFound = false;
  var unit = '';
  final notes = <String>[];
  if (qtySeg >= 0) {
    final body = segs[qtySeg].replaceFirst(RegExp(r'^عدد\s*'), '');
    final paren = RegExp(r'[\(（]([^\)）]*)[\)）]').firstMatch(body);
    if (paren != null) notes.add(paren.group(1)!.trim());
    final plain = paren == null ? body : body.replaceFirst(paren.group(0)!, ' ');
    final nums = RegExp(r'\d+(?:\.\d+)?').allMatches(normalizeDigits(plain)).toList();
    if (nums.isNotEmpty) {
      qty = nums.fold<double>(1, (a, m) => a * double.parse(m.group(0)!));
      qtyFound = true;
      final at = plain.indexOf(RegExp(r'[^\d\s×xX*.]'), nums.last.end);
      final after = at < 0 ? '' : plain.substring(at).trim();
      final firstWord = after.split(RegExp(r'[\s/،,]+')).firstWhere((e) => e.isNotEmpty, orElse: () => '');
      unit = _unit(firstWord) ?? '';
    }
  }
  var pack = 0.0;
  for (var k = 0; k < segs.length; k++) {
    if (k == 0 || k == modelSeg || k == qtySeg) continue;
    final m = RegExp(r'^ال\S+\s+(\d+(?:\.\d+)?)(?:\s*[×xX*]\s*(\d+(?:\.\d+)?))?').firstMatch(normalizeDigits(segs[k]));
    if (m != null) {
      pack = double.parse(m.group(1)!) * (m.group(2) == null ? 1 : double.parse(m.group(2)!));
    } else {
      notes.add(segs[k]);
    }
  }
  final item = InvoiceItem(description: name, itemCode: code, quantity: qty, unit: unit, packSize: pack);
  if (!qtyFound) item.flagged = true;
  InvoiceItem? hit;
  final ck = _codeKey(code);
  if (ck.isNotEmpty) {
    for (final c in catalog) {
      if (_codeKey(c.itemCode) == ck) {
        hit = c;
        break;
      }
    }
  }
  if (hit == null) {
    final nd = _norm(name);
    for (final c in catalog) {
      if (_norm(c.description) == nd && nd.isNotEmpty) {
        hit = c;
        break;
      }
    }
  }
  if (hit != null) {
    if (hit.itemCode.isNotEmpty) item.itemCode = hit.itemCode;
    if (item.unit.isEmpty) item.unit = hit.unit;
    if (item.packSize == 0) item.packSize = hit.packSize;
    item.unitPrice = hit.unitPrice;
    item.costPrice = hit.costPrice;
  }
  item.notes = notes.join(' • ');
  if ((item.unit == 'كرتون' || item.unit == 'درزن') && item.packSize > 0 && qtyFound) {
    item.wholesaleQty = qty;
    item.wholesaleUnit = item.unit;
    item.wholesalePrice = item.unitPrice * item.packSize;
    item.quantity = 0;
  }
  return item;
}

InvoiceItem? _parseLine(String chunk, List<InvoiceItem> catalog) {
  final structured = _parseStructuredLine(chunk, catalog);
  if (structured != null) return structured;
  var s = chunk;
  double? price;
  final pm = RegExp(r'(?:بسعر|سعره|سعرها|بـ|ب)\s*(\d+(?:\.\d+)?)\s*(?:ريال|ر\.س|رس|ر)?\s*$')
      .firstMatch(s);
  if (pm != null) {
    price = double.tryParse(pm.group(1)!);
    s = s.substring(0, pm.start).trim();
  }
  final toks = s.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  if (toks.isEmpty) return null;
  double? qty;
  var i = 0;
  // الرقم في البداية أو النهاية («كولا 5»).
  qty = _num(toks.first);
  if (qty != null) {
    i = 1;
  } else if (toks.length > 1) {
    final last = _num(toks.last);
    if (last != null) {
      qty = last;
      toks.removeLast();
    }
  }
  qty ??= 1;
  String unit = '';
  if (i < toks.length) {
    final u = _unit(toks[i]);
    if (u != null && toks.length - i > 1) {
      unit = u;
      i++;
    }
  }
  var rest = toks.sublist(i);
  if (rest.isNotEmpty && (rest.first == 'من' || rest.first == 'ال')) {
    rest = rest.sublist(1);
  }
  final desc = rest.join(' ').trim();
  if (desc.isEmpty) return null;
  final item = InvoiceItem(description: desc, quantity: qty, unit: unit);
  // مطابقة الكتالوج بالاسم.
  final nd = _norm(desc);
  InvoiceItem? hit;
  for (final c in catalog) {
    final nc = _norm(c.description);
    if (nc.isEmpty) continue;
    if (nc == nd) {
      hit = c;
      break;
    }
    if (hit == null && (nc.contains(nd) || nd.contains(nc))) hit = c;
  }
  if (hit != null) {
    item.description = hit.description;
    item.itemCode = hit.itemCode;
    if (item.unit.isEmpty) item.unit = hit.unit;
    item.unitPrice = hit.unitPrice;
    item.packSize = hit.packSize;
    item.costPrice = hit.costPrice;
  }
  if (price != null) item.unitPrice = price;
  // وحدة جملة معروفة (كرتون/درزن) مع حجم عبوة: انقل الكمية لخانة الجملة.
  if ((item.unit == 'كرتون' || item.unit == 'درزن') && item.packSize > 0) {
    item.wholesaleQty = qty;
    item.wholesaleUnit = item.unit;
    item.wholesalePrice = item.unitPrice * item.packSize;
    item.quantity = 0;
  }
  return item;
}
