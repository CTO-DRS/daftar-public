import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../utils/number_utils.dart';

/// عرض صفحات PDF مع شرائح للقفز إلى أي صفحة (ص1، ص2...) وتمييز الصفحة الحالية.
class PdfPagesView extends StatefulWidget {
  final List<PdfPreviewPageData> pages;
  const PdfPagesView({super.key, required this.pages});
  @override
  State<PdfPagesView> createState() => _PdfPagesViewState();
}

class _PdfPagesViewState extends State<PdfPagesView> {
  late List<GlobalKey> _keys;
  final _scroll = ScrollController();
  final _viewport = GlobalKey();
  int _current = 0;

  @override
  void initState() {
    super.initState();
    _keys = List.generate(widget.pages.length, (_) => GlobalKey());
  }

  /// مكتبة printing تُضيف الصفحات إلى نفس القائمة تباعاً أثناء التحويل (قائمة واحدة تتغير
  /// محتوياتها)، لذلك لا يمكن الاعتماد على didUpdateWidget لمعرفة تغيّر العدد: نُزامن المفاتيح هنا.
  void _syncKeys(int n) {
    while (_keys.length < n) {
      _keys.add(GlobalKey());
    }
    if (_keys.length > n) _keys = _keys.sublist(0, n);
    if (n == 0) {
      _current = 0;
    } else if (_current > n - 1) {
      _current = n - 1;
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _jump(int i) {
    if (i >= _keys.length) return;
    final ctx = _keys[i].currentContext;
    if (ctx == null) return;
    setState(() => _current = i);
    Scrollable.ensureVisible(ctx,
        duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  bool _onScroll(ScrollNotification n) {
    final vb = _viewport.currentContext?.findRenderObject() as RenderBox?;
    if (vb == null) return false;
    final mid = vb.localToGlobal(Offset(0, vb.size.height / 3)).dy;
    var best = 0;
    for (var i = 0; i < _keys.length; i++) {
      final rb = _keys[i].currentContext?.findRenderObject() as RenderBox?;
      if (rb == null || !rb.attached) continue;
      final top = rb.localToGlobal(Offset.zero).dy;
      if (top <= mid) best = i;
    }
    if (best != _current) setState(() => _current = best);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.pages.length;
    _syncKeys(n);
    return Column(children: [
      if (n > 1)
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            children: [
              for (var i = 0; i < n; i++)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: ChoiceChip(
                    key: ValueKey('pdf-page-$i'),
                    label: Text('ص${localizeDigits('${i + 1}')}'),
                    selected: _current == i,
                    onSelected: (_) => _jump(i),
                  ),
                ),
            ],
          ),
        ),
      Expanded(
        child: NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: SingleChildScrollView(
            key: _viewport,
            controller: _scroll,
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              for (var i = 0; i < n; i++)
                Container(
                  key: _keys[i],
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(color: Colors.white, boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: .18), blurRadius: 6)
                  ]),
                  child: AspectRatio(
                    aspectRatio: widget.pages[i].aspectRatio,
                    child: Image(image: widget.pages[i].image, fit: BoxFit.fill),
                  ),
                ),
            ]),
          ),
        ),
      ),
    ]);
  }
}
