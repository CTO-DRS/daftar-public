import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_info.dart';

/// حساب من حسابات المطور: لون الهوية، الأيقونة الحقيقية، الرابط.
class DevLink {
  final String label;
  final String url;
  final IconData icon;
  final Color color;
  const DevLink(this.label, this.url, this.icon, this.color);
}

/// الترتيب والألوان حسب مواصفات المطور.

const developerLinks = <DevLink>[
  DevLink('واتساب', 'https://wa.me/message/MVTVWPOPFOVFF1', IconData(0xf232, fontFamily: 'FABrands'), Color(0xFF25D366)),
  DevLink('تيليجرام', 'https://t.me/CTO_DRS', IconData(0xf2c6, fontFamily: 'FABrands'), Color(0xFF229ED9)),
  DevLink('تيك توك', 'https://www.tiktok.com/@cto.drs', IconData(0xe07b, fontFamily: 'FABrands'), Color(0xFF111111)),
  DevLink('إنستغرام', 'https://www.instagram.com/cto.drs', IconData(0xf16d, fontFamily: 'FABrands'), Color(0xFFE1306C)),
  DevLink('إكس', 'https://x.com/cto_drs', IconData(0xe61b, fontFamily: 'FABrands'), Color(0xFF000000)),
  DevLink('يوتيوب', 'https://youtube.com/@cto-drs', IconData(0xf167, fontFamily: 'FABrands'), Color(0xFFFF0000)),
  DevLink('GitHub', 'https://github.com/CTO-DRS', IconData(0xf09b, fontFamily: 'FABrands'), Color(0xFF24292F)),
  DevLink('الموقع', 'https://cto-drs.com', Icons.language, Color(0xFF4F46E5)),
];

const _photo = AssetImage('assets/images/developer.jpg');
const _violet = Color(0xFF6D3FC9);

Future<void> _openUrl(BuildContext context, String url) async {
  final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)
      .catchError((_) => false);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('تعذر فتح الرابط: $url')));
  }
}

/// شاشة "عن المطوّر": خلفية داكنة بتوهجات ناعمة، وبطاقة زجاجية.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF05061A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('عن المطوّر'),
        titleTextStyle: const TextStyle(
            fontFamily: 'IBMPlexSansArabic', fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
      ),
      extendBodyBehindAppBar: true,
      body: const DeveloperBackdrop(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16, 56, 16, 24),
            child: DeveloperSection(),
          ),
        ),
      ),
    );
  }
}

/// خلفية متدرجة #05061A → #0D0A2E مع توهجين شعاعيين.
class DeveloperBackdrop extends StatelessWidget {
  final Widget child;
  const DeveloperBackdrop({super.key, required this.child});

  Widget _glow(Color c, Alignment a, double size) => Align(
        alignment: a,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [c.withValues(alpha: .28), c.withValues(alpha: 0)]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF05061A), Color(0xFF0D0A2E)],
          ),
        ),
        child: Stack(children: [
          _glow(const Color(0xFF7C3AED), const Alignment(1.2, -.85), 420),
          _glow(const Color(0xFF06B6D4), const Alignment(-1.3, .9), 380),
          child,
        ]),
      );
}

class DeveloperSection extends StatelessWidget {
  const DeveloperSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Row(children: [
        _Bar(),
        SizedBox(width: 10),
        Text('عن المطوّر',
            style: TextStyle(fontSize: 17, color: Color(0xFFDDE1EA), fontWeight: FontWeight.w600)),
        SizedBox(width: 12),
        Expanded(child: Divider(height: 1, thickness: 1, color: Color(0x40A78BFA))),
      ]),
      const SizedBox(height: 14),
      const DeveloperCard(),
      const SizedBox(height: 18),
      const Center(
        child: Text('$appName • الإصدار $appVersionName',
            style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
      ),
    ]);
  }
}

class _Bar extends StatelessWidget {
  const _Bar();
  @override
  Widget build(BuildContext context) => Container(
      width: 4, height: 20, decoration: BoxDecoration(color: _violet, borderRadius: BorderRadius.circular(2)));
}

