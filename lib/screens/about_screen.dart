import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class DevLink {
  final String label;
  final String url;
  final IconData icon;
  final Color color;
  const DevLink(this.label, this.url, this.icon, this.color);
}

const developerLinks = <DevLink>[
  DevLink('Website', 'https://cto-drs.com', Icons.language, Color(0xFF0F766E)),
  DevLink('GitHub', 'https://github.com/CTO-DRS', Icons.code, Color(0xFF475569)),
  DevLink('X', 'https://x.com/cto_drs', Icons.close, Color(0xFF111827)),
  DevLink('Instagram', 'https://www.instagram.com/cto.drs', Icons.camera_alt_outlined, Color(0xFFC2185B)),
  DevLink('TikTok', 'https://www.tiktok.com/@cto.drs', Icons.music_note, Color(0xFF0891B2)),
  DevLink('YouTube', 'https://youtube.com/@cto-drs', Icons.play_arrow_rounded, Color(0xFFDC2626)),
  DevLink('Telegram', 'https://t.me/CTO_DRS', Icons.send_rounded, Color(0xFF0284C7)),
  DevLink('WhatsApp', 'https://wa.me/message/MVTVWPOPFOVFF1', Icons.chat_bubble_outline, Color(0xFF16A34A)),
];

/// بطاقة المطور: صورة دائرية، الاسم، سطر تعريفي، وصف روابط الحسابات.
class DeveloperCard extends StatelessWidget {
  const DeveloperCard({super.key});

  Future<void> _open(BuildContext context, String url) async {
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)
        .catchError((_) => false);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('تعذر فتح الرابط: $url')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        Container(
          height: 70,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: dark
                  ? [const Color(0xFF0E4F4B), const Color(0xFF12302F)]
                  : [const Color(0xFF0F766E), const Color(0xFF12B886)],
            ),
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -44),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).cardTheme.color,
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .18), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: const CircleAvatar(
                radius: 48,
                backgroundImage: AssetImage('assets/images/developer.jpg'),
              ),
            ),
            const SizedBox(height: 10),
            const Text('CTO: DRS',
                textDirection: TextDirection.ltr,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: .3)),
            const SizedBox(height: 4),
            Text('تطوير CTO: DRS', style: TextStyle(color: cs.onSurfaceVariant)),
            Text('Developed by CTO: DRS',
                textDirection: TextDirection.ltr,
                style: TextStyle(color: cs.onSurfaceVariant.withValues(alpha: .8), fontSize: 12)),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final l in developerLinks)
                    Tooltip(
                      message: l.label,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => _open(context, l.url),
                        child: Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: l.color.withValues(alpha: dark ? .22 : .10),
                            border: Border.all(color: l.color.withValues(alpha: .35)),
                          ),
                          child: Icon(l.icon,
                              size: 22,
                              color: dark ? Color.lerp(l.color, Colors.white, .45) : l.color),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ]),
        ),
        const SizedBox(height: 0),
      ]),
    );
  }
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('عن المطور')),
      body: ListView(padding: const EdgeInsets.all(16), children: const [
        DeveloperCard(),
      ]),
    );
  }
}
