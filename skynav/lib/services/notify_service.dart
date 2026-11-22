import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class Notify {
  static final _p = FlutterLocalNotificationsPlugin();
  static bool _ok = false;
  static Future<void> init() async {
    try {
      await _p.initialize(const InitializationSettings(android: AndroidInitializationSettings('ic_stat')));
      _ok = true;
    } catch (_) {}
  }
  static Future<void> requestPermission() async {
    try { await _p.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission(); } catch (_) {}
  }
  /// Sistemin kendi bildirim sesi kullanılır (sentetik ses yok).
  static Future<void> show(String title, String body) async {
    if (!_ok) return;
    try {
      await _p.show(DateTime.now().millisecondsSinceEpoch ~/ 1000, title, body,
          const NotificationDetails(android: AndroidNotificationDetails('skynav_main', 'SkyNav', importance: Importance.high, priority: Priority.high)));
    } catch (_) {}
  }
}
