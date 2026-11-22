import 'package:skynav_icon/skynav_icon.dart';
import '../data/models.dart';
import 'store.dart';

/// Hava durumuna göre launcher ikonu (activity-alias). Sık değiştirmemek için 30 dk'da en çok bir kez.
class IconService {
  static const aliases = <String, String>{
    'snow': 'IconSnow', 'lentil': 'IconLentil', 'blizzard': 'IconBlizzard', 'rain': 'IconRain',
    'sleet': 'IconSleet', 'cloudy': 'IconCloudy', 'night': 'IconNight', 'sun': 'IconSun',
    'sun_hot': 'IconSunHot', 'sun_extreme': 'IconSunExtreme',
  };
  static bool get enabled => Store.prefs.get('dyn_icon', defaultValue: true) as bool;
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

  /// Uygulama içinden: istenen ikonu kaydeder, uygulama ekrandayken DEĞİŞTİRMEZ (Android uygulamayı kapatabiliyor).
  /// Asıl değişiklik [applyPending] ile uygulama arka plana geçince ya da arka plan görevinde yapılır.
  static Future<void> maybeUpdate(Analysis? a, WeatherSnapshot? s) async {
    if (a == null || s == null || !enabled) return;
    await Store.put('icon_pending', keyFor(a, s));
  }

  /// Uygulama arka plana geçerken (ya da arka plan görevinde) bekleyen ikonu uygula. 30 dk'da en çok bir kez.
  static Future<String> applyPending({bool force = false}) async {
    final reset = Store.prefs.get('icon_reset', defaultValue: false) as bool;
    if (!enabled && !reset) return 'off';
    final key = reset ? 'snow' : Store.prefs.get('icon_pending') as String?;
    if (key == null || !aliases.containsKey(key)) return 'none';
    final last = (Store.prefs.get('icon_t') as int?) ?? 0;
    if (!reset && key != Store.prefs.get('icon_key') && DateTime.now().millisecondsSinceEpoch - last < 30 * 60 * 1000) return 'throttled';
    try {
      final r = await SkynavIcon.setIcon(aliases[key]!, aliases.values.toList(), force: force);
      if (r == 'changed' || r == 'same') {
        await Store.put('icon_key', key);
        if (reset) await Store.put('icon_reset', false);
        if (r == 'changed') await Store.put('icon_t', DateTime.now().millisecondsSinceEpoch);
      }
      return r;
    } catch (_) { return 'error'; }
  }

  /// Arka plan görevi için: hesapla ve uygulama ekranda değilse hemen uygula.
  static Future<String> updateFromBackground(Analysis a, WeatherSnapshot s) async {
    if (!enabled) return 'off';
    await Store.put('icon_pending', keyFor(a, s));
    return applyPending();
  }

  /// Ayarlardan kapatılınca varsayılan (kar kristali) ikona dön; uygulama arka plana geçince uygulanır.
  static Future<void> setEnabled(bool v) async {
    await Store.put('dyn_icon', v);
    await Store.put('icon_reset', !v);
  }
}
