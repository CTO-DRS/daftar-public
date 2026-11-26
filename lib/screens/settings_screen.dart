import 'dart:io';

import 'package:flutter/material.dart';
import '../services/pdf_service.dart' show PdfTemplate, PdfTemplateX;
import '../utils/brand_color.dart';
import 'about_screen.dart';
import '../main.dart' show themeModeNotifier, themeModeFrom;

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
  late final _vatNo = TextEditingController(text: s.sellerVat);
  bool _vatOn = SettingsService.instance.defaultVatRate > 0;
  late final _prefixInv = TextEditingController(text: s.inventoryPrefix);
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
    s.inventoryPrefix = _prefixInv.text;
    s.sellerVat = normalizeDigits(_vatNo.text);
    s.defaultVatRate = _vatOn ? 15 : 0;
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
        const Text('ضريبة القيمة المضافة (على طريقة المرحلة الأولى)',
            style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('تطبيق ضريبة 15% على الفواتير الجديدة'),
          subtitle: const Text('يمكن تعديل النسبة لكل فاتورة'),
          value: _vatOn,
          onChanged: (v) => setState(() => _vatOn = v),
        ),
        TextField(
            controller: _vatNo,
            keyboardType: TextInputType.number,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(
                labelText: 'الرقم الضريبي للمنشأة (15 رقماً)')),
        const SizedBox(height: 6),
        Text(
          'عند تعبئة الرقم الضريبي وتفعيل الضريبة يظهر رمز QR بصيغة المرحلة الأولى في ملف PDF. هذا تنسيق فقط وليس اعتماداً من هيئة الزكاة والضريبة والجمارك.',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
        ),
        const SizedBox(height: 24),
        const Text('قالب الفاتورة (PDF)', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: [
            for (final t in PdfTemplate.values)
              ButtonSegment(value: t.name, label: Text(t.label)),
          ],
          selected: {SettingsService.instance.pdfTemplate},
          onSelectionChanged: (v) {
            SettingsService.instance.pdfTemplate = v.first;
            setState(() {});
          },
        ),
        const SizedBox(height: 6),
        Text(PdfTemplateX.fromDb(SettingsService.instance.pdfTemplate).hint,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
        const SizedBox(height: 14),
        const Text('لون الترويسة', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
          ChoiceChip(
            avatar: const Icon(Icons.auto_awesome, size: 16),
            label: const Text('تلقائي من الشعار'),
            selected: SettingsService.instance.brandColor == null,
            onSelected: (_) {
              SettingsService.instance.brandColor = null;
              setState(() {});
            },
          ),
          for (final c in brandSwatches)
            InkWell(
              customBorder: const CircleBorder(),
              onTap: () {
                SettingsService.instance.brandColor = c;
                setState(() {});
              },
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Color(c),
                  shape: BoxShape.circle,
                  border: Border.all(
                      width: SettingsService.instance.brandColor == c ? 3 : 1,
                      color: SettingsService.instance.brandColor == c
                          ? Theme.of(context).colorScheme.onSurface
                          : Colors.black12),
                ),
                child: SettingsService.instance.brandColor == c
                    ? const Icon(Icons.check, size: 18, color: Colors.white)
                    : null,
              ),
            ),
        ]),
        const SizedBox(height: 24),
        const SizedBox(height: 4),
        Card(
          child: ListTile(
            leading: const CircleAvatar(
                backgroundImage: AssetImage('assets/images/developer.jpg')),
            title: const Text('عن المطور'),
            subtitle: const Text('CTO.DRS · cto-drs.com', textDirection: TextDirection.ltr),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AboutScreen())),
          ),
        ),
        const SizedBox(height: 20),
        const Text('المظهر', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'system', label: Text('تلقائي')),
            ButtonSegment(value: 'light', label: Text('فاتح')),
            ButtonSegment(value: 'dark', label: Text('داكن')),
          ],
          selected: {SettingsService.instance.themeMode},
          onSelectionChanged: (v) {
            SettingsService.instance.themeMode = v.first;
            themeModeNotifier.value = themeModeFrom(v.first);
            setState(() {});
          },
        ),
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
        TextField(
            controller: _prefixInv,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(
                labelText: 'بادئة جداول الجرد (تسلسل مستقل، مثل JRD-)')),
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
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
        ),
        const SizedBox(height: 24),
        SizedBox(
            height: 52,
            child: FilledButton(onPressed: _save, child: const Text('حفظ'))),
      ])),
    );
  }
}
