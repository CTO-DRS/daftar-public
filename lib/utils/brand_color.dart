import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// لون الهوية الافتراضي (أخضر دفتر الداكن).
const defaultBrandColor = 0xFF0F766E;

/// ألوان جاهزة للاختيار من الإعدادات (كلها داكنة بما يكفي لنص أبيض).
const brandSwatches = <int>[
  0xFF0F766E, // أخضر دفتر
  0xFF1D4ED8, // أزرق
  0xFF1E3A5F, // كحلي
  0xFF7C2D12, // بني محمر
  0xFF9F1239, // عنابي
  0xFF6D28D9, // بنفسجي
  0xFFB45309, // عنبري
  0xFF1F2937, // فحمي
];

double _lin(int c) {
  final s = c / 255;
  return s <= .03928 ? s / 12.92 : math.pow((s + .055) / 1.055, 2.4).toDouble();
}

double luminance(int argb) {
  final r = (argb >> 16) & 0xFF, g = (argb >> 8) & 0xFF, b = argb & 0xFF;
  return .2126 * _lin(r) + .7152 * _lin(g) + .0722 * _lin(b);
}

/// يغمّق اللون حتى تصبح نسبة التباين مع الأبيض ≥ 4.5 (نص أبيض مقروء فوقه).
int ensureReadableOnWhite(int argb) {
  var r = (argb >> 16) & 0xFF, g = (argb >> 8) & 0xFF, b = argb & 0xFF;
  for (var i = 0; i < 30 && 1.05 / (luminance(0xFF000000 | r << 16 | g << 8 | b) + .05) < 4.5; i++) {
    r = (r * .9).round();
    g = (g * .9).round();
    b = (b * .9).round();
  }
  return 0xFF000000 | r << 16 | g << 8 | b;
}

/// اللون المهيمن في الشعار: يتجاهل الشفاف والأبيض والرمادي، ويفضّل الألوان المشبعة.
/// يعيد null إذا كان الشعار بلا لون واضح (أبيض/أسود/رمادي فقط).
int? dominantBrandColor(Uint8List imageBytes) {
  final decoded = img.decodeImage(imageBytes);
  if (decoded == null) return null;
  final small = img.copyResize(decoded, width: 48);
  final sums = List.generate(12, (_) => [0.0, 0.0, 0.0, 0.0]); // r,g,b,weight لكل قناة تدرج لون
  for (final p in small) {
    if (p.a < 128) continue;
    final r = p.r.toDouble(), g = p.g.toDouble(), b = p.b.toDouble();
    final mx = math.max(r, math.max(g, b)), mn = math.min(r, math.min(g, b));
    final sat = mx == 0 ? 0 : (mx - mn) / mx;
    if (sat < .25 || mx < 40 || (mn > 225)) continue;
    double h;
    final d = mx - mn;
    if (mx == r) {
      h = ((g - b) / d) % 6;
    } else if (mx == g) {
      h = (b - r) / d + 2;
    } else {
      h = (r - g) / d + 4;
    }
    final bucket = ((h * 60) / 30).floor() % 12;
    final w = sat.toDouble();
    sums[bucket][0] += r * w;
    sums[bucket][1] += g * w;
    sums[bucket][2] += b * w;
    sums[bucket][3] += w;
  }
  var best = -1;
  for (var i = 0; i < 12; i++) {
    if (sums[i][3] > 0 && (best < 0 || sums[i][3] > sums[best][3])) best = i;
  }
  if (best < 0) return null;
  final w = sums[best][3];
  final c = 0xFF000000 |
      (sums[best][0] / w).round() << 16 |
      (sums[best][1] / w).round() << 8 |
      (sums[best][2] / w).round();
  return ensureReadableOnWhite(c);
}

/// لون الترويسة: اختيار المستخدم، وإلا من الشعار، وإلا الافتراضي.
int resolveBrandColor({required int? chosen, Uint8List? logo}) {
  if (chosen != null) return ensureReadableOnWhite(chosen);
  if (logo != null) {
    final d = dominantBrandColor(logo);
    if (d != null) return d;
  }
  return defaultBrandColor;
}
