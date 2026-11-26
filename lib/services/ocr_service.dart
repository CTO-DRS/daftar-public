import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import '../models/invoice_item.dart';
import '../models/ocr_result.dart';
import '../utils/date_utils.dart';
import '../utils/number_utils.dart';
import '../utils/ocr_parsing.dart';
import 'settings_service.dart';

const kOcrPrompt = '''
أنت محرك استخراج جداول فواتير. الصورة فاتورة أو جدول جرد ورقي (قد يكون بخط اليد، عربي أو إنجليزي).
استخرج كل صفوف جدول الأصناف بالترتيب كما هي على الورقة، وأعد JSON فقط بدون أي شرح وبهذا الشكل بالضبط:
{
  "invoice_number": "",
  "date": "YYYY-MM-DD أو فارغ",
  "party": "اسم العميل أو المورد إن وُجد",
  "grand_total": رقم أو null,
  "items": [
    {
      "item_code": "كود الصنف",
      "ref_number": "الرقم المرجعي (غالباً داخل دائرة)",
      "item_type": "النوع / الوصف",
      "quantity": رقم,
      "unit_price": رقم,
      "line_total": رقم أو null (الإجمالي المكتوب على الورقة للسطر),
      "notes": "",
      "unclear": true إذا لم تكن متأكداً من قراءة الصف
    }
  ]
}
قواعد: حوّل الأرقام العربية والهندية (١٢٣) إلى أرقام لاتينية (123). الأرقام بدون فواصل آلاف ولا رموز عملة.
لا تخمّن: إذا كانت قيمة غير مقروءة ضع null واجعل unclear = true. لا تحسب line_total بنفسك، انقله من الورقة فقط.
''';

class OcrService {
  OcrService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  final _settings = SettingsService.instance;

  /// يحسّن التباين ويصغّر الصورة ثم يعيد ملفاً مؤقتاً جاهزاً للإرسال.
  static Future<File> preprocess(File src) async {
    final bytes = await src.readAsBytes();
    final out = await Isolate.run(() {
      var im = img.decodeImage(bytes);
      if (im == null) return bytes;
      im = img.bakeOrientation(im);
      const maxSide = 2200;
      if (im.width > maxSide || im.height > maxSide) {
        im = im.width >= im.height
            ? img.copyResize(im, width: maxSide)
            : img.copyResize(im, height: maxSide);
      }
      im = img.adjustColor(im, contrast: 1.25, brightness: 1.03);
      return Uint8List.fromList(img.encodeJpg(im, quality: 88));
    });
    final f = File('${src.path}.proc.jpg');
    await f.writeAsBytes(out);
    return f;
  }

  /// المحرك الرئيسي: AI إن توفر مفتاح وإنترنت، وإلا الرجوع للمسح المحلي.
  Future<OcrResult> scan(File image) async {
    final warnings = <String>[];
    if (_settings.apiKey.isNotEmpty) {
      try {
        final r = await _scanOnline(image);
        verifyItems(r.items);
        return r;
      } on SocketException {
        warnings.add('لا يوجد اتصال بالإنترنت، تم استخدام المسح المحلي.');
      } on http.ClientException {
        warnings.add('تعذر الاتصال بالخدمة، تم استخدام المسح المحلي.');
      } on OcrException catch (e) {
        warnings.add('${e.message} تم استخدام المسح المحلي.');
      } on FormatException {
        warnings.add('رد الذكاء الاصطناعي غير مفهوم، تم استخدام المسح المحلي.');
      } on Exception catch (e) {
        warnings.add('خطأ في الخدمة ($e)، تم استخدام المسح المحلي.');
      }
    } else {
      warnings.add(
          'لم يُدخل مفتاح API في الإعدادات، تم استخدام المسح المحلي (نصوص مطبوعة فقط).');
    }
    final r = await scanOffline(image);
    return OcrResult(
      source: OcrSource.offline,
      items: r.items,
      warnings: [...warnings, ...r.warnings],
    );
  }

