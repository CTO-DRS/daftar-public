import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../services/ocr_service.dart';
import '../utils/platform_utils.dart';
import 'scan_verification_screen.dart';

/// مسار المسح: التقاط/اختيار صورة، قص وتدوير، ثم شاشة المراجعة.
/// يعيد true إذا اعتمد المستخدم الفاتورة وحُفظت.
Future<bool> startScanFlow(BuildContext context) async {
  final source = !isMobilePlatform
      ? ImageSource.gallery
      : await showModalBottomSheet<ImageSource>(
    context: context,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          minTileHeight: 56,
          leading: const Icon(Icons.photo_camera_outlined),
          title: const Text('التقاط صورة بالكاميرا'),
          onTap: () => Navigator.pop(c, ImageSource.camera),
        ),
        ListTile(
          minTileHeight: 56,
          leading: const Icon(Icons.photo_library_outlined),
          title: const Text('اختيار من المعرض'),
          onTap: () => Navigator.pop(c, ImageSource.gallery),
        ),
      ]),
    ),
  );
  if (source == null || !context.mounted) return false;

  final messenger = ScaffoldMessenger.of(context);
  final nav = Navigator.of(context);
  try {
    final picked = await ImagePicker()
        .pickImage(source: source, maxWidth: 3000, maxHeight: 3000, imageQuality: 92);
    if (picked == null) return false;

    final cropped = !isMobilePlatform
        ? CroppedFile(picked.path)
        : await ImageCropper().cropImage(
      sourcePath: picked.path,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 92,
      maxWidth: 3000,
      maxHeight: 3000,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'قص وتدوير الصورة',
          toolbarColor: const Color(0xFF0F766E),
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: const Color(0xFF0F766E),
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
          hideBottomControls: false,
        ),
      ],
    );
    if (cropped == null) return false;

    // تحسين التباين وتصغير الحجم قبل المعالجة.
    final processed = await OcrService.preprocess(File(cropped.path));
    final saved = await nav.push<bool>(MaterialPageRoute(
        builder: (_) => ScanVerificationScreen(image: processed)));
    return saved ?? false;
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('تعذر فتح الصورة: $e')));
    return false;
  }
}
