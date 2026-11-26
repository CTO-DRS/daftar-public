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

  String get openrouterModel =>
      _p.getString('openrouter_model') ?? 'google/gemini-2.5-flash';
  set openrouterModel(String v) => _p.setString('openrouter_model', v.trim());

  String get currency => _p.getString('currency') ?? 'ر.س';
  set currency(String v) => _p.setString('currency', v.trim());

  String get companyName => _p.getString('company_name') ?? '';
  set companyName(String v) => _p.setString('company_name', v.trim());

  String get logoPath => _p.getString('logo_path') ?? '';
  set logoPath(String v) => _p.setString('logo_path', v);

  /// ترقيم الفواتير: بادئة (مثل INV-)، أول رقم، عدد الخانات.
  String get numberPrefix => _p.getString('num_prefix') ?? '';
  set numberPrefix(String v) => _p.setString('num_prefix', v.trim());
  int get numberStart => _p.getInt('num_start') ?? 1;
  set numberStart(int v) => _p.setInt('num_start', v < 1 ? 1 : v);
  int get numberPadding => _p.getInt('num_padding') ?? 1;
  set numberPadding(int v) => _p.setInt('num_padding', v.clamp(1, 8));

  bool get arabicDigits => _p.getBool('arabic_digits') ?? false;
  set arabicDigits(bool v) => _p.setBool('arabic_digits', v);

  bool get oneHandedBarBottom => _p.getBool('one_hand') ?? true;
}
