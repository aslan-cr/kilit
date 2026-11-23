// Open-Meteo tabanlı anlık görüntü (WeatherSnapshot) servisi. Saf Dart.
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../data/models.dart';
import 'api_client.dart';

/// Forecast ve model kıyaslaması zorunludur (hata -> exception).
/// Ensemble ve hava kalitesi başarısızsa varsayılan 0 değerlerle devam edilir.
///
/// Birimler: wind_speed m/s; snowfall cm (Open-Meteo varsayılanı); precipitation mm.
class OpenMeteoService {
  OpenMeteoService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _pressureLevels = [1000, 925, 850, 700, 500, 300];
  static const _compareModels = ['ecmwf_ifs025', 'gfs_seamless', 'icon_seamless', 'gem_seamless'];
  static const _ensembleModels = 'gfs_seamless,icon_seamless,ecmwf_ifs025';

  static const _currentVars = [
    'temperature_2m', 'relative_humidity_2m', 'apparent_temperature', 'is_day',
    'precipitation', 'snowfall', 'weather_code', 'cloud_cover', 'pressure_msl',
    'wind_speed_10m', 'wind_direction_10m', 'wind_gusts_10m',
  ];
  static const _minutelyVars = ['precipitation', 'snowfall'];
  static final List<String> _hourlyVars = [
    'temperature_2m', 'relative_humidity_2m', 'precipitation', 'snowfall', 'weather_code', 'pressure_msl',
    'wind_speed_10m', 'wind_direction_10m', 'cloud_cover', 'cloud_cover_high',
    'visibility', 'cape', 'uv_index', 'freezing_level_height', 'snow_depth',
    'soil_temperature_0cm', 'soil_temperature_6cm', 'soil_temperature_18cm', 'soil_temperature_54cm',
    for (final lv in _pressureLevels) ...[
      'temperature_${lv}hPa', 'relative_humidity_${lv}hPa',
      'wind_speed_${lv}hPa', 'geopotential_height_${lv}hPa',
    ],
  ];
  static const _dailyVars = [
    'weather_code', 'temperature_2m_max', 'temperature_2m_min', 'precipitation_sum',
    'snowfall_sum', 'wind_speed_10m_max', 'sunrise', 'sunset',
  ];

  Future<WeatherSnapshot> fetch(GeoPoint2 p) async {
    final res = await Future.wait<Object?>([
      getJson(_client, _forecastUri(p)),
      getJson(_client, _modelsUri(p)),
      _ensembleSafe(p),
      _airSafe(p),
    ]);
    return _build(
      p,
      asMap(res[0]),
      asMap(res[1]),
      res[2] as _Ensemble,
      res[3] as _Air,
    );
  }

  // ---------------------------------------------------------------- URI'ler

