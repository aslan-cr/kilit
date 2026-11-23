import 'dart:math';
import '../astro/astro_math.dart';
import '../astro/sky_times.dart' show moonAltitude;
import '../data/models.dart';

/// Bir etkinlik için önümüzdeki 48 saatteki en iyi zaman aralığı.
class BestSlot {
  final String key, name;
  final DateTime? start, end; // null: uygun zaman yok
  final int score;            // 0..100
  final String why;           // neden bu aralık (gündelik dil)
  const BestSlot(this.key, this.name, this.start, this.end, this.score, this.why);
  bool get found => start != null;
}

/// Saatlik tahminden etkinliklere en uygun zamanlar. Gündüz/gece gerçek Güneş yüksekliğinden.
List<BestSlot> bestTimes(WeatherSnapshot s, DateTime now) {
  final from = DateTime(now.year, now.month, now.day, now.hour);
  final hs = s.hourly.where((h) => !h.time.isBefore(from) && h.time.isBefore(from.add(const Duration(hours: 48)))).toList();
  final lat = s.place.lat, lon = s.place.lon;
  double sun(DateTime t) => sunAltitude(lat, lon, t.add(const Duration(minutes: 30)).toUtc());
  bool wet(HourPoint h) => h.precip >= .1 || h.snowfall >= .1;
  // 0..100: değer ideal aralıktaysa 100, dışına çıktıkça düşer
  double band(double v, double lo, double hi, double soft) => v >= lo && v <= hi ? 100 : max(0, 100 - (v < lo ? lo - v : v - hi) / soft * 100);

  /// [block]: o saati neyin engellediği (yağış/soğuk/rüzgâr/karanlık…); uygun aralık yoksa en sık engel yazılır.
  BestSlot window(String key, String name, int len, double Function(HourPoint h) score, String Function(List<HourPoint> w) why,
      String? Function(HourPoint h) block) {
    var best = -1.0; int? at;
    for (var i = 0; i + len <= hs.length; i++) {
      final sc = hs.sublist(i, i + len).map(score).reduce(min);
      if (sc > best + .5) { best = sc; at = i; }
    }
    if (at == null || best < 45) {
      final counts = <String, int>{};
      for (final h in hs) { final b = block(h); if (b != null) counts[b] = (counts[b] ?? 0) + 1; }
      // Kuru saatler varsa asıl engel yağış değil, öbürüdür (soğuk, rüzgâr…)
      if (counts.length > 1) counts.remove('Yağış neredeyse hiç durmuyor');
      final top = counts.entries.fold<MapEntry<String, int>?>(null, (m, e) => m == null || e.value > m.value ? e : m);
      return BestSlot(key, name, null, null, max(0, best).round(), top?.key ?? 'Önümüzdeki 2 günde uygun aralık yok');
    }
    final w = hs.sublist(at, at + len);
    return BestSlot(key, name, w.first.time, w.last.time.add(const Duration(hours: 1)), best.round(), why(w));
  }

  // Engel nedenleri (gündelik dil)
  String? outdoor(HourPoint h, {required double cold, double windy = 9, double minSun = 2}) =>
      wet(h) ? 'Yağış neredeyse hiç durmuyor' : sun(h.time) < minSun ? null : h.temp < cold ? 'Hava bu iş için fazla soğuk' : h.windSpeed > windy ? 'Rüzgâr çok sert' : null;

  String summary(List<HourPoint> w) {
    final t = w.map((h) => h.temp).reduce((a, b) => a + b) / w.length;
    final wind = w.map((h) => h.windSpeed).reduce(max);
    final windWord = wind < 3 ? 'rüzgârsız' : wind < 6 ? 'hafif rüzgâr' : 'esintili';
    final r = t.round();
    return 'kuru, ${r < 0 ? '−' : ''}${r.abs()}°, $windWord';
  }

  final out = <BestSlot>[
    window('walk', 'Yürüyüş', 2, (h) => wet(h) || sun(h.time) < 2 ? 0 : min(band(h.temp, 5, 24, 20), band(h.windSpeed, 0, 7, 6)), summary,
        (h) => outdoor(h, cold: -6)),
    window('run', 'Koşu', 1, (h) => wet(h) || sun(h.time) < -4 ? 0 : min(band(h.temp, 2, 18, 18), band(h.windSpeed, 0, 6, 5)), summary,
        (h) => outdoor(h, cold: -8, minSun: -4)),
    window('bike', 'Bisiklet', 2, (h) => wet(h) || sun(h.time) < 2 ? 0 : min(band(h.temp, 10, 26, 14), band(h.windSpeed, 0, 5, 5)), summary,
        (h) => outdoor(h, cold: 3, windy: 7)),
    window('laundry', 'Çamaşır kurutma', 4,
        (h) => wet(h) || sun(h.time) < 5 ? 0 : min(min(band(h.temp, 15, 35, 12), band(h.humidity, 0, 65, 30)), band(h.windSpeed, 1.5, 8, 5)),
        (w) => 'kuru, nem %${(w.map((h) => h.humidity).reduce((a, b) => a + b) / w.length).round()}, ${w.map((h) => h.windSpeed).reduce(max) >= 2 ? 'esinti var' : 'durgun'}',
        (h) => wet(h) ? 'Yağış neredeyse hiç durmuyor' : sun(h.time) < 5 ? null : h.temp < 8 ? 'Dışarıda kurumaz, hava soğuk' : h.humidity > 85 ? 'Hava çok nemli' : null),
  ];

  // Araba yıkama: gündüz, donmuyor ve sonraki 36 saat kuru
  {
    BestSlot? car;
    for (var i = 0; i < hs.length; i++) {
      final h = hs[i];
      if (sun(h.time) < 5 || h.temp < 3 || wet(h)) continue;
      final next = s.hourly.where((x) => x.time.isAfter(h.time) && x.time.isBefore(h.time.add(const Duration(hours: 36)))).toList();
      if (next.length < 33) continue; // 36 saatin tahmini yoksa "kuru" denemez
      final rain = next.fold<double>(0, (a, x) => a + x.precip + x.snowfall * .7);
      if (rain < .2) { car = BestSlot('car', 'Araba yıkama', h.time, h.time.add(const Duration(hours: 2)), 90, 'sonraki 36 saat yağış yok'); break; }
    }
    out.add(car ?? const BestSlot('car', 'Araba yıkama', null, null, 0, 'Yakında yağış var; yıkama boşa gider'));
  }

  // Yıldız gözlemi: gök kararmış (Güneş −12° altı), bulut az, Ay ufkun altında ya da ince hilal
  out.add(window('stars', 'Yıldız gözlemi', 1, (h) {
    if (sun(h.time) > -12 || wet(h)) return 0;
    final moonUp = moonAltitude(lat, lon, h.time.add(const Duration(minutes: 30)).toUtc()) > 0;
    final moonPenalty = moonUp ? 35 * moonPhaseInfo(h.time.toUtc()).illumination : 0;
    return max(0, 100 - h.cloud * 1.6 - moonPenalty);
  }, (w) => 'bulut %${w.map((h) => h.cloud).reduce(max).round()}, gök karanlık',
      (h) => sun(h.time) > -12 ? null : wet(h) || h.cloud > 50 ? 'Bulutlar gökyüzünü kapatıyor' : 'Ay çok parlak'));
  return out;
}
