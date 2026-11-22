// OSRM (ücretsiz, herkese açık demo sunucu) ile araç rotası.
// Saf Dart: yalnızca `http` paketi kullanır, UI bağımlılığı yoktur.
import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

/// (lat, lon) çifti.
typedef LatLon = (double lat, double lon);

const double _earthRadiusM = 6371000.0;
const double _mPerDeg = 111320.0;

double _rad(double deg) => deg * math.pi / 180.0;

class OsrmException implements Exception {
  final String message;
  const OsrmException(this.message);
  @override
  String toString() => 'OsrmException: $message';
}

/// Rota üzerindeki tek bir manevra adımı.
class RouteStep {
  /// Mesafe öneki dahil tam Türkçe talimat, örn. "300 metre sonra sağa dön".
  /// İlk adımda (başlangıç) mesafe öneki yoktur.
  final String instructionTr;

  /// Önekten bağımsız, küçük harfli eylem, örn. "sağa dön".
  final String phraseTr;

  /// Bu adımın uzunluğu (bu adımın sonundaki manevraya kadar).
  final double distanceM, durationS;
  final String maneuverType, modifier, streetName;

  /// Manevranın yapıldığı nokta.
  final double lat, lon;

  const RouteStep({
    required this.instructionTr,
    required this.phraseTr,
    required this.distanceM,
    required this.durationS,
    required this.maneuverType,
    required this.modifier,
    required this.streetName,
    required this.lat,
    required this.lon,
  });

  /// Manevraya [distanceToManeuverM] metre kala anlık duyuru.
  String announce(double distanceToManeuverM) => RouteText.announce(
      RouteText.withStreet(phraseTr, maneuverType, streetName),
      distanceToManeuverM);
}

class RouteResult {
  final List<LatLon> geometry;
  final double distanceM, durationS;
  final List<RouteStep> steps;
  const RouteResult({
    required this.geometry,
    required this.distanceM,
    required this.durationS,
    required this.steps,
  });
}

/// OSRM manevra tip/modifier'ını Türkçe metne çevirir.
class RouteText {
  RouteText._();

  static String _modifierTr(String m) => switch (m) {
        'left' => 'sola dön',
        'right' => 'sağa dön',
        'slight left' => 'hafif sola dön',
        'slight right' => 'hafif sağa dön',
        'sharp left' => 'keskin sola dön',
        'sharp right' => 'keskin sağa dön',
        'uturn' => 'geri dön (U dönüşü yap)',
        _ => 'devam et',
      };

  static String _continueTr(String m) => switch (m) {
        'left' => 'sola doğru devam et',
        'right' => 'sağa doğru devam et',
        'slight left' => 'hafif sola doğru devam et',
        'slight right' => 'hafif sağa doğru devam et',
        _ => 'yola devam et',
      };

  /// Önekten ve sokak adından bağımsız, küçük harfli eylem.
  static String phrase({
    required String type,
    required String modifier,
    int? exit,
  }) =>
      switch (type) {
        'depart' => 'yola çık',
        'arrive' => 'varış noktasına ulaştın',
        'turn' || 'new name' => modifier.isEmpty || modifier == 'straight'
            ? 'yola devam et'
            : _modifierTr(modifier),
        'continue' => _continueTr(modifier),
        'merge' => 'yola katıl',
        'on ramp' => 'rampaya gir',
        'off ramp' => 'çıkışa gir',
        'fork' => modifier.isEmpty || modifier == 'straight'
            ? 'ayrımda devam et'
            : 'ayrımda ${_modifierTr(modifier)}',
        'end of road' => 'yolun sonunda ${_modifierTr(modifier)}',
        'roundabout' || 'rotary' => exit != null
            ? 'dönel kavşaktan $exit. çıkış'
            : 'dönel kavşağa gir',
        'roundabout turn' => 'dönel kavşakta ${_modifierTr(modifier)}',
        'exit roundabout' || 'exit rotary' => 'dönel kavşaktan çık',
        'use lane' => 'şeridi kullan',
        _ => 'yola devam et',
      };