  Uri _forecastUri(GeoPoint2 p) => Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': coord(p.lat),
        'longitude': coord(p.lon),
        'current': _currentVars.join(','),
        'minutely_15': _minutelyVars.join(','),
        'hourly': _hourlyVars.join(','),
        'daily': _dailyVars.join(','),
        'past_days': '3',
        'wind_speed_unit': 'ms',
        'timezone': 'auto',
      });

  Uri _modelsUri(GeoPoint2 p) => Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': coord(p.lat),
        'longitude': coord(p.lon),
        'models': _compareModels.join(','),
        'hourly': 'temperature_2m,precipitation',
        'timezone': 'auto',
      });

  // Ensemble zamanları GMT; "şimdi" de UTC olarak alınır (forecast'a bağımlı değil).
  Uri _ensembleUri(GeoPoint2 p) => Uri.https('ensemble-api.open-meteo.com', '/v1/ensemble', {
        'latitude': coord(p.lat),
        'longitude': coord(p.lon),
        'models': _ensembleModels,
        'hourly': 'snowfall,rain',
        'timezone': 'GMT',
      });

  Uri _airUri(GeoPoint2 p) => Uri.https('air-quality-api.open-meteo.com', '/v1/air-quality', {
        'latitude': coord(p.lat),
        'longitude': coord(p.lon),
        'current': 'pm10,pm2_5,dust',
      });

  // ---------------------------------------------------------- yardımcı çağrılar

  Future<_Ensemble> _ensembleSafe(GeoPoint2 p) async {
    try {
      final hourly = asMap(asMap(await getJson(_client, _ensembleUri(p)))['hourly']);
      final i = idxAtOrBefore(strList(hourly['time']), utcHourIso());
      final snow = _memberSeries(hourly, 'snowfall');
      final rain = _memberSeries(hourly, 'rain');
      final n = snow.length;
      return _Ensemble(
        members: n,
        snowProb: _pct(_hits(snow, i), n),
        rainProb: _pct(_hits(rain, i), rain.length),
      );
    } catch (_) {
      return const _Ensemble(members: 0, snowProb: 0, rainProb: 0);
    }
  }

  Future<_Air> _airSafe(GeoPoint2 p) async {
    try {
      final c = asMap(asMap(await getJson(_client, _airUri(p)))['current']);
      return _Air(
        pm10: toD(c['pm10']) ?? 0,
        pm25: toD(c['pm2_5']) ?? 0,
        dust: toD(c['dust']) ?? 0,
      );
    } catch (_) {
      return const _Air(pm10: 0, pm25: 0, dust: 0);
    }
  }

  /// "snowfall_member01" gibi üye serileri (kontrol üyesi dahil değil).
  Map<String, List<double?>> _memberSeries(Map<String, dynamic> hourly, String prefix) => {
        for (final e in hourly.entries)
          if (e.key.startsWith(prefix) && e.key.contains('member')) e.key: numList(e.value),
      };

  /// Sonraki 24 saatte toplam > 0 olan üye sayısı.
  int _hits(Map<String, List<double?>> members, int i) {
    var n = 0;
    for (final s in members.values) {
      if (sumOf(window(s, i, 24)) > 0) n++;
    }
    return n;
  }

  double _pct(int hits, int total) => total == 0 ? 0.0 : hits * 100.0 / total;

  // ------------------------------------------------------------- snapshot

  WeatherSnapshot _build(GeoPoint2 p, Map<String, dynamic> f, Map<String, dynamic> mm,
      _Ensemble ens, _Air air) {
    final cur = asMap(f['current']);
    final nowIso = strOf(cur['time']);
    final temp = toD(cur['temperature_2m']) ??
        (throw const FormatException('Open-Meteo: current.temperature_2m yok'));
    final rh = toD(cur['relative_humidity_2m']) ?? 0.0;

    final hourly = asMap(f['hourly']);
    final times = strList(hourly['time']);
    final hi = idxAtOrBefore(times, nowIso);
    List<double?> h(String k) => numList(hourly[k]);

    final tAll = h('temperature_2m');
    final rhAll = h('relative_humidity_2m');
    final prAll = h('precipitation');
    final snAll = h('snowfall');
    final wcAll = h('weather_code');
    final pmAll = h('pressure_msl');
    final wsAll = h('wind_speed_10m');
    final wdAll = h('wind_direction_10m');
    final ccAll = h('cloud_cover');
    final chAll = h('cloud_cover_high');
    final visAll = h('visibility');
    final capeAll = h('cape');
    final uvAll = h('uv_index');
    final frzAll = h('freezing_level_height');
    final snowDAll = h('snow_depth');
    final soil0All = h('soil_temperature_0cm');
    final soil6All = h('soil_temperature_6cm');
    final soil18All = h('soil_temperature_18cm');
    final soil54All = h('soil_temperature_54cm');

    // Şu an yağış/kar: 15 dakikalık seri (en yakın dilim), yoksa current.
    final minutely = asMap(f['minutely_15']);
    final mi = idxAtOrBefore(strList(minutely['time']), nowIso);
    final minPr = opt(numList(minutely['precipitation']), mi);
    final minSn = opt(numList(minutely['snowfall']), mi);

    final pressureLevels = <int, Map<String, double>>{
      for (final lv in _pressureLevels)
        lv: {
          'temp': at(h('temperature_${lv}hPa'), hi),
          'rh': at(h('relative_humidity_${lv}hPa'), hi),
          'windSpeed': at(h('wind_speed_${lv}hPa'), hi),
          'geopotential': at(h('geopotential_height_${lv}hPa'), hi),
        },
    };

    final hours = <HourPoint>[
      for (var i = 0; i < times.length; i++)
        HourPoint(
          time: DateTime.parse(times[i]),
          temp: at(tAll, i),
          precip: at(prAll, i),
          snowfall: at(snAll, i),
          windSpeed: at(wsAll, i),
          windDir: at(wdAll, i),
          cloud: at(ccAll, i),
          humidity: at(rhAll, i),
          dewPoint: _dewPoint(at(tAll, i), at(rhAll, i)),
          weatherCode: at(wcAll, i).round(),
          pressure: opt(pmAll, i) ?? double.nan,
        ),
    ];

    final daily = asMap(f['daily']);
    final dTimes = strList(daily['time']);
    final dMax = numList(daily['temperature_2m_max']);
    final dMin = numList(daily['temperature_2m_min']);
    final dPr = numList(daily['precipitation_sum']);
    final dSn = numList(daily['snowfall_sum']);
    final dWm = numList(daily['wind_speed_10m_max']);
    final dWc = numList(daily['weather_code']);
    final dRise = strList(daily['sunrise']);
    final dSet = strList(daily['sunset']);
    final days = <DayPoint>[
      for (var i = 0; i < dTimes.length; i++)
        DayPoint(
          date: DateTime.parse(dTimes[i]),
          tMax: at(dMax, i),
          tMin: at(dMin, i),
          precipSum: at(dPr, i),
          snowSum: at(dSn, i),
          windMax: at(dWm, i),
          weatherCode: at(dWc, i).round(),
          sunrise: i < dRise.length ? DateTime.tryParse(dRise[i]) : null,
          sunset: i < dSet.length ? DateTime.tryParse(dSet[i]) : null,
        ),
    ];

    // Zemin hafızası: şimdiden önceki 72 saatin 0 cm toprak ortalaması.
    final pastStart = math.max(0, hi - 72);
    final soil0Past = meanOf(window(soil0All, pastStart, hi - pastStart));

    // Model kıyaslaması: sonraki 24 saat (sıcaklık ortalaması, yağış toplamı).
    final mHourly = asMap(mm['hourly']);
    final mi2 = idxAtOrBefore(strList(mHourly['time']), nowIso);
    final temp24 = <String, double>{};
    final prec24 = <String, double>{};
    for (final m in _compareModels) {
      final t = meanOf(window(numList(mHourly['temperature_2m_$m']), mi2, 24));
      if (t != null) temp24[m] = t;
      final pr = window(numList(mHourly['precipitation_$m']), mi2, 24);
      if (pr.isNotEmpty) prec24[m] = sumOf(pr);
    }

    return WeatherSnapshot(
      place: p,
      fetchedAt: DateTime.now(),
      temp: temp,
      feelsLike: toD(cur['apparent_temperature']) ?? temp,
      humidity: rh,
      dewPoint: _dewPoint(temp, rh),
      pressure: toD(cur['pressure_msl']) ?? 0.0,
      windSpeed: toD(cur['wind_speed_10m']) ?? 0.0,
      windDir: toD(cur['wind_direction_10m']) ?? 0.0,
      windGust: toD(cur['wind_gusts_10m']) ?? 0.0,
      cloudCover: toD(cur['cloud_cover']) ?? 0.0,
      cloudHigh: opt(chAll, hi) ?? 0.0,
      precip: minPr ?? toD(cur['precipitation']) ?? 0.0,
      snowfall: minSn ?? toD(cur['snowfall']) ?? 0.0,
      visibilityM: at(visAll, hi),
      cape: at(capeAll, hi),
      uv: at(uvAll, hi),
      freezingLevelM: opt(frzAll, hi),
      snowDepthM: opt(snowDAll, hi),
      wetBulb: _wetBulb(temp, rh),
      weatherCode: toD(cur['weather_code'])?.round() ?? 0,
      isDay: (toD(cur['is_day']) ?? 1.0) >= 1,
      soil0: opt(soil0All, hi),
      soil6: opt(soil6All, hi),
      soil18: opt(soil18All, hi),
      soil54: opt(soil54All, hi),
      soil0Past3dAvg: soil0Past,
      pressureLevels: pressureLevels,
      hourly: hours,
      daily: days,
      ensembleMembers: ens.members,
      ensembleSnowProb: ens.snowProb,
      ensembleRainProb: ens.rainProb,
      modelTemp24h: temp24,
      modelPrecip24h: prec24,
      aqPm10: air.pm10,
      aqPm25: air.pm25,
      aqDust: air.dust,
    );
  }
}

/// Stull (2011) ıslak termometre formülü. T °C, RH %.
double _wetBulb(double t, double rh) {
  final r = math.min(math.max(rh, 1.0), 100.0);
  return t * math.atan(0.151977 * math.sqrt(r + 8.313659)) +
      math.atan(t + r) -
      math.atan(r - 1.676331) +
      0.00391838 * math.pow(r, 1.5).toDouble() * math.atan(0.023101 * r) -
      4.686035;
}

/// Magnus formülü (a=17.625, b=243.04). T °C, RH %.
double _dewPoint(double t, double rh) {
  const a = 17.625;
  const b = 243.04;
  final r = math.max(rh, 0.1);
  final g = math.log(r / 100) + a * t / (b + t);
  return b * g / (a - g);
}

class _Ensemble {
  const _Ensemble({required this.members, required this.snowProb, required this.rainProb});
  final int members;
  final double snowProb, rainProb;
}

class _Air {
  const _Air({required this.pm10, required this.pm25, required this.dust});
  final double pm10, pm25, dust;
}
