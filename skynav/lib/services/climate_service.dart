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
  const ClimateNormals({required this.fromYear, required this.toYear, required this.tMax, required this.tMin,
      required this.recMax, required this.recMin, required this.recMaxYear, required this.recMinYear});

  static const _cum = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334];
  static int doy(DateTime d) => _cum[d.month - 1] + min<int>(d.day, d.month == 2 ? 28 : 31) - 1;

  double maxOn(DateTime d) => tMax[doy(d)];
  double minOn(DateTime d) => tMin[doy(d)];

  /// Ham günlük seriden hesap (saf; test edilebilir).
  static ClimateNormals? compute(List<String> times, List<double?> mx, List<double?> mn) {
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
    return ClimateNormals(fromYear: y0, toYear: y1, tMax: smooth(sMax, nMax), tMin: smooth(sMin, nMin),
        recMax: rMax, recMin: rMin, recMaxYear: yMax, recMinYear: yMin);
  }

  Map<String, dynamic> toJson() => {'y0': fromYear, 'y1': toYear, 'mx': tMax, 'mn': tMin, 'rx': recMax, 'rn': recMin, 'yx': recMaxYear, 'yn': recMinYear};
  static ClimateNormals fromJson(Map<String, dynamic> j) {
    List<double> d(String k) => [for (final v in j[k] as List) (v as num).toDouble()];
    List<int> i(String k) => [for (final v in j[k] as List) (v as num).toInt()];
    return ClimateNormals(fromYear: j['y0'] as int, toYear: j['y1'] as int, tMax: d('mx'), tMin: d('mn'),
        recMax: d('rx'), recMin: d('rn'), recMaxYear: i('yx'), recMinYear: i('yn'));
  }
}

/// İklim normallerini indirir ve konum başına (0,1° hassasiyetle) kalıcı saklar: normaller değişmez.
class ClimateService {
  static final Map<String, ClimateNormals> _mem = {};
  static String _key(GeoPoint2 p) => 'clim_v1_${p.lat.toStringAsFixed(1)}_${p.lon.toStringAsFixed(1)}';

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
      'daily': 'temperature_2m_max,temperature_2m_min', 'timezone': 'auto',
    });
    final j = asMap(await getJson(client ?? http.Client(), uri));
    final d = asMap(j['daily']);
    final n = ClimateNormals.compute(strList(d['time']), numList(d['temperature_2m_max']), numList(d['temperature_2m_min']));
    if (n == null) return null;
    final k = _key(p);
    _mem[k] = n;
    try { Store.cachePut(k, jsonDecode(jsonEncode(n.toJson())) as Map<String, dynamic>); } catch (_) {}
    return n;
  }
}
