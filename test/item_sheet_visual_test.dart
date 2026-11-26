import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:daftar/main.dart' show buildTheme;
import 'package:daftar/models/invoice_item.dart';
import 'package:daftar/widgets/item_edit_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final out = Platform.environment['SHOT_DIR'];
  testWidgets('item sheet wholesale + tiers', (t) async {
    if (out == null) return;
    await t.runAsync(() async {
      final l = FontLoader('IBMPlexSansArabic');
      for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
        l.addFont(Future.value(ByteData.sublistView(File('assets/fonts/IBMPlexSansArabic-$w.ttf').readAsBytesSync())));
      }
      await l.load();
      final m = FontLoader('MaterialIcons')
        ..addFont(Future.value(ByteData.sublistView(File('/home/sandbox/flutter/bin/cache/dart-sdk/bin/resources/devtools/assets/fonts/MaterialIcons-Regular.otf').readAsBytesSync())));
      await m.load();
    });
    t.view.physicalSize = const Size(540, 2100);
    t.view.devicePixelRatio = 1.5;
    final key = GlobalKey();
    await t.pumpWidget(RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: buildTheme(Brightness.light),
          home: Directionality(
              textDirection: TextDirection.rtl,
              child: Builder(
                  builder: (c) => Scaffold(
                      body: Center(
                          child: ElevatedButton(
                              onPressed: () => showItemEditSheet(c,
                                  item: InvoiceItem(itemCode: 'A1', description: 'كولا 330 مل', quantity: 12, unitPrice: 2, unit: 'حبة', wholesaleQty: 5, wholesalePrice: 44, wholesaleUnit: 'كرتون', packSize: 24),
                                  isNew: false, pinPrice: false, pinType: false),
                              child: const Text('open')))))),
        )));
    await t.tap(find.text('open'));
    await t.pump(const Duration(milliseconds: 600));
    await t.tap(find.text('شرائح السعر حسب الكمية'));
    await t.pump(const Duration(milliseconds: 300));
    await t.runAsync(() async {
      final rb = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = await rb.toImage(pixelRatio: 1);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      File('$out/item_sheet.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  });
}
