import '../models/invoice.dart';
import 'auto_fill.dart' show normArabic;
import 'number_utils.dart';

enum NlIntent { invoices, itemSales, balance, addPayment, unknown }

/// سطر مبيعات لصنف (للإجابة على «كم بعت من ...»).
class SoldRow {
  final String description;
  final double pieces;
  final double total;
  final DateTime date;
  final String party;
  const SoldRow(this.description, this.pieces, this.total, this.date, this.party);
}

class NlQuery {
  final NlIntent intent;
  final String? party;
  final String? item;
  final String status; // any | unpaid | overdue | paid
  final DateTime? from; // شامل
  final DateTime? to; // غير شامل
  final String periodLabel;
  final double? amount;
  final bool quotes;
  const NlQuery(this.intent,
      {this.party,
      this.item,
      this.status = 'any',
      this.from,
      this.to,
      this.periodLabel = '',
      this.amount,
      this.quotes = false});
}

DateTime _d(DateTime x) => DateTime(x.year, x.month, x.day);

/// (من، إلى، وصف) للفترة المذكورة في الجملة، أو null. الأسبوع يبدأ السبت.
({DateTime from, DateTime to, String label})? parsePeriod(String n, DateTime now) {
  final today = _d(now);
  DateTime weekStart(DateTime d) => d.subtract(Duration(days: (d.weekday + 1) % 7));
  if (n.contains('اليوم')) return (from: today, to: today.add(const Duration(days: 1)), label: 'اليوم');
  if (n.contains('امس')) return (from: today.subtract(const Duration(days: 1)), to: today, label: 'أمس');
  if (n.contains('الاسبوع الماضي') || n.contains('الاسبوع الفايت')) {
    final s = weekStart(today).subtract(const Duration(days: 7));
    return (from: s, to: s.add(const Duration(days: 7)), label: 'الأسبوع الماضي');
  }
  if (n.contains('هذا الاسبوع') || n.contains('الاسبوع')) {
    final s = weekStart(today);
    return (from: s, to: s.add(const Duration(days: 7)), label: 'هذا الأسبوع');
  }
  if (n.contains('الشهر الماضي') || n.contains('الشهر الفايت')) {
    final s = DateTime(now.year, now.month - 1, 1);
    return (from: s, to: DateTime(now.year, now.month, 1), label: 'الشهر الماضي');
  }
  if (n.contains('هذا الشهر') || n.contains('الشهر')) {
    return (from: DateTime(now.year, now.month, 1), to: DateTime(now.year, now.month + 1, 1), label: 'هذا الشهر');
  }
  if (n.contains('السنه الماضيه') || n.contains('العام الماضي')) {
    return (from: DateTime(now.year - 1, 1, 1), to: DateTime(now.year, 1, 1), label: 'السنة الماضية');
  }
  if (n.contains('هذه السنه') || n.contains('هذا العام') || n.contains('السنه')) {
    return (from: DateTime(now.year, 1, 1), to: DateTime(now.year + 1, 1, 1), label: 'هذه السنة');
  }
  return null;
}

String _strip(String t) => t.length > 4 && t.startsWith('ال') ? t.substring(2) : t;

List<String> _tokens(String n) =>
    n.split(RegExp(r'[\s،,.؟?]+')).where((e) => e.isNotEmpty).map(_strip).toList();

/// كلمات الجملة مع صور بدون حرف اللام الجارّة («لاحمد» ← «احمد»).
Set<String> _queryTokens(String n) {
  final out = <String>{};
  for (final t in _tokens(n)) {
    out.add(t);
    if (t.length > 3 && t.startsWith('ل')) out.add(t.substring(1));
  }
  return out;
}

/// أفضل اسم معروف مذكور في الجملة: تطابق كامل للكلمات أولاً، ثم كلمة فريدة.
String? findNamed(String n, List<String> known, {int minLen = 3}) {
  final qt = _queryTokens(n);
  String? best;
  var bestScore = 0;
  for (final k in known) {
    final nk = normArabic(k);
    final kt = _tokens(nk);
    if (kt.isEmpty || nk.length < minLen) continue;
    if (kt.every(qt.contains)) {
      final score = kt.length * 100 + nk.length;
      if (score > bestScore) {
        best = k;
        bestScore = score;
      }
    }
  }
  if (best != null) return best;
  // كلمة واحدة من الجملة تطابق كلمة في اسم واحد فقط.
  String? uniq;
  var hits = 0;
  for (final t in qt) {
    if (t.length < 3 || _stop.contains(t) || _stop.contains('ال$t')) continue;
    for (final k in known) {
      if (_tokens(normArabic(k)).contains(t)) {
        if (uniq != k) hits++;
        uniq = k;
      }
    }
  }
  return hits == 1 ? uniq : null;
}

