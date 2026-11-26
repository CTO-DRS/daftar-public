import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:daftar/main.dart' show buildTheme;
import 'package:daftar/models/invoice.dart';
import 'package:daftar/models/invoice_item.dart';
import 'package:daftar/screens/insights_screen.dart';
import 'package:daftar/utils/insights.dart';
import 'package:daftar/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

InvoiceSummary _mk(String party, double total, DateTime date,
    {DateTime? due, InvoiceStatus st = InvoiceStatus.confirmed, String no = '1', double paid = 0}) {
  final inv = Invoice(
      number: no, date: date, party: party, dueDate: due, status: st, paidAmount: paid,
      items: [InvoiceItem(description: 'x', quantity: 1, unitPrice: total)]);
  return InvoiceSummary(inv, 1, 1, inv.grandTotal);
}

void main() {
  final out = Platform.environment['SHOT_DIR'];
  for (final b in [Brightness.light, Brightness.dark]) {
    testWidgets('insights ${b.name}', (t) async {
      if (out == null) return;
      await t.runAsync(() async {
        SharedPreferences.setMockInitialValues({});
        await SettingsService.instance.init();
        final l = FontLoader('IBMPlexSansArabic');
        for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
          l.addFont(Future.value(ByteData.sublistView(File('assets/fonts/IBMPlexSansArabic-$w.ttf').readAsBytesSync())));
        }
        await l.load();
        final m = FontLoader('MaterialIcons')
          ..addFont(Future.value(ByteData.sublistView(File('/home/sandbox/flutter/bin/cache/dart-sdk/bin/resources/devtools/assets/fonts/MaterialIcons-Regular.otf').readAsBytesSync())));
        await m.load();
      });
      t.view.physicalSize = const Size(540, 2700);
      t.view.devicePixelRatio = 1.5;
      final now = DateTime(2026, 11, 26);
      final r = computeInsights([
        _mk('مؤسسة النور', 14200, DateTime(2026, 11, 3), due: DateTime(2026, 12, 3), no: '1041'),
        _mk('مؤسسة النور', 9000, DateTime(2026, 10, 5), st: InvoiceStatus.paid, no: '1030'),
        _mk('شركة الأفق', 8600, DateTime(2026, 8, 10), due: DateTime(2026, 8, 25), no: '1012'),
        _mk('شركة الأفق', 3100, DateTime(2026, 10, 9), due: DateTime(2026, 11, 10), no: '1033'),
        _mk('مطعم السلام', 5200, DateTime(2026, 11, 8), due: DateTime(2026, 12, 20), no: '1044'),
        _mk('أبو خالد', 2300, DateTime(2026, 10, 20), st: InvoiceStatus.paid, no: '1036'),
        _mk('أبو خالد', 1900, DateTime(2026, 11, 15), due: DateTime(2026, 11, 30), no: '1047'),
      ], now, currency: 'ر.س', products: const [
        ProductSales('مفتاح كهربائي مزدوج', 320, 9600),
        ProductSales('كيبل نحاس 2.5 مم', 90, 7200),
        ProductSales('لمبة LED 12 واط', 410, 4100),
      ]);
      final key = GlobalKey();
      await t.pumpWidget(RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            locale: const Locale('ar'),
            supportedLocales: const [Locale('ar')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            theme: buildTheme(b),
            home: Directionality(textDirection: TextDirection.rtl, child: InsightsScreen(preloaded: r)),
          )));
      await t.pump();
      await t.runAsync(() async {
        final rb = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final img = await rb.toImage(pixelRatio: 1);
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        File('$out/insights_${b.name}.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    });
  }
}
