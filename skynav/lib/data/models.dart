// Ortak veri modelleri. Saf Dart (Flutter bağımlılığı yok).

class GeoPoint2 {
  final double lat, lon;
  final double? elevation; // metre
  final String name;
  const GeoPoint2(this.lat, this.lon, {this.elevation, this.name = ''});
  Map<String, dynamic> toJson() => {'lat': lat, 'lon': lon, 'ele': elevation, 'name': name};
  factory GeoPoint2.fromJson(Map<String, dynamic> j) => GeoPoint2(
      (j['lat'] as num).toDouble(), (j['lon'] as num).toDouble(),
      elevation: (j['ele'] as num?)?.toDouble(), name: (j['name'] ?? '') as String);
}

/// Çevre dağlar radarındaki tek bir tepe noktası.
class Mountain {
  final double lat, lon, elevation, distanceKm, bearingDeg;
  final double? snowDepthM, tempC;
  const Mountain({required this.lat, required this.lon, required this.elevation,
      required this.distanceKm, required this.bearingDeg, this.snowDepthM, this.tempC});
}

class HourPoint {
  final DateTime time;
  final double temp, precip, snowfall, windSpeed, windDir, cloud, humidity, dewPoint;
  /// Deniz seviyesi basıncı (hPa); veri yoksa NaN.
  final double pressure;
  final int weatherCode;
  const HourPoint({required this.time, required this.temp, required this.precip,
      required this.snowfall, required this.windSpeed, required this.windDir,
      required this.cloud, required this.humidity, required this.dewPoint, required this.weatherCode,
      this.pressure = double.nan});
}

class DayPoint {
  final DateTime date;
  final double tMax, tMin, precipSum, snowSum, windMax;
  final int weatherCode;
  final DateTime? sunrise, sunset;
  const DayPoint({required this.date, required this.tMax, required this.tMin,
      required this.precipSum, required this.snowSum, required this.windMax,
      required this.weatherCode, this.sunrise, this.sunset});
}

class MetarObs {
  final String icao, raw;
  final double? tempC, dewC, windKt, windDir, visibilityM, pressureHpa;
  final double distanceKm;
  const MetarObs({required this.icao, required this.raw, required this.distanceKm,
      this.tempC, this.dewC, this.windKt, this.windDir, this.visibilityM, this.pressureHpa});
}

/// Tüm motor ve UI'nin tükettiği tek anlık görüntü.
class WeatherSnapshot {
  final GeoPoint2 place;
  final DateTime fetchedAt;
  final bool fromCache;

  // Şu an (15 dk'lık veri)
  final double temp, feelsLike, humidity, dewPoint, pressure, windSpeed, windDir, windGust;
  final double cloudCover, cloudHigh, precip, snowfall, visibilityM, cape, uv;
  final double? freezingLevelM, snowDepthM, wetBulb;
  final int weatherCode;
  final bool isDay;

  // Toprak sıcaklıkları (0,6,18,54 cm)
  final double? soil0, soil6, soil18, soil54;
  // Geçmiş 3 gün ortalama 0 cm toprak (zemin hafızası)
  final double? soil0Past3dAvg;

  // 1000-300 hPa katmanları: basınç -> {temp, rh, windSpeed, geopotential}
  final Map<int, Map<String, double>> pressureLevels;

  final List<HourPoint> hourly;
  final List<DayPoint> daily;

  // Ensemble: üye sayısı ve olasılıklar (0-100)
  final int ensembleMembers;
  final double ensembleSnowProb, ensembleRainProb;
  // Model kıyaslaması: model adı -> 24 saatlik sıcaklık/yağış toplamı
  final Map<String, double> modelTemp24h;
  final Map<String, double> modelPrecip24h;

  final double aqPm10, aqPm25, aqDust;
  final MetarObs? metar;
  final List<Mountain> mountains;

