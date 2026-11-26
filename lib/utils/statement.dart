import '../models/invoice.dart';

class StatementRow {
  final DateTime date;
  final String label; // «فاتورة 1041»
  final double amount; // موجب = مدين على العميل، سالب = دائن (إشعار دائن)
  final double paid; // ما سُدِّد من هذا المستند
  final double balance; // الرصيد التراكمي بعد هذا السطر
  final DateTime? due;
  final bool overdue;
  const StatementRow(this.date, this.label, this.amount, this.paid, this.balance,
      this.due, this.overdue);
}

class Statement {
  final String party;
  final List<StatementRow> rows;
  final double totalAmount, totalPaid, balance;
  const Statement(this.party, this.rows, this.totalAmount, this.totalPaid, this.balance);
}

/// كشف حساب لطرف: كل مستنداته المعتمدة (بدون المسودات) مرتبة بالتاريخ مع رصيد تراكمي.
/// الإشعار الدائن يُنقص الرصيد والمدين يزيده. المستندات بعملة مختلفة تُستثنى.
Statement buildStatement(List<InvoiceSummary> all, String party, DateTime now,
    {String currency = '', DateTime? from, DateTime? to}) {
  final key = party.trim();
  final docs = all.where((s) {
    final i = s.invoice;
    if (i.kind != DocKind.invoice || i.status == InvoiceStatus.draft) return false;
    if (i.party.trim() != key) return false;
    final c = i.currency.trim();
    if (c.isNotEmpty && currency.isNotEmpty && c != currency) return false;
    if (from != null && i.date.isBefore(from)) return false;
    if (to != null && i.date.isAfter(to)) return false;
    return true;
  }).toList()
    ..sort((a, b) {
      final c = a.invoice.date.compareTo(b.invoice.date);
      return c != 0 ? c : (a.invoice.id ?? 0).compareTo(b.invoice.id ?? 0);
    });
  var bal = 0.0, ta = 0.0, tp = 0.0;
  final rows = <StatementRow>[];
  for (final s in docs) {
    final i = s.invoice;
    final credit = i.noteType == 'credit';
    final amount = credit ? -s.grandTotal : s.grandTotal;
    final paid = i.isNote ? 0.0 : s.grandTotal - paymentRemaining(s.grandTotal, i.paidAmount, i.status);
    bal += amount - paid;
    ta += amount;
    tp += paid;
    final rem = i.isNote ? 0.0 : paymentRemaining(s.grandTotal, i.paidAmount, i.status);
    rows.add(StatementRow(i.date, '${i.docLabel} ${i.number}', amount, paid, bal, i.dueDate,
        isOverdueFor(i.kind, i.dueDate, rem, s.grandTotal, now)));
  }
  return Statement(key, rows, ta, tp, bal);
}
