import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:skynav/astro/space_events.dart';
import 'package:skynav/astro/sky_times.dart';
import 'package:skynav/astro/star_catalog.dart';
import 'package:skynav/engine/alerts.dart';
import 'package:skynav/engine/brief.dart';
import 'package:skynav/services/climate_service.dart';
import 'package:skynav/services/air_service.dart';
import 'package:skynav/engine/best_time.dart';
import 'package:skynav/engine/compare.dart';
import 'package:skynav/engine/nowcast.dart';
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

  WeatherSnapshot withHours(WeatherSnapshot b, DateTime now, List<(double t, double pr, double sn, int code, double gust)> hs) => WeatherSnapshot(
      place: b.place, fetchedAt: now, temp: b.temp, feelsLike: b.feelsLike, humidity: b.humidity, dewPoint: b.dewPoint, pressure: b.pressure,
      windSpeed: b.windSpeed, windDir: b.windDir, windGust: b.windGust, cloudCover: b.cloudCover, cloudHigh: 0, precip: b.precip, snowfall: b.snowfall,
      visibilityM: 10000, cape: b.cape, uv: 0, weatherCode: 0, isDay: b.isDay,
      hourly: [for (var i = 0; i < hs.length; i++) HourPoint(time: now.add(Duration(hours: i - 2)), temp: hs[i].$1, precip: hs[i].$2, snowfall: hs[i].$3,
          windSpeed: 4, windDir: 0, cloud: 80, humidity: 85, dewPoint: hs[i].$1 - 2, weatherCode: hs[i].$4, gust: hs[i].$5)]);

  test('uyarılar: yağmur sonrası don → buzlanma, yoğun kar, gök gürültüsü, sakin havada yok', () {
    final now = DateTime(2026, 12, 1, 18);
    final calm = withHours(snap(t: 8), now, [for (var i = 0; i < 14; i++) (8.0, 0.0, 0.0, 2, 6.0)]);
    expect(weatherAlerts(calm, WeatherEngine.analyze(calm), now), isEmpty);
    final ice = withHours(snap(t: 2), now, [(3, 1.2, 0, 61, 6), (2, .6, 0, 61, 6), (1, 0, 0, 3, 5), (0, 0, 0, 3, 5), (-1, 0, 0, 3, 5), (-2, 0, 0, 3, 5),
      for (var i = 0; i < 8; i++) (-3.0, 0.0, 0.0, 3, 5.0)]);
    expect(weatherAlerts(ice, WeatherEngine.analyze(ice), now).map((e) => e.key), contains('ice'));
    final snowy = withHours(snap(t: -3), now, [(-3, 0, 0, 3, 5), (-3, 0, 0, 3, 5), for (var i = 0; i < 6; i++) (-4.0, 1.6, 2.2, 75, 8.0), for (var i = 0; i < 6; i++) (-4.0, 0.0, 0.0, 3, 5.0)]);
    expect(weatherAlerts(snowy, WeatherEngine.analyze(snowy), now).map((e) => e.key), contains('heavySnow'));
    final storm = withHours(snap(t: 22), now, [for (var i = 0; i < 4; i++) (22.0, 0.0, 0.0, 2, 8.0), (21, 6, 0, 95, 26), for (var i = 0; i < 9; i++) (20.0, 0.0, 0.0, 3, 8.0)]);
    final keys = weatherAlerts(storm, WeatherEngine.analyze(storm), now).map((e) => e.key).toList();
    expect(keys.first, 'storm');
    expect(keys, contains('gale'));
  });

  test('gök zamanları: fotoğrafçı saatleri, Ay doğuş/batış ve dolunay (PyEphem ile ±2 dk / ±15 dk)', () {
    final day = DateTime.utc(2026, 11, 22, 21); // Erzurum 23 Kasım yerel gece yarısı
    final p = PhotoHours.of(39.9, 41.27, day);
    void near(DateTime? a, DateTime b, int minutes) => expect(a!.difference(b).inMinutes.abs(), lessThanOrEqualTo(minutes), reason: '$a ~ $b');
    near(p.morningGolden!.start, DateTime.utc(2026, 11, 23, 3, 50), 2);
    near(p.eveningGolden!.start, DateTime.utc(2026, 11, 23, 13, 12), 2);
    near(p.eveningBlue!.end, DateTime.utc(2026, 11, 23, 14, 23), 2);
    final m = moonRiseSet(39.9, 41.27, day);
    near(m.rise, DateTime.utc(2026, 11, 23, 12, 37), 2);
    near(m.set, DateTime.utc(2026, 11, 23, 2, 37), 2);
    near(nextMoonPhase(DateTime.utc(2026, 11, 23, 17), 180), DateTime.utc(2026, 11, 24, 14, 53), 15);
    near(nextMoonPhase(DateTime.utc(2026, 11, 23, 17), 0), DateTime.utc(2026, 12, 9, 0, 52), 15);
  });

  test('şimdi-tahmini: başlıyor, diniyor, sürüyor, yok', () {
    final now = DateTime(2026, 12, 1, 18, 7);
    List<NowPoint> pts(List<double> pr, {double snow = 0}) =>
        [for (var i = 0; i < pr.length; i++) NowPoint(DateTime(2026, 12, 1, 18).add(Duration(minutes: 15 * i)), pr[i], pr[i] > 0 ? snow : 0)];
    final starts = Nowcast.of(pts([0, 0, 0, .4, .5, .2, 0, 0, 0]), now);
    expect(starts.startsIn, 40); // 18:45 dilimi, şimdi 18:07 → 38 dk → 40
    expect(starts.headline, contains('Yağmur'));
    final ends = Nowcast.of(pts([.3, .3, 0, 0, 0, 0, 0, 0, 0], snow: .4), now);
    expect(ends.wetNow, isTrue);
    expect(ends.snow, isTrue);
    expect(ends.endsIn, 25);
    expect(Nowcast.of(pts([.6, .7, .8, .9, 1, 1, 1, 1, 1]), now).headline, contains('sürüyor'));
    expect(Nowcast.of(pts(List.filled(9, 0)), now).any, isFalse);
  });

  test('dünle kıyas: geçmiş saatlik veriden', () {
    final now = DateTime(2026, 12, 1, 18, 10);
    final base = snap(t: 2);
    WeatherSnapshot at(double yesterday) => withHours(base, now.subtract(const Duration(hours: 22)), [for (var i = 0; i < 30; i++) (i == 0 ? yesterday : 5.0, 0.0, 0.0, 3, 5.0)]);
    expect(yesterdayLine(at(6), now), 'Dün bu saatten 4° daha soğuk.');
    expect(yesterdayLine(at(-1), now), 'Dün bu saatten 3° daha sıcak.');
    expect(yesterdayLine(at(2.5), now), isNull);
  });

  test('en iyi zaman: yağmurdan sonra kuru gündüz yürüyüş, yağış yakınsa araba yıkama yok, açık gecede yıldız', () {
    // Test saat dilimi UTC; Erzurum'da Aralık'ta Güneş ~04:45–13:50 UTC arası ufkun üstünde.
    final now = DateTime(2026, 12, 9, 3);
    final hs = <HourPoint>[
      for (var i = 0; i < 48; i++) HourPoint(time: now.add(Duration(hours: i)),
          temp: 12, precip: i < 3 ? 1.0 : (i >= 30 && i < 33 ? 2.0 : 0), snowfall: 0, windSpeed: 3, windDir: 0,
          cloud: (i >= 15 && i < 24) ? 0 : 80, humidity: 55, dewPoint: 3, weatherCode: i < 3 ? 61 : 2),
    ];
    final s = WeatherSnapshot(place: const GeoPoint2(39.9, 41.27), fetchedAt: now, temp: 12, feelsLike: 12, humidity: 55, dewPoint: 3, pressure: 1015,
        windSpeed: 3, windDir: 0, windGust: 5, cloudCover: 80, cloudHigh: 0, precip: 1, snowfall: 0, visibilityM: 10000, cape: 0, uv: 0,
        weatherCode: 61, isDay: false, hourly: hs);
    final b = {for (final e in bestTimes(s, now)) e.key: e};
    expect(b['walk']!.found, isTrue);
    expect(b['walk']!.start!.isAfter(now.add(const Duration(hours: 2))), isTrue); // yağmur bittikten sonra
    expect(b['walk']!.start!.hour, inInclusiveRange(5, 12));
    expect(b['car']!.found, isFalse); // 27 saat sonra yine yağmur
    expect(b['stars']!.found, isTrue);
    expect(b['stars']!.start!.hour, anyOf(inInclusiveRange(15, 23), inInclusiveRange(0, 2)));
  });

  test('iklim normalleri: 30 yıllık seriden mevsim normali ve takvim günü rekoru', () {
    final times = <String>[]; final mx = <double?>[]; final mn = <double?>[]; final sn = <double?>[];
    for (var d = DateTime.utc(1995); d.year < 2025; d = d.add(const Duration(days: 1))) {
      final k = ClimateNormals.doy(d);
      final base = 12 - 14 * cos(2 * pi * (k - 15) / 365); // Ocak ortası en soğuk
      times.add(d.toIso8601String().substring(0, 10));
      mx.add(base + 5 + (d.year == 2010 && d.month == 11 && d.day == 23 ? 15 : 0));
      mn.add(base - 5);
      sn.add(d.month == 12 || d.month == 1 ? 1.0 : 0); // Aralık ve Ocak'ta her gün 1 cm
    }
    final n = ClimateNormals.compute(times, mx, mn, sn)!;
    expect(n.snowSeasonNormal, closeTo(62, .5)); // 31 + 31 gün
    expect(n.snowNormalBy(DateTime(2026, 12, 31)), closeTo(31, .5));
    expect(ClimateNormals.seasonDay(DateTime(2026, 9, 1)), 0);
    expect(ClimateNormals.seasonDay(DateTime(2027, 5, 31)), 272);
    expect(ClimateNormals.seasonDay(DateTime(2026, 7, 1)), isNull);
    expect(n.fromYear, 1995); expect(n.toYear, 2024);
    final nov23 = DateTime(2026, 11, 23);
    final expected = 12 - 14 * cos(2 * pi * (ClimateNormals.doy(nov23) - 15) / 365) + 5;
    expect((n.maxOn(nov23) - expected).abs(), lessThan(1.0)); // 31 günlük yumuşatma
    expect(n.recMaxYear[ClimateNormals.doy(nov23)], 2010);
    final back = ClimateNormals.fromJson(n.toJson());
    expect(back.maxOn(nov23), n.maxOn(nov23));
    expect(back.snowSeasonNormal, n.snowSeasonNormal);
    final season = SeasonSnow.fromDaily(['2026-12-01', '2026-12-02', '2026-12-03'], [2, null, 3.5]);
    expect(season.total, 5.5);
  });

  test('hava kalitesi: ayrıştırma ve Avrupa endeksi kademeleri', () {
    final pts = AirService.parse({
      'time': ['2026-12-01T10:00', '2026-12-01T11:00', '2026-12-01T12:00'],
      'european_aqi': [18, null, 64], 'pm2_5': [4.2, 5.0, 30], 'pm10': [9, 10, 55], 'ozone': [60, 61, 40], 'nitrogen_dioxide': [12, 13, 44],
    });
    expect(pts.length, 2); // endeksi olmayan saat atlanır
    expect(pts.last.pm10, 55);
    expect(Aqi.label(18), 'İyi'); expect(Aqi.label(35), 'Makul'); expect(Aqi.label(64), 'Kötü'); expect(Aqi.label(120), 'Aşırı kötü');
  });

  test('sabah özeti: gidişat ve öneri', () {
    final now = DateTime(2026, 12, 9, 7, 30);
    final d0 = DateTime(2026, 12, 9);
    final hs = [for (var i = 0; i < 24; i++) HourPoint(time: d0.add(Duration(hours: i)), temp: -3, precip: i >= 6 && i < 12 ? .8 : 0,
        snowfall: i >= 6 && i < 12 ? .9 : 0, windSpeed: 3, windDir: 0, cloud: i >= 12 ? 10 : 90, humidity: 80, dewPoint: -5, weatherCode: i >= 6 && i < 12 ? 73 : 1)];
    final s = WeatherSnapshot(place: const GeoPoint2(39.9, 41.27), fetchedAt: now, temp: -3, feelsLike: -6, humidity: 80, dewPoint: -5, pressure: 1015,
        windSpeed: 3, windDir: 0, windGust: 5, cloudCover: 90, cloudHigh: 0, precip: .8, snowfall: .9, visibilityM: 4000, cape: 0, uv: 0,
        weatherCode: 73, isDay: true, hourly: hs,
        daily: [DayPoint(date: d0, tMax: 1, tMin: -7, precipSum: 4.8, snowSum: 5.4, windMax: 4, weatherCode: 73)]);
    final b = morningBrief(s, now);
    expect(b, startsWith('Bugün −7° / 1°, sabah yoğun karlı, öğleden sonra açık.'));
    expect(b, contains('yollar kaygan'));
  });
}
