import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:satellite_dart/ext.dart' show jday;
import 'package:satellite_dart/io.dart' show twoline2satrec;
import 'package:satellite_dart/propagation/gstime.dart' show gstimeInternal;
import 'package:satellite_dart/propagation/sgp4.dart' show sgp4;
import 'package:satellite_dart/transforms.dart' show ecfToLookAngles, eciToEcf;

/// CelesTrak GP (TLE) verisi ile SGP4 konum/geçiş hesapları. API anahtarı gerekmez.
///
/// Güneş konumu düşük hassasiyetli bir modelle (~0.01 derece) hesaplanır; parlaklık
/// tahmini kabaca bir değerlendirmedir, gerçek gözlem koşullarını (bulut, ufuk
/// engelleri, uydunun boyutu/yansıtma) hesaba katmaz.

const String issName = 'ISS (ZARYA)';

const String celestrakStations = 'stations';
const String celestrakStarlink = 'starlink';
const String celestrakCosmos1408Debris = 'cosmos-1408-debris';
const String celestrakFengyun1cDebris = 'fengyun-1c-debris';
const String celestrakIridium33Debris = 'iridium-33-debris';

const double _earthRadiusKm = 6378.137;
const double _deg2rad = math.pi / 180.0;
const double _rad2deg = 180.0 / math.pi;
const double _minutesPerDay = 1440.0;
const Duration _timeout = Duration(seconds: 12);
const Duration _cacheTtl = Duration(hours: 6);
const Duration _scanStep = Duration(seconds: 30);

/// Bir uydunun TLE kaydı.
class Sat {
  Sat(this.name, this.line1, this.line2);

  final String name;
  final String line1;
  final String line2;

  Map<String, dynamic>? _rec;

  Map<String, dynamic> get _record {
    final cached = _rec;
    if (cached != null) return cached;
    try {
      final rec = twoline2satrec(line1, line2);
      _rec = rec;
      return rec;
    } catch (e) {
      throw FormatException('Geçersiz TLE ($name): $e');
    }
  }

  @override
  String toString() => 'Sat($name)';
}

/// Gözlemci konumu. [lon] doğu pozitif, [altM] deniz seviyesi üstü metre.
class GeoObserver {
  const GeoObserver(this.lat, this.lon, this.altM);

  final double lat;
  final double lon;
  final double altM;
}

/// Bakış açıları. [azDeg] kuzeyden doğuya, [altDeg] ufuk üstü açı.
typedef LookAngles = ({double azDeg, double altDeg, double rangeKm, bool sunlit});

/// Bir geçiş (pass) bilgisi. Tüm zamanlar UTC.
///
/// [visibleToEye] gözlemcinin güneş ufkun 6° altında (sivil alacakaranlık sonrası)
/// ve tepe anında uydunun güneş ışığında olması durumunda true'dur.
class PassInfo {
  const PassInfo({
    required this.start,
    required this.peak,
    required this.end,
    required this.peakAltDeg,
    required this.startAzDeg,
    required this.endAzDeg,
    required this.visibleToEye,
  });

  /// Uydunun [minAlt] üstüne çıktığı an (sorgu anında zaten üstündeyse sorgu zamanı).
  final DateTime start;
  final DateTime peak;
  final DateTime end;
  final double peakAltDeg;
  final double startAzDeg;
  final double endAzDeg;
  final bool visibleToEye;

  Duration get duration => end.difference(start);
}

typedef _CacheEntry = ({DateTime at, List<Sat> sats});

final Map<String, _CacheEntry> _groupCache = {};

/// [group] için CelesTrak GP verisini TLE olarak indirir. Aynı grup 6 saat bellekte
/// tutulur. Hata, zaman aşımı (12 sn) veya boş/çözülemeyen yanıtta exception fırlatır.
Future<List<Sat>> fetchGroup(String group, {http.Client? client}) async {
  final cached = _groupCache[group];
  if (cached != null && DateTime.now().difference(cached.at) < _cacheTtl) {
    return cached.sats;
  }

  final uri = Uri.https(
    'celestrak.org',
    '/NORAD/elements/gp.php',
    {'GROUP': group, 'FORMAT': 'tle'},
  );
  final c = client ?? http.Client();
  try {
    final res = await c
        .get(uri, headers: {'User-Agent': 'skynav-client'})
        .timeout(_timeout);
    if (res.statusCode != 200) {
      throw Exception('CelesTrak HTTP ${res.statusCode} (grup=$group)');
    }
    final sats = parseTle(utf8.decode(res.bodyBytes, allowMalformed: true));
    if (sats.isEmpty) {
      throw FormatException('CelesTrak grubunda TLE bulunamadı: $group');
    }
    final unmodifiable = List<Sat>.unmodifiable(sats);
    _groupCache[group] = (at: DateTime.now(), sats: unmodifiable);
    return unmodifiable;
  } finally {
    if (client == null) c.close();
  }
}

