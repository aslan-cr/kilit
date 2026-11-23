// Konum arama: Open-Meteo Geocoding (Türkçe adlar, il, rakım) + Photon (komoot, köy/mahalle).
// İkisi paralel sorgulanır, sonuçlar birleştirilir. Anahtar gerektirmez. Saf Dart.
import 'dart:math' as math;
import 'package:http/http.dart' as http;

import '../data/models.dart';
import 'api_client.dart';

/// Arama servislerinin hiçbirine ulaşılamadı.
class GeocodeOffline implements Exception {
  const GeocodeOffline();
}

class GeocodeService {
  GeocodeService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Sorgu için en fazla 10 sonuç. Etiket: "ad, il, ülke". [near]: yakın sonuçlar öne alınır.
  /// Hiçbir servise ulaşılamazsa [GeocodeOffline] fırlatır.
  Future<List<GeoPoint2>> search(String q, {GeoPoint2? near}) async {
    final query = q.trim();
    if (query.length < 2) return const [];
    var r = await _both(query, near);
    // "Ağrı" gibi yazımlar bir serviste eşleşmezse düz harflerle bir kez daha dene ("Agri")
    if (r.points.isEmpty) {
      final folded = fold(query);
      if (folded != query) r = await _both(folded, near);
    }
    if (r.points.isEmpty && r.failures == 2) throw const GeocodeOffline();
    return r.points;
  }

  Future<({List<GeoPoint2> points, int failures})> _both(String q, GeoPoint2? near) async {
    var failures = 0;
    Future<List<GeoPoint2>> safe(Future<List<GeoPoint2>> f) => f.catchError((_) { failures++; return <GeoPoint2>[]; });
    final res = await Future.wait([safe(_openMeteo(q)), safe(_photon(q, near))]);
    return (points: merge(res[0], res[1]), failures: failures);
  }

  Future<List<GeoPoint2>> _openMeteo(String q) async => parseOpenMeteo(await getJson(_client,
      Uri.https('geocoding-api.open-meteo.com', '/v1/search', {'name': q, 'count': '10', 'language': 'tr', 'format': 'json'})));

  Future<List<GeoPoint2>> _photon(String q, GeoPoint2? near) async => parsePhoton(await getJson(_client,
      Uri.https('photon.komoot.io', '/api/', {
        'q': q, 'limit': '8', 'lang': 'default',
        if (near != null) ...{'lat': near.lat.toStringAsFixed(3), 'lon': near.lon.toStringAsFixed(3)},
      })));

  /// Open-Meteo Geocoding yanıtı: {"results":[{name, latitude, longitude, elevation, admin1, admin2, country}]}.
  static List<GeoPoint2> parseOpenMeteo(Object? body) {
    final list = asMap(body)['results'];
    if (list is! List) return const [];
    final out = <GeoPoint2>[];
    for (final e in list) {
      if (e is! Map) continue;
      final m = e.cast<String, dynamic>();
      final lat = toD(m['latitude']), lon = toD(m['longitude']);
      if (lat == null || lon == null) continue;
      final name = strOf(m['name']).trim();
      final parts = <String>[];
      for (final p in [name, strOf(m['admin2']).trim(), strOf(m['admin1']).trim(), strOf(m['country']).trim()]) {
        if (p.isNotEmpty && !parts.contains(p)) parts.add(p);
      }
      // İlçe + il + ülke uzun olmasın: ad, (ilçe), il, ülke en fazla 3 parça
      final label = parts.length > 3 ? [parts[0], parts[2], parts[3]].join(', ') : parts.join(', ');
      out.add(GeoPoint2(lat, lon, elevation: toD(m['elevation']), name: _shortTr(label)));
    }
    return out;
  }

  /// Photon GeoJSON yanıtı.
  static List<GeoPoint2> parsePhoton(Object? body) {
    final features = asMap(body)['features'];
    if (features is! List) return const [];
    final out = <GeoPoint2>[];
    for (final f in features) {
      if (f is! Map) continue;
      final coords = asMap(f['geometry'])['coordinates'];
      if (coords is! List || coords.length < 2) continue;
      final lon = toD(coords[0]), lat = toD(coords[1]); // GeoJSON: [lon, lat]
      if (lat == null || lon == null) continue;
      final pr = asMap(f['properties']);
      String s(String k) => strOf(pr[k]).trim();
      final region = s('state').isNotEmpty ? s('state') : s('city');
      final parts = <String>[];
      for (final part in [s('name'), s('county'), region, s('country')]) {
        if (part.isNotEmpty && !parts.contains(part)) parts.add(part);
      }
      if (parts.isEmpty) continue;
      out.add(GeoPoint2(lat, lon, name: _shortTr(parts.take(3).join(', '))));
    }
    return out;
  }

  /// Önce Open-Meteo sonuçları; Photon'dan yalnızca 2 km'den uzak (yeni) yerler eklenir. En fazla 10.
  static List<GeoPoint2> merge(List<GeoPoint2> a, List<GeoPoint2> b) {
    final out = [...a];
    for (final p in b) {
      if (out.any((q) => _km(p, q) < 2)) continue;
      out.add(p);
    }
    return out.take(10).toList();
  }

  static double _km(GeoPoint2 a, GeoPoint2 b) {
    const r = 6371.0;
    final dLat = (b.lat - a.lat) * math.pi / 180, dLon = (b.lon - a.lon) * math.pi / 180;
    final h = math.pow(math.sin(dLat / 2), 2) + math.cos(a.lat * math.pi / 180) * math.cos(b.lat * math.pi / 180) * math.pow(math.sin(dLon / 2), 2);
    return 2 * r * math.asin(math.sqrt(h.toDouble()));
  }

  /// Türkiye içindeki yerlerde ülke adını yazma (kısa ve tanıdık: "Doğubayazıt, Ağrı").
  static String _shortTr(String label) {
    for (final c in [', Türkiye', ', Turkey', ', Türkiye Cumhuriyeti']) {
      if (label.endsWith(c) && label.length > c.length) return label.substring(0, label.length - c.length);
    }
    return label;
  }

  /// Türkçe harfleri düzleştirir: "Ağrı Doğubayazıt" → "Agri Dogubayazit".
  static String fold(String s) {
    const map = {'ç': 'c', 'Ç': 'C', 'ğ': 'g', 'Ğ': 'G', 'ı': 'i', 'İ': 'I', 'ö': 'o', 'Ö': 'O', 'ş': 's', 'Ş': 'S', 'ü': 'u', 'Ü': 'U', 'â': 'a', 'î': 'i', 'û': 'u'};
    return s.split('').map((c) => map[c] ?? c).join();
  }
}