  /// Sokak adını eyleme ekler (varış hariç).
  static String withStreet(String phraseTr, String type, String street) {
    if (street.isEmpty || type == 'arrive') return phraseTr;
    return '$phraseTr ($street)';
  }

  /// Cümle başını büyütür (Türkçe i/İ kuralına uygun).
  static String cap(String s) {
    if (s.isEmpty) return s;
    final first = s[0];
    final up = first == 'i' ? 'İ' : first.toUpperCase();
    return up + s.substring(1);
  }

  /// Mesafe metni: 1 km'nin altı 10 m'ye yuvarlanır.
  static String distanceTr(double m) {
    if (m >= 1000) {
      return '${(m / 1000).toStringAsFixed(1).replaceAll('.', ',')} kilometre';
    }
    return '${(m / 10).round() * 10} metre';
  }

  /// [phrase] eylemini [distanceM] metre sonra olacak şekilde duyurur.
  static String announce(String phrase, double distanceM) {
    if (distanceM < 30) return cap(phrase);
    return '${distanceTr(distanceM)} sonra $phrase';
  }
}

/// (lat, lon) noktaları arası büyük daire mesafesi (m).
double haversineM(double lat1, double lon1, double lat2, double lon2) {
  final dLat = _rad(lat2 - lat1);
  final dLon = _rad(lon2 - lon1);
  final sLat = math.sin(dLat / 2);
  final sLon = math.sin(dLon / 2);
  final a = sLat * sLat +
      math.cos(_rad(lat1)) * math.cos(_rad(lat2)) * sLon * sLon;
  return 2 * _earthRadiusM * math.asin(math.min(1.0, math.sqrt(a)));
}

/// Noktanın [a]-[b] doğru parçasına uzaklığı (m). Yerel düzlem yaklaşımı;
/// kısa parçalarda (rota segmentleri) hata ihmal edilebilir düzeydedir.
double _pointSegmentM(double lat, double lon, LatLon a, LatLon b) {
  final cosLat = math.cos(_rad(lat));
  final ax = (a.$2 - lon) * cosLat * _mPerDeg;
  final ay = (a.$1 - lat) * _mPerDeg;
  final bx = (b.$2 - lon) * cosLat * _mPerDeg;
  final by = (b.$1 - lat) * _mPerDeg;
  final dx = bx - ax;
  final dy = by - ay;
  final len2 = dx * dx + dy * dy;
  final double t = len2 == 0
      ? 0.0
      : math.min(1.0, math.max(0.0, -(ax * dx + ay * dy) / len2));
  final px = ax + t * dx;
  final py = ay + t * dy;
  return math.sqrt(px * px + py * py);
}

/// Konumun rotaya (geometri polyline'ına) en kısa uzaklığı (m).
/// Rota dışı algılama için kullanılır: değer ~50 m üstündeyse rota dışısın.
double distanceToRouteM(double lat, double lon, List<LatLon> geometry) {
  if (geometry.isEmpty) return double.infinity;
  if (geometry.length == 1) {
    return haversineM(lat, lon, geometry[0].$1, geometry[0].$2);
  }
  var best = double.infinity;
  for (var i = 0; i < geometry.length - 1; i++) {
    final d = _pointSegmentM(lat, lon, geometry[i], geometry[i + 1]);
    if (d < best) best = d;
  }
  return best;
}

/// Bir sonraki manevra adımının indeksi.
///
/// [fromIndex] mevcut hedef adım; konum o adımın manevra noktasından
/// [reachedRadiusM] içindeyse adım geçilmiş sayılır ve sonrakine bakılır.
/// Dönen değeri bir sonraki çağrıda `fromIndex` olarak geri ver.
/// Son adımdan sonra ilerlemez (varış adımında kalır).
int nextStepIndex(
  double lat,
  double lon,
  List<RouteStep> steps, {
  int fromIndex = 0,
  double reachedRadiusM = 25,
}) {
  if (steps.isEmpty) return -1;
  var i = math.min(math.max(fromIndex, 0), steps.length - 1);
  while (i < steps.length - 1 &&
      haversineM(lat, lon, steps[i].lat, steps[i].lon) <= reachedRadiusM) {
    i++;
  }
  return i;
}