  const WeatherSnapshot({
    required this.place, required this.fetchedAt, this.fromCache = false,
    required this.temp, required this.feelsLike, required this.humidity,
    required this.dewPoint, required this.pressure, required this.windSpeed,
    required this.windDir, required this.windGust, required this.cloudCover,
    required this.cloudHigh, required this.precip, required this.snowfall,
    required this.visibilityM, required this.cape, required this.uv,
    this.freezingLevelM, this.snowDepthM, this.wetBulb,
    required this.weatherCode, required this.isDay,
    this.soil0, this.soil6, this.soil18, this.soil54, this.soil0Past3dAvg,
    this.pressureLevels = const {}, this.hourly = const [], this.daily = const [],
    this.ensembleMembers = 0, this.ensembleSnowProb = 0, this.ensembleRainProb = 0,
    this.modelTemp24h = const {}, this.modelPrecip24h = const {},
    this.aqPm10 = 0, this.aqPm25 = 0, this.aqDust = 0,
    this.metar, this.mountains = const [],
  });

  WeatherSnapshot copyWith({bool? fromCache, List<Mountain>? mountains, MetarObs? metar}) =>
      WeatherSnapshot(
        place: place, fetchedAt: fetchedAt, fromCache: fromCache ?? this.fromCache,
        temp: temp, feelsLike: feelsLike, humidity: humidity, dewPoint: dewPoint,
        pressure: pressure, windSpeed: windSpeed, windDir: windDir, windGust: windGust,
        cloudCover: cloudCover, cloudHigh: cloudHigh, precip: precip, snowfall: snowfall,
        visibilityM: visibilityM, cape: cape, uv: uv, freezingLevelM: freezingLevelM,
        snowDepthM: snowDepthM, wetBulb: wetBulb, weatherCode: weatherCode, isDay: isDay,
        soil0: soil0, soil6: soil6, soil18: soil18, soil54: soil54, soil0Past3dAvg: soil0Past3dAvg,
        pressureLevels: pressureLevels, hourly: hourly, daily: daily,
        ensembleMembers: ensembleMembers, ensembleSnowProb: ensembleSnowProb,
        ensembleRainProb: ensembleRainProb, modelTemp24h: modelTemp24h,
        modelPrecip24h: modelPrecip24h, aqPm10: aqPm10, aqPm25: aqPm25, aqDust: aqDust,
        metar: metar ?? this.metar, mountains: mountains ?? this.mountains,
      );
}

enum PrecipKind { none, rain, sleet, snow, lentilSnow, blizzard }

/// Motorun ürettiği, doğrulanmış karar seti.
class Analysis {
  final PrecipKind kind;
  final double snowProb, sleetProb, lentilProb, blizzardProb; // 0-100
  final double mountainBonusPct; // "+Dağ Desteği: +%X"
  final double blizzardSeverity; // 0-100
  final double fogProb, fogDensity; // 0-100
  final double starClarity; // 0-100
  final double unevenSnowNote; // 0-100 (her yere yağmama)
  final String unevenSnowText;
  final double confidence; // 0-100 (3-7 gün model uyumu)
  final double localityNote; // yerel gerçeklik sapması (°C)
  const Analysis({required this.kind, this.snowProb = 0, this.sleetProb = 0,
      this.lentilProb = 0, this.blizzardProb = 0, this.mountainBonusPct = 0,
      this.blizzardSeverity = 0, this.fogProb = 0, this.fogDensity = 0,
      this.starClarity = 0, this.unevenSnowNote = 0, this.unevenSnowText = '',
      this.confidence = 0, this.localityNote = 0});
}

/// Yaşam laboratuvarındaki tek hesaplayıcı çıktısı.
class LabResult {
  final String id, emoji, title;
  final String valueText; // örn "%72" ya da "38 dk"
  final double? score; // 0-100, varsa
  final String kanki; // samimi tek cümle
  final String explain; // "Bu ne demek?" çekmecesi
  final bool entertainment; // bilimsel olmayan/eğlence
  const LabResult({required this.id, required this.emoji, required this.title,
      required this.valueText, this.score, required this.kanki, required this.explain,
      this.entertainment = false});
}
