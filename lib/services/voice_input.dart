import 'package:speech_to_text/speech_to_text.dart';
import '../utils/platform_utils.dart';

/// إملاء صوتي بالعربية عبر خدمة التعرف على الكلام في الهاتف (أندرويد فقط).
class VoiceInput {
  final SpeechToText _stt = SpeechToText();
  bool _ready = false;

  static bool get supported => isMobilePlatform;
  bool get listening => _stt.isListening;

  /// يهيّئ الخدمة ويطلب إذن الميكروفون. يعيد false إن لم تتوفر أو رُفض الإذن.
  Future<bool> init({void Function(String status)? onStatus, void Function(String error)? onError}) async {
    if (!supported) return false;
    _ready = await _stt.initialize(
      onStatus: onStatus,
      onError: (e) => onError?.call(e.errorMsg),
    );
    return _ready;
  }

  /// يفضّل لغة عربية (السعودية أولاً) إن وُجدت.
  Future<String?> arabicLocale() async {
    final ls = await _stt.locales();
    String? any;
    for (final l in ls) {
      if (l.localeId.toLowerCase().replaceAll('-', '_') == 'ar_sa') return l.localeId;
      if (any == null && l.localeId.toLowerCase().startsWith('ar')) any = l.localeId;
    }
    return any;
  }

  Future<void> start(void Function(String text, bool isFinal) onText) async {
    if (!_ready) return;
    final loc = await arabicLocale();
    await _stt.listen(
      onResult: (r) => onText(r.recognizedWords, r.finalResult),
      localeId: loc,
      listenOptions: SpeechListenOptions(
          partialResults: true, listenMode: ListenMode.dictation),
      pauseFor: const Duration(seconds: 4),
      listenFor: const Duration(minutes: 1),
    );
  }

  Future<void> stop() => _stt.stop();
  Future<void> cancel() => _stt.cancel();
}