/// Üç satırlı (isim + iki TLE satırı) veya iki satırlı TLE metnini ayrıştırır.
List<Sat> parseTle(String text) {
  final lines = text
      .split(RegExp(r'\r?\n'))
      .map((l) => l.trimRight())
      .where((l) => l.isNotEmpty)
      .toList();
  final out = <Sat>[];
  for (var i = 0; i + 1 < lines.length; i++) {
    final l1 = lines[i];
    final l2 = lines[i + 1];
    if (l1.startsWith('1 ') && l2.startsWith('2 ')) {
      if (l1.length < 69 || l2.length < 69) {
        throw FormatException('TLE satır uzunluğu geçersiz: $l1');
      }
      final hasName = i > 0 &&
          !lines[i - 1].startsWith('1 ') &&
          !lines[i - 1].startsWith('2 ');
      final name = hasName ? lines[i - 1].trim() : 'UNKNOWN';
      out.add(Sat(name, l1, l2));
      i++;
    }
  }
  return out;
}

/// [sat] için [time] anındaki bakış açılarını döndürür. SGP4 hatası/uydu düşmüşse null.
LookAngles? lookAngles(Sat sat, GeoObserver obs, DateTime time) {
  final jd = _julian(time.toUtc());
  final eci = _eciPosition(sat, jd);
  if (eci == null) return null;

  final gmst = gstimeInternal(jd);
  final ecf = eciToEcf(eci, gmst);
  final look = ecfToLookAngles(_geodetic(obs), ecf);

  final azDeg = (look['azimuth'] as double) * _rad2deg;
  final altDeg = (look['elevation'] as double) * _rad2deg;
  final rangeKm = look['rangeSat'] as double;
  final sunlit = _isSunlit(eci, _sunUnitEci(jd));

  return (
    azDeg: _normDeg(azDeg),
    altDeg: altDeg,
    rangeKm: rangeKm,
    sunlit: sunlit,
  );
}

/// [from] anından itibaren [horizon] içinde [minAlt] (derece) üstüne çıkan ilk geçişi
/// bulur. Geçiş bulunamazsa null. Geçiş [from] anında zaten sürüyorsa `start = from`
/// olur. Bitiş, pencere sonundan en fazla 2 saat sonrasına kadar aranır.
PassInfo? nextPass(
  Sat sat,
  GeoObserver obs,
  DateTime from, {
  Duration horizon = const Duration(hours: 24),
  double minAlt = 10,
}) {
  final start = from.toUtc();
  final windowEnd = start.add(horizon);
  final hardEnd = windowEnd.add(const Duration(hours: 2));

  double altAt(DateTime t) => lookAngles(sat, obs, t)?.altDeg ?? -90.0;
  bool above(DateTime t) => altAt(t) >= minAlt;

  // Yükseliş (AOS).
  final DateTime aos;
  if (above(start)) {
    aos = start;
  } else {
    final rise = _firstMatch(start, windowEnd, above);
    if (rise == null) return null;
    aos = rise;
  }

  // Alçalış (LOS) ve tepe örneği.
  var t = aos;
  var bestT = aos;
  var bestAlt = altAt(aos);
  DateTime? los;
  while (t.isBefore(hardEnd)) {
    final n = t.add(_scanStep);
    final a = altAt(n);
    if (a < minAlt) {
      los = _boundary(t, n, above);
      break;
    }
    if (a > bestAlt) {
      bestAlt = a;
      bestT = n;
    }
    t = n;
  }
  los ??= hardEnd;

  // Tepe anını üçlü arama ile iyileştir.
  var lo = _clampTime(bestT.subtract(_scanStep), aos, los);
  var hi = _clampTime(bestT.add(_scanStep), aos, los);
  for (var i = 0; i < 25; i++) {
    final span = hi.difference(lo);
    final m1 = lo.add(span ~/ 3);
    final m2 = hi.subtract(span ~/ 3);
    if (altAt(m1) < altAt(m2)) {
      lo = m1;
    } else {
      hi = m2;
    }
  }
  var tca = lo.add(hi.difference(lo) ~/ 2);
  var peakAlt = altAt(tca);
  if (peakAlt < bestAlt) {
    tca = bestT;
    peakAlt = bestAlt;
  }

  final aosLook = lookAngles(sat, obs, aos);
  final losLook = lookAngles(sat, obs, los);
  final peakLook = lookAngles(sat, obs, tca);
  if (aosLook == null || losLook == null || peakLook == null) return null;

  final visible = peakLook.sunlit && _observerSunAltDeg(obs, tca) < -6.0;

  return PassInfo(
    start: aos,
    peak: tca,
    end: los,
    peakAltDeg: peakAlt,
    startAzDeg: aosLook.azDeg,
    endAzDeg: losLook.azDeg,
    visibleToEye: visible,
  );
}

