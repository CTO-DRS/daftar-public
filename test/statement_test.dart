import 'package:daftar/models/invoice.dart';
import 'package:daftar/models/invoice_item.dart';
import 'package:daftar/services/pdf_service.dart';
import 'package:daftar/utils/statement.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

InvoiceSummary mk(String party, double total, DateTime date,
    {DateTime? due, double paid = 0, InvoiceStatus st = InvoiceStatus.confirmed, String note = '', String no = '1', int id = 0}) {
  final inv = Invoice(
      id: id, number: no, date: date, party: party, dueDate: due, paidAmount: paid, status: st, noteType: note,
      items: [InvoiceItem(description: 'x', quantity: 1, unitPrice: total)]);
  return InvoiceSummary(inv, 1, 1, inv.grandTotal);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime(2026, 11, 26);
  final all = [
    mk('أ', 500, DateTime(2026, 10, 1), paid: 200, no: '2', id: 2, due: DateTime(2026, 10, 15)),
    mk('أ', 1000, DateTime(2026, 9, 1), st: InvoiceStatus.paid, no: '1', id: 1),
    mk('أ', 100, DateTime(2026, 10, 20), note: 'credit', no: '3', id: 3),
    mk('أ', 999, DateTime(2026, 10, 25), st: InvoiceStatus.draft, no: '4', id: 4),
    mk('ب', 700, DateTime(2026, 10, 2), no: '5', id: 5),
  ];
  test('running balance, order, credit notes, drafts', () {
    final s = buildStatement(all, 'أ', now);
    expect(s.rows.length, 3);
    expect(s.rows.first.label.contains('1'), true);
    expect(s.rows[0].balance, 0); // مدفوعة بالكامل
    expect(s.rows[1].balance, 300); // 500 - 200
    expect(s.rows[2].balance, 200); // بعد إشعار دائن 100
    expect(s.balance, 200);
    expect(s.rows[1].overdue, true);
    expect(buildStatement(all, 'ب', now).balance, 700);
    expect(buildStatement(all, 'غير موجود', now).rows, isEmpty);
  });
  test('statement PDF builds', () async {
    List<int> f(String n) => File('assets/fonts/$n.ttf').readAsBytesSync();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler('flutter/assets', (m) async {
      final key = const StringCodec().decodeMessage(m)!;
      final bytes = f(key.split('/').last.replaceAll('.ttf', ''));
      return ByteData.sublistView(Uint8List.fromList(bytes));
    });
    final bytes = await PdfService.buildStatementPdf(buildStatement(all, 'أ', now), now: now);
    expect(String.fromCharCodes(bytes.sublist(0, 4)), '%PDF');
    final out = Platform.environment['SHOT_DIR'];
    if (out != null) File('$out/statement.pdf').writeAsBytesSync(bytes);
  });
}
