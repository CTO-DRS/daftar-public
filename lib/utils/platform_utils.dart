import 'dart:io' show Platform;

/// أندرويد/آيفون: الكاميرا وقص الصور ومسح ML Kit المحلي متاحة.
bool get isMobilePlatform => Platform.isAndroid || Platform.isIOS;

bool get isDesktopPlatform =>
    Platform.isWindows || Platform.isLinux || Platform.isMacOS;
