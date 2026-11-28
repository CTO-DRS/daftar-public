import 'dart:io';
import 'package:flutter/services.dart' show Clipboard;
import 'package:url_launcher/url_launcher.dart';

import 'package:flutter/material.dart';
import '../services/digest_notifier.dart';
import '../services/pdf_service.dart' show PdfTemplate, PdfTemplateX;
import '../utils/brand_color.dart';
import 'about_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../services/backup_service.dart';
import '../services/file_saver.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../main.dart' show themeModeNotifier, themeModeFrom;

import '../services/logo_service.dart';
import '../services/settings_service.dart';
import '../utils/number_utils.dart';
import '../utils/platform_utils.dart';
import '../widgets/responsive.dart';
import '../widgets/app_lock.dart';
import '../widgets/sync_card.dart';
import '../services/auto_backup.dart';
import 'audit_screen.dart';
import 'onboarding_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final s = SettingsService.instance;

  @override
  void initState() {
    super.initState();
    AppLock.supported().then((v) {
      if (mounted) setState(() => _lockSupported = v);
    });
  }
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
  bool _appLock = SettingsService.instance.appLock;
  bool _digestNotify = SettingsService.instance.weeklyDigestNotify;
  bool _lockSupported = false;

  void _save() {
    s.apiKey = _key.text;
    s.companyName = _company.text;
    s.currency = _currency.text.trim().isEmpty ? 'ر.س' : _currency.text;
    s.geminiModel = _gModel.text.isEmpty ? 'gemini-2.5-flash' : _gModel.text;
    s.openrouterModel =
        _oModel.text.isEmpty ? SettingsService.freeVisionModels.first : _oModel.text;
    s.numberPrefix = _prefix.text;
    s.inventoryPrefix = _prefixInv.text;
    s.sellerVat = normalizeDigits(_vatNo.text).replaceAll(RegExp(r'[^0-9]'), '');
    s.defaultVatRate = _vatOn ? (s.defaultVatRate > 0 ? s.defaultVatRate : 15) : 0; // لا نكتب فوق نسبة مخصّصة
    s.numberStart = parseNumber(_start.text)?.toInt() ?? 1;
    s.numberPadding = parseNumber(_pad.text)?.toInt() ?? 1;
    s.provider = _provider;
    s.arabicDigits = _arabicDigits;
    s.appLock = _appLock;
    useArabicDigits = _arabicDigits;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('تم حفظ الإعدادات')));
    Navigator.pop(context);
  }

  Future<void> _exportBackup() async {
    final m = ScaffoldMessenger.of(context);
    try {
      final json = await BackupService.exportJson();
      final d = DateTime.now();
      final name =
          'daftar-backup-${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}.json';
      final bytes = Uint8List.fromList(utf8.encode(json));
      final where = await FileSaver.saveToDownloads(bytes, name, mime: 'application/json');
      m.showSnackBar(SnackBar(content: Text('تم حفظ النسخة في $where')));
      if (!isDesktopPlatform) {
        await SharePlus.instance.share(ShareParams(
            files: [XFile.fromData(bytes, mimeType: 'application/json', name: name)],
            fileNameOverrides: [name]));
      }
    } catch (e) {
      m.showSnackBar(SnackBar(content: Text('تعذر إنشاء النسخة: $e')));
    }
  }

  Future<void> _restoreAuto() async {
    final m = ScaffoldMessenger.of(context);
    final files = await AutoBackup.list();
    if (!mounted) return;
    if (files.isEmpty) {
      m.showSnackBar(const SnackBar(content: Text('لا توجد نسخ تلقائية بعد. تُنشأ أول نسخة عند فتح التطبيق وفيه بيانات.')));
      return;
    }
    final pick = await showModalBottomSheet<File>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          for (final f in files)
            ListTile(
              leading: const Icon(Icons.history),
              title: Text(f.path.split(RegExp(r'[\\/]')).last.replaceAll('auto-', '').replaceAll('.json', ''),
                  textDirection: TextDirection.ltr),
              subtitle: Text('${(f.lengthSync() / 1024).toStringAsFixed(0)} ك.ب'),
              onTap: () => Navigator.pop(c, f),
            ),
        ]),
      ),
    );
    if (pick == null || !mounted) return;
    try {
      final text = await pick.readAsString();
      final sum = BackupService.summarize(BackupService.parse(text));
      if (!mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('استعادة هذه النسخة؟'),
          content: Text('ستُستبدل بياناتك الحالية: ${localizeDigits('${sum.invoices}')} مستنداً و${localizeDigits('${sum.parties}')} عميلاً.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('استعادة')),
          ],
        ),
      );
      if (ok != true) return;
      await BackupService.restore(text);
      m.showSnackBar(const SnackBar(content: Text('تمت الاستعادة. أعد فتح القائمة الرئيسية.')));
    } catch (e) {
      m.showSnackBar(SnackBar(content: Text('تعذرت الاستعادة: $e')));
    }
  }

  Future<void> _restoreBackup() async {
    final m = ScaffoldMessenger.of(context);
    try {
      final f = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['json']);
      if (f == null) return;
      final text = utf8.decode(await f.readAsBytes());
      final sum = BackupService.summarize(BackupService.parse(text));
      if (!mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('استعادة النسخة؟'),
          content: Text(
              'ستُستبدل كل بياناتك الحالية بمحتوى النسخة: ${localizeDigits('${sum.invoices}')} مستنداً و${localizeDigits('${sum.parties}')} عميلاً. لا يمكن التراجع، فصدّر نسخة من بياناتك الحالية أولاً إن لزم.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('استعادة')),
          ],
        ),
      );
      if (ok != true) return;
      await BackupService.restore(text);
      m.showSnackBar(const SnackBar(content: Text('تمت الاستعادة. أعد فتح القائمة الرئيسية.')));
    } on FormatException catch (e) {
      m.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      m.showSnackBar(SnackBar(content: Text('تعذرت الاستعادة: $e')));
    }
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
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final t in PdfTemplate.values)
            ChoiceChip(
              label: Text(t.label),
              selected: SettingsService.instance.pdfTemplate == t.name,
              onSelected: (_) {
                SettingsService.instance.pdfTemplate = t.name;
                setState(() {});
              },
            ),
        ]),
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
        const Text('النسخ الاحتياطي', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('احفظ نسخة كاملة من فواتيرك وعملائك، واستعدها على أي جهاز.',
            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: FilledButton.tonalIcon(
              onPressed: _exportBackup,
              icon: const Icon(Icons.cloud_upload_outlined),
              label: const Text('تصدير نسخة'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _restoreBackup,
              icon: const Icon(Icons.settings_backup_restore),
              label: const Text('استعادة نسخة'),
            ),
          ),
        ]),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('نسخ احتياطي تلقائي يومي'),
          subtitle: const Text('آخر 7 نسخ داخل التطبيق. تُحذف مع حذف التطبيق، فصدّر نسخة أو فعّل المزامنة للحماية الكاملة.',
              style: TextStyle(fontSize: 12)),
          value: s.autoBackup,
          onChanged: (v) => setState(() => s.autoBackup = v),
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: _restoreAuto,
            icon: const Icon(Icons.history),
            label: const Text('استعادة من نسخة تلقائية'),
          ),
        ),
        const SizedBox(height: 8),
        const SyncCard(),
        const SizedBox(height: 12),
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
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.tour_outlined),
            title: const Text('جولة تعريفية'),
            subtitle: const Text('مراجعة سريعة لأهم ما يقدمه دفتر'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OnboardingScreen())),
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
        if (DigestNotifier.supported)
          SwitchListTile(
            key: const ValueKey('digest-notify'),
            contentPadding: EdgeInsets.zero,
            title: const Text('تذكير أسبوعي بالملخص'),
            subtitle: const Text('إشعار مرة كل أسبوع (يبدأ من لحظة التفعيل) يطلب إذن الإشعارات'),
            value: _digestNotify,
            onChanged: (v) async {
              final messenger = ScaffoldMessenger.of(context);
              if (v) {
                final ok = await DigestNotifier.instance.enable();
                if (!ok) {
                  messenger.showSnackBar(const SnackBar(
                      content: Text('لم يُمنح إذن الإشعارات. فعّله من إعدادات الهاتف.')));
                  return;
                }
              } else {
                await DigestNotifier.instance.disable();
              }
              SettingsService.instance.weeklyDigestNotify = v;
              setState(() => _digestNotify = v);
            },
          ),
        if (_lockSupported)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('قفل التطبيق بالبصمة'),
            subtitle: const Text('يُطلب عند فتح التطبيق وبعد 30 ثانية في الخلفية'),
            value: _appLock,
            onChanged: (v) async {
              if (v && !await AppLock.authenticate()) return;
              setState(() => _appLock = v);
            },
          ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.history),
          title: const Text('سجل التدقيق'),
          subtitle: const Text('كل إنشاء وتعديل وحذف'),
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const AuditScreen())),
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
              tooltip: _hide ? 'إظهار المفتاح' : 'إخفاء المفتاح',
              icon: Icon(_hide ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _hide = !_hide),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.open_in_new, size: 18),
            label: Text(_provider == OcrProvider.gemini
                ? 'احصل على مفتاح Gemini المجاني'
                : 'احصل على مفتاح OpenRouter'),
            onPressed: () => launchUrl(
                Uri.parse(_provider == OcrProvider.gemini
                    ? 'https://aistudio.google.com/apikey'
                    : 'https://openrouter.ai/keys'),
                mode: LaunchMode.externalApplication),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.content_paste, size: 18),
            label: const Text('الصق المفتاح'),
            onPressed: () async {
              final d = await Clipboard.getData('text/plain');
              final t = (d?.text ?? '').trim();
              if (t.isNotEmpty) setState(() => _key.text = t);
            },
          ),
        ]),
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
