import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../database/app_database.dart';
import '../models/invoice.dart';
import '../services/file_saver.dart';
import '../services/pdf_service.dart';
import '../services/logo_service.dart';
import '../services/settings_service.dart';
import '../utils/platform_utils.dart';
import '../widgets/responsive.dart';

/// معاينة PDF داخل التطبيق + مشاركة (واتساب وغيره) + حفظ في الهاتف + طباعة.
class PdfPreviewScreen extends StatefulWidget {
  final Invoice invoice;
  const PdfPreviewScreen({super.key, required this.invoice});

  @override
  State<PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends State<PdfPreviewScreen> {
  late final Future<Uint8List> _bytes = _build();

  Future<Uint8List> _build() async {
    final party = await AppDatabase.instance.partyByName(widget.invoice.party);
    return PdfService.build(
        widget.invoice,
        partyPhone: party?.phone ?? '',
        partyAddress: party?.address ?? '',
        currency: SettingsService.instance.currency,
        company: SettingsService.instance.companyName,
        logo: await LogoService.load(),
    );
  }

  String get _fileName =>
      '${widget.invoice.kind == DocKind.invoice ? 'invoice' : 'inventory'}-${widget.invoice.number}.pdf'
          .replaceAll(RegExp(r'[^\w.\-]'), '_');

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
      appBar: AppBar(title: const Text('معاينة PDF')),
      body: FutureBuilder<Uint8List>(
        future: _bytes,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('تعذر إنشاء الملف: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final bytes = snap.data!;
          return ContentWidth(maxWidth: 1000, child: Column(children: [
            Expanded(
              child: PdfPreview(
                build: (_) async => bytes,
                pdfFileName: _fileName,
                canChangeOrientation: false,
                canChangePageFormat: false,
                canDebug: false,
                allowPrinting: true,
                allowSharing: true,
                loadingWidget: const CircularProgressIndicator(),
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