  Future<OcrResult> _scanOnline(File image) async {
    final b64 = base64Encode(await image.readAsBytes());
    final prov = _settings.provider;
    final key = _settings.apiKey;
    String text;
    if (prov == OcrProvider.gemini) {
      final model = _settings.geminiModel;
      final res = await _client
          .post(
            Uri.https('generativelanguage.googleapis.com',
                '/v1beta/models/$model:generateContent'),
            headers: {
              'content-type': 'application/json',
              'x-goog-api-key': key,
            },
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {'text': kOcrPrompt},
                    {
                      'inline_data': {'mime_type': 'image/jpeg', 'data': b64}
                    },
                  ]
                }
              ],
              'generationConfig': {
                'temperature': 0,
                'responseMimeType': 'application/json',
              },
            }),
          )
          .timeout(const Duration(seconds: 90));
      _checkStatus(res);
      final j = jsonDecode(utf8.decode(res.bodyBytes));
      text = (j['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '')
          .toString();
    } else {
      final model = _settings.openrouterModel;
      final res = await _client
          .post(
            Uri.https('openrouter.ai', '/api/v1/chat/completions'),
            headers: {
              'content-type': 'application/json',
              'authorization': 'Bearer $key',
            },
            body: jsonEncode({
              'model': model,
              'temperature': 0,
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': kOcrPrompt},
                    {
                      'type': 'image_url',
                      'image_url': {'url': 'data:image/jpeg;base64,$b64'}
                    },
                  ],
                }
              ],
            }),
          )
          .timeout(const Duration(seconds: 90));
      _checkStatus(res);
      final j = jsonDecode(utf8.decode(res.bodyBytes));
      text = (j['choices']?[0]?['message']?['content'] ?? '').toString();
    }
    if (text.trim().isEmpty) throw OcrException('رد فارغ من الخدمة.');
    return parseOnlineResponse(text,
        prov == OcrProvider.gemini ? OcrSource.gemini : OcrSource.openrouter);
  }

  void _checkStatus(http.Response res) {
    if (res.statusCode == 200) return;
    if (res.statusCode == 401 || res.statusCode == 403) {
      throw OcrException('مفتاح API غير صالح أو غير مصرّح.');
    }
    if (res.statusCode == 429) {
      throw OcrException('تجاوزت حد الاستخدام عند المزود.');
    }
    throw OcrException('الخدمة أعادت خطأ ${res.statusCode}.');
  }

  /// تحويل نص رد النموذج إلى نتيجة (للاختبار أيضاً).
  static OcrResult parseOnlineResponse(String text, OcrSource source) {
    final j = extractJsonObject(text);
    final rawItems = (j['items'] as List?) ?? const [];
    final items = <InvoiceItem>[
      for (final e in rawItems)
        if (e is Map<String, dynamic>) itemFromJson(e),
    ];
    DateTime? date;
    final d = j['date']?.toString() ?? '';
    if (d.isNotEmpty) date = DateTime.tryParse(normalizeDigits(d));
    final gt = j['grand_total'];
    return OcrResult(
      source: source,
      party: (j['party'] ?? '').toString().trim(),
      invoiceNumber: normalizeDigits((j['invoice_number'] ?? '').toString()).trim(),
      date: date,
      items: items,
      statedGrandTotal: gt == null ? null : (gt is num ? gt.toDouble() : parseNumber(gt.toString())),
    );
  }

  /// المسح المحلي بـ ML Kit (يعمل بدون إنترنت، للنصوص المطبوعة اللاتينية والأرقام).
  Future<OcrResult> scanOffline(File image) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final rt = await recognizer.processImage(InputImage.fromFile(image));
      final lines = <String>[];
      for (final b in rt.blocks) {
        for (final l in b.lines) {
          lines.add(l.text);
        }
      }
      final items = parseOfflineLines(lines);
      return OcrResult(
        source: OcrSource.offline,
        items: items,
        warnings: [
          'المسح المحلي لا يقرأ الخط العربي ولا خط اليد بدقة. راجع كل صف قبل الاعتماد.',
          if (items.isEmpty) 'لم يُعثر على صفوف أصناف. أضفها يدوياً أو جرّب المسح بالذكاء الاصطناعي.',
        ],
      );
    } finally {
      await recognizer.close();
    }
  }

  String today() => formatDate(DateTime.now());
}
