import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:printing/printing.dart';
import 'package:daftar/widgets/pdf_pages_view.dart';

final _png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==');

void main() {
  testWidgets('chips jump between pages and mark the current one', (t) async {
    final pages = [
      for (var i = 0; i < 3; i++)
        PdfPreviewPageData(image: MemoryImage(_png), width: 595, height: 842)
    ];
    await t.pumpWidget(MaterialApp(
        home: Scaffold(body: SizedBox(height: 500, child: PdfPagesView(pages: pages)))));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('pdf-page-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('pdf-page-2')), findsOneWidget);
    var c0 = t.widget<ChoiceChip>(find.byKey(const ValueKey('pdf-page-0')));
    expect(c0.selected, isTrue);
    await t.tap(find.byKey(const ValueKey('pdf-page-2')));
    await t.pumpAndSettle();
    final c2 = t.widget<ChoiceChip>(find.byKey(const ValueKey('pdf-page-2')));
    expect(c2.selected, isTrue);
    c0 = t.widget<ChoiceChip>(find.byKey(const ValueKey('pdf-page-0')));
    expect(c0.selected, isFalse);
  });
  testWidgets('single page shows no chips', (t) async {
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: PdfPagesView(pages: [
      PdfPreviewPageData(image: MemoryImage(_png), width: 595, height: 842)
    ]))));
    await t.pumpAndSettle();
    expect(find.byType(ChoiceChip), findsNothing);
  });
  testWidgets('pages appended to the same list while rasterising do not crash the view', (t) async {
    // مكتبة printing تضيف الصفحات تباعاً إلى القائمة نفسها: كان ذلك يُسقط العرض (شاشة رمادية).
    final pages = <PdfPreviewPageData>[
      PdfPreviewPageData(image: MemoryImage(_png), width: 595, height: 842)
    ];
    late StateSetter set;
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: StatefulBuilder(builder: (c, s) {
      set = s;
      return SizedBox(height: 500, child: PdfPagesView(pages: pages));
    }))));
    await t.pumpAndSettle();
    pages.add(PdfPreviewPageData(image: MemoryImage(_png), width: 595, height: 842));
    set(() {});
    await t.pumpAndSettle();
    pages.add(PdfPreviewPageData(image: MemoryImage(_png), width: 595, height: 842));
    set(() {});
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.byKey(const ValueKey('pdf-page-2')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('pdf-page-2')));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
}
