import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../utils/platform_utils.dart';

/// حفظ ملف: أندرويد = Download/Daftar عبر MediaStore، سطح المكتب = مجلد التنزيلات/Daftar.
class FileSaver {
  static const _ch = MethodChannel('daftar/files');

  static Future<String> saveToDownloads(Uint8List bytes, String name,
      {String mime = 'application/pdf'}) async {
    if (isDesktopPlatform) {
      final base = await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
      final dir = Directory(p.join(base.path, 'Daftar'));
      await dir.create(recursive: true);
      final f = File(p.join(dir.path, name));
      await f.writeAsBytes(bytes);
      return f.path;
    }
    final r = await _ch.invokeMethod<String>(
        'saveToDownloads', {'bytes': bytes, 'name': name, 'mime': mime});
    return r ?? name;
  }
}
