import 'package:flutter/services.dart';

/// حفظ ملف في مجلد التنزيلات (Download/Daftar) عبر MediaStore.
class FileSaver {
  static const _ch = MethodChannel('daftar/files');

  static Future<String> saveToDownloads(Uint8List bytes, String name,
      {String mime = 'application/pdf'}) async {
    final r = await _ch.invokeMethod<String>(
        'saveToDownloads', {'bytes': bytes, 'name': name, 'mime': mime});
    return r ?? name;
  }
}
