// Yol güvenliği kartları: köprü buzlanması, eğim, güneş, cam kazıma,
// silecek suyu, görüş/far, rüzgâr-yakıt, rüzgâr tüneli, dağ manzarası, yankı.
// Saf Dart. Girdi: WeatherSnapshot + Analysis. Metinler Kanki listelerinden.
import 'dart:math' as math;

import '../data/models.dart';
import '../data/phrases.dart';

class RoadItem {
  final String id, emoji, title, valueText, kanki, explain;
  /// Şiddet 0 (sorun yok) ... 3 (ciddi).
  final int level0to3;
  const RoadItem({
    required this.id,
    required this.emoji,
    required this.title,
    required this.valueText,
    required this.kanki,
    required this.explain,
    required this.level0to3,
  });
}

typedef SolarPosition = ({double elevationDeg, double azimuthDeg});

double _rad(double d) => d * math.pi / 180.0;
double _deg(double r) => r * 180.0 / math.pi;
double _norm360(double d) {
  final r = d % 360.0;
  return r < 0 ? r + 360.0 : r;
}

int _clampLevel(int l) => l < 0 ? 0 : (l > 3 ? 3 : l);

String _kanki(List<String> list, int seed) => Kanki.pick(list, seed);

/// Güneşin yüksekliği (°) ve azimutu (° kuzeyden saat yönünde) — NOAA/Meeus
/// yaklaşımı, ~0.01° doğrulukta. [time] yerel veya UTC olabilir.
SolarPosition solarPosition(DateTime time, double latDeg, double lonDeg) {
  final n = time.toUtc().difference(DateTime.utc(2000, 1, 1, 12)).inMicroseconds /
      (86400 * 1000000.0);
  final l = _norm360(280.460 + 0.9856474 * n);
  final g = _rad(_norm360(357.528 + 0.9856003 * n));
  final lambda = _rad(_norm360(l + 1.915 * math.sin(g) + 0.020 * math.sin(2 * g)));
  final eps = _rad(23.439 - 0.0000004 * n);
  final dec = math.asin(math.sin(eps) * math.sin(lambda));
  final raDeg = _deg(math.atan2(math.cos(eps) * math.sin(lambda), math.cos(lambda)));
  final gmst = _norm360(280.46061837 + 360.98564736629 * n);
  final h = _rad(_norm360(gmst + lonDeg - raDeg));
  final lat = _rad(latDeg);
  final sinAlt = (math.sin(lat) * math.sin(dec) +
          math.cos(lat) * math.cos(dec) * math.cos(h))
      .clamp(-1.0, 1.0);
  final alt = math.asin(sinAlt);
  final az = math.atan2(
      -math.sin(h), math.tan(dec) * math.cos(lat) - math.sin(lat) * math.cos(h));
  return (elevationDeg: _deg(alt), azimuthDeg: _norm360(_deg(az)));
}

/// Angle farkı (0-180°).
double _angleDiff(double a, double b) {
  final d = _norm360(a - b);
  return d > 180 ? 360 - d : d;
}

/// 1. Viyadük / Köprü Gizli Buzlanma: köprü güvertesi yer ve havadan daha
/// hızlı soğur. Tahmin: min(hava, toprak yüzeyi) - 2 °C.
RoadItem bridgeIceItem(WeatherSnapshot s, Analysis a) {
  final ground = s.soil0 ?? s.temp;
  final deck = math.min(s.temp, ground) - 2.0;
  final wet = s.precip > 0 || s.humidity >= 90 || (s.temp - s.dewPoint) <= 1.0;
  var lvl = 0;
  if (wet && deck <= 0) {
    lvl = deck <= -3 ? 3 : 2;
  } else if (wet && deck <= 2) {
    lvl = 1;
  }
  return RoadItem(
    id: 'bridge_ice',
    emoji: '🌉',
    title: 'Viyadük / Köprü Gizli Buzlanma',
    valueText: 'Köprü ~${deck.toStringAsFixed(1)} °C',
    kanki: _kanki(Kanki.yolBuzlu, (s.temp * 10).round()),
    explain: 'Köprü güvertesi altından da soğur, yer yüzeyinden önce buz tutar. '
        'Tahmini güverte sıcaklığı ${deck.toStringAsFixed(1)} °C'
        '${wet ? ', hava nemli/yağışlı' : ''}. Köprü ve viyadüklerde gaz kes, sabit sür.',
    level0to3: _clampLevel(lvl),
  );
}

