import 'dart:math';
import '../data/models.dart';

/// 1 sn'lik nabızda sessizce çalışan 10 aşamalı çapraz doğrulama.
/// Hepsi geçerse aday veri "onaylı" olur; biri takılırsa ekranda önceki onaylı veri korunur.
class Validator {
  /// [integrityOk]: kural/indirim/kota bütünlüğü sonucu (ProService'ten gelir).
  static bool verify(WeatherSnapshot s, Analysis a, {WeatherSnapshot? prev, bool integrityOk = true}) {
    return _c1(s) && _c2(s) && _c3(s) && _c4(s, prev) && _c5(s, a) && _c6(s) && _c7(s, a) && _c8(s) && _c9(s) && integrityOk;
  }

  // 1 sayısal bütünlük
  static bool _c1(WeatherSnapshot s) => [s.temp, s.humidity, s.pressure, s.windSpeed, s.cloudCover, s.dewPoint, s.precip].every((v) => v.isFinite);
  // 2 fiziksel aralıklar
  static bool _c2(WeatherSnapshot s) => s.temp > -90 && s.temp < 60 && s.humidity >= 0 && s.humidity <= 100.5 &&
      s.pressure > 800 && s.pressure < 1100 && s.windSpeed >= 0 && s.windSpeed < 90 && s.cloudCover >= 0 && s.cloudCover <= 100.5;
  // 3 çiy noktası ≤ sıcaklık
  static bool _c3(WeatherSnapshot s) => s.dewPoint <= s.temp + 0.6;
  // 4 ani sapma (aynı yer, kısa süre)
  static bool _c4(WeatherSnapshot s, WeatherSnapshot? p) {
    if (p == null) return true;
    final close = (s.place.lat - p.place.lat).abs() < .05 && (s.place.lon - p.place.lon).abs() < .05;
    if (!close) return true;
    final mins = max(1, s.fetchedAt.difference(p.fetchedAt).inMinutes);
    return (s.temp - p.temp).abs() <= 3 + mins * .4 && (s.pressure - p.pressure).abs() <= 4 + mins * .1;
  }
  // 5 yağış türü ↔ sıcaklık tutarlılığı
  static bool _c5(WeatherSnapshot s, Analysis a) {
    if ((a.kind == PrecipKind.snow || a.kind == PrecipKind.lentilSnow || a.kind == PrecipKind.blizzard) && s.temp > 6) return false;
    if (a.kind == PrecipKind.rain && s.temp < -4) return false;
    return true;
  }
  // 6 yaş termometre ≤ sıcaklık
  static bool _c6(WeatherSnapshot s) => s.wetBulb == null || s.wetBulb! <= s.temp + 0.6;
  // 7 sis ↔ nem/çiy farkı
  static bool _c7(WeatherSnapshot s, Analysis a) => a.fogProb < 60 || s.humidity > 80 || (s.temp - s.dewPoint) < 3;
  // 8 dağ–şehir farkı: yüksek dağ şehirden çok daha sıcak olamaz
  static bool _c8(WeatherSnapshot s) {
    for (final m in s.mountains) {
      if (m.tempC != null && s.place.elevation != null && m.elevation > (s.place.elevation ?? 0) + 200 && m.tempC! > s.temp + 6) return false;
    }
    return true;
  }
  // 9 METAR çapraz kontrol
  static bool _c9(WeatherSnapshot s) => s.metar?.tempC == null || (s.metar!.tempC! - s.temp).abs() < 14;
}
