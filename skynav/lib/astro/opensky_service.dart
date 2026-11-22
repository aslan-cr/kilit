import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

/// OpenSky Network anonim `states/all` verisi (API anahtarı gerekmez).
///
/// Önemli sınırlar:
/// - OpenSky yalnızca ADS-B / Mode-S / MLAT ile yayın yapan uçakları gösterir. Askerî
///   uçakların çoğu transponder'ını kapattığı veya yalnızca kısıtlı veri yaydığı için
///   görünmeyebilir; listede olmaması "orada uçak yok" anlamına gelmez.
/// - [Plane.militaryHint] callsign kalıbına dayalı bir ipucudur, kesin tespit değildir.
///   Kalıp listesi bilinçli olarak kısadır; yanlış negatif çoktur.
/// - Anonim kullanımda hız limiti vardır: [fetch] en az 15 sn aralıkla istek atar.

const Duration _minInterval = Duration(seconds: 15);
const Duration _timeout = Duration(seconds: 12);
const double _earthRadiusM = 6371000.0;

/// Coğrafi kutu (derece). lomin > lomax (tarih değiştirme çizgisi) desteklenmez.
class Bbox {
  const Bbox({
    required this.lamin,
    required this.lomin,
    required this.lamax,
    required this.lomax,
  });

  final double lamin;
  final double lomin;
  final double lamax;
  final double lomax;

  bool contains(double lat, double lon) =>
      lat >= lamin && lat <= lamax && lon >= lomin && lon <= lomax;

  bool containsBox(Bbox o) =>
      o.lamin >= lamin && o.lamax <= lamax && o.lomin >= lomin && o.lomax <= lomax;
}

/// Bir uçağın son konum durumu. Opsiyonel alanlar OpenSky'da boş gelebilir.
class Plane {
  const Plane({
    required this.icao24,
    required this.callsign,
    required this.originCountry,
    required this.lat,
    required this.lon,
    required this.baroAltM,
    required this.velocityMs,
    required this.headingDeg,
    required this.verticalRate,
    required this.onGround,
    required this.militaryHint,
  });

  final String icao24;
  final String callsign;
  final String originCountry;
  final double lat;
  final double lon;
  final double? baroAltM;
  final double? velocityMs;
  final double? headingDeg;
  final double? verticalRate;
  final bool onGround;
  final bool militaryHint;
}

const List<String> _militaryPrefixes = [
  'RCH', 'REACH', 'FORTE', 'NATO', 'TUAF', 'RRR', 'ASCOT', 'DUKE', 'HOMER', 'EVAC',
];
const List<String> _civilExcluded = ['THK'];
final RegExp _militaryRe =
    RegExp('^(${_militaryPrefixes.join('|')})\\d');

/// Callsign askerî kalıba uyuyor mu. Sivil önekler ([_civilExcluded]) hariç tutulur.
bool isMilitaryCallsign(String callsign) {
  final cs = callsign.trim().toUpperCase();
  if (cs.isEmpty) return false;
  for (final ex in _civilExcluded) {
    if (cs.startsWith(ex)) return false;
  }
  return _militaryRe.hasMatch(cs);
}

DateTime? _lastResultAt;
Bbox? _lastBox;
List<Plane> _lastPlanes = const [];
DateTime _nextSlot = DateTime.fromMillisecondsSinceEpoch(0);

/// [box] içindeki uçakları getirir.
///
/// 15 sn içinde, önceki sonucun kutusu [box]'ı kapsıyorsa önbellekten (filtrelenerek)
/// döner. Farklı/büyük bir kutu için gerekirse kalan süre kadar bekleyip istek atar.
/// HTTP hatası, 429 veya zaman aşımında exception fırlatır.
Future<List<Plane>> fetch(Bbox box, {http.Client? client}) async {
  if (box.lamin > box.lamax || box.lomin > box.lomax) {
    throw ArgumentError('Geçersiz bbox: min değerler max değerleri aşamaz');
  }

  final now = DateTime.now();
  final lastAt = _lastResultAt;
  final lastBox = _lastBox;
  if (lastAt != null &&
      lastBox != null &&
      now.difference(lastAt) < _minInterval &&
      lastBox.containsBox(box)) {
    return _lastPlanes
        .where((p) => box.contains(p.lat, p.lon))
        .toList(growable: false);
  }

  // Hız limiti: bu isteğin başlayabileceği en erken anı rezerve et.
  final slot = _nextSlot.isAfter(now) ? _nextSlot : now;
  _nextSlot = slot.add(_minInterval);
  final wait = slot.difference(now);
  if (wait > Duration.zero) await Future<void>.delayed(wait);

  final uri = Uri.https('opensky-network.org', '/api/states/all', {
    'lamin': box.lamin.toString(),
    'lomin': box.lomin.toString(),
    'lamax': box.lamax.toString(),
    'lomax': box.lomax.toString(),
  });

  final c = client ?? http.Client();
  try {
    final res = await c.get(uri).timeout(_timeout);
    if (res.statusCode == 429) {
      throw Exception('OpenSky hız limiti aşıldı (HTTP 429)');
    }
    if (res.statusCode != 200) {
      throw Exception('OpenSky HTTP ${res.statusCode}');
    }
    final body = jsonDecode(utf8.decode(res.bodyBytes));
    final planes = _parseStates(body);
    _lastPlanes = List.unmodifiable(planes);
    _lastBox = box;
    _lastResultAt = DateTime.now();
    return planes;
  } finally {
    if (client == null) c.close();
  }
}

