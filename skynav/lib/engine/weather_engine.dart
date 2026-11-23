// Hava durumu analiz motoru. Saf Dart; UI metinleri dışarıda, burada sayısal karar ve kısa notlar üretilir.
import 'dart:math' as math;

import '../astro/astro_math.dart' show moonRaDec, raDecToAltAz;
import '../data/models.dart';
import 'formulas.dart';

class WeatherEngine {
  /// Anlık görüntüden doğrulanmış karar seti üretir.
  /// [biasCorrection] °C cinsinden öz-denetim düzeltmesi; sıcaklık eşiklerine uygulanır.
  /// Birimler: sıcaklık °C, rüzgar ve hamle m/s, yağış mm, kar cm/sa, görüş m, basınç hPa.
  static Analysis analyze(WeatherSnapshot s, {double biasCorrection = 0}) {
    final elev = s.place.elevation ?? 0.0;
    final tc = s.temp + biasCorrection;
    final wb = (s.wetBulb ?? wetBulbC(s.temp, s.humidity)) + biasCorrection;
    final t850Raw = s.pressureLevels[850]?['temp'];
    final t850 = t850Raw == null ? null : t850Raw + biasCorrection;
    final fl = s.freezingLevelM;
    final wind = s.windSpeed;
    final gust = s.windGust;
    final wc = s.weatherCode;

    // --- Yağış tipi koşulları ---
    final precipping = s.precip > 0.05 || s.snowfall > 0.05;
    // Kar tanesi donma seviyesinin altındaki ~300 m'lik ılık katmanı erimeden geçebilir.
    final flBelow = fl == null || fl < elev + 300;
    final snowCond = tc <= 0.5 && wb <= 0 && flBelow;
    final mixedCond = (tc > 0.5 && tc <= 2.5) || (wb >= -0.5 && wb <= 1.5);
    final snowy = precipping && snowCond;
    final sleetyPrecip = precipping && !snowCond && mixedCond;

    final convective = s.cape > 50;
    final t850InRange = t850 != null && t850 >= -10 && t850 <= -3;
    final lentilCodes = wc == 77 || wc == 85 || wc == 86;
    final lentilEnv = convective && (snowCond || (t850InRange && tc <= 2.5));
    final lentilKind = precipping && (lentilCodes || lentilEnv);

    // --- Tipi ---
    final windy = wind >= 10 || gust >= 17;
    // Savrulan kar (yağış olmasa da): kuru kar gerekir (≤ −1 °C), rüzgâr ≥ 9 m/s, kar ya bulunduğun yerde
    // ya da rüzgârın geldiği yöndeki yakın (≤ 30 km) karlı dağda olmalı.
    final upwindSnow = s.mountains.any((m) => (m.snowDepthM ?? 0) > 0.05 && m.distanceKm <= 30 && angleDiff(s.windDir, m.bearingDeg) <= 60);
    final drift = tc <= -1 && wind >= 9 && ((s.snowDepthM ?? 0) > 0.05 || upwindSnow);
    final blizzardCond = (windy && snowy) || drift;

    final windEff = math.max(wind, gust * 0.8);
    final windScore = _pct((windEff - 8) / 17 * 100);
    final snowRate = _pct(s.snowfall / 2 * 100);
    final visScore = _pct((3000 - s.visibilityM) / 3000 * 100);
    final driftScore = drift ? 50.0 : 0.0;
    final severity = _pct(0.45 * windScore + 0.2 * snowRate + 0.2 * visScore + 0.15 * driftScore);
    final blizzardProb = blizzardCond ? _pct(40 + severity * 0.6) : _pct(severity * 0.2);

    // --- Kar, karla karışık yağmur, mercimek karı ---
    final tempScore = _pct((2.5 - tc) / 3 * 100);
    final wbScore = _pct((1.5 - wb) / 2 * 100);
    final flScore = fl == null ? 60.0 : _pct((elev - fl + 300) / 600 * 100);
    final condScore = 0.4 * tempScore + 0.4 * wbScore + 0.2 * flScore;

    final mountainBonus = _mountainBonus(s, elev, tc, wind);

    final snowProb = s.ensembleMembers > 0
        ? _pct(0.7 * condScore + 0.3 * s.ensembleSnowProb + 0.3 * mountainBonus)
        : _pct(condScore + 0.3 * mountainBonus);

    final tMix = _pct(100 - (tc - 1.5).abs() * 40);
    final wbMix = _pct(100 - (wb - 0.5).abs() * 50);
    final sleetProb = _pct((0.5 * tMix + 0.5 * wbMix) * (precipping ? 1.0 : 0.5));

    final capeScore = _pct((s.cape - 50) / 450 * 100);
    final t850Score = t850 == null ? 0.0 : _pct(100 - _distOutside(t850, -10, -3) * 25);
    var lentilProb = lentilCodes && precipping ? 90.0 : 0.0;
    if (precipping && lentilEnv) {
      lentilProb = math.max(lentilProb, 0.5 * capeScore + 0.3 * t850Score + 0.2 * snowProb);
    }
    lentilProb = _pct(lentilProb);

    final PrecipKind kind;
    if (blizzardCond) {
      kind = PrecipKind.blizzard;
    } else if (!precipping) {
      kind = PrecipKind.none;
    } else if (lentilKind) {
      kind = PrecipKind.lentilSnow;
    } else if (snowCond) {
      kind = PrecipKind.snow;
    } else if (sleetyPrecip) {
      kind = PrecipKind.sleet;
    } else {
      kind = PrecipKind.rain;
    }

    // --- Sis ---
    final spread = s.temp - s.dewPoint;
    final spreadScore = _pct((3 - spread) / 3 * 100);
    final humScore = _pct((s.humidity - 80) / 18 * 100);
    final visFogScore = _pct((10000 - s.visibilityM) / 9000 * 100);
    final calmScore = _pct((3 - wind) / 3 * 100);
    final mtemps = [for (final m in s.mountains) if (m.tempC != null) m.tempC!];
    final inv = mtemps.isEmpty
        ? 0.0
        : mtemps.reduce((a, b) => a + b) / mtemps.length - s.temp;
    final invScore = _pct(inv / 4 * 100);
    final fogProb = _pct(0.3 * spreadScore +
        0.25 * humScore +
        0.2 * visFogScore +
        0.15 * calmScore +
        0.1 * invScore +
        (s.isDay ? 0 : 5));
    final fogDensity = _pct(fogProb * (0.6 * visFogScore + 0.4 * spreadScore) / 100);

    // --- Yıldız netliği ---
    double starClarity = 0;
    if (s.cloudCover <= 75) {
      final moon = moonPhase(s.fetchedAt);
      final humPen = _pct((s.humidity - 60) / 40 * 100);
      final visPen = _pct((10000 - s.visibilityM) / 10000 * 100);
      final dustPen = _pct(s.aqDust / 80 * 100);
      // Ay ışığı yalnızca Ay ufkun üstündeyken gökyüzünü aydınlatır.
      final mr = moonRaDec(s.fetchedAt.toUtc());
      final moonAlt = raDecToAltAz(mr.raDeg, mr.decDeg, s.place.lat, s.place.lon, s.fetchedAt.toUtc()).alt;
      final moonUp = clampD((moonAlt + 2) / 12, 0, 1);
      var q = 100.0 - s.cloudCover;
      q -= 0.3 * s.cloudHigh +
          0.25 * humPen +
          0.2 * visPen +
          0.15 * dustPen +
          30 * moon.illumination * moonUp +
          12; // ışık kirliliği: sabit orta varsayım
      starClarity = _pct(q);
    }

    // --- Her yere yağmama (dağılım) ---
    final mt = s.metar?.tempC;
    final metarDiff = mt == null ? 0.0 : (mt - s.temp).abs();
    final windPart = _pct((wind - 3) / 7 * 100);
    final mtnPart = _pct(mountainBonus / 40 * 100);
    final metarPart = _pct(metarDiff / 3 * 100);
    final dryPart = _pct((70 - s.humidity) / 30 * 100);
    final unevenScore = _pct(0.3 * windPart + 0.3 * mtnPart + 0.25 * metarPart + 0.15 * dryPart);
    final String unevenText;
    if (unevenScore >= 60) {
      unevenText = "Her yere eşit yağmayabilir kanki: rüzgar, dağ etkisi ya da yerel nem farkı yağışı bölgesel yapıyor. Bir mahalle beyaza bulanırken öbürü kuru kalabilir.";
    } else if (unevenScore >= 30) {
      unevenText = "Yağış biraz lokal olabilir; bulunduğun nokta ile genel tahmin birebir örtüşmeyebilir.";
    } else {
      unevenText = "Yağış bölgede daha eşit dağılıyor gibi görünüyor.";
    }

    // --- Güven (0-100) ---
    var conf = 95.0;
    if (s.modelTemp24h.length >= 2) {
      final vals = s.modelTemp24h.values;
      conf -= clampD((vals.reduce((a, b) => a > b ? a : b) - vals.reduce((a, b) => a < b ? a : b)) * 8, 0, 35);
    }
    if (s.modelPrecip24h.length >= 2) {
      final vals = s.modelPrecip24h.values;
      conf -= clampD((vals.reduce((a, b) => a > b ? a : b) - vals.reduce((a, b) => a < b ? a : b)) * 6, 0, 25);
    }
    if (s.ensembleMembers > 0) {
      final ambig = 50 - (s.ensembleRainProb - 50).abs();
      conf -= clampD(ambig * 0.4, 0, 20);
    }
    if (s.daily.length > 3) {
      conf -= clampD((s.daily.length - 3) * 2.0, 0, 20);
    }
    conf -= clampD(biasCorrection.abs() * 5, 0, 15);

    return Analysis(
      kind: kind,
      snowProb: snowProb,
      sleetProb: sleetProb,
      lentilProb: lentilProb,
      blizzardProb: blizzardProb,
      mountainBonusPct: _pct(mountainBonus),
      blizzardSeverity: severity,
      fogProb: fogProb,
      fogDensity: fogDensity,
      starClarity: starClarity,
      unevenSnowNote: unevenScore,
      unevenSnowText: unevenText,
      confidence: _pct(conf),
      // Yerel sapma °C cinsinden; yüzde aralığı değil, ±15 °C ile sınırlı.
      localityNote: clampD(mt == null ? 0.0 : mt - s.temp, -15, 15),
    );
  }

