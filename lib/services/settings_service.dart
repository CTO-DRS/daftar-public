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

  bool get oneHandedBarBottom => _p.getBool('one_hand') ?? true;
}
