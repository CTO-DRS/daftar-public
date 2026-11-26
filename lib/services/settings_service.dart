import 'package:shared_preferences/shared_preferences.dart';

enum OcrProvider { gemini, openrouter }

/// إعدادات التطبيق (مفتاح الـ API، المزود، العملة، بيانات الترويسة).
class SettingsService {
  SettingsService._();
  static final SettingsService instance = SettingsService._();

  late SharedPreferences _p;

  Future<void> init() async => _p = await SharedPreferences.getInstance();

  OcrProvider get provider =>
      _p.getString('ocr_provider') == 'openrouter'
          ? OcrProvider.openrouter
          : OcrProvider.gemini;
  set provider(OcrProvider v) => _p.setString('ocr_provider', v.name);

  String get apiKey => _p.getString('ocr_api_key') ?? '';
  set apiKey(String v) => _p.setString('ocr_api_key', v.trim());

  String get geminiModel => _p.getString('gemini_model') ?? 'gemini-2.5-flash';
  set geminiModel(String v) => _p.setString('gemini_model', v.trim());

  /// النماذج المجانية تُجرَّب تلقائياً بالترتيب (رصيد صفر لا يوقف المسح).
  static const freeVisionModels = <String>[
    'google/gemma-4-31b-it:free',
    'google/gemma-4-26b-a4b-it:free',
    'nvidia/nemotron-3.5-super-vl:free',
    'nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free',
  ];

  String get openrouterModel {
    final v = _p.getString('openrouter_model');
    // القيمة القديمة الافتراضية (مدفوعة) تُعتبر غير مضبوطة.
    if (v == null || v.isEmpty || v == 'google/gemini-2.5-flash') {
      return freeVisionModels.first;
    }
    return v;
  }
  set openrouterModel(String v) => _p.setString('openrouter_model', v.trim());

  /// وضع المظهر: system / light / dark.
  String get themeMode => _p.getString('theme_mode') ?? 'system';
  set themeMode(String v) => _p.setString('theme_mode', v);

  /// لون ترويسة PDF (ARGB) أو null = تلقائي من الشعار.
  int? get brandColor => _p.getInt('brand_color');
  set brandColor(int? v) =>
      v == null ? _p.remove('brand_color') : _p.setInt('brand_color', v);

  /// قالب PDF: classic / modern / compact.
  String get pdfTemplate => _p.getString('pdf_template') ?? 'classic';
  set pdfTemplate(String v) => _p.setString('pdf_template', v);

  String get currency => _p.getString('currency') ?? 'ر.س';
  set currency(String v) => _p.setString('currency', v.trim());

  String get companyName => _p.getString('company_name') ?? '';
  set companyName(String v) => _p.setString('company_name', v.trim());

  /// الرقم الضريبي للبائع ونسبة الضريبة الافتراضية للفواتير الجديدة (0 = معطّلة).
  String get sellerVat => _p.getString('seller_vat') ?? '';
  set sellerVat(String v) => _p.setString('seller_vat', v.trim());
  double get defaultVatRate => _p.getDouble('vat_rate') ?? 0;
  set defaultVatRate(double v) => _p.setDouble('vat_rate', v < 0 ? 0 : v);

  String get logoPath => _p.getString('logo_path') ?? '';
  set logoPath(String v) => _p.setString('logo_path', v);

  /// ترقيم الفواتير: بادئة (مثل INV-)، أول رقم، عدد الخانات.
  String get numberPrefix => _p.getString('num_prefix') ?? '';
  set numberPrefix(String v) => _p.setString('num_prefix', v.trim());
  /// بادئة ترقيم جداول الجرد (تسلسل مستقل عن الفواتير).
  String get inventoryPrefix => _p.getString('num_prefix_inv') ?? 'JRD-';
  set inventoryPrefix(String v) => _p.setString('num_prefix_inv', v.trim());
  int get numberStart => _p.getInt('num_start') ?? 1;
  set numberStart(int v) => _p.setInt('num_start', v < 1 ? 1 : v);
  int get numberPadding => _p.getInt('num_padding') ?? 1;
  set numberPadding(int v) => _p.setInt('num_padding', v.clamp(1, 8));

  bool get arabicDigits => _p.getBool('arabic_digits') ?? false;
  set arabicDigits(bool v) => _p.setBool('arabic_digits', v);

  bool get oneHandedBarBottom => _p.getBool('one_hand') ?? true;
}
