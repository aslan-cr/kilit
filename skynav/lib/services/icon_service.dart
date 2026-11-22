import 'package:skynav_icon/skynav_icon.dart';
import '../data/models.dart';
import 'shared_state.dart';

/// Hava durumuna göre launcher ikonu (activity-alias).
///
/// Android (özellikle Samsung) uygulamayı başlatan alias kapatılınca uygulamayı sonlandırabiliyor.
/// Bu yüzden ikon ASLA uygulama açıkken ya da yeni kapatılmışken değiştirilmez:
/// yalnızca uygulama ekranda değilken VE en az [idle] süredir kullanılmıyorken, arka plan görevinde uygulanır.
class IconService {
  static const aliases = <String, String>{
    'snow': 'IconSnow', 'lentil': 'IconLentil', 'blizzard': 'IconBlizzard', 'rain': 'IconRain',
    'sleet': 'IconSleet', 'cloudy': 'IconCloudy', 'night': 'IconNight', 'sun': 'IconSun',
    'sun_hot': 'IconSunHot', 'sun_extreme': 'IconSunExtreme',
  };
  static const idle = Duration(minutes: 2, seconds: 30);
  static const _minGap = Duration(minutes: 30);

  static bool get enabled => SharedState.cached?.getBool('sn_dyn_icon') ?? true;

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

  /// Uygulama içinden: istenen ikonu yalnızca KAYDEDER.
  static Future<void> maybeUpdate(Analysis? a, WeatherSnapshot? s) async {
    if (a == null || s == null || !enabled) return;
    await (await SharedState.get()).setString('sn_icon_pending', keyFor(a, s));
  }

  /// Uygulama ön plana gelince / arka plana geçince çağrılır (son kullanım anını tutar).
  static Future<void> markForeground(bool fg) async {
    final p = await SharedState.get();
    await p.setInt('sn_last_used', DateTime.now().millisecondsSinceEpoch);
    await p.setBool('sn_fg', fg);
  }

  /// Bekleyen ikonu uygula: sadece uygulama ekranda değilse ve [idle] süredir kullanılmıyorsa.
  /// Dönüş: off | none | busy | throttled | deferred | same | changed | error
  static Future<String> applyPending() async {
    final p = await SharedState.fresh();
    final reset = p.getBool('sn_icon_reset') ?? false;
    if (!(p.getBool('sn_dyn_icon') ?? true) && !reset) return 'off';
    final key = reset ? 'snow' : p.getString('sn_icon_pending');
    if (key == null || !aliases.containsKey(key)) return 'none';
    final now = DateTime.now().millisecondsSinceEpoch;
    final lastUsed = p.getInt('sn_last_used') ?? 0;
    if ((p.getBool('sn_fg') ?? false) || now - lastUsed < idle.inMilliseconds) return 'busy';
    final last = p.getInt('sn_icon_t') ?? 0;
    if (!reset && key != p.getString('sn_icon_key') && now - last < _minGap.inMilliseconds) return 'throttled';
    try {
      final r = await SkynavIcon.setIcon(aliases[key]!, aliases.values.toList());
      if (r == 'changed' || r == 'same') {
        await p.setString('sn_icon_key', key);
        if (reset) await p.setBool('sn_icon_reset', false);
        if (r == 'changed') await p.setInt('sn_icon_t', now);
      }
      return r;
    } catch (_) { return 'error'; }
  }

  /// Arka plan görevi için: hesapla, kaydet, koşullar uygunsa uygula.
  static Future<String> updateFromBackground(Analysis a, WeatherSnapshot s) async {
    final p = await SharedState.fresh();
    if (!(p.getBool('sn_dyn_icon') ?? true)) return applyPending(); // kapalıysa yalnızca sıfırlamayı uygula
    await p.setString('sn_icon_pending', keyFor(a, s));
    return applyPending();
  }

  /// Ayarlardan kapatılınca varsayılan (kar kristali) ikona dön; uygulama kullanılmadığında uygulanır.
  static Future<void> setEnabled(bool v) async {
    final p = await SharedState.get();
    await p.setBool('sn_dyn_icon', v);
    await p.setBool('sn_icon_reset', !v);
  }
}
