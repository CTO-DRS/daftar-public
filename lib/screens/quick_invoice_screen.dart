import 'package:flutter/material.dart';
import '../database/app_database.dart';
import '../models/invoice.dart';
import '../models/invoice_item.dart';
import '../utils/number_utils.dart';
import '../utils/quick_invoice.dart';
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
    final inv = Invoice(
        number: number, party: _q.party, items: _q.items);
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
            decoration: const InputDecoration(
              labelText: 'اكتب أو املِ الفاتورة',
              hintText: 'فاتورة لأحمد، 5 درزن كولا، 3 كرتون عصير بسعر 20',
              helperText: 'اضغط الميكروفون في لوحة المفاتيح للإملاء بالعربية',
            ),
          ),
          const SizedBox(height: 16),
          if (_q.items.isEmpty)
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
              onPressed: _q.items.isEmpty || _busy ? null : _create,
              icon: const Icon(Icons.check),
              label: const Text('إنشاء الفاتورة'),
            ),
          ),
        ]),
      ),
    );
  }
}
