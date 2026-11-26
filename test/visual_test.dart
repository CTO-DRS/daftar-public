import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:daftar/models/invoice.dart';
import 'package:daftar/utils/dashboard.dart';
import 'package:daftar/widgets/dashboard_header.dart';
import 'package:daftar/widgets/empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';

Future<void> _font() async {
  final l = FontLoader('IBMPlexSansArabic');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    l.addFont(Future.value(
        ByteData.sublistView(File('assets/fonts/IBMPlexSansArabic-$w.ttf').readAsBytesSync())));
  }
  await l.load();
}

Widget _app(Widget child, Brightness b) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
          useMaterial3: true,
          brightness: b,
          fontFamily: 'IBMPlexSansArabic',
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F766E), brightness: b)),
      home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: SafeArea(child: child))),
    );

void main() {
  final out = Platform.environment['SHOT_DIR'];
  for (final b in [Brightness.light, Brightness.dark]) {
    testWidgets('visual ${b.name}', (t) async {
      if (out == null) return;
      await t.runAsync(_font);
      t.view.physicalSize = const Size(540, 1000);
      t.view.devicePixelRatio = 1.5;
      final key = GlobalKey();
      final now = DateTime(2026, 11, 26);
      final list = [
        for (var m = 0; m < 6; m++)
          InvoiceSummary(
              Invoice(number: '$m', status: InvoiceStatus.confirmed, date: DateTime(2026, 6 + m, 5)),
              1, 1, [1200.0, 3400.0, 2100.0, 5200.0, 4100.0, 6350.0][m])
      ];
      await t.pumpWidget(_app(
          RepaintBoundary(
              key: key,
              child: Container(
                color: b == Brightness.dark ? const Color(0xFF101414) : const Color(0xFFF6F8F8),
                child: Column(children: [
                  DashboardHeader(stats: computeDashboard(list, now), currency: 'ر.س'),
                  const Expanded(
                      child: EmptyState(
                          title: 'ابدأ بأول فاتورة',
                          hint: 'اضغط «جديد» لإنشاء فاتورة أو جدول جرد.',
                          badge: Icons.add)),
                ]),
              )),
          b));
      await t.pump();
      await t.runAsync(() async {
        final r = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final img = await r.toImage(pixelRatio: 1.5);
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        File('$out/dash_${b.name}.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    });
  }
}
