import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../database/app_database.dart';
import '../services/file_saver.dart';
import '../services/logo_service.dart';
import '../services/pdf_service.dart';
import '../services/settings_service.dart';
import '../utils/platform_utils.dart';
import '../utils/statement.dart';
import '../widgets/responsive.dart';

/// كشف حساب عميل/مورد: معاينة PDF ومشاركة وحفظ وطباعة.
class StatementScreen extends StatefulWidget {
  final String party;
  const StatementScreen({super.key, required this.party});
  @override
  State<StatementScreen> createState() => _StatementScreenState();
}

class _StatementScreenState extends State<StatementScreen> {
  late final Future<Uint8List> _bytes = _build();

  Future<Uint8List> _build() async {
    final s = SettingsService.instance;
    final all = await AppDatabase.instance.listInvoices();
    final now = DateTime.now();
    final st = buildStatement(all, widget.party, now, currency: s.currency);
    final p = await AppDatabase.instance.partyByName(widget.party);
    return PdfService.buildStatementPdf(st,
        currency: s.currency,
        company: s.companyName,
        logo: await LogoService.load(),
        partyPhone: p?.phone ?? '',
        now: now,
        brandColor: s.brandColor,
        template: PdfTemplateX.fromDb(s.pdfTemplate));
  }

  String get _fileName {
    final d = DateTime.now();
    final date = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    return 'statement-$date.pdf';
  }

  Future<void> _save(Uint8List bytes) async {
    final m = ScaffoldMessenger.of(context);
    try {
      final where = await FileSaver.saveToDownloads(bytes, _fileName);
      m.showSnackBar(SnackBar(content: Text('تم الحفظ في $where')));
    } catch (e) {
      m.showSnackBar(SnackBar(content: Text('تعذر الحفظ: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('كشف حساب: ${widget.party}')),
      body: FutureBuilder<Uint8List>(
        future: _bytes,
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('تعذر إنشاء الكشف: ${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final bytes = snap.data!;
          return ContentWidth(
              maxWidth: 1000,
              child: Column(children: [
                Expanded(
                  child: PdfPreview(
                    build: (_) async => bytes,
                    pdfFileName: _fileName,
                    canChangeOrientation: false,
                    canChangePageFormat: false,
                    canDebug: false,
                    allowPrinting: true,
                    allowSharing: true,
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    child: Row(children: [
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: FilledButton.icon(
                            onPressed: () => isDesktopPlatform
                                ? Printing.layoutPdf(onLayout: (_) async => bytes, name: _fileName)
                                : Printing.sharePdf(bytes: bytes, filename: _fileName),
                            icon: Icon(isDesktopPlatform ? Icons.print : Icons.share),
                            label: Text(isDesktopPlatform ? 'طباعة' : 'مشاركة (واتساب)'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: FilledButton.tonalIcon(
                            onPressed: () => _save(bytes),
                            icon: const Icon(Icons.download),
                            label: const Text('حفظ في الهاتف'),
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
              ]));
        },
      ),
    );
  }
}
