import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../data/models.dart';
import 'api_client.dart';
import 'store.dart';

/// Bir yerin 30 yıllık iklim normalleri ve takvim günü rekorları (ERA5 yeniden analizi, Open-Meteo arşivi).
class ClimateNormals {
  final int fromYear, toYear;
  /// Yılın günü (0..364, 29 Şubat 28 Şubat sayılır) için 31 günlük kayan ortalama en yüksek/en düşük.
  final List<double> tMax, tMin;
  /// O takvim gününün rekorları ve yılları.
  final List<double> recMax, recMin;
  final List<int> recMaxYear, recMinYear;
  /// Kar sezonu (1 Eylül → 31 Mayıs, 273 gün) boyunca ortalama birikmiş yeni kar (cm). Boşsa veri yok.
  final List<double> snowCum;
  const ClimateNormals({required this.fromYear, required this.toYear, required this.tMax, required this.tMin,
      required this.recMax, required this.recMin, required this.recMaxYear, required this.recMinYear, this.snowCum = const []});

  /// Kar sezonu günü: 1 Eylül = 0 … 31 Mayıs = 272; sezon dışı (Haziran–Ağustos) null.
  static int? seasonDay(DateTime d) {
    if (d.month >= 6 && d.month <= 8) return null;
    final start = DateTime(d.month >= 9 ? d.year : d.year - 1, 9, 1);
    return min(272, DateTime(d.year, d.month, d.day).difference(start).inDays - (d.month <= 5 && _leap(start.year + 1) && (d.month > 2) ? 1 : 0));
  }
  static bool _leap(int y) => (y % 4 == 0 && y % 100 != 0) || y % 400 == 0;

  /// Bu tarihe kadar normalde biriken kar (cm); veri yoksa null.
  double? snowNormalBy(DateTime d) { final k = seasonDay(d); return k == null || snowCum.isEmpty ? null : snowCum[k]; }
  double get snowSeasonNormal => snowCum.isEmpty ? 0 : snowCum.last;

  static const _cum = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334];
  static int doy(DateTime d) => _cum[d.month - 1] + min<int>(d.day, d.month == 2 ? 28 : 31) - 1;

  double maxOn(DateTime d) => tMax[doy(d)];
  double minOn(DateTime d) => tMin[doy(d)];

  /// Ham günlük seriden hesap (saf; test edilebilir).
  static ClimateNormals? compute(List<String> times, List<double?> mx, List<double?> mn, [List<double?> snow = const []]) {
    final sMax = List<double>.filled(365, 0), sMin = List<double>.filled(365, 0);
    final nMax = List<int>.filled(365, 0), nMin = List<int>.filled(365, 0);
    final rMax = List<double>.filled(365, -999), rMin = List<double>.filled(365, 999);
    final yMax = List<int>.filled(365, 0), yMin = List<int>.filled(365, 0);
    var y0 = 9999, y1 = 0;
    for (var i = 0; i < times.length; i++) {
      final d = DateTime.tryParse(times[i]);
      if (d == null) continue;
      final k = doy(d);
      y0 = min(y0, d.year); y1 = max(y1, d.year);
      final a = i < mx.length ? mx[i] : null, b = i < mn.length ? mn[i] : null;
      if (a != null && a.isFinite) { sMax[k] += a; nMax[k]++; if (a > rMax[k]) { rMax[k] = a; yMax[k] = d.year; } }
      if (b != null && b.isFinite) { sMin[k] += b; nMin[k]++; if (b < rMin[k]) { rMin[k] = b; yMin[k] = d.year; } }
    }
    if (nMax.where((n) => n > 0).length < 300) return null;
    List<double> smooth(List<double> s, List<int> n) => [
          for (var k = 0; k < 365; k++) () {
            var t = 0.0, c = 0;
            for (var j = -15; j <= 15; j++) { final q = (k + j + 365) % 365; t += s[q]; c += n[q]; }
            return c == 0 ? 0.0 : t / c;
          }(),
        ];
    // Sezon birikimi: her tam sezon için günlük kümülatif, sonra sezonların ortalaması
    final seasons = <int, List<double>>{};
    for (var i = 0; i < times.length && i < snow.length; i++) {
      final d = DateTime.tryParse(times[i]); final v = snow[i];
      if (d == null) continue;
      final k = seasonDay(d);
      if (k == null) continue;
      final sy = d.month >= 9 ? d.year : d.year - 1;
      final arr = seasons.putIfAbsent(sy, () => List<double>.filled(273, double.nan));
      arr[k] = (v != null && v.isFinite) ? v : 0;
    }
    final full = seasons.values.where((a) => a.where((x) => x.isNaN).length < 10).toList();
    final snowCum = <double>[];
    if (full.length >= 5) {
      final sum = List<double>.filled(273, 0);
      for (final a in full) {
        var c = 0.0;
        for (var k = 0; k < 273; k++) { c += a[k].isNaN ? 0 : a[k]; sum[k] += c; }
      }
      for (var k = 0; k < 273; k++) { snowCum.add(sum[k] / full.length); }
    }
    return ClimateNormals(fromYear: y0, toYear: y1, tMax: smooth(sMax, nMax), tMin: smooth(sMin, nMin),
        recMax: rMax, recMin: rMin, recMaxYear: yMax, recMinYear: yMin, snowCum: snowCum);
  }

  Map<String, dynamic> toJson() => {'y0': fromYear, 'y1': toYear, 'mx': tMax, 'mn': tMin, 'rx': recMax, 'rn': recMin, 'yx': recMaxYear, 'yn': recMinYear, 'sc': snowCum};
  static ClimateNormals fromJson(Map<String, dynamic> j) {
    List<double> d(String k) => [for (final v in j[k] as List) (v as num).toDouble()];
    List<int> i(String k) => [for (final v in j[k] as List) (v as num).toInt()];
    return ClimateNormals(fromYear: j['y0'] as int, toYear: j['y1'] as int, tMax: d('mx'), tMin: d('mn'),
        recMax: d('rx'), recMin: d('rn'), recMaxYear: i('yx'), recMinYear: i('yn'), snowCum: j['sc'] == null ? const [] : d('sc'));
  }
}

