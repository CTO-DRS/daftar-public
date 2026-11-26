import 'dart:typed_data';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:daftar/main.dart' show buildTheme;
import 'package:daftar/screens/about_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';

void main() {
  final out = Platform.environment['SHOT_DIR'];
  for (final b in [Brightness.light, Brightness.dark]) {
    testWidgets('sheet ${b.name}', (t) async {
      if (out == null) return;
      await t.runAsync(() async {
        final l = FontLoader('IBMPlexSansArabic');
        for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
          l.addFont(Future.value(ByteData.sublistView(
              File('assets/fonts/IBMPlexSansArabic-$w.ttf').readAsBytesSync())));
        }
        await l.load();
        final m = FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(File('/home/sandbox/flutter/bin/cache/dart-sdk/bin/resources/devtools/assets/fonts/MaterialIcons-Regular.otf').readAsBytesSync())));
        await m.load();
        final fa = FontLoader('FABrands')
          ..addFont(Future.value(ByteData.sublistView(File('assets/fonts/FABrands.otf').readAsBytesSync())));
        await fa.load();
      });
      t.view.physicalSize = const Size(540, 820);
      t.view.devicePixelRatio = 1.5;
      final key = GlobalKey();
      await t.pumpWidget(RepaintBoundary(key: key, child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildTheme(b),
        home: Directionality(
            textDirection: TextDirection.rtl,
            child: const Scaffold(
                    body: DeveloperBackdrop(
                        child: SafeArea(
                            child: Padding(padding: EdgeInsets.all(16), child: DeveloperSection()))))),
      )));
      await t.runAsync(() async {
        await precacheImage(const AssetImage('assets/images/developer.jpg'),
            t.element(find.byType(DeveloperCard)));
      });
      await t.pump();
      await t.tap(find.text('تيليجرام'));
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      await t.runAsync(() async {
        final r = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final img = await r.toImage(pixelRatio: 1.5);
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        File('$out/sheet_${b.name}.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    });
  }
}
