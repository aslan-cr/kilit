import 'package:flutter_test/flutter_test.dart';
import 'package:skynav/data/models.dart';
import 'package:skynav/engine/garden.dart';

/// Saatlik ve günlük seri: şimdiden 12 saat önce başlar, 7 gün sürer.
WeatherSnapshot garden(DateTime now, {required double Function(DateTime t) temp, double Function(DateTime t)? surface, double soil6 = 10,
    double wind = 2, double hum = 60, double rain = 0, double dayMax = 20, double dayMin = 8, double dayRain = 0, double snowDepth = 0}) {
  final start = DateTime(now.year, now.month, now.day, now.hour).subtract(const Duration(hours: 12));
  return WeatherSnapshot(
    place: const GeoPoint2(39.9, 41.27, elevation: 1850), fetchedAt: now,
    temp: temp(now), feelsLike: temp(now), humidity: hum, dewPoint: temp(now) - 5, pressure: 1015, windSpeed: wind, windDir: 0, windGust: wind * 1.4,
    cloudCover: 20, cloudHigh: 0, precip: 0, snowfall: 0, visibilityM: 10000, cape: 0, uv: 0, snowDepthM: snowDepth, weatherCode: 0, isDay: true,
    soil6: soil6,
    hourly: [
      for (var i = 0; i < 24 * 7 + 12; i++)
        for (final t in [start.add(Duration(hours: i))])
          HourPoint(time: t, temp: temp(t), precip: rain, snowfall: 0, windSpeed: wind, windDir: 0, cloud: 20, humidity: hum, dewPoint: temp(t) - 5,
              weatherCode: rain > 0 ? 61 : 1, gust: wind * 1.4, surface: surface == null ? temp(t) : surface(t), soil6: soil6),
    ],
    daily: [
      for (var d = 0; d < 7; d++)
        DayPoint(date: DateTime(now.year, now.month, now.day + d), tMax: dayMax, tMin: dayMin, precipSum: dayRain, snowSum: 0, windMax: wind, weatherCode: 1),
    ],
  );
}

void main() {
  test('ET₀ (Hargreaves): yazın birkaç mm, kışın neredeyse sıfır', () {
    expect(et0Hargreaves(27, 10, 39.9, 196), inInclusiveRange(4.5, 7.0));
    expect(et0Hargreaves(0, -12, 39.9, 350), lessThan(1.0));
    expect(et0Hargreaves(-25, -30, 39.9, 20), 0); // çok soğukta negatif olmaz
  });

  test('don takvimi: orta don, yer donu ve don yok ayrımı', () {
    final now = DateTime(2026, 4, 20, 14);
    // Geceleri −3 °C
    final cold = gardenReport(garden(now, temp: (t) => t.hour >= 20 || t.hour < 7 ? -3 : 9), now);
    expect(cold.nights.first.level, 3);
    expect(cold.nextFrost, isNotNull);
    expect(frostName(cold.nights.first.level), 'Orta don');
    // Hava +2 ama toprak yüzeyi −1: yer donu
    final ground = gardenReport(garden(now, temp: (t) => t.hour >= 20 || t.hour < 7 ? 2 : 12, surface: (t) => t.hour >= 20 || t.hour < 7 ? -1 : 14), now);
    expect(ground.nights.first.level, 1);
    expect(ground.nextFrost, isNull);
    expect(ground.tips.any((t) => t.contains('Yer donu')), isTrue);
    // Ilık geceler
    final warm = gardenReport(garden(now, temp: (t) => 12), now);
    expect(warm.nights.every((n) => n.level == 0), isTrue);
    expect(warm.nights.length, greaterThanOrEqualTo(6));
  });

  test('ekim: toprak sıcaklığına göre ürünler; önde don varsa sıcak sevenler beklemeli', () {
    final now = DateTime(2026, 5, 10, 14);
    final r = gardenReport(garden(now, temp: (t) => 14, soil6: 12), now);
    bool ok(String n) => r.crops.firstWhere((c) => c.crop.name.startsWith(n)).ok;
    expect(ok('Buğday'), isTrue);
    expect(ok('Fasulye'), isTrue);
    expect(ok('Domates'), isFalse);
    final frost = gardenReport(garden(now, temp: (t) => t.hour >= 22 || t.hour < 6 ? -1 : 14, surface: (t) => 6, soil6: 12), now);
    final bean = frost.crops.firstWhere((c) => c.crop.name == 'Fasulye');
    expect(bean.ok, isFalse);
    expect(bean.why, contains('don'));
    expect(frost.crops.first.ok, isTrue); // buğday dona dayanır
    // Karlı toprak: hiçbir şey ekilmez
    final snow = gardenReport(garden(now, temp: (t) => -2, soil6: 0, snowDepth: .2), now);
    expect(snow.crops.every((c) => !c.ok), isTrue);
    expect(snow.waterVerdict, contains('kar'));
  });

  test('ilaçlama: sakin ve kuru gündüz uygun; rüzgârlı havada değil', () {
    final now = DateTime(2026, 6, 1, 6);
    final calm = gardenReport(garden(now, temp: (t) => 16, wind: 2), now);
    expect(calm.spray, isNotEmpty);
    expect(calm.sprayBlock, isNull);
    expect(calm.spray.first.to.difference(calm.spray.first.from).inHours, greaterThanOrEqualTo(2));
    final windy = gardenReport(garden(now, temp: (t) => 16, wind: 8), now);
    expect(windy.spray, isEmpty);
    expect(windy.sprayBlock, contains('Rüzgâr'));
    final wet = gardenReport(garden(now, temp: (t) => 16, rain: .5), now);
    expect(wet.spray, isEmpty);
    expect(wet.sprayBlock, contains('Yağış'));
  });

  test('sulama: kurak sıcak haftada litre önerisi, yağışlı haftada gerek yok', () {
    final now = DateTime(2026, 7, 15, 10);
    final dry = gardenReport(garden(now, temp: (t) => 24, dayMax: 31, dayMin: 15, soil6: 22), now);
    expect(dry.water.length, 7);
    expect(dry.waterVerdict, contains('litre'));
    final wet = gardenReport(garden(now, temp: (t) => 18, dayMax: 22, dayMin: 12, dayRain: 12, soil6: 16), now);
    expect(wet.waterVerdict, contains('yetiyor'));
  });

  test('Keşfet özeti: don varsa önce don', () {
    final now = DateTime(2026, 11, 24, 15);
    expect(gardenTeaser(garden(now, temp: (t) => t.hour >= 19 || t.hour < 8 ? -8 : 1), now), 'Don: bu gece −8°');
  });
}
