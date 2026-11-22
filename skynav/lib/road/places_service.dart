// Yer arama (Photon) ve yakın çevre sorgusu (Overpass).
// Saf Dart: yalnızca `http` paketi kullanır, UI bağımlılığı yoktur.
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'osrm_service.dart' show haversineM;

class PlacesException implements Exception {
  final String message;
  const PlacesException(this.message);
  @override
  String toString() => 'PlacesException: $message';
}

/// Photon arama veya Overpass yakın çevre sonucu tek yer.
class Place {
  final String name, subtitle, type;
  final double lat, lon;
  const Place({
    required this.name,
    this.subtitle = '',
    required this.lat,
    required this.lon,
    this.type = '',
  });
}

/// Overpass kategorisi: Türkçe etiket, emoji ve OSM etiketi.
class PlaceCategory {
  final String labelTr, emoji, osmKey, osmValue;
  const PlaceCategory(this.labelTr, this.emoji, this.osmKey, this.osmValue);
  String get tag => '$osmKey=$osmValue';
}

/// Hızlı seçim çipi: bir kategori ya da bir zincir.
class NearbyQuery {
  final String labelTr, emoji;
  final String? chain; // PlacesService.chains içinden
  final String? category; // PlacesService.categories anahtarı
  const NearbyQuery(this.labelTr, this.emoji, {this.chain, this.category});
}

class PlacesService {
  static const String photonUrl = 'https://photon.komoot.io/api/';
  static const String overpassUrl = 'https://overpass-api.de/api/interpreter';
  static const Duration cacheTtl = Duration(minutes: 5);
  static const Duration minOverpassGap = Duration(seconds: 2);

  /// Kategori anahtarı Türkçe ad. [nearby] `category:` parametresi bunu alır.
  static const Map<String, PlaceCategory> categories = {
    'fırın': PlaceCategory('Fırın', '🥖', 'shop', 'bakery'),
    'bakkal': PlaceCategory('Bakkal', '🏪', 'shop', 'convenience'),
    'eczane': PlaceCategory('Eczane', '💊', 'amenity', 'pharmacy'),
    'kafe': PlaceCategory('Kafe', '☕', 'amenity', 'cafe'),
    'benzinlik': PlaceCategory('Benzinlik', '⛽', 'amenity', 'fuel'),
    'hastane': PlaceCategory('Hastane', '🏥', 'amenity', 'hospital'),
    'market': PlaceCategory('Market', '🛒', 'shop', 'supermarket'),
  };

  /// Overpass'ta marka/isim regex ile aranacak zincirler.
  static const List<String> chains = [
    'Migros', 'BİM', 'A101', 'ŞOK', 'CarrefourSA', 'Walmart', 'Lidl', 'Tesco',
    'Aldi', 'Carrefour', 'Kaufland', 'Spar', 'Auchan', 'Mercadona', 'Costco',
    'Target',
  ];

  /// Hızlı çipler: önce kategoriler, sonra Türkiye'de yaygın zincirler.
  static const List<NearbyQuery> quickChips = [
    NearbyQuery('Fırın', '🥖', category: 'fırın'),
    NearbyQuery('Bakkal', '🏪', category: 'bakkal'),
    NearbyQuery('Eczane', '💊', category: 'eczane'),
    NearbyQuery('Kafe', '☕', category: 'kafe'),
    NearbyQuery('Benzinlik', '⛽', category: 'benzinlik'),
    NearbyQuery('Hastane', '🏥', category: 'hastane'),
    NearbyQuery('Market', '🛒', category: 'market'),
    NearbyQuery('Migros', '🛒', chain: 'Migros'),
    NearbyQuery('BİM', '🛒', chain: 'BİM'),
    NearbyQuery('A101', '🛒', chain: 'A101'),
    NearbyQuery('ŞOK', '🛒', chain: 'ŞOK'),
    NearbyQuery('CarrefourSA', '🛒', chain: 'CarrefourSA'),
  ];

  final http.Client _client;
  final DateTime Function() _clock;
  final Map<String, (DateTime at, List<Place> data)> _cache = {};
  DateTime? _lastOverpassAt;
  Future<void> _queue = Future.value();

  PlacesService({http.Client? client, DateTime Function()? clock})
      : _client = client ?? http.Client(),
        _clock = clock ?? DateTime.now;

  // ------------------------------------------------------------ Photon

