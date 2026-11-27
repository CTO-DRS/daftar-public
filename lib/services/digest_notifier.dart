import 'dart:io' show Platform;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// تذكير أسبوعي اختياري: «ملخص أسبوعك جاهز». النص ثابت (الأرقام تظهر داخل التطبيق)
/// لأن الإشعار المجدول لا يعرف بيانات المستقبل. أندرويد فقط، ولا يحتاج إنترنت.
class DigestNotifier {
  DigestNotifier._();
  static final instance = DigestNotifier._();
  static const _id = 7301;
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _inited = false;

  static bool get supported => Platform.isAndroid;

  Future<void> _init() async {
    if (_inited) return;
    await _plugin.initialize(
        settings: const InitializationSettings(
            android: AndroidInitializationSettings('@mipmap/ic_launcher')));
    _inited = true;
  }

  /// يطلب الإذن ثم يجدول إشعاراً كل أسبوع. يعيد false إن رُفض الإذن.
  Future<bool> enable() async {
    if (!supported) return false;
    await _init();
    final android =
        _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final ok = await android?.requestNotificationsPermission() ?? false;
    if (!ok) return false;
    await _plugin.periodicallyShow(
      id: _id,
      title: 'ملخص أسبوعك في دفتر',
      body: 'مبيعاتك مقارنة بالأسبوع الماضي، والعملاء الذين يحتاجون متابعة. افتح دفتر لتراها.',
      repeatInterval: RepeatInterval.weekly,
      notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails('weekly_digest', 'الملخص الأسبوعي',
              channelDescription: 'تذكير أسبوعي بملخص المبيعات والمتابعات')),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
    return true;
  }

  Future<void> disable() async {
    if (!supported) return;
    await _init();
    await _plugin.cancel(id: _id);
  }
}
