import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// ماسح باركود: يعيد أول رمز يُقرأ (EAN/UPC/QR/Code128...).
class BarcodeScanScreen extends StatefulWidget {
  const BarcodeScanScreen({super.key});
  @override
  State<BarcodeScanScreen> createState() => _BarcodeScanScreenState();
}

class _BarcodeScanScreenState extends State<BarcodeScanScreen> {
  final _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates, formats: const []);
  bool _done = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture cap) {
    if (_done) return;
    for (final b in cap.barcodes) {
      final v = b.rawValue;
      if (v != null && v.isNotEmpty) {
        _done = true;
        Navigator.pop(context, v);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('امسح الباركود'), actions: [
          IconButton(
              icon: const Icon(Icons.flash_on),
              onPressed: () => _controller.toggleTorch()),
        ]),
        body: Stack(children: [
          MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
              errorBuilder: (c, e) => Center(
                  child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                    'تعذر فتح الكاميرا. اسمح لدفتر باستخدام الكاميرا من إعدادات الجهاز.',
                    textAlign: TextAlign.center),
              ))),
          Center(
            child: Container(
              width: 260,
              height: 160,
              decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ]),
      );
}