const _stop = {
  'فواتير', 'فاتوره', 'كم', 'بعت', 'علي', 'على', 'عليه', 'من', 'الى', 'في', 'هذا', 'هذه',
  'الشهر', 'الاسبوع', 'اليوم', 'امس', 'غير', 'مدفوعه', 'متاخره', 'مدفوعات', 'دفعه', 'اضف',
  'سجل', 'رصيد', 'لل', 'عروض', 'اسعار', 'مبيعات', 'السنه', 'العام', 'الماضي', 'الماضيه',
};

/// يفهم جملة عربية قصيرة. [parties] و[items] أسماء معروفة من بيانات المستخدم.
NlQuery parseNl(String raw, DateTime now,
    {List<String> parties = const [], List<String> items = const []}) {
  final n = normArabic(normalizeDigits(raw));
  final period = parsePeriod(n, now);
  final party = findNamed(n, parties);
  final numMatch = RegExp(r'(\d+(?:[.,]\d+)?)').firstMatch(n);
  final amount = numMatch == null ? null : parseNumber(numMatch.group(1));
  String status = 'any';
  if (RegExp(r'غير\s+(ال)?(مدفوع|مسدد)').hasMatch(n) || n.contains('مستحق')) {
    status = 'unpaid';
  } else if (n.contains('متاخر')) {
    status = 'overdue';
  } else if (n.contains('مدفوعه') || n.contains('مسدده') || n.contains('مسدد')) {
    status = 'paid';
  }
  NlQuery q(NlIntent i, {String? item, bool quotes = false, double? amt}) => NlQuery(i,
      party: party,
      item: item,
      status: status,
      from: period?.from,
      to: period?.to,
      periodLabel: period?.label ?? '',
      amount: amt,
      quotes: quotes);

  final isPay = n.contains('دفعه') &&
      (n.contains('اضف') || n.contains('سجل') || n.contains('استلمت') || n.contains('قبضت') || n.contains('دفع'));
  if (isPay && amount != null && amount > 0 && party != null) {
    return q(NlIntent.addPayment, amt: amount);
  }
  if (n.contains('بعت') || n.contains('مبيعات') || n.contains('بيع ')) {
    final item = findNamed(n, items);
    if (item != null) return q(NlIntent.itemSales, item: item);
  }
  if (party != null &&
      (n.contains('كم علي') || n.contains('كم على') || n.contains('رصيد') || n.contains('كم يطلب') ||
          n.contains('كم عليه') || n.contains('مستحقات') || n.contains('كم له'))) {
    return q(NlIntent.balance);
  }
  if (n.contains('فاتور') || n.contains('فواتير') || n.contains('عروض') || n.contains('عرض سعر')) {
    return q(NlIntent.invoices, quotes: n.contains('عروض') || n.contains('عرض سعر'));
  }
  return q(NlIntent.unknown);
}

class NlPaymentPart {
  final InvoiceSummary invoice;
  final double apply;
  const NlPaymentPart(this.invoice, this.apply);
}

class NlAnswer {
  final String headline;
  final List<String> lines;
  final List<InvoiceSummary> invoices;
  final List<NlPaymentPart> payment; // أمر يحتاج تأكيداً
  final double leftover;
  const NlAnswer(this.headline,
      {this.lines = const [], this.invoices = const [], this.payment = const [], this.leftover = 0});
}

bool _inRange(DateTime d, NlQuery q) =>
    (q.from == null || !d.isBefore(q.from!)) && (q.to == null || d.isBefore(q.to!));

String _per(NlQuery q) => q.periodLabel.isEmpty ? '' : ' ${q.periodLabel}';

