import 'package:flutter/material.dart';

import '../database/app_database.dart';
import '../models/invoice.dart';
import '../services/settings_service.dart';
import '../services/voice_input.dart';
import '../utils/nl_query.dart';
import '../utils/number_utils.dart';
import 'invoice_editor_screen.dart';

/// «اسأل دفتر»: أسئلة وأوامر بالعربية كتابةً أو صوتاً، تُنفَّذ على البيانات المحلية فقط.
/// أي أمر يغيّر البيانات (تسجيل دفعة) يحتاج تأكيداً صريحاً.
class AskScreen extends StatefulWidget {
  const AskScreen({super.key});
  @override
  State<AskScreen> createState() => _AskScreenState();
}

class _AskScreenState extends State<AskScreen> {
  final _ctl = TextEditingController();
  final _voice = VoiceInput();
  List<InvoiceSummary> _all = [];
  List<SoldRow> _sold = [];
  List<String> _parties = [];
  List<String> _items = [];
  NlAnswer? _answer;
  bool _ready = false;
  bool _listening = false;
  String? _done;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final db = AppDatabase.instance;
    final all = await db.listInvoices();
    final sold = await db.soldRows();
    final parties = await db.partyNames();
    final items = {for (final r in sold) r.description}.toList();
    if (!mounted) return;
    setState(() {
      _all = all;
      _sold = sold;
      _parties = parties;
      _items = items;
      _ready = true;
    });
  }

  @override
  void dispose() {
    _voice.cancel();
    _ctl.dispose();
    super.dispose();
  }

  void _ask([String? text]) {
    if (text != null) _ctl.text = text;
    final q = parseNl(_ctl.text, DateTime.now(), parties: _parties, items: _items);
    setState(() {
      _done = null;
      _answer = answerNl(q, _all, _sold, DateTime.now(), currency: SettingsService.instance.currency);
    });
  }

  Future<void> _mic() async {
    if (_listening) {
      await _voice.stop();
      setState(() => _listening = false);
      return;
    }
    final ok = await _voice.init(onStatus: (s) {
      if ((s == 'done' || s == 'notListening') && mounted) setState(() => _listening = false);
    });
    if (!ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('الإملاء الصوتي غير متاح هنا. اكتب سؤالك.')));
      return;
    }
    setState(() => _listening = true);
    await _voice.start((t, fin) {
      if (!mounted) return;
      _ctl.text = t;
      if (fin) {
        setState(() => _listening = false);
        _ask();
      }
    });
  }

  Future<void> _confirmPayment(NlAnswer a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('تأكيد تسجيل الدفعة'),
        content: Text('${a.headline}\n\n${a.lines.join('\n')}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
          FilledButton(
              key: const ValueKey('confirm-payment'),
              onPressed: () => Navigator.pop(c, true),
              child: const Text('سجّل الدفعة')),
        ],
      ),
    );
    if (ok != true) return;
    for (final p in a.payment) {
      await AppDatabase.instance.addPaymentTo(p.invoice.invoice.id!, p.apply);
    }
    await _loadData();
    if (!mounted) return;
    setState(() {
      _answer = null;
      _done = 'سُجّلت الدفعة على ${localizeDigits('${a.payment.length}')} فاتورة.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final a = _answer;
    return Scaffold(
      appBar: AppBar(title: const Text('اسأل دفتر')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(
          key: const ValueKey('ask-field'),
          controller: _ctl,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _ask(),
          decoration: InputDecoration(
            hintText: 'مثال: فواتير أحمد غير المدفوعة هذا الشهر',
            prefixIcon: const Icon(Icons.auto_awesome),
            suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
              if (VoiceInput.supported)
                IconButton(
                    tooltip: 'صوت',
                    icon: Icon(_listening ? Icons.stop_circle : Icons.mic_none,
                        color: _listening ? Colors.red : null),
                    onPressed: _mic),
              IconButton(
                  key: const ValueKey('ask-go'),
                  tooltip: 'اسأل',
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _ready ? _ask : null),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        if (a == null && _done == null)
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final e in const [
              'فواتير هذا الشهر غير المدفوعة',
              'الفواتير المتأخرة',
              'كم بعت اليوم؟',
              'عروض الأسعار هذا الشهر',
            ])
              ActionChip(label: Text(e), onPressed: _ready ? () => _ask(e) : null),
          ]),
        if (_done != null)
          Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: ListTile(leading: const Icon(Icons.check_circle), title: Text(_done!))),
        if (a != null) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(a.headline,
                    key: const ValueKey('ask-headline'),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                for (final l in a.lines)
                  Padding(padding: const EdgeInsets.only(top: 4), child: Text(l)),
                if (a.payment.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  FilledButton.icon(
                      key: const ValueKey('ask-pay'),
                      onPressed: () => _confirmPayment(a),
                      icon: const Icon(Icons.payments_outlined),
                      label: const Text('راجع وسجّل الدفعة')),
                ],
              ]),
            ),
          ),
          for (final s in a.invoices.take(30))
            ListTile(
              title: Text('${localizeDigits(s.invoice.number)} • ${s.invoice.party}'),
              subtitle: Text(
                  '${formatMoney(s.grandTotal)} • المتبقي ${formatMoney(paymentRemaining(s.grandTotal, s.invoice.paidAmount, s.invoice.status))}'),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => InvoiceEditorScreen(invoiceId: s.invoice.id))),
            ),
        ],
        const SizedBox(height: 12),
        const Text('كل الإجابات من بياناتك على جهازك، بدون إنترنت. تسجيل الدفعة لا يتم إلا بعد تأكيدك.',
            style: TextStyle(fontSize: 12)),
      ]),
    );
  }
}
