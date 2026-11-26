import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_info.dart';
import '../services/dev_feed.dart';

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
  /// لافتات جاهزة (للاختبار). null = تحميل من الشبكة مع بديل مدمج.
  final List<DevBanner>? banners;
  const DeveloperSection({super.key, this.banners});

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
      BannerCarousel(initial: banners),
      const SizedBox(height: 14),
      const DeveloperCard(),
      const SizedBox(height: 14),
      const DeveloperActions(),
      const SizedBox(height: 18),
      const Center(
        child: Text('$appName • الإصدار $appVersionName',
            style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
      ),
    ]);
  }
}

/// لافتة متحركة فوق البطاقة: تتبدل كل 5 ثوانٍ، والمحتوى من banners.json.
class BannerCarousel extends StatefulWidget {
  final List<DevBanner>? initial;
  const BannerCarousel({super.key, this.initial});
  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  late List<DevBanner> _items = widget.initial ?? defaultBanners;
  final _ctl = PageController();
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    if (widget.initial == null) {
      loadBanners().then((v) {
        if (mounted) setState(() => _items = v);
      });
    }
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || _items.length < 2 || !_ctl.hasClients) return;
      _ctl.animateToPage((_page + 1) % _items.length,
          duration: const Duration(milliseconds: 600), curve: Curves.easeInOutCubic);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    return Column(children: [
      SizedBox(
        height: 122,
        child: PageView.builder(
          controller: _ctl,
          itemCount: _items.length,
          onPageChanged: (i) => setState(() => _page = i),
          itemBuilder: (c, i) {
            final b = _items[i];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: b.url == null ? null : () => _openUrl(context, b.url!),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                        colors: [b.color.withValues(alpha: .85), b.color.withValues(alpha: .35)]),
                    border: Border.all(color: const Color(0x40FFFFFF)),
                  ),
                  child: Row(children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x33FFFFFF)),
                      child: Icon(b.icon, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(b.title(ar),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                        const SizedBox(height: 4),
                        Text(b.body(ar),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: Color(0xDDFFFFFF))),
                      ]),
                    ),
                    if (b.url != null) const Icon(Icons.chevron_left_rounded, color: Colors.white70),
                  ]),
                ),
              ),
            );
          },
        ),
      ),
      if (_items.length > 1) ...[
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 0; i < _items.length; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == _page ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                  color: i == _page ? const Color(0xFFA78BFA) : const Color(0x40FFFFFF),
                  borderRadius: BorderRadius.circular(3)),
            ),
        ]),
      ],
    ]);
  }
}

String appShareMessage() =>
    'جرّب تطبيق «دفتر» للفواتير والمخزون: عربي ويعمل بدون إنترنت.\n'
    'حمّله من هنا:\n$releasesPageUrl\n\n'
    'Try Daftar, an Arabic offline invoice and inventory app:\n$releasesPageUrl';

String allAccountsMessage() {
  final b = StringBuffer('حسابات CTO.DRS • CTO.DRS accounts\n');
  for (final l in developerLinks) {
    b.writeln('${l.label}: ${l.url}');
  }
  return b.toString().trimRight();
}

/// أزرار النظام: شارك التطبيق، شارك كل الحسابات، التحقق من التحديثات.
class DeveloperActions extends StatefulWidget {
  const DeveloperActions({super.key});
  @override
  State<DeveloperActions> createState() => _DeveloperActionsState();
}

class _DeveloperActionsState extends State<DeveloperActions> {
  bool _checking = false;

  Future<void> _check() async {
    setState(() => _checking = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final u = await checkForUpdate();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          backgroundColor: const Color(0xF20B0C24),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24), side: const BorderSide(color: Color(0x408E5BD0))),
          title: Text(u.newer ? 'يتوفر إصدار جديد' : 'أنت على أحدث إصدار',
              style: const TextStyle(color: Colors.white, fontSize: 18)),
          content: Text(
              u.newer
                  ? 'الإصدار الحالي $appVersionName، والأحدث ${u.latest}.'
                  : 'الإصدار $appVersionName هو الأحدث.\nYou are up to date.',
              style: const TextStyle(color: Color(0xFFCBD5E1))),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('إغلاق')),
            if (u.newer)
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: _violet, foregroundColor: Colors.white),
                onPressed: () {
                  Navigator.pop(c);
                  _openUrl(context, u.url);
                },
                child: const Text('تنزيل التحديث'),
              ),
          ],
        ),
      );
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('تعذّر التحقق من التحديثات. تأكد من الاتصال بالإنترنت.')));
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0x14FFFFFF),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0x268E5BD0)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
              child: _GlassButton(
                icon: Icons.ios_share,
                label: 'شارك التطبيق',
                onTap: () => SharePlus.instance.share(ShareParams(text: appShareMessage(), subject: appName)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _GlassButton(
                icon: Icons.groups_2_rounded,
                label: 'شارك الحسابات',
                onTap: () => SharePlus.instance.share(ShareParams(text: allAccountsMessage(), subject: 'CTO.DRS')),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          FilledButton.icon(
            style: FilledButton.styleFrom(
                backgroundColor: _violet, foregroundColor: Colors.white, minimumSize: const Size(0, 46)),
            onPressed: _checking ? null : _check,
            icon: _checking
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.system_update_alt_rounded, size: 18),
            label: const Text('التحقق من التحديثات  •  $appVersionName'),
          ),
        ]),
      ),
    );
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
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: _GlassButton(
                icon: Icons.ios_share,
                label: 'مشاركة الرابط',
                onTap: () => SharePlus.instance.share(ShareParams(text: l.url, subject: l.label)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _GlassButton(
                icon: Icons.qr_code_2,
                label: 'مشاركة QR',
                onTap: () => shareQrImage(l),
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

class _GlassButton extends StatelessWidget {
  const _GlassButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: const Color(0x14FFFFFF),
            side: const BorderSide(color: Color(0x30FFFFFF)),
            minimumSize: const Size(0, 44)),
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label, maxLines: 1, style: const TextStyle(fontSize: 12.5)),
      );
}

/// يرسم رمز QR على الجهاز (بدون شبكة) ويشاركه كصورة PNG.
Future<void> shareQrImage(DevLink l) async {
  final painter = QrPainter(
    data: l.url,
    version: QrVersions.auto,
    gapless: false,
    eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF000000)),
    dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF000000)),
  );
  final data = await painter.toImageData(1024, format: ui.ImageByteFormat.png);
  if (data == null) return;
  // خلفية بيضاء مع هامش: QrPainter شفاف افتراضياً.
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  const size = 1280.0;
  c.drawRect(const Rect.fromLTWH(0, 0, size, size), Paint()..color = const Color(0xFFFFFFFF));
  final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
  final frame = await codec.getNextFrame();
  c.drawImage(frame.image, const Offset(128, 128), Paint());
  final img = await rec.endRecording().toImage(size.toInt(), size.toInt());
  final png = await img.toByteData(format: ui.ImageByteFormat.png);
  if (png == null) return;
  final dir = await getTemporaryDirectory();
  final f = File('${dir.path}/qr_${l.label.replaceAll(RegExp(r'[^A-Za-z0-9]'), '')}_${l.url.hashCode.abs()}.png');
  await f.writeAsBytes(png.buffer.asUint8List(), flush: true);
  await SharePlus.instance.share(ShareParams(files: [XFile(f.path, mimeType: 'image/png')], text: l.url));
}
