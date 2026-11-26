import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../app_info.dart';

const releasesPageUrl = 'https://github.com/CTO-DRS/daftar-public/releases/latest';
const _latestApi = 'https://api.github.com/repos/CTO-DRS/daftar-public/releases/latest';

/// ملف اللافتات: عدّله في المستودع العام (banners.json) فتظهر اللافتات الجديدة
/// بدون إصدار تطبيق جديد. النسخة المدمجة أدناه تعمل بدون إنترنت.
const bannersUrl = 'https://raw.githubusercontent.com/CTO-DRS/daftar-public/main/banners.json';
const _bannersCacheKey = 'dev_banners_json_v1';

class DevBanner {
  final String id;
  final String titleAr, titleEn, bodyAr, bodyEn;
  final String? url;
  final Color color;
  final IconData icon;
  const DevBanner({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    required this.bodyAr,
    required this.bodyEn,
    this.url,
    this.color = const Color(0xFF6D3FC9),
    this.icon = Icons.campaign_rounded,
  });

  String title(bool ar) => ar ? (titleAr.isNotEmpty ? titleAr : titleEn) : (titleEn.isNotEmpty ? titleEn : titleAr);
  String body(bool ar) => ar ? (bodyAr.isNotEmpty ? bodyAr : bodyEn) : (bodyEn.isNotEmpty ? bodyEn : bodyAr);

  static const _icons = <String, IconData>{
    'campaign': Icons.campaign_rounded,
    'rocket': Icons.rocket_launch_rounded,
    'offer': Icons.local_offer_rounded,
    'star': Icons.auto_awesome_rounded,
    'apps': Icons.apps_rounded,
    'support': Icons.support_agent_rounded,
  };

  static Color? _color(String? h) {
    if (h == null) return null;
    final v = int.tryParse(h.replaceFirst('#', ''), radix: 16);
    if (v == null) return null;
    return Color(h.replaceFirst('#', '').length <= 6 ? 0xFF000000 | v : v);
  }

  static DevBanner? fromJson(Object? j) {
    if (j is! Map) return null;
    String s(String k) => (j[k] ?? '').toString();
    final id = s('id');
    if (id.isEmpty || (s('title_ar').isEmpty && s('title_en').isEmpty)) return null;
    final url = s('url');
    return DevBanner(
      id: id,
      titleAr: s('title_ar'),
      titleEn: s('title_en'),
      bodyAr: s('body_ar'),
      bodyEn: s('body_en'),
      url: url.startsWith('https://') ? url : null,
      color: _color(j['color']?.toString()) ?? const Color(0xFF6D3FC9),
      icon: _icons[s('icon')] ?? Icons.campaign_rounded,
    );
  }

  static List<DevBanner> parse(String body) {
    final d = jsonDecode(body);
    final list = d is Map ? d['banners'] : d;
    if (list is! List) return const [];
    return list.map(DevBanner.fromJson).whereType<DevBanner>().toList();
  }
}

/// اللافتات المدمجة (تظهر دائماً بدون إنترنت أو عند فشل الجلب).
const defaultBanners = <DevBanner>[
  DevBanner(
    id: 'daftar-welcome',
    titleAr: 'دفتر: فواتيرك ومخزونك في جيبك',
    titleEn: 'Daftar: invoices and stock in your pocket',
    bodyAr: 'تطبيق عربي يعمل بدون إنترنت. شاركه مع من يحتاجه.',
    bodyEn: 'An Arabic, offline-first app. Share it with someone who needs it.',
    url: releasesPageUrl,
    icon: Icons.receipt_long_rounded,
  ),
  DevBanner(
    id: 'dev-services',
    titleAr: 'تحتاج تطبيقاً أو استشارة تقنية؟',
    titleEn: 'Need an app or tech consulting?',
    bodyAr: 'تواصل مع المطوّر مباشرة عبر واتساب.',
    bodyEn: 'Message the developer directly on WhatsApp.',
    url: 'https://wa.me/message/MVTVWPOPFOVFF1',
    color: Color(0xFF128C7E),
    icon: Icons.support_agent_rounded,
  ),
];

/// يجلب اللافتات: الشبكة أولاً (مهلة 6 ثوانٍ) ثم آخر نسخة مخزنة ثم المدمجة.
Future<List<DevBanner>> loadBanners({http.Client? client}) async {
  final prefs = await SharedPreferences.getInstance();
  try {
    final c = client ?? http.Client();
    final r = await c.get(Uri.parse(bannersUrl)).timeout(const Duration(seconds: 6));
    if (r.statusCode == 200) {
      final parsed = DevBanner.parse(utf8.decode(r.bodyBytes));
      if (parsed.isNotEmpty) {
        await prefs.setString(_bannersCacheKey, utf8.decode(r.bodyBytes));
        return parsed;
      }
    }
  } catch (_) {}
  try {
    final cached = prefs.getString(_bannersCacheKey);
    if (cached != null) {
      final parsed = DevBanner.parse(cached);
      if (parsed.isNotEmpty) return parsed;
    }
  } catch (_) {}
  return defaultBanners;
}

class UpdateInfo {
  final bool newer;
  final String latest;
  final String url;
  const UpdateInfo(this.newer, this.latest, this.url);
}

List<int> _nums(String v) =>
    RegExp(r'\d+').allMatches(v.split('+').first).map((m) => int.parse(m.group(0)!)).toList();

/// true إذا كانت [a] أحدث من [b].
bool isNewerVersion(String a, String b) {
  final x = _nums(a), y = _nums(b);
  for (var i = 0; i < 3; i++) {
    final p = i < x.length ? x[i] : 0, q = i < y.length ? y[i] : 0;
    if (p != q) return p > q;
  }
  return false;
}

/// يقرأ آخر إصدار من صفحة إصدارات المستودع العام. يرمي خطأً عند فشل الشبكة.
Future<UpdateInfo> checkForUpdate({http.Client? client}) async {
  final c = client ?? http.Client();
  final r = await c
      .get(Uri.parse(_latestApi), headers: {'Accept': 'application/vnd.github+json'})
      .timeout(const Duration(seconds: 10));
  if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
  final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map;
  final tag = (j['tag_name'] ?? '').toString();
  final url = (j['html_url'] ?? releasesPageUrl).toString();
  return UpdateInfo(isNewerVersion(tag, appVersionName), tag.replaceFirst('v', ''), url);
}