  /// Dünya genelinde ülke/il/ilçe/mahalle/köy/yer araması.
  Future<List<Place>> search(
    String query, {
    double? lat,
    double? lon,
    int limit = 10,
  }) async {
    final q = query.trim();
    if (q.length < 2) return const [];
    final uri = Uri.https('photon.komoot.io', '/api/', {
      'q': q,
      'limit': '$limit',
      if (lat != null) 'lat': '$lat',
      if (lon != null) 'lon': '$lon',
    });
    final resp = await _client
        .get(uri, headers: const {'User-Agent': 'SkyNav/1.0'})
        .timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) {
      throw PlacesException('Arama hatası (HTTP ${resp.statusCode})');
    }
    final body = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final out = <Place>[];
    for (final f in (body['features'] as List? ?? const [])) {
      final m = f as Map<String, dynamic>;
      final p = (m['properties'] as Map<String, dynamic>?) ?? const {};
      final name = (p['name'] ?? '').toString();
      if (name.isEmpty) continue;
      final coords = (m['geometry'] as Map<String, dynamic>)['coordinates']
          as List;
      final parts = <String>[];
      for (final k in const [
        'district', 'locality', 'city', 'county', 'state', 'country'
      ]) {
        final v = p[k];
        if (v is String && v.isNotEmpty && v != name && !parts.contains(v)) {
          parts.add(v);
        }
      }
      out.add(Place(
        name: name,
        subtitle: parts.join(', '),
        lon: (coords[0] as num).toDouble(),
        lat: (coords[1] as num).toDouble(),
        type: (p['osm_value'] ?? p['type'] ?? '').toString(),
      ));
    }
    return out;
  }

  // ------------------------------------------------------------ Overpass

  /// Yakın çevrede zincir ya da kategori araması. Tam olarak biri verilmeli.
  /// Sonuçlar kuşa uçuşu mesafeye göre sıralanır; 5 dk önbelleklenir.
  Future<List<Place>> nearby(
    double lat,
    double lon, {
    String? chain,
    String? category,
    int radiusM = 3000,
  }) async {
    if ((chain == null) == (category == null)) {
      throw ArgumentError('chain veya category değerinden tam biri verilmeli');
    }
    final query = _buildQuery(lat, lon, radiusM, chain, category);
    final now = _clock();

    final cached = _cache[query];
    if (cached != null && now.difference(cached.$1) < cacheTtl) {
      return cached.$2;
    }
    _cache.removeWhere((_, v) => now.difference(v.$1) >= cacheTtl);

    final data = await _throttled(() => _fetchOverpass(query));
    final places = _toPlaces(data, lat, lon, category);
    _cache[query] = (_clock(), places);
    return places;
  }

  String _buildQuery(
      double lat, double lon, int radiusM, String? chain, String? category) {
    final around =
        'around:$radiusM,${lat.toStringAsFixed(5)},${lon.toStringAsFixed(5)}';
    final String selectors;
    if (chain != null) {
      if (!chains.contains(chain)) {
        throw ArgumentError.value(chain, 'chain', 'Bilinmeyen zincir');
      }
      final re = '^${_caseInsensitiveRegex(chain)}';
      selectors = 'nwr($around)["brand"~"$re",i];\n'
          'nwr($around)["name"~"$re",i];';
    } else {
      final c = categories[category];
      if (c == null) {
        throw ArgumentError.value(category, 'category', 'Bilinmeyen kategori');
      }
      selectors = 'nwr($around)["${c.osmKey}"="${c.osmValue}"];';
    }
    return '[out:json][timeout:25];\n($selectors\n);\nout tags center 60;';
  }

  /// Türkçe harfleri kapsayan büyük/küçük harf duyarsız regex parçası.
  static String _caseInsensitiveRegex(String s) {
    final sb = StringBuffer();
    for (final ch in s.split('')) {
      if (ch == 'İ' || ch == 'I') {
        sb.write(ch == 'İ' ? '[İi]' : '[Iı]');
      } else if (ch.codeUnitAt(0) > 127) {
        sb.write('[${ch.toUpperCase()}${ch.toLowerCase()}]');
      } else {
        sb.write(ch);
      }
    }
    return sb.toString();
  }

  Future<List<dynamic>> _fetchOverpass(String query) async {
    final resp = await _client
        .post(
          Uri.parse(overpassUrl),
          headers: const {
            'User-Agent': 'SkyNav/1.0',
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: {'data': query},
        )
        .timeout(const Duration(seconds: 30));
    if (resp.statusCode != 200) {
      throw PlacesException('Yakın çevre hatası (HTTP ${resp.statusCode})');
    }
    final body = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    return (body['elements'] as List?) ?? const [];
  }

  /// Ardışık Overpass çağrıları arasında en az [minOverpassGap] bırakır.
  Future<T> _throttled<T>(Future<T> Function() fn) {
    final run = _queue.then((_) async {
      final last = _lastOverpassAt;
      if (last != null) {
        final wait = minOverpassGap - _clock().difference(last);
        if (wait > Duration.zero) await Future.delayed(wait);
      }
      _lastOverpassAt = _clock();
      return fn();
    });
    _queue = run.then((_) {}, onError: (_) {});
    return run;
  }

  List<Place> _toPlaces(
      List<dynamic> elements, double lat, double lon, String? category) {
    final seen = <String>{};
    final out = <(double dist, Place place)>[];
    final catLabel = category == null ? null : categories[category]?.labelTr;
    for (final e in elements) {
      final m = e as Map<String, dynamic>;
      if (!seen.add('${m['type']}/${m['id']}')) continue;
      final center = m['center'] as Map<String, dynamic>?;
      final pLat = ((m['lat'] ?? center?['lat']) as num?)?.toDouble();
      final pLon = ((m['lon'] ?? center?['lon']) as num?)?.toDouble();
      if (pLat == null || pLon == null) continue;
      final tags = (m['tags'] as Map<String, dynamic>?) ?? const {};
      final name = (tags['name'] ?? tags['brand'] ?? catLabel ?? '').toString();
      final place = Place(
        name: name,
        subtitle: (tags['addr:street'] ?? '').toString(),
        lat: pLat,
        lon: pLon,
        type: (tags['shop'] ?? tags['amenity'] ?? '').toString(),
      );
      out.add((haversineM(lat, lon, pLat, pLon), place));
    }
    out.sort((a, b) => a.$1.compareTo(b.$1));
    return [for (final o in out.take(50)) o.$2];
  }

  void close() => _client.close();
}
