import 'package:flutter/material.dart';
import '../services/backup_service.dart';
import '../services/cloud_backup.dart';
import '../services/settings_service.dart';
import '../services/sync_service.dart';
import '../utils/number_utils.dart';

/// بطاقة المزامنة السحابية (اختيارية؛ التطبيق يعمل دون إنترنت كما هو).
class SyncCard extends StatefulWidget {
  const SyncCard({super.key});
  @override
  State<SyncCard> createState() => _SyncCardState();
}

class _SyncCardState extends State<SyncCard> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;
  String _msg = '';

  Future<void> _run(Future<String> Function() f) async {
    setState(() {
      _busy = true;
      _msg = '';
    });
    try {
      _msg = await f();
    } on SyncException catch (e) {
      _msg = e.message;
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<String?> _askPass(String title, String hint) {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(title),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(hint, style: const TextStyle(fontSize: 12.5)),
          const SizedBox(height: 10),
          TextField(
              controller: c,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'عبارة مرور النسخة')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('إلغاء')),
          FilledButton(
              onPressed: () => Navigator.pop(d, c.text.length >= 6 ? c.text : null),
              child: const Text('متابعة')),
        ],
      ),
    );
  }

  Future<void> _upload() async {
    final p = await _askPass('رفع نسخة مشفرة',
        'تُشفَّر نسخة بياناتك على جهازك قبل الرفع، والخادم لا يرى إلا بيانات مشفرة. اكتب عبارة مرور (6 أحرف فأكثر). إذا نسيتها لا يمكن استرجاع النسخة.');
    if (p == null) return;
    await _run(() async {
      try {
        await CloudBackup.upload(p);
        return 'تم رفع نسخة مشفرة (وتُحفظ معها النسخة السابقة).';
      } on SyncException {
        rethrow;
      } catch (_) {
        throw SyncException('تعذر الرفع (تحقق من الاتصال)');
      }
    });
  }

  Future<void> _download() async {
    final p = await _askPass('استعادة النسخة المشفرة',
        'اكتب عبارة المرور التي استخدمتها عند الرفع. ستُستبدل بياناتك الحالية بمحتوى النسخة.');
    if (p == null || !mounted) return;
    await _run(() async {
      try {
        final text = await CloudBackup.download(p);
        if (text == null) return 'لا توجد نسخة سحابية بعد.';
        final sum = BackupService.summarize(BackupService.parse(text));
        await BackupService.restore(text);
        return 'تمت الاستعادة: ${sum.invoices} مستنداً و${sum.parties} عميلاً. أعد فتح القائمة الرئيسية.';
      } on WrongPassphrase catch (e) {
        throw SyncException(e.toString());
      } on SyncException {
        rethrow;
      } on FormatException catch (e) {
        throw SyncException(e.message);
      } catch (_) {
        throw SyncException('تعذرت الاستعادة (تحقق من الاتصال)');
      }
    });
  }

  Future<String> _signIn(bool create) async {
    await SyncService.instance.signIn(_email.text, _pass.text, create: create);
    _pass.clear();
    final r = await SyncService.instance.sync();
    return 'تم. $r';
  }

  @override
  Widget build(BuildContext context) {
    final s = SettingsService.instance;
    final on = SyncService.instance.enabled;
    final last = s.syncLast == 0
        ? ''
        : '\nآخر مزامنة: ${DateTime.fromMillisecondsSinceEpoch(s.syncLast).toString().substring(0, 16)}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.sync_outlined),
            const SizedBox(width: 8),
            const Text('المزامنة السحابية (اختيارية)',
                style: TextStyle(fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 6),
          Text(
              on
                  ? 'مفعّلة: ${s.syncEmail}$last'
                  : 'اربط جهازك بحساب لمزامنة العملاء والفواتير بين أجهزتك. بدونها يبقى كل شيء على هذا الجهاز فقط.',
              style: const TextStyle(fontSize: 12.5)),
          const SizedBox(height: 8),
          if (!on) ...[
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(labelText: 'البريد الإلكتروني'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _pass,
              obscureText: true,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(labelText: 'كلمة المرور (6 أحرف فأكثر)'),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                  child: FilledButton(
                      onPressed: _busy ? null : () => _run(() => _signIn(false)),
                      child: const Text('تسجيل الدخول'))),
              const SizedBox(width: 8),
              Expanded(
                  child: OutlinedButton(
                      onPressed: _busy ? null : () => _run(() => _signIn(true)),
                      child: const Text('حساب جديد'))),
            ]),
          ] else
            Row(children: [
              Expanded(
                  child: FilledButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _run(() async => 'تمت المزامنة. ${await SyncService.instance.sync()}'),
                      icon: const Icon(Icons.sync),
                      label: const Text('مزامنة الآن'))),
              const SizedBox(width: 8),
              OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () => _run(() async {
                            SyncService.instance.signOut();
                            return 'تم إيقاف المزامنة. بياناتك المحلية كما هي.';
                          }),
                  child: const Text('إيقاف')),
            ]),
          if (on) ...[
            const Divider(height: 24),
            const Text('نسخة سحابية مشفرة', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('مشفرة على جهازك بعبارة مرور تخصك، فلا يقرؤها أحد غيرك.',
                style: TextStyle(fontSize: 12.5)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                  child: FilledButton.tonalIcon(
                      onPressed: _busy ? null : _upload,
                      icon: const Icon(Icons.lock_outline),
                      label: const Text('رفع نسخة'))),
              const SizedBox(width: 8),
              Expanded(
                  child: OutlinedButton.icon(
                      onPressed: _busy ? null : _download,
                      icon: const Icon(Icons.cloud_download_outlined),
                      label: const Text('استعادة'))),
            ]),
          ],
          if (_busy) const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
          if (_msg.isNotEmpty)
            Padding(padding: const EdgeInsets.only(top: 8), child: Text(localizeDigits(_msg))),
        ]),
      ),
    );
  }
}
