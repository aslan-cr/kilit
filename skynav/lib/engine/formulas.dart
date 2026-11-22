// Saf Dart meteoroloji ve astronomi formülleri. Flutter bağımlılığı yok.
import 'dart:math' as math;

const double _deg2rad = math.pi / 180;

const List<String> _moonNames = [
  'Yeni Ay',
  'Büyüyen Hilal',
  'İlk Dördün',
  'Büyüyen Şişkin Ay',
  'Dolunay',
  'Küçülen Şişkin Ay',
  'Son Dördün',
  'Küçülen Hilal',
];

const List<String> _dirNames = ['K', 'KD', 'D', 'GD', 'G', 'GB', 'B', 'KB'];

/// Değeri [lo, hi] aralığına sıkıştırır. NaN gelirse [lo] döner.
double clampD(num v, num lo, num hi) {
  final d = v.toDouble();
  if (d.isNaN) return lo.toDouble();
  if (d < lo) return lo.toDouble();
  if (d > hi) return hi.toDouble();
  return d;
}

/// Çiy noktası (°C). Magnus formülü. [rh] yüzde (0-100).
double dewPointC(double t, double rh) {
  final h = clampD(rh, 0.5, 100);
  const a = 17.62, b = 243.12;
  final gamma = math.log(h / 100) + a * t / (b + t);
  return b * gamma / (a - gamma);
}

/// Yaş termometre (°C). Stull (2011) yaklaşımı. [rh] yüzde (0-100).
double wetBulbC(double t, double rh) {
  final r = clampD(rh, 0, 100);
  return t * math.atan(0.151977 * math.sqrt(r + 8.313659)) +
      math.atan(t + r) -
      math.atan(r - 1.676331) +
      0.00391838 * math.pow(r, 1.5).toDouble() * math.atan(0.023101 * r) -
      4.686035;
}

typedef MoonInfo = ({double fraction, double illumination, String name});

/// Ay evresi. [fraction] 0-1 (0 = yeni ay), [illumination] 0-1, [name] Türkçe.
/// Referans: 2000-01-06 18:14 UTC yeni ay (JD 2451550.26), sinodik ay 29.530588853 gün.
MoonInfo moonPhase(DateTime date) {
  final jd = date.toUtc().millisecondsSinceEpoch / 86400000.0 + 2440587.5;
  const synodic = 29.530588853;
  const knownNewMoonJd = 2451550.26;
  var frac = ((jd - knownNewMoonJd) / synodic) % 1.0;
  if (frac < 0) frac += 1.0;
  final illum = (1 - math.cos(2 * math.pi * frac)) / 2;
  final idx = ((frac * 8) + 0.5).floor() % 8;
  return (fraction: frac, illumination: illum, name: _moonNames[idx]);
}

/// Rüzgar soğuğu (°C). Kanada formülü. [windMs] m/s cinsinden rüzgar hızı.
/// Geçerli değilse (T > 10 °C veya v <= 4.8 km/sa) [t] döner.
double windChill(double t, double windMs) {
  final vKmh = windMs * 3.6;
  if (t > 10 || vKmh <= 4.8 || !vKmh.isFinite) return t;
  final v16 = math.pow(vKmh, 0.16).toDouble();
  return 13.12 + 0.6215 * t - 11.37 * v16 + 0.3965 * t * v16;
}

/// Hissedilen sıcaklık (°C). Rothfusz regresyonu. [rh] yüzde.
/// 80 °F altında [t] döner.
double heatIndex(double t, double rh) {
  final tf = t * 9 / 5 + 32;
  if (tf < 80) return t;
  final r = clampD(rh, 0, 100);
  var hi = -42.379 +
      2.04901523 * tf +
      10.14333127 * r -
      0.22475541 * tf * r -
      0.00683783 * tf * tf -
      0.05481717 * r * r +
      0.00122874 * tf * tf * r +
      0.00085282 * tf * r * r -
      0.00000199 * tf * tf * r * r;
  if (r < 13 && tf >= 80 && tf <= 112) {
    hi -= ((13 - r) / 4) * math.sqrt((17 - (tf - 95).abs()) / 17);
  } else if (r > 85 && tf >= 80 && tf <= 87) {
    hi += ((r - 85) / 10) * ((87 - tf) / 5);
  }
  return (hi - 32) * 5 / 9;
}

/// Rüzgarın geldiği yön, Türkçe 8 yön (K, KD, D, GD, G, GB, B, KB).
/// Geçersiz değerde '-' döner.
String windDirName(double deg) {
  if (!deg.isFinite) return '-';
  final d = ((deg % 360) + 360) % 360;
  return _dirNames[((d + 22.5) / 45).floor() % 8];
}

/// İki yön arasındaki en kısa açı farkı (0-180 derece).
double angleDiff(double a, double b) {
  if (!a.isFinite || !b.isFinite) return 180;
  final d = (((a - b) % 360) + 360) % 360;
  return d > 180 ? 360 - d : d;
}

/// Gözlemciden hedefe pusula yönü (0-360 derece, kuzeyden saat yönünde).
double bearingDeg(double lat1, double lon1, double lat2, double lon2) {
  final p1 = lat1 * _deg2rad;
  final p2 = lat2 * _deg2rad;
  final dl = (lon2 - lon1) * _deg2rad;
  final y = math.sin(dl) * math.cos(p2);
  final x = math.cos(p1) * math.sin(p2) - math.sin(p1) * math.cos(p2) * math.cos(dl);
  return (math.atan2(y, x) / _deg2rad + 360) % 360;
}

/// İki koordinat arası büyük daire mesafesi (km), haversine.
double haversineKm(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371.0088;
  final dLat = (lat2 - lat1) * _deg2rad;
  final dLon = (lon2 - lon1) * _deg2rad;
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1 * _deg2rad) *
          math.cos(lat2 * _deg2rad) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  return 2 * r * math.asin(math.sqrt(clampD(a, 0, 1)));
}
