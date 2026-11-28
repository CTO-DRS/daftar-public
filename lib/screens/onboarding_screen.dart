import 'package:flutter/material.dart';

import '../database/app_database.dart';
import '../services/settings_service.dart';

/// جولة تعريفية قصيرة (3 بطاقات) تظهر مرة واحدة لمن يفتح التطبيق وهو فارغ.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _Card {
  final IconData icon;
  final String title, body;
  const _Card(this.icon, this.title, this.body);
}

const onboardingCards = [
  _Card(Icons.bolt, 'فاتورة في ثوانٍ',
      'اكتب أو قل جملة مثل «فاتورة لأحمد، 5 درزن كولا» فتتحول فاتورة جاهزة. أو صوّر ورقة أو قائمة مكتوبة بخط اليد وسيقرأها دفتر.'),
  _Card(Icons.insights, 'يفهم نشاطك',
      'يتوقع نفاد المخزون، ويرتب من تتابع تحصيله، وينبّهك لسعر أو كمية غريبة، ويقدّر تدفقك النقدي للشهر القادم.'),
  _Card(Icons.lock_outline, 'بياناتك عندك',
      'كل شيء محفوظ على جهازك ويعمل بدون إنترنت. النسخ الاحتياطي والمزامنة اختياريان ومشفّران، وتشغّلهما من الإعدادات.'),
];

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _page = PageController();
  int _i = 0;

  void _done() {
    SettingsService.instance.onboarded = true;
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final last = _i == onboardingCards.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
                key: const ValueKey('skip'), onPressed: _done, child: const Text('تخطي')),
          ),
          Expanded(
            child: PageView(
              controller: _page,
              onPageChanged: (v) => setState(() => _i = v),
              children: [
                for (final c in onboardingCards)
                  SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const SizedBox(height: 24),
                      Container(
                        width: 112,
                        height: 112,
                        decoration: BoxDecoration(color: cs.primaryContainer, shape: BoxShape.circle),
                        child: Icon(c.icon, size: 56, color: cs.primary),
                      ),
                      const SizedBox(height: 28),
                      Text(c.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 12),
                      Text(c.body,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, height: 1.6, color: cs.onSurfaceVariant)),
                    ]),
                  ),
              ],
            ),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var k = 0; k < onboardingCards.length; k++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.all(4),
                width: k == _i ? 22 : 8,
                height: 8,
                decoration: BoxDecoration(
                    color: k == _i ? cs.primary : cs.outlineVariant, borderRadius: BorderRadius.circular(4)),
              ),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const ValueKey('next'),
                onPressed: last
                    ? _done
                    : () => _page.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut),
                child: Text(last ? 'ابدأ' : 'التالي'),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// يعرض الجولة مرة واحدة إن كان التطبيق فارغاً؛ من لديه فواتير لا تُعرض له أبداً.
class FirstRunGate extends StatefulWidget {
  final Widget child;
  const FirstRunGate({super.key, required this.child});
  @override
  State<FirstRunGate> createState() => _FirstRunGateState();
}

class _FirstRunGateState extends State<FirstRunGate> {
  @override
  void initState() {
    super.initState();
    if (!SettingsService.instance.onboarded) WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  Future<void> _check() async {
    var empty = false;
    try {
      empty = (await AppDatabase.instance.listInvoices()).isEmpty;
    } catch (_) {}
    if (!mounted) return;
    if (!empty) {
      SettingsService.instance.onboarded = true;
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OnboardingScreen()));
    SettingsService.instance.onboarded = true;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
