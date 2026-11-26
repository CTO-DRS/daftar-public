import 'package:daftar/screens/about_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('developer links are the exact official URLs', () {
    expect(developerLinks.map((l) => l.url).toList(), [
      'https://cto-drs.com',
      'https://github.com/CTO-DRS',
      'https://x.com/cto_drs',
      'https://www.instagram.com/cto.drs',
      'https://www.tiktok.com/@cto.drs',
      'https://youtube.com/@cto-drs',
      'https://t.me/CTO_DRS',
      'https://wa.me/message/MVTVWPOPFOVFF1',
    ]);
  });
}
