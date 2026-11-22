import 'package:flutter/services.dart';
import '../data/models.dart';
import 'store.dart';

/// Hava durumuna göre launcher ikonu (activity-alias). Sık değiştirmemek için 30 dk'da en çok bir kez.
class IconService {
  static const _ch = MethodChannel('skynav/native');
  static String keyFor(Analysis a, WeatherSnapshot s) {
    if (a.kind == PrecipKind.lentilSnow || a.kind == PrecipKind.blizzard) return 'lentil';
    if (a.kind == PrecipKind.snow || a.kind == PrecipKind.sleet) return 'snow';
    if (s.temp >= 30 || s.uv >= 8) return 'sun';
    if (!s.isDay && s.cloudCover <= 60) return 'night';
    return 'snow';
  }
  static Future<void> maybeUpdate(Analysis? a, WeatherSnapshot? s) async {
    if (a == null || s == null) return;
    final last = (Store.prefs.get('icon_t') as int?) ?? 0;
    if (DateTime.now().millisecondsSinceEpoch - last < 30 * 60 * 1000) return;
    final k = keyFor(a, s);
    if (k == Store.prefs.get('icon_key')) return;
    try {
      await _ch.invokeMethod('setIcon', k);
      await Store.put('icon_key', k);
      await Store.put('icon_t', DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }
}