NlAnswer answerNl(NlQuery q, List<InvoiceSummary> all, List<SoldRow> sold, DateTime now,
    {String currency = ''}) {
  String m(double v) => '${formatMoney(v)} $currency'.trim();
  final qp = q.party == null ? null : normArabic(q.party!);
  bool partyOk(String p) => qp == null || normArabic(p.trim()) == qp;
  switch (q.intent) {
    case NlIntent.unknown:
      return const NlAnswer('ما فهمت السؤال',
          lines: [
            'جرّب مثلاً: «فواتير أحمد غير المدفوعة هذا الشهر»',
            '«كم بعت من الأسمنت هذا الأسبوع؟»',
            '«كم على سالم؟»',
            '«أضف دفعة 500 لمحمد»',
          ]);
    case NlIntent.invoices:
      final kind = q.quotes ? DocKind.quote : DocKind.invoice;
      final list = all.where((s) {
        final i = s.invoice;
        if (i.kind != kind || i.isNote) return false;
        if (!partyOk(i.party) || !_inRange(i.date, q)) return false;
        final rem = paymentRemaining(s.grandTotal, i.paidAmount, i.status);
        switch (q.status) {
          case 'unpaid':
            return rem > 0.005 && i.status != InvoiceStatus.draft;
          case 'overdue':
            return isOverdueFor(i.kind, i.dueDate, rem, s.grandTotal, now);
          case 'paid':
            return rem <= 0.005 && s.grandTotal > 0;
        }
        return true;
      }).toList()
        ..sort((a, b) => b.invoice.date.compareTo(a.invoice.date));
      final total = list.fold(0.0, (s, e) => s + e.grandTotal);
      final rem = list.fold(0.0, (s, e) => s + paymentRemaining(e.grandTotal, e.invoice.paidAmount, e.invoice.status));
      final who = q.party == null ? '' : ' لـ${q.party}';
      final what = q.quotes ? 'عرض سعر' : 'فاتورة';
      if (list.isEmpty) return NlAnswer('لا توجد $what$who${_per(q)} بهذه الشروط');
      return NlAnswer('${localizeDigits('${list.length}')} $what$who${_per(q)}',
          lines: [
            'الإجمالي ${m(total)}',
            if (!q.quotes) 'المتبقي ${m(rem)}',
          ],
          invoices: list);
    case NlIntent.itemSales:
      final it = normArabic(q.item!);
      final rows = sold.where((r) => normArabic(r.description) == it && _inRange(r.date, q) && partyOk(r.party));
      final pieces = rows.fold(0.0, (s, r) => s + r.pieces);
      final total = rows.fold(0.0, (s, r) => s + r.total);
      if (rows.isEmpty) return NlAnswer('لا مبيعات لـ${q.item}${_per(q)}');
      return NlAnswer('بعت ${plainNumber(pieces)} من ${q.item}${_per(q)}',
          lines: ['بقيمة ${m(total)} في ${localizeDigits('${rows.length}')} أسطر']);
    case NlIntent.balance:
      final list = all.where((s) {
        final i = s.invoice;
        if (i.kind != DocKind.invoice || i.isNote || i.status == InvoiceStatus.draft) return false;
        return partyOk(i.party) &&
            paymentRemaining(s.grandTotal, i.paidAmount, i.status) > 0.005;
      }).toList()
        ..sort((a, b) => a.invoice.date.compareTo(b.invoice.date));
      final rem = list.fold(0.0, (s, e) => s + paymentRemaining(e.grandTotal, e.invoice.paidAmount, e.invoice.status));
      if (list.isEmpty) return NlAnswer('${q.party} ما عليه شيء');
      final overdue = list.where((s) => isOverdueFor(s.invoice.kind, s.invoice.dueDate,
          paymentRemaining(s.grandTotal, s.invoice.paidAmount, s.invoice.status), s.grandTotal, now)).length;
      return NlAnswer('على ${q.party}: ${m(rem)}',
          lines: [
            '${localizeDigits('${list.length}')} فواتير غير مسددة'
                '${overdue > 0 ? '، منها ${localizeDigits('$overdue')} متأخرة' : ''}',
          ],
          invoices: list);
    case NlIntent.addPayment:
      final list = all.where((s) {
        final i = s.invoice;
        if (i.kind != DocKind.invoice || i.isNote || i.status == InvoiceStatus.draft) return false;
        return partyOk(i.party) &&
            paymentRemaining(s.grandTotal, i.paidAmount, i.status) > 0.005;
      }).toList()
        ..sort((a, b) => a.invoice.date.compareTo(b.invoice.date));
      if (list.isEmpty) return NlAnswer('لا توجد فواتير غير مسددة لـ${q.party}');
      var left = q.amount!;
      final parts = <NlPaymentPart>[];
      for (final s in list) {
        if (left <= 0.005) break;
        final rem = paymentRemaining(s.grandTotal, s.invoice.paidAmount, s.invoice.status);
        final a = left < rem ? left : rem;
        parts.add(NlPaymentPart(s, a));
        left -= a;
      }
      return NlAnswer('دفعة ${m(q.amount!)} من ${q.party}',
          lines: [
            for (final p in parts) '${localizeDigits(p.invoice.invoice.number)}: ${m(p.apply)}',
            if (left > 0.005) 'يزيد ${m(left)} عن مجموع المتبقي ولن يُسجَّل.',
          ],
          payment: parts,
          leftover: left > 0.005 ? left : 0);
  }
}
