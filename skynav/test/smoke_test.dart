import 'package:flutter_test/flutter_test.dart';
import 'package:skynav/data/models.dart';
import 'package:skynav/engine/lab_calculators.dart';
import 'package:skynav/engine/validator.dart';
import 'package:skynav/engine/weather_engine.dart';

WeatherSnapshot snap({double t = -3, double cloud = 90, double wind = 12}) => WeatherSnapshot(
      place: const GeoPoint2(39.9, 41.27, elevation: 1850, name: 'Erzurum'), fetchedAt: DateTime.now(),
      temp: t, feelsLike: t - 6, humidity: 92, dewPoint: t - 1, pressure: 1008, windSpeed: wind, windDir: 300, windGust: wind * 1.5,
      cloudCover: cloud, cloudHigh: 40, precip: 1.2, snowfall: 1.0, visibilityM: 1500, cape: 20, uv: 1, freezingLevelM: 900,
      snowDepthM: .2, wetBulb: t - .8, weatherCode: 73, isDay: true,
      mountains: const [Mountain(lat: 40, lon: 41.1, elevation: 3100, distanceKm: 25, bearingDeg: 300, snowDepthM: .8, tempC: -12)],
    );

void main() {
  test('motor + lab + doğrulama (çevrimdışı örnek veri)', () {
    final s = snap();
    final a = WeatherEngine.analyze(s);
    final lab = computeLab(s, a);
    expect(a.kind == PrecipKind.snow || a.kind == PrecipKind.blizzard || a.kind == PrecipKind.lentilSnow, isTrue, reason: a.kind.name);
    expect(a.mountainBonusPct, greaterThan(0));
    expect(lab.length, greaterThan(20));
    expect(Validator.verify(s, a), isTrue);
    expect(WeatherEngine.analyze(snap(cloud: 80)).starClarity, 0);
  });
  test('doğrulayıcı aykırı değeri reddeder', () {
    final bad = snap(t: 80);
    expect(Validator.verify(bad, WeatherEngine.analyze(bad)), isFalse);
  });
}
