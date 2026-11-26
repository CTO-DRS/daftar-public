import 'dart:io';

import 'package:daftar/app_info.dart';
import 'package:daftar/screens/about_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('developer links are the exact official URLs', () {
    expect(developerLinks.map((l) => l.url).toList(), [
      'https://wa.me/message/MVTVWPOPFOVFF1',
      'https://t.me/CTO_DRS',
      'https://www.tiktok.com/@cto.drs',
      'https://www.instagram.com/cto.drs',
      'https://x.com/cto_drs',
      'https://youtube.com/@cto-drs',
      'https://github.com/CTO-DRS',
      'https://cto-drs.com',
    ]);
  });

  test('app version constant matches pubspec', () {
    final v = RegExp(r'^version:\s*([\d.]+)\+', multiLine: true)
        .firstMatch(File('pubspec.yaml').readAsStringSync())!
        .group(1);
    expect(appVersionName, v);
  });
}
