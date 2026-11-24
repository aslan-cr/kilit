import 'dart:math' as math;
import 'package:http/http.dart' as http;
import '../data/models.dart';
import 'api_client.dart';

/// Türkiye'deki başlıca kayak merkezleri (yaklaşık konum; yükseklikler pist alt/üst, yaklaşık).
class SkiResort {
  final String name, city;
  final double lat, lon, base, top; // m
  const SkiResort(this.name, this.city, this.lat, this.lon, this.base, this.top);
  double get mid => (base + top) / 2;
}

const skiResorts = [
  SkiResort('Palandöken', 'Erzurum', 39.860, 41.270, 2200, 3176),
  SkiResort('Sarıkamış Cıbıltepe', 'Kars', 40.300, 42.530, 2100, 2634),
  SkiResort('Erciyes', 'Kayseri', 38.540, 35.490, 2150, 3400),
  SkiResort('Uludağ', 'Bursa', 40.105, 29.120, 1750, 2300),
  SkiResort('Kartalkaya', 'Bolu', 40.610, 31.740, 1850, 2220),
  SkiResort('Davraz', 'Isparta', 37.760, 30.740, 1650, 2635),
  SkiResort('Kartepe', 'Kocaeli', 40.650, 30.090, 1450, 1650),
  SkiResort('Ilgaz', 'Kastamonu', 41.070, 33.720, 1800, 2000),
];

/// Bir merkezin anlık kar ve hava durumu (model tahmini, merkez orta yüksekliğinde).
class SkiNow {
  final SkiResort r;
  final double snowCm, new24, next72, temp, wind, gust, gustNext12;
  final int code;
  const SkiNow(this.r, {required this.snowCm, required this.new24, required this.next72, required this.temp,
      required this.wind, required this.gust, required this.gustNext12, required this.code});
  /// Sert rüzgârda teleferik ve telesiyejler durabilir (genelde 15–20 m/s hamle üstü).
  bool get windy => math.max(gust, gustNext12) >= 15;
}

class SkiService {
  static List<SkiNow>? _cache;
  static DateTime? _at;

  /// Tüm merkezler tek istekte (Open-Meteo çoklu konum). 30 dk saklanır.
  static Future<List<SkiNow>> load({http.Client? client}) async {
    if (_cache != null && _at != null && DateTime.now().difference(_at!) < const Duration(minutes: 30)) return _cache!;
    String join(double Function(SkiResort) f, int d) => skiResorts.map((r) => f(r).toStringAsFixed(d)).join(',');
    final body = await getJson(client ?? http.Client(), Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': join((r) => r.lat, 3), 'longitude': join((r) => r.lon, 3), 'elevation': join((r) => r.mid, 0),
      'hourly': 'snow_depth,snowfall,temperature_2m,wind_speed_10m,wind_gusts_10m,weather_code',
      'past_days': '1', 'forecast_days': '3', 'wind_speed_unit': 'ms', 'timezone': 'auto',
    }));
    final out = parse(body, DateTime.now());
    _cache = out; _at = DateTime.now();
    return out;
  }

  /// Saf ayrıştırma: çoklu konumda yanıt bir dizi, tek konumda nesnedir.
  static List<SkiNow> parse(Object? body, DateTime now) {
    final list = body is List ? body : [body];
    final out = <SkiNow>[];
    for (var k = 0; k < list.length && k < skiResorts.length; k++) {
      final h = asMap(asMap(list[k])['hourly']);
      final times = [for (final t in strList(h['time'])) DateTime.parse(t)];
      if (times.isEmpty) continue;
      var i = 0;
      for (var j = 0; j < times.length; j++) { if (!times[j].isAfter(now)) i = j; }
      List<double?> v(String key) => numList(h[key]);
      final depth = v('snow_depth'), snow = v('snowfall'), t = v('temperature_2m'), w = v('wind_speed_10m'), g = v('wind_gusts_10m'), c = v('weather_code');
      double sum(List<double?> l, int a, int b) { var s = 0.0; for (var j = math.max(0, a); j < math.min(l.length, b); j++) { s += l[j] ?? 0; } return s; }
      double mx(List<double?> l, int a, int b) { var m = 0.0; for (var j = math.max(0, a); j < math.min(l.length, b); j++) { m = math.max(m, l[j] ?? 0); } return m; }
      out.add(SkiNow(skiResorts[k],
          snowCm: (opt(depth, i) ?? 0) * 100,
          new24: sum(snow, i - 23, i + 1),
          next72: sum(snow, i + 1, i + 73),
          temp: opt(t, i) ?? double.nan,
          wind: opt(w, i) ?? 0, gust: opt(g, i) ?? 0, gustNext12: mx(g, i + 1, i + 13),
          code: (opt(c, i) ?? 0).round()));
    }
    return out;
  }

  /// İki nokta arası kuş uçuşu km.
  static double km(GeoPoint2 a, SkiResort r) {
    const rr = 6371.0;
    final dLat = (r.lat - a.lat) * math.pi / 180, dLon = (r.lon - a.lon) * math.pi / 180;
    final h = math.pow(math.sin(dLat / 2), 2) + math.cos(a.lat * math.pi / 180) * math.cos(r.lat * math.pi / 180) * math.pow(math.sin(dLon / 2), 2);
    return 2 * rr * math.asin(math.sqrt(h.toDouble()));
  }
}