/// İklim normallerini indirir ve konum başına (0,1° hassasiyetle) kalıcı saklar: normaller değişmez.
class ClimateService {
  static final Map<String, ClimateNormals> _mem = {};
  static String _key(GeoPoint2 p) => 'clim_v2_${p.lat.toStringAsFixed(1)}_${p.lon.toStringAsFixed(1)}';

  /// Önceden indirilmişse hemen döner (Keşfet kutusu için), yoksa null.
  static ClimateNormals? cached(GeoPoint2 p) {
    final k = _key(p);
    final m = _mem[k];
    if (m != null) return m;
    try {
      final c = Store.cacheGet(k);
      if (c != null) return _mem[k] = ClimateNormals.fromJson(c.v);
    } catch (_) {}
    return null;
  }

  static final Map<String, Future<ClimateNormals?>> _inflight = {};

  /// Aynı yer için aynı anda tek indirme.
  static Future<ClimateNormals?> load(GeoPoint2 p, {http.Client? client}) {
    final have = cached(p);
    if (have != null) return Future.value(have);
    final k = _key(p);
    return _inflight[k] ??= _fetch(p, client).whenComplete(() => _inflight.remove(k));
  }

  static Future<ClimateNormals?> _fetch(GeoPoint2 p, http.Client? client) async {
    final now = DateTime.now();
    final y1 = now.year - 1, y0 = y1 - 29;
    final uri = Uri.https('archive-api.open-meteo.com', '/v1/archive', {
      'latitude': coord(p.lat), 'longitude': coord(p.lon),
      'start_date': '$y0-01-01', 'end_date': '$y1-12-31',
      'daily': 'temperature_2m_max,temperature_2m_min,snowfall_sum', 'timezone': 'auto',
    });
    final j = asMap(await getJson(client ?? http.Client(), uri));
    final d = asMap(j['daily']);
    final n = ClimateNormals.compute(strList(d['time']), numList(d['temperature_2m_max']), numList(d['temperature_2m_min']), numList(d['snowfall_sum']));
    if (n == null) return null;
    final k = _key(p);
    _mem[k] = n;
    try { Store.cachePut(k, jsonDecode(jsonEncode(n.toJson())) as Map<String, dynamic>); } catch (_) {}
    return n;
  }
}

