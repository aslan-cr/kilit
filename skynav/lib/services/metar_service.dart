// aviationweather.gov METAR servisi: bbox içinde en yakın istasyon. Saf Dart.
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../data/models.dart';
import 'api_client.dart';

class MetarService {
  MetarService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _mileM = 1609.34;
  // Önce dar kutu, bulunamazsa geniş kutu.
  static const _boxes = [0.7, 1.5];

  /// En yakın istasyonun METAR'ı; istasyon yoksa null. HTTP hatasında exception.
  Future<MetarObs?> nearest(GeoPoint2 p) async {
    for (final d in _boxes) {
      final best = _closest(p, await _query(p, d));
      if (best != null) return best;
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> _query(GeoPoint2 p, double d) async {
    final bbox = [
      coord(p.lat - d),
      coord(p.lon - d),
      coord(p.lat + d),
      coord(p.lon + d),
    ].join(',');
    final uri = Uri(
      scheme: 'https',
      host: 'aviationweather.gov',
      path: '/api/data/metar',
      query: 'bbox=$bbox&format=json',
    );
    final body = await getJson(_client, uri);
    if (body is! List) return const [];
    return [
      for (final e in body)
        if (e is Map<String, dynamic>) e,
    ];
  }

  MetarObs? _closest(GeoPoint2 p, List<Map<String, dynamic>> recs) {
    MetarObs? best;
    var bestD = double.infinity;
    for (final r in recs) {
      final icao = r['icaoId']?.toString() ?? '';
      final lat = toD(r['lat']);
      final lon = toD(r['lon']);
      if (icao.isEmpty || lat == null || lon == null) continue;
      final d = _haversineKm(p.lat, p.lon, lat, lon);
      if (d < bestD) {
        bestD = d;
        best = MetarObs(
          icao: icao,
          raw: strOf(r['rawOb']),
          distanceKm: d,
          tempC: toD(r['temp']),
          dewC: toD(r['dewp']),
          windKt: toD(r['wspd']),
          windDir: toD(r['wdir']), // "VRB" gibi metin değerler null olur
          visibilityM: _visibilityM(r['visib']),
          pressureHpa: toD(r['altim']), // altim zaten hPa
        );
      }
    }
    return best;
  }

  /// visib: sayı (statute mile) veya "10+", "1 1/2", "M1/4" gibi metin.
  double? _visibilityM(Object? v) {
    if (v is num) return v.toDouble() * _mileM;
    if (v is! String) return null;
    final s = v.trim().replaceAll('+', '').replaceAll('M', '');
    var total = 0.0;
    var any = false;
    for (final part in s.split(' ')) {
      if (part.isEmpty) continue;
      double? val;
      if (part.contains('/')) {
        final ab = part.split('/');
        final a = ab.length == 2 ? double.tryParse(ab[0]) : null;
        final b = ab.length == 2 ? double.tryParse(ab[1]) : null;
        if (a != null && b != null && b != 0) val = a / b;
      } else {
        val = double.tryParse(part);
      }
      if (val == null) return null;
      total += val;
      any = true;
    }
    return any ? total * _mileM : null;
  }

  double _haversineKm(double la1, double lo1, double la2, double lo2) {
    const rad = math.pi / 180;
    final dLat = (la2 - la1) * rad;
    final dLon = (lo2 - lo1) * rad;
    final s1 = math.sin(dLat / 2);
    final s2 = math.sin(dLon / 2);
    final a = s1 * s1 + math.cos(la1 * rad) * math.cos(la2 * rad) * s2 * s2;
    return 2 * 6371.0 * math.asin(math.sqrt(a));
  }
}