List<Plane> _parseStates(Object? body) {
  if (body is! Map) throw const FormatException('OpenSky yanıtı geçersiz');
  final states = body['states'];
  if (states == null) return const [];
  if (states is! List) throw const FormatException('OpenSky states geçersiz');

  final out = <Plane>[];
  for (final raw in states) {
    if (raw is! List || raw.length < 12) continue;
    final lon = _toDouble(raw[5]);
    final lat = _toDouble(raw[6]);
    if (lat == null || lon == null) continue; // konumsuz kayıtlar atlanır
    final callsign = (raw[1] as String?)?.trim() ?? '';
    out.add(Plane(
      icao24: raw[0] as String,
      callsign: callsign,
      originCountry: (raw[2] as String?) ?? '',
      lat: lat,
      lon: lon,
      baroAltM: _toDouble(raw[7]),
      velocityMs: _toDouble(raw[9]),
      headingDeg: _toDouble(raw[10]),
      verticalRate: _toDouble(raw[11]),
      onGround: raw[8] == true,
      militaryHint: isMilitaryCallsign(callsign),
    ));
  }
  return out;
}

/// Uçağın mevcut hız ve yönüyle [minutes] dakika ileri büyük daire projeksiyonu.
/// İlk eleman şimdiki konumdur; her dakika için bir nokta eklenir (lat, lon).
/// Hız/yön yoksa veya yerdeyse yalnızca şimdiki konum döner.
List<(double, double)> projectedRoute(Plane p, {int minutes = 30}) {
  final start = (p.lat, p.lon);
  final h = p.headingDeg;
  final v = p.velocityMs;
  if (h == null || v == null || p.onGround || v <= 0 || minutes <= 0) {
    return [start];
  }
  final out = <(double, double)>[start];
  for (var m = 1; m <= minutes; m++) {
    out.add(_destination(p.lat, p.lon, h, v * 60.0 * m));
  }
  return out;
}

(double, double) _destination(double lat, double lon, double bearingDeg, double distM) {
  final phi1 = lat * math.pi / 180;
  final lam1 = lon * math.pi / 180;
  final theta = bearingDeg * math.pi / 180;
  final delta = distM / _earthRadiusM;

  final sinPhi2 = math.sin(phi1) * math.cos(delta) +
      math.cos(phi1) * math.sin(delta) * math.cos(theta);
  final phi2 = math.asin(sinPhi2.clamp(-1.0, 1.0));
  final lam2 = lam1 +
      math.atan2(
        math.sin(theta) * math.sin(delta) * math.cos(phi1),
        math.cos(delta) - math.sin(phi1) * sinPhi2,
      );

  var lonDeg = lam2 * 180 / math.pi;
  lonDeg = ((lonDeg + 540) % 360) - 180;
  return (phi2 * 180 / math.pi, lonDeg);
}

class TrailPoint {
  const TrailPoint(this.lat, this.lon, this.at);

  final double lat;
  final double lon;
  final DateTime at;
}

/// Ardışık [fetch] sonuçlarından uçak izleri biriktirir. Her poll sonrası [addAll]
/// çağrılmalıdır. Eski noktalar [maxAge] sonra, uzun izler [maxPoints] ile sınırlanır.
class TrailStore {
  TrailStore({
    this.maxPoints = 60,
    this.maxAge = const Duration(minutes: 30),
  });

  final int maxPoints;
  final Duration maxAge;

  final Map<String, List<TrailPoint>> _tracks = {};

  void addAll(List<Plane> planes, {DateTime? at}) {
    final now = at ?? DateTime.now();
    for (final p in planes) {
      final list = _tracks.putIfAbsent(p.icao24, () => <TrailPoint>[]);
      list.add(TrailPoint(p.lat, p.lon, now));
      if (list.length > maxPoints) {
        list.removeRange(0, list.length - maxPoints);
      }
    }
    _tracks.removeWhere((_, pts) {
      pts.removeWhere((q) => now.difference(q.at) > maxAge);
      return pts.isEmpty;
    });
  }

  /// [icao24] uçağının iz noktaları (eskiden yeniye).
  List<(double, double)> trail(String icao24) =>
      (_tracks[icao24] ?? const <TrailPoint>[])
          .map((q) => (q.lat, q.lon))
          .toList(growable: false);

  void clear() => _tracks.clear();
}

double? _toDouble(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.trim());
  return null;
}