/// OSRM demo sunucusu üzerinden rota hesaplayıcı.
class OsrmService {
  static const String defaultBaseUrl = 'https://router.project-osrm.org';

  final http.Client _client;
  final String baseUrl;
  final Duration timeout;

  OsrmService({
    http.Client? client,
    this.baseUrl = defaultBaseUrl,
    this.timeout = const Duration(seconds: 20),
  }) : _client = client ?? http.Client();

  /// [stops] sırasıyla: başlangıç, ara duraklar, varış. En az 2 nokta.
  Future<RouteResult> route(List<LatLon> stops) async {
    if (stops.length < 2) {
      throw ArgumentError.value(stops.length, 'stops', 'En az 2 nokta gerekli');
    }
    final coords = stops
        .map((p) => '${p.$2.toStringAsFixed(6)},${p.$1.toStringAsFixed(6)}')
        .join(';');
    final uri = Uri.parse('$baseUrl/route/v1/driving/$coords').replace(
      queryParameters: {
        'overview': 'full',
        'geometries': 'geojson',
        'steps': 'true',
      },
    );

    final resp = await _client
        .get(uri, headers: const {'User-Agent': 'SkyNav/1.0'})
        .timeout(timeout);

    final Map<String, dynamic> body;
    try {
      body = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw OsrmException('Geçersiz yanıt (HTTP ${resp.statusCode})');
    }
    final code = body['code'] as String?;
    if (resp.statusCode != 200 || code != 'Ok') {
      throw OsrmException(
          body['message']?.toString() ?? code ?? 'HTTP ${resp.statusCode}');
    }
    final routes = body['routes'] as List? ?? const [];
    if (routes.isEmpty) throw const OsrmException('Rota bulunamadı');
    return _parse(routes.first as Map<String, dynamic>);
  }

  RouteResult _parse(Map<String, dynamic> route) {
    final coords = (route['geometry'] as Map<String, dynamic>)['coordinates']
        as List;
    // GeoJSON [lon, lat] -> (lat, lon)
    final geometry = <LatLon>[
      for (final c in coords)
        (((c as List)[1] as num).toDouble(), (c[0] as num).toDouble()),
    ];

    final raw = <Map<String, dynamic>>[];
    for (final leg in route['legs'] as List) {
      for (final st in (leg as Map<String, dynamic>)['steps'] as List) {
        raw.add(st as Map<String, dynamic>);
      }
    }

    final steps = <RouteStep>[];
    for (var i = 0; i < raw.length; i++) {
      final st = raw[i];
      final man = st['maneuver'] as Map<String, dynamic>;
      final type = (man['type'] ?? '').toString();
      final modifier = (man['modifier'] ?? '').toString();
      final exitRaw = man['exit'];
      final exit = exitRaw is num ? exitRaw.toInt() : null;
      final street = (st['name'] ?? '').toString();
      final loc = man['location'] as List;

      final base = RouteText.phrase(type: type, modifier: modifier, exit: exit);
      final full = RouteText.withStreet(base, type, street);
      final instr = i == 0
          ? RouteText.cap(full)
          : RouteText.announce(
              full, (raw[i - 1]['distance'] as num).toDouble());

      steps.add(RouteStep(
        instructionTr: instr,
        phraseTr: base,
        distanceM: (st['distance'] as num).toDouble(),
        durationS: (st['duration'] as num).toDouble(),
        maneuverType: type,
        modifier: modifier,
        streetName: street,
        lat: (loc[1] as num).toDouble(),
        lon: (loc[0] as num).toDouble(),
      ));
    }

    return RouteResult(
      geometry: geometry,
      distanceM: (route['distance'] as num).toDouble(),
      durationS: (route['duration'] as num).toDouble(),
      steps: steps,
    );
  }

  void close() => _client.close();
}
