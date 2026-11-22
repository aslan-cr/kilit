import 'package:flutter/services.dart';

/// SkyNav launcher ikonu değiştirici (Android activity-alias).
class SkynavIcon {
  static const _ch = MethodChannel('skynav/icon');

  /// Dönüş: "same" (zaten bu ikon), "deferred" (uygulama ekranda, sonra denenecek), "changed".
  static Future<String> setIcon(String alias, List<String> all, {bool force = false}) async =>
      (await _ch.invokeMethod<String>('setIcon', {'alias': alias, 'all': all, 'force': force})) ?? 'same';

  static Future<String?> current(List<String> all) => _ch.invokeMethod<String>('current', {'all': all});

  static Future<bool> isForeground() async => (await _ch.invokeMethod<bool>('isForeground')) ?? false;
}
