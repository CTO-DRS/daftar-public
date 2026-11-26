import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:daftar/main.dart' show buildTheme;
import 'package:daftar/models/invoice.dart';
import 'package:daftar/models/invoice_item.dart';
import 'package:daftar/widgets/item_tile.dart';
import 'package:daftar/widgets/totals_bar.dart';
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
      theme: buildTheme(b),
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
      t.view.physicalSize = const Size(540, 1200);
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
                  Padding(
                      padding: const EdgeInsets.all(12),
                      child: ItemTile(
                          index: 1,
                          item: InvoiceItem(itemCode: 'A1', description: 'مفتاح كهربائي مزدوج', quantity: 12, unitPrice: 12.5, unit: 'درزن', notes: 'عاجل'),
                          onTap: () {}, onDuplicate: () {}, onDelete: () {})),
                  const Expanded(
                      child: EmptyState(
                          title: 'ابدأ بأول فاتورة',
                          hint: 'اضغط «جديد» لإنشاء فاتورة أو جدول جرد.',
                          badge: Icons.add)),
                  const TotalsBar(itemCount: 3, totalQty: 40, grandTotal: 1250, currency: 'ر.س', subtotal: 1087.5, vatAmount: 162.5, vatRate: 15),
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