/// Bu kar sezonunda (1 Eylül'den bugüne) günlük yağan kar ve birikimi. Yakın geçmiş için
/// Open-Meteo Historical Forecast API (gecikmesiz). 6 saat bellekte saklanır.
class SeasonSnow {
  final List<DateTime> days;
  final List<double> cum; // cm, birikmiş
  const SeasonSnow(this.days, this.cum);
  double get total => cum.isEmpty ? 0 : cum.last;

  static final Map<String, (DateTime, SeasonSnow)> _mem = {};

  static SeasonSnow fromDaily(List<String> times, List<double?> snow) {
    final d = <DateTime>[]; final c = <double>[];
    var t = 0.0;
    for (var i = 0; i < times.length; i++) {
      final x = DateTime.tryParse(times[i]);
      if (x == null) continue;
      final v = i < snow.length ? snow[i] : null;
      t += (v != null && v.isFinite) ? v : 0;
      d.add(x); c.add(t);
    }
    return SeasonSnow(d, c);
  }

  static Future<SeasonSnow?> load(GeoPoint2 p, {http.Client? client}) async {
    final now = DateTime.now();
    if (ClimateNormals.seasonDay(now) == null) return null; // yaz: sezon yok
    final k = '${p.lat.toStringAsFixed(1)}_${p.lon.toStringAsFixed(1)}';
    final m = _mem[k];
    if (m != null && now.difference(m.$1) < const Duration(hours: 6)) return m.$2;
    final start = DateTime(now.month >= 9 ? now.year : now.year - 1, 9, 1);
    String f(DateTime x) => '${x.year}-${x.month.toString().padLeft(2, '0')}-${x.day.toString().padLeft(2, '0')}';
    final j = asMap(await getJson(client ?? http.Client(), Uri.https('historical-forecast-api.open-meteo.com', '/v1/forecast', {
      'latitude': coord(p.lat), 'longitude': coord(p.lon), 'start_date': f(start), 'end_date': f(now),
      'daily': 'snowfall_sum', 'timezone': 'auto',
    })));
    final d = asMap(j['daily']);
    final s = fromDaily(strList(d['time']), numList(d['snowfall_sum']));
    _mem[k] = (now, s);
    return s;
  }
}

/// Son 30 günün gerçekleşen günlük değerleri (Open-Meteo, past_days). 3 saat bellekte.
class RecentDays {
  static final Map<String, (DateTime, List<DayPoint>)> _mem = {};

  static List<DayPoint> parse(Object? body) {
    final d = asMap(asMap(body)['daily']);
    final t = strList(d['time']);
    final mx = numList(d['temperature_2m_max']), mn = numList(d['temperature_2m_min']);
    final sn = numList(d['snowfall_sum']), pr = numList(d['precipitation_sum']);
    return [
      for (var i = 0; i < t.length; i++)
        if (opt(mx, i) != null)
          DayPoint(date: DateTime.parse(t[i]), tMax: opt(mx, i)!, tMin: opt(mn, i) ?? opt(mx, i)!, precipSum: opt(pr, i) ?? 0, snowSum: opt(sn, i) ?? 0, windMax: 0, weatherCode: 0),
    ];
  }

  static Future<List<DayPoint>> load(GeoPoint2 p, {http.Client? client}) async {
    final k = '${p.lat.toStringAsFixed(2)}_${p.lon.toStringAsFixed(2)}';
    final m = _mem[k];
    if (m != null && DateTime.now().difference(m.$1) < const Duration(hours: 3)) return m.$2;
    final body = await getJson(client ?? http.Client(), Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': coord(p.lat), 'longitude': coord(p.lon),
      'daily': 'temperature_2m_max,temperature_2m_min,snowfall_sum,precipitation_sum',
      'past_days': '30', 'forecast_days': '1', 'timezone': 'auto',
    }));
    final today = DateTime.now();
    final r = parse(body).where((d) => d.date.isBefore(DateTime(today.year, today.month, today.day))).toList();
    _mem[k] = (DateTime.now(), r);
    return r;
  }
}

