import 'package:flutter/material.dart';
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
          if (_busy) const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
          if (_msg.isNotEmpty)
            Padding(padding: const EdgeInsets.only(top: 8), child: Text(localizeDigits(_msg))),
        ]),
      ),
    );
  }
}
