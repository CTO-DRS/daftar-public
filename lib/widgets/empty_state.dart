import 'package:flutter/material.dart';

/// حالة فارغة لطيفة: رسم ورقة فاتورة صغيرة مع شارة، عنوان وتلميح.
class EmptyState extends StatelessWidget {
  final String title;
  final String hint;
  final IconData badge;
  const EmptyState(
      {super.key,
      required this.title,
      required this.hint,
      this.badge = Icons.add});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            width: 150,
            height: 120,
            child: Stack(alignment: Alignment.center, children: [
              CustomPaint(
                size: const Size(150, 120),
                painter: _SheetPainter(
                    blob: cs.primary.withValues(alpha: .10),
                    paper: Theme.of(context).cardTheme.color ?? Colors.white,
                    edge: cs.outlineVariant,
                    line: cs.outlineVariant.withValues(alpha: .8),
                    accent: cs.primary),
              ),
              PositionedDirectional(
                end: 18,
                bottom: 8,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                      color: const Color(0xFF12B886),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: const Color(0xFF12B886).withValues(alpha: .35),
                            blurRadius: 10,
                            offset: const Offset(0, 4))
                      ]),
                  child: Icon(badge, color: Colors.white, size: 22),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(hint,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant, height: 1.5)),
        ]),
      ),
    );
  }
}

class _SheetPainter extends CustomPainter {
  final Color blob, paper, edge, line, accent;
  _SheetPainter(
      {required this.blob,
      required this.paper,
      required this.edge,
      required this.line,
      required this.accent});

  @override
  void paint(Canvas c, Size s) {
    c.drawOval(Rect.fromLTWH(6, 14, s.width - 12, s.height - 26), Paint()..color = blob);
    c.save();
    c.translate(s.width * .36, s.height * .5);
    c.rotate(-.08);
    final r = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: 78, height: 98),
        const Radius.circular(10));
    c.drawShadow(Path()..addRRect(r), Colors.black45, 4, false);
    c.drawRRect(r, Paint()..color = paper);
    c.drawRRect(r, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = edge);
    c.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(-30, -40, 36, 8), const Radius.circular(4)),
        Paint()..color = accent.withValues(alpha: .85));
    final p = Paint()
      ..color = line
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 4; i++) {
      c.drawLine(Offset(-30, -16.0 + i * 15), Offset(i.isEven ? 28 : 14, -16.0 + i * 15), p);
    }
    c.restore();
  }

  @override
  bool shouldRepaint(_SheetPainter o) => o.accent != accent || o.paper != paper;
}