/// 2. Dik Yokuş & Kar/Tipi Patinaj Riski. [slopePct] yüzde eğim (örn. 12 = %12).
RoadItem slopeGripItem(WeatherSnapshot s, Analysis a, {required double slopePct}) {
  final slope = slopePct.abs();
  final snowy = a.snowProb >= 40 ||
      a.kind == PrecipKind.snow ||
      a.kind == PrecipKind.lentilSnow ||
      a.kind == PrecipKind.blizzard ||
      s.snowfall > 0.2;
  final icy = a.sleetProb >= 50 || (s.temp <= 0.5 && s.precip > 0.1);
  var lvl = slope >= 18 ? 3 : slope >= 12 ? 2 : slope >= 7 ? 1 : 0;
  if (!(snowy || icy)) lvl = math.min(lvl, 1); // kuru yolda eğim sınırlı risk
  if (snowy && icy) lvl = math.min(3, lvl + 1);
  final kanki = lvl == 0
      ? 'Yokuş dik değil kanki, rahat tırman.'
      : _kanki(Kanki.kayganYolUyari, slope.round());
  return RoadItem(
    id: 'slope_grip',
    emoji: '⛰️',
    title: 'Dik Yokuş & Patinaj Riski',
    valueText: '%${slope.round()} eğim',
    kanki: kanki,
    explain: 'Eğim %${slope.round()}'
        '${snowy ? ', yolda kar var' : ''}${icy ? ', buzlanma ihtimali var' : ''}. '
        'Yokuşa tırmanırken vites düşük kalsın, gazı yavaş ver; yokuşta durursan '
        'kalkış için kavrama değil yavaş gaz kullan.',
    level0to3: _clampLevel(lvl),
  );
}

/// 3. Güneş Gözlüğü & Güneşlik Uyarısı. [headingDeg] yol yönü (0 = kuzey).
RoadItem sunGlareItem(WeatherSnapshot s,
    {double headingDeg = 0, DateTime? now}) {
  final t = now ?? s.fetchedAt;
  final p = solarPosition(t, s.place.lat, s.place.lon);
  final ahead = _angleDiff(p.azimuthDeg, headingDeg) <= 35;
  var lvl = 0;
  if (ahead && p.elevationDeg > -1 && p.elevationDeg <= 25) {
    lvl = p.elevationDeg <= 5 ? 3 : p.elevationDeg <= 12 ? 2 : 1;
    if (s.cloudCover >= 70) lvl -= 1;
  }
  return RoadItem(
    id: 'sun_glare',
    emoji: '🕶️',
    title: 'Güneş Gözlüğü & Güneşlik',
    valueText: 'Güneş %${p.elevationDeg.round()}° yükseklik',
    kanki: ahead && lvl > 0
        ? 'Güneş tam önüne vuruyor kanki, gözlüğü tak ve güneşliği indir.'
        : _kanki(Kanki.acik, t.minute),
    explain: 'Güneş azimutu ${p.azimuthDeg.round()}°, yol yönü ${headingDeg.round()}°. '
        '${ahead ? 'Güneş tam karşıdan geliyor. ' : 'Güneş yolun dışında. '}'
        'Alçak güneş (ufka yakın) en çok kamaştırır; bulut varsa etkisi azalır.',
    level0to3: _clampLevel(lvl),
  );
}

/// 4. Sabah Cam Kazıma Süresi Tahmini (dakika). Don/kırağı ve kar birikimi.
RoadItem morningScrapeItem(WeatherSnapshot s, Analysis a) {
  final frostLikely = s.temp <= 2 && (s.temp - s.dewPoint) <= 2.5;
  final clear = s.cloudCover < 40;
  double mins;
  if (s.temp > 3 && s.snowfall <= 0) {
    mins = 0.5;
  } else {
    mins = 1 +
        math.max(0.0, -s.temp) * 0.4 +
        (frostLikely && clear ? 3 : 0) +
        s.snowfall * 1.5 +
        ((s.snowDepthM ?? 0) > 0.05 ? 2 : 0);
  }
  mins = math.min(25.0, mins);
  final m = mins.round();
  final lvl = m <= 2 ? 0 : m <= 6 ? 1 : m <= 12 ? 2 : 3;
  return RoadItem(
    id: 'morning_scrape',
    emoji: '🧊',
    title: 'Sabah Cam Kazıma Süresi',
    valueText: m <= 1 ? 'Kazıma yok' : '~$m dk',
    kanki: m <= 2
        ? 'Sabah camın temiz kanki, kahveni al çık.'
        : _kanki(Kanki.donmaUyari, m),
    explain: 'Tahmini kazıma süresi ~$m dk. Açık gökyüzü ve düşük sıcaklık '
        '(kırağı) süreyi uzatır; kar varsa ek süre eklenir. Motoru çalıştırıp '
        'kalorifer/defrost açmak kazımayı kısaltır.',
    level0to3: _clampLevel(lvl),
  );
}

