import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'settings_service.dart';

/// شعار المنشأة: يُختار من المعرض ويُصغَّر ويُحفظ داخل مجلد التطبيق.
class LogoService {
  LogoService._();

  /// يصغّر الصورة (أقصى 400 بكسل) ويعيدها PNG.
  static Uint8List normalize(Uint8List raw) {
    final decoded = img.decodeImage(raw);
    if (decoded == null) throw const FormatException('صورة غير صالحة');
    final longest = decoded.width > decoded.height ? decoded.width : decoded.height;
    final out = longest > 400
        ? img.copyResize(decoded,
            width: decoded.width >= decoded.height ? 400 : null,
            height: decoded.height > decoded.width ? 400 : null)
        : decoded;
    return Uint8List.fromList(img.encodePng(out));
  }

  /// يفتح المعرض ويحفظ الشعار. يعيد false عند الإلغاء.
  static Future<bool> pickAndSave() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (x == null) return false;
    final png = normalize(await x.readAsBytes());
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'company_logo.png');
    await File(path).writeAsBytes(png, flush: true);
    SettingsService.instance.logoPath = path;
    return true;
  }

  static Future<void> remove() async {
    final path = SettingsService.instance.logoPath;
    if (path.isNotEmpty) {
      final f = File(path);
      if (await f.exists()) await f.delete();
    }
    SettingsService.instance.logoPath = '';
  }

  static Future<Uint8List?> load() async {
    final path = SettingsService.instance.logoPath;
    if (path.isEmpty) return null;
    final f = File(path);
    return await f.exists() ? f.readAsBytes() : null;
  }
}
