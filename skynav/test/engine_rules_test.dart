import 'package:flutter_test/flutter_test.dart';
import 'package:skynav/astro/space_events.dart';
import 'package:skynav/astro/star_catalog.dart';
import 'package:skynav/data/models.dart';
import 'package:skynav/engine/weather_engine.dart';
import 'package:skynav/ui/sky_stars.dart';

WeatherSnapshot snap({double t = 0, double wind = 2, double precip = 0, double snowfall = 0, double? fl, double snowDepth = 0, List<Mountain> mountains = const [], double windDir = 0, double cloud = 20, double hum = 70}) =>
    WeatherSnapshot(
      place: const GeoPoint2(39.9, 41.27, elevation: 1850), fetchedAt: DateTime.utc(2026, 11, 23, 21),
      temp: t, feelsLike: t, humidity: hum, dewPoint: t - 5, pressure: 1015, windSpeed: wind, windDir: windDir, windGust: wind * 1.4,
      cloudCover: cloud, cloudHigh: 0, precip: precip, snowfall: snowfall, visibilityM: 10000, cape: 0, uv: 0,
      freezingLevelM: fl, snowDepthM: snowDepth, weatherCode: 0, isDay: false, mountains: mountains,
    );

void main() {
  const snowyPeak = Mountain(lat: 40, lon: 41.1, elevation: 3100, distanceKm: 20, bearingDeg: 300, snowDepthM: .8, tempC: -6);

  test('ılık havada uzak karlı dağ tipi yapmaz', () {
    final a = WeatherEngine.analyze(snap(t: 15, wind: 8, windDir: 300, mountains: const [snowyPeak]));
    expect(a.kind, PrecipKind.none);
  });

  test('soğuk, sert rüzgâr ve rüzgâr üstü karlı dağ: savrulan kar (tipi)', () {
    final a = WeatherEngine.analyze(snap(t: -6, wind: 11, windDir: 300, mountains: const [snowyPeak]));
    expect(a.kind, PrecipKind.blizzard);
  });

  test('rüzgâr dağdan değil, karşı yönden eserse tipi yok', () {
    final a = WeatherEngine.analyze(snap(t: -6, wind: 11, windDir: 120, mountains: const [snowyPeak]));
    expect(a.kind, PrecipKind.none);
  });

  test('donma seviyesi 200 m yukarıdayken soğuk zeminde yağış kar olur', () {
    final a = WeatherEngine.analyze(snap(t: -0.5, precip: 1, snowfall: .8, fl: 2050, hum: 95));
    expect(a.kind, PrecipKind.snow);
  });

  test('tutulma listesi sıralı ve 2030 sonuna kadar dolu', () {
    for (var i = 1; i < eclipses.length; i++) { expect(eclipses[i].utcDay.isAfter(eclipses[i - 1].utcDay), isTrue); }
    expect(eclipses.last.utcDay.year, 2030);
    expect(nextEclipse(DateTime.utc(2028, 12, 1))!.utcDay, DateTime.utc(2028, 12, 31));
  });

  test('yıldız koordinatları geçerli aralıkta', () {
    for (final s in brightStars) {
      expect(s.raDeg, inInclusiveRange(0, 360), reason: s.name);
      expect(s.decDeg, inInclusiveRange(-90, 90), reason: s.name);
    }
  });

  test('sahne gökyüzü: gerçek yıldız ve gezegenler, alacakaranlık ve Ay ışığı', () {
    final dark = DateTime.utc(2026, 12, 9, 21); // Erzurum, aysız gece
    expect(SceneSky.limitAt(39.9, 41.27, dark), greaterThan(4.5));
    expect(SceneSky.limitAt(39.9, 41.27, DateTime.utc(2026, 12, 9, 9)), lessThan(-4)); // öğlen: yalnızca Venüs olabilir
    expect(SceneSky.limitAt(39.9, 41.27, DateTime.utc(2026, 11, 24, 21)), lessThan(3.6)); // dolunay yüksekte
    final dots = SceneSky.at(39.9, 41.27, dark);
    expect(dots.where((d) => d.mag < 5).length, greaterThan(150));
    final jup = dots.where((d) => d.name == 'jupiter');
    expect(jup, isNotEmpty);
    expect(jup.first.mag, lessThan(-1.5));
    for (final d in dots) { expect(d.alt, greaterThan(0)); expect(d.along, inInclusiveRange(-.02, 1.02)); }
    // Kuzeyde güneye, güneyde kuzeye bakış: tam karşı ortada, doğu kuzeyde solda.
    expect(SceneSky.along(180, 40), .5);
    expect(SceneSky.along(90, 40), 0);
    expect(SceneSky.along(0, -33), .5);
    expect(SceneSky.along(90, -33), 1);
  });
}
