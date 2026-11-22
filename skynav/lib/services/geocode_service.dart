// Photon (komoot) ile konum arama. Anahtar gerektirmez. Saf Dart.
import 'package:http/http.dart' as http;

import '../data/models.dart';
import 'api_client.dart';

class GeocodeService {
  GeocodeService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Sorgu için en fazla 8 sonuç. Etiket: "ad, il/eyalet, ülke".
  Future<List<GeoPoint2>> search(String q) async {
    final query = q.trim();
    if (query.isEmpty) return const [];

    final body = await getJson(
      _client,
      Uri.https('photon.komoot.io', '/api/', {'q': query, 'limit': '8', 'lang': 'en'}),
    );
    final features = asMap(body)['features'];
    if (features is! List) return const [];

    final out = <GeoPoint2>[];
    for (final f in features) {
      if (f is! Map) continue;
      final coords = asMap(f['geometry'])['coordinates'];
      if (coords is! List || coords.length < 2) continue;
      // GeoJSON sırası: [lon, lat]
      final lon = toD(coords[0]);
      final lat = toD(coords[1]);
      if (lat == null || lon == null) continue;
      out.add(GeoPoint2(lat, lon, name: _label(asMap(f['properties']))));
    }
    return out;
  }

  String _label(Map<String, dynamic> pr) {
    String s(String k) => strOf(pr[k]).trim();
    final region = s('state').isNotEmpty ? s('state') : s('city');
    final parts = <String>[];
    for (final part in [s('name'), region, s('country')]) {
      if (part.isNotEmpty && !parts.contains(part)) parts.add(part);
    }
    return parts.join(', ');
  }
}