/// 5. Silecek Suyu Donma Uyarısı (-5 °C altı).
RoadItem washerFluidItem(WeatherSnapshot s) {
  final t = s.temp;
  final lvl = t < -10 ? 3 : t < -5 ? 2 : 0;
  return RoadItem(
    id: 'washer_fluid',
    emoji: '🚿',
    title: 'Silecek Suyu Donma Uyarısı',
    valueText: '${t.toStringAsFixed(0)} °C',
    kanki: lvl == 0
        ? 'Silecek suyu donmaz bu hava kanki.'
        : 'Silecek suyun donabilir kanki, kışlık (antifriz) silecek suyu tak.',
    explain: 'Sıcaklık -5 °C altına inince normal silecek suyu donabilir ve camda '
        'buz yapar. -10 °C ve altında kışlık antifriz şart. Hortum ve memeler de donabilir.',
    level0to3: _clampLevel(lvl),
  );
}

/// Güvenli hız (km/sa): tepki (1.5 sn) + frenleme (6 m/s²) mesafesi görüş
/// mesafesine sığacak şekilde. v = -a·t + sqrt(a²t² + 2aD).
double safeSpeedKmh(double visibilityM, {double reactionS = 1.5, double decelMs2 = 6.0}) {
  final d = math.max(0.0, visibilityM);
  final v = -decelMs2 * reactionS +
      math.sqrt(decelMs2 * decelMs2 * reactionS * reactionS + 2 * decelMs2 * d);
  return math.min(130.0, v * 3.6);
}

/// 6. Karanlıkta Far & Sis Görüş Simülatörü.
RoadItem visibilityLightItem(WeatherSnapshot s, Analysis a) {
  final vis = s.visibilityM;
  final night = !s.isDay;
  final safe = safeSpeedKmh(vis);
  var lvl = vis < 200 ? 3 : vis < 500 ? 2 : vis < 1000 ? 1 : 0;
  if (night && lvl < 3) lvl += 1;
  final foggy = a.fogDensity >= 30 || vis < 1000;
  final String lights;
  if (foggy) {
    lights = 'Sis/düşük görüşte kısa far ve sis lambası; uzun far sisi aydınlatıp görüşü kör eder.';
  } else if (night) {
    lights = 'Karanlıkta uzun far, karşıdan araç yoksa; görüş açısını genişletir.';
  } else {
    lights = 'Gündüz de farları yak; görünürlüğü artırır.';
  }
  return RoadItem(
    id: 'visibility_light',
    emoji: '🔦',
    title: 'Far & Görüş Simülatörü',
    valueText: 'Güvenli ~${safe.round()} km/sa',
    kanki: a.fogDensity >= 15
        ? Kanki.sisKademeli(a.fogDensity, vis.round())
        : _kanki(Kanki.acik, vis.round()),
    explain: 'Görüş ${vis.round()} m. Tepki + frenleme mesafesi görüşe sığacak '
        'hız yaklaşık ${safe.round()} km/sa (1.5 sn tepki, 6 m/s² fren). $lights',
    level0to3: _clampLevel(lvl),
  );
}

/// 7. Rüzgara Göre Yakıt Tasarruf Hızı. [headingDeg] yol yönü (0 = kuzey).
/// Rüzgâr meteorolojik (nereden esiyor): baş rüzgâr = v·cos(yön - rüzgâr).
RoadItem fuelWindItem(WeatherSnapshot s, {double headingDeg = 0}) {
  final vKmh = s.windSpeed * 3.6;
  final along = s.windSpeed * math.cos(_rad(headingDeg - s.windDir)); // + baş, - arka
  final headKmh = along * 3.6;
  var target = 95.0 - math.max(0.0, headKmh) * 0.35 + math.max(0.0, -headKmh) * 0.1;
  target = math.max(60.0, math.min(110.0, target));
  final lvl = along >= 12 ? 3 : along >= 8 ? 2 : along >= 3 ? 1 : 0;
  final String wind = along > 1
      ? 'Baş rüzgâr (${along.toStringAsFixed(1)} m/sn) direnci artırır'
      : along < -1
          ? 'Arka rüzgâr (${(-along).toStringAsFixed(1)} m/sn) sana yardım ediyor'
          : 'Rüzgâr yandan ya da zayıf';
  return RoadItem(
    id: 'fuel_wind',
    emoji: '⛽',
    title: 'Rüzgâra Göre Yakıt Hızı',
    valueText: '~${target.round()} km/sa',
    kanki: along > 8
        ? 'Rüzgâr karşıdan kanki, hızı biraz düşür, yakıt da seni affeder.'
        : _kanki(Kanki.acik, vKmh.round()),
    explain: '$wind. Rüzgâr ${vKmh.round()} km/sa. Karşı rüzgârda hız arttıkça '
        'hava direnci üssel artar; tasarruf için yaklaşık ${target.round()} km/sa '
        'civarında sürmek iyi olur.',
    level0to3: _clampLevel(lvl),
  );
}

