import 'dart:typed_data';

import 'package:daftar/utils/brand_color.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

Uint8List png(int r, int g, int b, {int bg = 255}) {
  final i = img.Image(width: 60, height: 60, numChannels: 4);
  img.fill(i, color: img.ColorRgba8(bg, bg, bg, 255));
  img.fillRect(i, x1: 10, y1: 10, x2: 50, y2: 50, color: img.ColorRgba8(r, g, b, 255));
  return Uint8List.fromList(img.encodePng(i));
}

void main() {
  test('dominant color ignores white background', () {
    final c = dominantBrandColor(png(200, 30, 40))!;
    expect((c >> 16) & 0xFF, greaterThan((c >> 8) & 0xFF)); // أحمر غالب
    expect(1.05 / (luminance(c) + .05), greaterThanOrEqualTo(4.5));
  });
  test('gray or white logo gives null and falls back to default', () {
    expect(dominantBrandColor(png(128, 128, 128)), isNull);
    expect(resolveBrandColor(chosen: null, logo: png(128, 128, 128)), defaultBrandColor);
  });
  test('chosen color wins and is made readable', () {
    final c = resolveBrandColor(chosen: 0xFFFFEE00);
    expect(1.05 / (luminance(c) + .05), greaterThanOrEqualTo(4.5));
  });
  test('all swatches are readable with white text', () {
    for (final s in brandSwatches) {
      expect(1.05 / (luminance(s) + .05), greaterThanOrEqualTo(4.5), reason: s.toRadixString(16));
    }
  });
}