/// البطاقة الزجاجية: صورة بحلقة متدرجة وشارة توثيق، الاسم، الدور، وشبكة الحسابات.
class DeveloperCard extends StatelessWidget {
  const DeveloperCard({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _RimPainter(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(children: [
          Positioned.fill(
              child: Container(
                  color: const Color(0xB80B0C24), // ~72%
                  foregroundDecoration: const BoxDecoration(color: Color(0x0CFFFFFF)))),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 60,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x1CFFFFFF), Color(0x00FFFFFF)]),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(height: 8),
              const _Avatar(),
              const SizedBox(height: 14),
              const Text('CTO.DRS',
                  textDirection: TextDirection.ltr,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: .4)),
              const SizedBox(height: 4),
              const Text('مطوّر تطبيقات • استشارات تقنية',
                  style: TextStyle(fontSize: 13, color: Color(0xFFA5B4FC))),
              const SizedBox(height: 2),
              const Text('App developer • Tech consulting',
                  textDirection: TextDirection.ltr,
                  style: TextStyle(fontSize: 11, color: Color(0xFF8A94C9))),
              const SizedBox(height: 20),
              LayoutBuilder(builder: (context, c) {
                final cell = c.maxWidth / 4;
                return Wrap(runSpacing: 16, children: [
                  for (final l in developerLinks)
                    SizedBox(width: cell, child: _LinkCell(link: l)),
                ]);
              }),
              const SizedBox(height: 4),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _RimPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(24));
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFF8E5BD0).withValues(alpha: .36),
          const Color(0xFF5558C2).withValues(alpha: .36),
          const Color(0xFF2FA9C0).withValues(alpha: .36),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRRect(r.deflate(.5), p);
  }

  @override
  bool shouldRepaint(_RimPainter o) => false;
}

class _Avatar extends StatelessWidget {
  const _Avatar();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        barrierDismissible: true,
        pageBuilder: (_, _, _) => const _PhotoViewer(),
        transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
      )),
      child: SizedBox(
        width: 102,
        height: 102,
        child: Stack(clipBehavior: Clip.none, children: [
          Hero(
            tag: 'dev-photo',
            child: Container(
              width: 102,
              height: 102,
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF6366F1), Color(0xFF06B6D4), Color(0xFFA855F7)],
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF161437)),
                child: const CircleAvatar(radius: 45, backgroundImage: _photo),
              ),
            ),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: const Color(0xFF1D9BF0),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF0B0C24), width: 2),
              ),
              child: const Icon(Icons.check, size: 15, color: Colors.white),
            ),
          ),
        ]),
      ),
    );
  }
}

class _PhotoViewer extends StatelessWidget {
  const _PhotoViewer();
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
            child: Hero(
              tag: 'dev-photo',
              child: InteractiveViewer(
                maxScale: 4,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image(image: _photo, fit: BoxFit.contain),
                ),
              ),
            ),
          ),
        ),
      );
}

class _LinkCell extends StatelessWidget {
  final DevLink link;
  const _LinkCell({required this.link});

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: () => showLinkSheet(context, link),
      radius: 36,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: link.color,
            border: Border.all(color: const Color(0x40FFFFFF), width: 1),
          ),
          child: Center(child: Icon(link.icon, size: 22, color: Colors.white)),
        ),
        const SizedBox(height: 6),
        Text(link.label,
            textAlign: TextAlign.center,
            maxLines: 1,
            style: const TextStyle(fontSize: 11, color: Color(0xFFCBD5E1))),
      ]),
    );
  }
}

/// ورقة سفلية بالـ QR للحساب مع زر الفتح والنسخ.
Future<void> showLinkSheet(BuildContext context, DevLink l) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    elevation: 0,
    isScrollControlled: true,
    builder: (c) => _GlassSheet(
      child: SafeArea(
        top: false,
        child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(color: const Color(0x66FFFFFF), borderRadius: BorderRadius.circular(2))),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(shape: BoxShape.circle, color: l.color, border: Border.all(color: const Color(0x40FFFFFF))),
              child: Center(child: Icon(l.icon, size: 16, color: Colors.white)),
            ),
            const SizedBox(width: 10),
            Text(l.label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
          ]),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
            child: QrImageView(data: l.url, size: 200, padding: EdgeInsets.zero),
          ),
          const SizedBox(height: 12),
          Text(l.url,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: _violet, foregroundColor: Colors.white, minimumSize: const Size(0, 46)),
                onPressed: () {
                  Navigator.pop(c);
                  _openUrl(context, l.url);
                },
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('فتح'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0x40FFFFFF)),
                    minimumSize: const Size(0, 46)),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: l.url));
                  if (c.mounted) Navigator.pop(c);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(const SnackBar(content: Text('تم نسخ الرابط')));
                  }
                },
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('نسخ'),
              ),
            ),
          ]),
        ]),
      ),
      ),
    ),
  );
}

class _GlassSheet extends StatelessWidget {
  const _GlassSheet({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    const r = BorderRadius.vertical(top: Radius.circular(28));
    return ClipRRect(
      borderRadius: r,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: r,
            color: const Color(0xCC0B0C24),
            border: Border.all(color: const Color(0x408E5BD0)),
            gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x26FFFFFF), Color(0x0AFFFFFF), Color(0x00FFFFFF)],
                stops: [0, 0.3, 1]),
          ),
          child: child,
        ),
      ),
    );
  }
}