/// 8. Bisiklet / Scooter / Uçurtma Rüzgâr Tüneli.
RoadItem windTunnelItem(WeatherSnapshot s) {
  final gust = s.windGust;
  final bike = gust < 8;
  final scooter = gust < 10;
  final kite = s.windSpeed >= 5 && gust < 18;
  final lvl = gust < 8 ? 0 : gust < 12 ? 1 : gust < 16 ? 2 : 3;
  String v(bool ok) => ok ? 'uygun' : 'riskli';
  return RoadItem(
    id: 'wind_tunnel',
    emoji: '🪁',
    title: 'Rüzgâr Tüneli (Bisiklet/Scooter/Uçurtma)',
    valueText: 'Hamle ${(gust * 3.6).round()} km/sa',
    kanki: kite
        ? 'Uçurtma havası var kanki, ama bisikletle çıkma.'
        : 'Bugün rüzgâr sert kanki, pedalı ya da scooter\'ı ertele.',
    explain: 'Bisiklet: ${v(bike)}. Scooter: ${v(scooter)}. Uçurtma: ${v(kite)}. '
        'Hamle ${gust.toStringAsFixed(1)} m/sn; hamleler ortalamadan çok daha sert olabilir.',
    level0to3: _clampLevel(lvl),
  );
}

String _compass(double deg) {
  const names = ['K', 'KD', 'D', 'GD', 'G', 'GB', 'B', 'KB'];
  return names[((_norm360(deg) + 22.5) ~/ 45) % 8];
}

/// 9. Yol Üstü Manzara Tepeleri (s.mountains listesinden, en yakın 3, 80 km içi).
RoadItem mountainViewItem(WeatherSnapshot s) {
  final list = s.mountains.where((m) => m.distanceKm <= 80).toList()
    ..sort((x, y) => x.distanceKm.compareTo(y.distanceKm));
  final top = list.take(3).toList();
  final snowy = top.any((m) => (m.snowDepthM ?? 0) >= 0.3);
  final lines = [
    for (var i = 0; i < top.length; i++)
      '${i + 1}) ${top[i].elevation.round()} m, ${top[i].distanceKm.toStringAsFixed(0)} km, '
          '${_compass(top[i].bearingDeg)}',
  ];
  return RoadItem(
    id: 'mountain_view',
    emoji: '🏔️',
    title: 'Yol Üstü Manzara Tepeleri',
    valueText: top.isEmpty ? 'Tepe yok' : '${top.length} tepe',
    kanki: top.isEmpty
        ? 'Yakında öne çıkan tepe yok kanki, düz yolun keyfini çıkar.'
        : 'Yol boyunca tepeler var kanki, manzarayı kaçırma.',
    explain: top.isEmpty
        ? '80 km içinde radarda öne çıkan tepe yok.'
        : '${lines.join('; ')}.${snowy ? ' Tepelerde kar kalınlığı 30 cm üzeri, manzara güzel ama yol kapalı olabilir.' : ''}',
    level0to3: snowy ? 1 : 0,
  );
}

const double soundSpeedMs = 343.0;

/// Yankı süresinden (sn) dağ mesafesi (m): ses gidip dönüyor, bu yüzden /2.
double echoDistanceM(double seconds) => soundSpeedMs * seconds / 2.0;

/// Mesafeden (m) yankı süresi (sn).
double echoSecondsForDistance(double distanceM) => 2.0 * distanceM / soundSpeedMs;

/// 10. Dağ Yankı Ölçer (sabit bilgi kartı; süre girilince mesafe hesaplanır).
RoadItem echoItem() => RoadItem(
      id: 'echo',
      emoji: '📣',
      title: 'Dağ Yankı Ölçer',
      valueText: '1 sn ≈ ${echoDistanceM(1).round()} m',
      kanki: 'Dağa bir bağır kanki, yankı kaç saniyede dönüyor say bakalım.',
      explain: 'Ses havada yaklaşık 343 m/sn. Yankı t saniyede dönüyorsa dağ '
          'yaklaşık 343 × t / 2 metre uzakta. Örnek: 4 sn ≈ '
          '${echoDistanceM(4).round()} m.',
      level0to3: 0,
    );

/// Tüm yol kartları, sırasıyla. [headingDeg] yol yönü, [slopePct] yüzde eğim.
List<RoadItem> computeRoad(
  WeatherSnapshot s,
  Analysis a, {
  double headingDeg = 0,
  double slopePct = 0,
  DateTime? now,
}) =>
    [
      bridgeIceItem(s, a),
      slopeGripItem(s, a, slopePct: slopePct),
      sunGlareItem(s, headingDeg: headingDeg, now: now),
      morningScrapeItem(s, a),
      washerFluidItem(s),
      visibilityLightItem(s, a),
      fuelWindItem(s, headingDeg: headingDeg),
      windTunnelItem(s),
      mountainViewItem(s),
      echoItem(),
    ];
