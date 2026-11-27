import 'dart:convert';
import '../database/app_database.dart';
import '../models/invoice.dart';
import 'settings_service.dart';
import 'sync_service.dart';

const shareViewerBase = 'https://cto-drs.github.io/daftar-public/i.html';

class ShareView {
  final int views;
  final DateTime? first, last;
  const ShareView(this.views, this.first, this.last);
}

/// نسخة الفاتورة العامة: ما يحتاجه العميل فقط (لا تكلفة ولا ربح ولا ملاحظات داخلية).
Map<String, Object?> shareSnapshot(Invoice inv, {String company = '', String currency = ''}) => {
      'label': inv.docLabel,
      'number': inv.number,
      'company': company,
      'party': inv.party,
      'date': inv.date.millisecondsSinceEpoch,
      'due': inv.dueDate?.millisecondsSinceEpoch,
      'currency': inv.currency.isEmpty ? currency : inv.currency,
      'vat': inv.vatRate,
      'vatAmount': inv.vatAmount,
      'subtotal': inv.subtotal,
      'total': inv.grandTotal,
      'paid': inv.status == InvoiceStatus.paid ? inv.grandTotal : inv.paidAmount,
      'remaining': inv.remaining,
      'notes': inv.notes,
      'items': [
        for (final i in inv.items) ...[
          if (i.quantity > 0 || i.wholesaleQty == 0)
            {'d': i.description, 'q': i.quantity, 'u': i.unit, 'p': i.unitPrice, 't': i.quantity * i.unitPrice},
          if (i.wholesaleQty > 0)
            {
              'd': '${i.description} (جملة)',
              'q': i.wholesaleQty,
              'u': i.wholesaleUnit,
              'p': i.wholesalePrice,
              't': i.wholesaleQty * i.wholesalePrice,
            },
        ]
      ],
    };

class ShareService {
  ShareService._();
  static final instance = ShareService._();

  final _sync = SyncService.instance;

  bool get available => _sync.enabled;

  /// ينشئ الرابط أو يحدّث نسخته إن وُجد، ويعيد الرابط الكامل.
  Future<String> link(Invoice inv) async {
    if (!available) throw SyncException('فعّل المزامنة السحابية من الإعدادات أولاً');
    await _sync.ensureUids();
    final d = await AppDatabase.instance.db;
    final r = await d.query('invoices', columns: ['uid'], where: 'id = ?', whereArgs: [inv.id]);
    final uid = r.isEmpty ? null : r.first['uid'] as String?;
    if (uid == null) throw SyncException('احفظ الفاتورة أولاً');
    final token = await _sync.accessToken();
    final snap = shareSnapshot(inv,
        company: SettingsService.instance.companyName,
        currency: SettingsService.instance.currency);
    final h = _sync.headers(token, 'daftar', true);
    final base = '${_sync.baseUrl}/rest/v1/shares';
    final found = await _sync.client.get(
        Uri.parse('$base?select=token&invoice_id=eq.$uid'),
        headers: _sync.headers(token, 'daftar'));
    if (found.statusCode >= 300) throw SyncException('تعذر إنشاء الرابط');
    final list = jsonDecode(utf8.decode(found.bodyBytes)) as List;
    String t;
    if (list.isNotEmpty) {
      t = list.first['token'] as String;
      final u = await _sync.client.patch(Uri.parse('$base?token=eq.$t'),
          headers: {...h, 'Prefer': 'return=minimal'}, body: jsonEncode({'snapshot': snap}));
      if (u.statusCode >= 300) throw SyncException('تعذر تحديث الرابط');
    } else {
      final c = await _sync.client.post(Uri.parse(base),
          headers: {...h, 'Prefer': 'return=representation'},
          body: jsonEncode({'invoice_id': uid, 'snapshot': snap}));
      if (c.statusCode >= 300) throw SyncException('تعذر إنشاء الرابط');
      t = (jsonDecode(utf8.decode(c.bodyBytes)) as List).first['token'] as String;
    }
    return '$shareViewerBase#$t';
  }

  /// معرّف الفاتورة المحلي ← uid (للربط مع حالة المشاهدة).
  Future<Map<int, String>> uidsById() async {
    final d = await AppDatabase.instance.db;
    final r = await d.query('invoices', columns: ['id', 'uid'], where: "uid IS NOT NULL AND uid != ''");
    return {for (final m in r) m['id'] as int: m['uid'] as String};
  }

  /// حالة المشاهدة لكل فاتورة مشاركة: رقم الفاتورة ← ShareView. فارغة إن تعذر.
  Future<Map<String, ShareView>> views() async {
    if (!available) return {};
    try {
      final token = await _sync.accessToken();
      final r = await _sync.client.get(
          Uri.parse('${_sync.baseUrl}/rest/v1/shares?select=invoice_id,views,first_viewed_at,last_viewed_at'),
          headers: _sync.headers(token, 'daftar'));
      if (r.statusCode >= 300) return {};
      final out = <String, ShareView>{};
      for (final m in (jsonDecode(utf8.decode(r.bodyBytes)) as List)) {
        DateTime? p(Object? v) => v == null ? null : DateTime.tryParse(v as String)?.toLocal();
        out[m['invoice_id'] as String] =
            ShareView((m['views'] as num).toInt(), p(m['first_viewed_at']), p(m['last_viewed_at']));
      }
      return out;
    } catch (_) {
      return {};
    }
  }
}
