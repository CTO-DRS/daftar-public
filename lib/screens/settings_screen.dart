import 'dart:io';

import 'package:flutter/material.dart';

import '../services/logo_service.dart';
import '../services/settings_service.dart';
import '../utils/number_utils.dart';
import '../widgets/responsive.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final s = SettingsService.instance;
  late final _key = TextEditingController(text: s.apiKey);
  late final _company = TextEditingController(text: s.companyName);
  late final _currency = TextEditingController(text: s.currency);
  late final _gModel = TextEditingController(text: s.geminiModel);
  late final _oModel = TextEditingController(text: s.openrouterModel);
  late final _prefix = TextEditingController(text: s.numberPrefix);
  late final _start = TextEditingController(text: '${s.numberStart}');
  late final _pad = TextEditingController(text: '${s.numberPadding}');
  late OcrProvider _provider = s.provider;
  bool _hide = true;
  bool _arabicDigits = SettingsService.instance.arabicDigits;

  void _save() {
    s.apiKey = _key.text;
    s.companyName = _company.text;
    s.currency = _currency.text.trim().isEmpty ? 'ر.س' : _currency.text;
    s.geminiModel = _gModel.text.isEmpty ? 'gemini-2.5-flash' : _gModel.text;
    s.openrouterModel =
        _oModel.text.isEmpty ? 'google/gemini-2.5-flash' : _oModel.text;
    s.numberPrefix = _prefix.text;
    s.numberStart = parseNumber(_start.text)?.toInt() ?? 1;
    s.numberPadding = parseNumber(_pad.text)?.toInt() ?? 1;
    s.provider = _provider;
    s.arabicDigits = _arabicDigits;
    useArabicDigits = _arabicDigits;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('تم حفظ الإعدادات')));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ContentWidth(maxWidth: 640, child: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('عام', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        TextField(
            controller: _company,
            decoration: const InputDecoration(
                labelText: 'اسم المنشأة (يظهر في ترويسة PDF)')),
        const SizedBox(height: 12),
        Row(children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(8)),
            child: s.logoPath.isEmpty
                ? const Icon(Icons.image_outlined)
                : Image.file(File(s.logoPath), fit: BoxFit.contain,
                    errorBuilder: (c, e, st) => const Icon(Icons.broken_image)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(s.logoPath.isEmpty ? 'إضافة شعار للـ PDF' : 'تغيير الشعار'),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                try {
                  if (await LogoService.pickAndSave()) setState(() {});
                } catch (e) {
                  messenger.showSnackBar(
                      SnackBar(content: Text('تعذر استخدام الصورة: $e')));
                }
              },
            ),
          ),
          if (s.logoPath.isNotEmpty)
            IconButton(
              tooltip: 'حذف الشعار',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                await LogoService.remove();
                setState(() {});
              },
            ),
        ]),
        const SizedBox(height: 12),
        TextField(
            controller: _currency,
            decoration: const InputDecoration(labelText: 'رمز العملة')),
        const SizedBox(height: 24),
        const Text('ترقيم الفواتير', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
              child: TextField(
                  controller: _prefix,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(labelText: 'البادئة (مثل INV-)'))),
          const SizedBox(width: 8),
          Expanded(
              child: TextField(
                  controller: _start,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'أول رقم'))),
          const SizedBox(width: 8),
          Expanded(
              child: TextField(
                  controller: _pad,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'عدد الخانات'))),
        ]),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('عرض الأرقام بالهندية (١٢٣)'),
          subtitle: const Text('يؤثر على الشاشات وملف PDF'),
          value: _arabicDigits,
          onChanged: (v) => setState(() => _arabicDigits = v),
        ),
        const SizedBox(height: 24),
        const Text('مسح الفواتير بالذكاء الاصطناعي',
            style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        SegmentedButton<OcrProvider>(
          segments: const [
            ButtonSegment(value: OcrProvider.gemini, label: Text('Gemini')),
            ButtonSegment(
                value: OcrProvider.openrouter, label: Text('OpenRouter')),
          ],
          selected: {_provider},
          onSelectionChanged: (v) => setState(() => _provider = v.first),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _key,
          obscureText: _hide,
          autocorrect: false,
          enableSuggestions: false,
          textDirection: TextDirection.ltr,
          decoration: InputDecoration(
            labelText: 'مفتاح API',
            suffixIcon: IconButton(
              icon: Icon(_hide ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _hide = !_hide),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
            controller: _provider == OcrProvider.gemini ? _gModel : _oModel,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(labelText: 'اسم النموذج')),
        const SizedBox(height: 8),
        Text(
          'المفتاح يُحفظ على جهازك فقط ويُرسل إلى المزود المختار عند المسح. بدون مفتاح أو بدون إنترنت يُستخدم المسح المحلي للنصوص المطبوعة.',
          style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
        ),
        const SizedBox(height: 24),
        SizedBox(
            height: 52,
            child: FilledButton(onPressed: _save, child: const Text('حفظ'))),
      ])),
    );
  }
}
