import 'package:flutter/material.dart';
import '../database/app_database.dart';
import '../models/invoice.dart';
import '../models/invoice_item.dart';
import '../utils/number_utils.dart';
import '../utils/quick_invoice.dart';
import '../services/voice_input.dart';
import '../services/settings_service.dart';
import 'invoice_editor_screen.dart';

/// فاتورة سريعة: اكتب أو املِ جملة واحدة وتتجهز الفاتورة تلقائياً.
/// الإملاء الصوتي عبر ميكروفون لوحة المفاتيح (يدعم العربية).
class QuickInvoiceScreen extends StatefulWidget {
  const QuickInvoiceScreen({super.key});
  @override
  State<QuickInvoiceScreen> createState() => _QuickInvoiceScreenState();
}

class _QuickInvoiceScreenState extends State<QuickInvoiceScreen> {
  final _text = TextEditingController();
  final _db = AppDatabase.instance;
  List<InvoiceItem> _catalog = [];
  List<String> _parties = [];
  QuickInvoice _q = QuickInvoice('', []);
  bool _busy = false;
  final _voice = VoiceInput();
  bool _listening = false;
  String _base = '';

  @override
  void dispose() {
    _voice.cancel();
    _text.dispose();
    super.dispose();
  }

  Future<void> _toggleMic() async {
    if (_listening) {
      await _voice.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    final ok = await _voice.init(
      onStatus: (st) {
        if ((st == 'done' || st == 'notListening') && mounted) {
          setState(() => _listening = false);
        }
      },
      onError: (e) {
        if (mounted) setState(() => _listening = false);
      },
    );
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تعذر تشغيل الإملاء: اسمح للميكروفون وتأكد من خدمة التعرف على الكلام في هاتفك')));
      return;
    }
    _base = _text.text.trim();
    setState(() => _listening = true);
    await _voice.start((words, _) {
      final t = _base.isEmpty ? words : '$_base، $words';
      _text.value = TextEditingValue(
          text: t, selection: TextSelection.collapsed(offset: t.length));
      _reparse(t);
    });
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cat = await _db.itemCatalog();
    final names = await _db.partyNames();
    if (!mounted) return;
    setState(() {
      _catalog = cat.values.toList();
      _parties = names;
    });
  }

  void _reparse(String v) => setState(() =>
      _q = parseQuickInvoice(v, catalog: _catalog, parties: _parties));

  Future<void> _create() async {
    setState(() => _busy = true);
    final number = await _db.nextNumber();
    final items = <InvoiceItem>[];
    if (_q.repeatLast && _q.party.isNotEmpty) {
      items.addAll(await _db.lastInvoiceItems(_q.party));
    }
    items.addAll(_q.items);
    final inv = Invoice(
        number: number,
        party: _q.party,
        items: items,
        vatRate: _q.vatRate ?? SettingsService.instance.defaultVatRate);
    final id = await _db.saveInvoice(inv);
    if (!mounted) return;
    await Navigator.pushReplacement(context,
        MaterialPageRoute(builder: (_) => InvoiceEditorScreen(invoiceId: id)));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('فاتورة سريعة')),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          TextField(
            controller: _text,
            autofocus: true,
            minLines: 3,
            maxLines: 6,
            onChanged: _reparse,
            decoration: InputDecoration(
              suffixIcon: VoiceInput.supported
                  ? IconButton(
                      key: const ValueKey('mic'),
                      tooltip: _listening ? 'إيقاف' : 'إملاء صوتي',
                      icon: Icon(_listening ? Icons.stop_circle : Icons.mic,
                          color: _listening ? Colors.red : null),
                      onPressed: _toggleMic,
                    )
                  : null,
              labelText: 'اكتب أو املِ الفاتورة',
              hintText: 'فاتورة لأحمد، 5 درزن كولا، 3 كرتون عصير بسعر 20',
              helperText: 'اضغط 🎙️ وتكلم بالعربية. تقدر تقول «نفس الفاتورة السابقة» أو «بدون ضريبة»',
            ),
          ),
          const SizedBox(height: 16),
          if (_q.items.isEmpty && !_q.repeatLast)
            Text('اكتب أصنافاً بالشكل: عدد + وحدة + اسم الصنف، وافصل بينها بفاصلة.',
                style: TextStyle(color: cs.onSurfaceVariant))
          else ...[
            Row(children: [
              Icon(Icons.person_outline, color: cs.primary),
              const SizedBox(width: 8),
              Text(_q.party.isEmpty ? 'بدون عميل' : _q.party,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 8),
            if (_q.repeatLast)
              Card(
                  child: ListTile(
                      leading: const Icon(Icons.replay),
                      title: Text(_q.party.isEmpty
                          ? 'نفس الفاتورة السابقة: اذكر اسم العميل'
                          : 'ستُنسخ أسطر آخر فاتورة لـ ${_q.party}'))),
            if (_q.vatRate != null)
              Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(_q.vatRate == 0
                      ? 'بدون ضريبة'
                      : 'ضريبة ${formatQty(_q.vatRate!)}%')),
            for (final it in _q.items)
              Card(
                child: ListTile(
                  title: Text(it.description),
                  subtitle: Text([
                    if (it.hasWholesale)
                      '${formatQty(it.wholesaleQty)} ${it.wholesaleUnit}'
                          '${it.packSize > 0 ? ' = ${formatQty(it.pieces)} قطعة' : ''}'
                    else
                      '${formatQty(it.quantity)} ${it.unit}',
                    if (it.total > 0) 'الإجمالي ${formatMoney(it.total)}'
                    else 'السعر غير محدد',
                  ].join(' • ')),
                ),
              ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: (_q.items.isEmpty && !(_q.repeatLast && _q.party.isNotEmpty)) || _busy
                  ? null
                  : _create,
              icon: const Icon(Icons.check),
              label: const Text('إنشاء الفاتورة'),
            ),
          ),
        ]),
      ),
    );
  }
}
