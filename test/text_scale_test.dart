import 'package:daftar/main.dart' show buildTheme;
import 'package:daftar/models/invoice.dart';
import 'package:daftar/models/invoice_item.dart';
import 'package:daftar/utils/dashboard.dart';
import 'package:daftar/widgets/dashboard_header.dart';
import 'package:daftar/widgets/empty_state.dart';
import 'package:daftar/widgets/item_tile.dart';
import 'package:daftar/widgets/totals_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// الخط الكبير في إعدادات النظام (حتى 200%) يجب ألا يكسر الواجهة بأخطاء تجاوز.
void main() {
  for (final scale in [1.3, 2.0]) {
    testWidgets('core widgets survive text scale $scale on a narrow phone', (t) async {
      t.view.physicalSize = const Size(360, 780);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);
      final now = DateTime(2026, 11, 26);
      final list = [
        for (var m = 0; m < 6; m++)
          InvoiceSummary(Invoice(number: '$m', status: InvoiceStatus.confirmed, date: DateTime(2026, 6 + m, 5)), 1, 1, 1200.0 * (m + 1))
      ];
      await t.pumpWidget(MaterialApp(
        theme: buildTheme(Brightness.light),
        builder: (c, w) => MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)), child: w!),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            bottomNavigationBar: const TotalsBar(itemCount: 3, totalQty: 4000, grandTotal: 1250000.5, currency: 'ر.س', subtotal: 1087000.5, vatAmount: 162500, vatRate: 15),
            body: SafeArea(
              child: ListView(children: [
                DashboardHeader(stats: computeDashboard(list, now), currency: 'ر.س'),
                ItemTile(
                    index: 1,
                    item: InvoiceItem(itemCode: 'W-2130', description: 'بناجر بناتي أوميغا موديل طويل جداً', quantity: 12, unitPrice: 12.5, unit: 'درزن', notes: 'عاجل'),
                    onTap: () {}, onDuplicate: () {}, onDelete: () {}),
                const SizedBox(height: 300, child: EmptyState(title: 'ابدأ بأول فاتورة', hint: 'اضغط «جديد» لإنشاء فاتورة أو جدول جرد.', badge: Icons.add)),
              ]),
            ),
          ),
        ),
      ));
      await t.pump();
      final ex = t.takeException();
      if (ex != null) { debugPrint("EXC: $ex"); }
      expect(ex, isNull);
    });
  }
}
