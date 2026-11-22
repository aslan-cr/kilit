import 'package:flutter/services.dart';
import '../data/models.dart';
import 'store.dart';

/// Hava durumuna göre launcher ikonu (activity-alias). Sık değiştirmemek için 30 dk'da en çok bir kez.
class IconService {
  static const _ch = MethodChannel('skynav/native');
  /// Hava durumu → launcher ikonu.
  /// Sıcak tehlikesi: 33°C+ ya da UV 8+ turuncu güneş; 38°C+ ya da UV 10+ kırmızı, kıvırcık ışınlı güneş.
  static String keyFor(Analysis a, WeatherSnapshot s) {
    switch (a.kind) {
      case PrecipKind.lentilSnow: return 'lentil';
      case PrecipKind.blizzard: return 'blizzard';
      case PrecipKind.snow: return 'snow';
      case PrecipKind.sleet: return 'sleet';
      case PrecipKind.rain: return 'rain';
      case PrecipKind.none:
        if (s.temp >= 38 || s.uv >= 10) return 'sun_extreme';
        if (s.temp >= 33 || s.uv >= 8) return 'sun_hot';
        if (!s.isDay) return s.cloudCover <= 60 ? 'night' : 'cloudy';
        if (s.cloudCover > 70) return 'cloudy';
        return 'sun';
    }
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
