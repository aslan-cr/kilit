// Çevre dağlar radarı: 16 yön x (10, 25, 40 km) = 48 nokta. Saf Dart.
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../data/models.dart';
import 'api_client.dart';

class MountainRadar {
  MountainRadar({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _radiiKm = [10.0, 25.0, 40.0];
  static const _directions = 16;
  static const _earthRadiusKm = 6371.0;
  static const _maxPeaks = 4;

  /// Merkezden daha yüksek en iyi [_maxPeaks] noktayı döndürür (yükseklik azalan).
  Future<List<Mountain>> scan(GeoPoint2 p) async {
    // İndeks 0: merkez; 1..48: halka noktaları.
    final coords = [_RingPoint(p.lat, p.lon, 0, 0), ..._ringPoints(p)];

    final elevJson = asMap(await getJson(
      _client,
      Uri.https('api.open-meteo.com', '/v1/elevation', {
        'latitude': coords.map((c) => coord(c.lat)).join(','),
        'longitude': coords.map((c) => coord(c.lon)).join(','),
      }),
    ));
    final elev = numList(elevJson['elevation']);
    if (elev.length != coords.length) {
      throw Exception('Yükseklik yanıtı eksik (${elev.length}/${coords.length})');
    }

    final centerElev = p.elevation ?? elev[0];
    if (centerElev == null) throw Exception('Merkez yüksekliği alınamadı');

    final candidates = [
      for (var i = 1; i < coords.length; i++)
        if (elev[i] != null && elev[i]! > centerElev) i,
    ]..sort((a, b) => elev[b]!.compareTo(elev[a]!));
    final top = candidates.take(_maxPeaks).toList();
    if (top.isEmpty) return const [];

    // Kar derinliği current'ta güvenilir değil; hourly'den şu anki saat alınır.
    final body = await getJson(
      _client,
      Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': top.map((i) => coord(coords[i].lat)).join(','),
        'longitude': top.map((i) => coord(coords[i].lon)).join(','),
        'current': 'temperature_2m',
        'hourly': 'snow_depth',
        'forecast_days': '1',
        'timezone': 'auto',
      }),
    );
    // Tek konum -> nesne, çok konum -> dizi.
    final List<dynamic> items = body is List ? body : [body];

    final result = <Mountain>[];
    for (var k = 0; k < top.length; k++) {
      final item = asMap(k < items.length ? items[k] : null);
      final cur = asMap(item['current']);
      final hourly = asMap(item['hourly']);
      final hi = idxAtOrBefore(strList(hourly['time']), strOf(cur['time']));
      final c = coords[top[k]];
      result.add(Mountain(
        lat: c.lat,
        lon: c.lon,
        elevation: elev[top[k]]!,
        distanceKm: c.distKm,
        bearingDeg: c.bearing,
        snowDepthM: opt(numList(hourly['snow_depth']), hi),
        tempC: toD(cur['temperature_2m']),
      ));
    }
    return result;
  }

  List<_RingPoint> _ringPoints(GeoPoint2 p) {
    final out = <_RingPoint>[];
    for (final r in _radiiKm) {
      for (var k = 0; k < _directions; k++) {
        final bearing = k * 360.0 / _directions;
        final d = _destination(p.lat, p.lon, bearing, r);
        out.add(_RingPoint(d.lat, d.lon, bearing, r));
      }
    }
    return out;
  }

  /// Küre üzerinde başlangıçtan verilen yön ve mesafede nokta (büyük daire).
  ({double lat, double lon}) _destination(
      double lat, double lon, double bearingDeg, double distKm) {
    const rad = math.pi / 180;
    final delta = distKm / _earthRadiusKm;
    final theta = bearingDeg * rad;
    final phi1 = lat * rad;
    final lambda1 = lon * rad;
    final phi2 = math.asin(math.sin(phi1) * math.cos(delta) +
        math.cos(phi1) * math.sin(delta) * math.cos(theta));
    final lambda2 = lambda1 +
        math.atan2(math.sin(theta) * math.sin(delta) * math.cos(phi1),
            math.cos(delta) - math.sin(phi1) * math.sin(phi2));
    final lon2 = ((lambda2 / rad) + 540) % 360 - 180;
    return (lat: phi2 / rad, lon: lon2);
  }
}

class _RingPoint {
  const _RingPoint(this.lat, this.lon, this.bearing, this.distKm);
  final double lat, lon, bearing, distKm;
}