// ---------------------------------------------------------------------------
// Yardımcılar
// ---------------------------------------------------------------------------

double _julian(DateTime utc) => jday(
      utc.year,
      utc.month,
      utc.day,
      utc.hour,
      utc.minute,
      utc.second.toDouble(),
      utc.millisecond.toDouble(),
    )!;

Map<String, dynamic>? _eciPosition(Sat sat, double jd) {
  final rec = sat._record;
  final tsince = (jd - (rec['jdsatepoch'] as num).toDouble()) * _minutesPerDay;
  final out = sgp4(rec, tsince);
  final pos = out?['position'];
  // Uydu düşmüşse (decay) sgp4 position=false döndürür.
  return pos is Map<String, dynamic> ? pos : null;
}

Map<String, dynamic> _geodetic(GeoObserver obs) => {
      'latitude': obs.lat * _deg2rad,
      'longitude': obs.lon * _deg2rad,
      'height': obs.altM / 1000.0, // satellite_dart km bekler
    };

/// Güneşin ECI (ekvatoral, J2000 yakını) birim vektörü. Düşük hassasiyetli model.
List<double> _sunUnitEci(double jd) {
  final n = jd - 2451545.0;
  final meanLon = 280.460 + 0.9856474 * n;
  final g = (357.528 + 0.9856003 * n) * _deg2rad;
  final lambda =
      (meanLon + 1.915 * math.sin(g) + 0.020 * math.sin(2 * g)) * _deg2rad;
  final eps = (23.439 - 0.0000004 * n) * _deg2rad;
  return [
    math.cos(lambda),
    math.cos(eps) * math.sin(lambda),
    math.sin(eps) * math.sin(lambda),
  ];
}

/// Silindirik Dünya gölgesi modeli: uydu güneşin arkasında ve Dünya'nın gölge
/// silindirinin içindeyse güneş ışığında değildir.
bool _isSunlit(Map<String, dynamic> eci, List<double> sun) {
  final x = (eci['x'] as num).toDouble();
  final y = (eci['y'] as num).toDouble();
  final z = (eci['z'] as num).toDouble();
  final proj = x * sun[0] + y * sun[1] + z * sun[2];
  if (proj >= 0) return true;
  final perp2 = x * x + y * y + z * z - proj * proj;
  return perp2 > _earthRadiusKm * _earthRadiusKm;
}

/// Gözlemcide güneşin ufuk üstü açısı (derece).
double _observerSunAltDeg(GeoObserver obs, DateTime utc) {
  final jd = _julian(utc);
  final sun = _sunUnitEci(jd);
  final theta = gstimeInternal(jd) + obs.lon * _deg2rad;
  final phi = obs.lat * _deg2rad;
  final up0 = math.cos(phi) * math.cos(theta);
  final up1 = math.cos(phi) * math.sin(theta);
  final up2 = math.sin(phi);
  var dot = up0 * sun[0] + up1 * sun[1] + up2 * sun[2];
  if (dot > 1) dot = 1;
  if (dot < -1) dot = -1;
  return math.asin(dot) * _rad2deg;
}

double _normDeg(double d) {
  final r = d % 360.0;
  return r < 0 ? r + 360.0 : r;
}

DateTime _clampTime(DateTime t, DateTime lo, DateTime hi) {
  if (t.isBefore(lo)) return lo;
  if (t.isAfter(hi)) return hi;
  return t;
}

/// [from]..[until] aralığında [pred]'in ilk doğru olduğu sınırı (1 sn hassasiyetle) bulur.
DateTime? _firstMatch(
  DateTime from,
  DateTime until,
  bool Function(DateTime) pred,
) {
  var t = from;
  while (t.isBefore(until)) {
    final n = t.add(_scanStep);
    if (pred(n)) return _boundary(t, n, pred);
    t = n;
  }
  return null;
}

/// pred(lo) != pred(hi) varsayımıyla durum değişimini ikiye bölerek bulur. hi döner.
DateTime _boundary(DateTime lo, DateTime hi, bool Function(DateTime) pred) {
  final loState = pred(lo);
  var a = lo;
  var b = hi;
  while (b.difference(a) > const Duration(seconds: 1)) {
    final mid = a.add(Duration(milliseconds: b.difference(a).inMilliseconds ~/ 2));
    if (pred(mid) == loState) {
      a = mid;
    } else {
      b = mid;
    }
  }
  return b;
}