  /// "+Dağ Desteği" yüzdesi (0-40). Yüksek dağlarda kar + soğukluk ve
  /// rüzgarın dağdan şehre esmesi (windDir ~ dağ yönü) birlikte aranır.
  static double _mountainBonus(WeatherSnapshot s, double elev, double tc, double wind) {
    final highs = s.mountains.where((m) => m.elevation - elev >= 500).toList();
    if (highs.isEmpty) return 0;
    var cold = 0;
    var bestAlign = 0.0;
    var bestDepth = 0.0;
    for (final m in highs) {
      final mtTemp = m.tempC ?? (tc - 0.65 * (m.elevation - elev) / 100);
      final depth = m.snowDepthM ?? 0;
      if (depth <= 0.05 || mtTemp > 0.5) continue;
      cold++;
      final align = clampD(1 - angleDiff(s.windDir, m.bearingDeg) / 60, 0, 1);
      final windF = align * clampD(wind / 8, 0, 1);
      if (windF > bestAlign) bestAlign = windF;
      if (depth > bestDepth) bestDepth = depth;
    }
    if (cold == 0 || bestAlign <= 0) return 0;
    final coldRatio = cold / highs.length;
    final bonus = coldRatio * 35 * bestAlign + (bestDepth > 0.5 ? 3 : 0);
    return clampD(bonus, 0, 40);
  }

  static double _distOutside(double v, double lo, double hi) {
    if (v < lo) return lo - v;
    if (v > hi) return v - hi;
    return 0;
  }

  static double _pct(num v) => clampD(v, 0, 100);
}
