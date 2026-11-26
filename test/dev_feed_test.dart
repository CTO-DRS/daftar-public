import 'package:daftar/screens/about_screen.dart';
import 'package:daftar/services/dev_feed.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('version compare', () {
    expect(isNewerVersion('v0.1.11', '0.1.10'), true);
    expect(isNewerVersion('v0.1.10', '0.1.10'), false);
    expect(isNewerVersion('v0.1.9', '0.1.10'), false);
    expect(isNewerVersion('v0.2.0', '0.1.10+11'), true);
  });
  test('banners json parse', () {
    final l = DevBanner.parse('{"banners":[{"id":"a","title_ar":"x","url":"https://e.com","color":"#112233"},{"id":"","title_ar":"bad"},{"id":"b","title_en":"y","url":"http://insecure"}]}');
    expect(l.length, 2);
    expect(l[0].url, 'https://e.com');
    expect(l[1].url, null);
    expect(DevBanner.parse('[]'), isEmpty);
  });
  test('share messages', () {
    final m = allAccountsMessage();
    for (final k in developerLinks) {
      expect(m.contains(k.url), true);
    }
    expect(appShareMessage().contains(releasesPageUrl), true);
  });
}
