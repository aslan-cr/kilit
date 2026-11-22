// Saf Dart astronomi hesapları (Meeus düşük hassasiyetli formüller).
// Flutter bağımlılığı yoktur. Tüm açılar derece, zamanlar UTC kabul edilir
// (yerel DateTime verilirse otomatik UTC'ye çevrilir).
import 'dart:math' as math;

const double _j2000 = 2451545.0;
const double _synodicMonthDays = 29.530588853;
const double _arcsecToRad = math.pi / (180.0 * 3600.0);

double _r(double deg) => deg * math.pi / 180.0;
double _d(double rad) => rad * 180.0 / math.pi;

/// Açıyı [0, 360) aralığına getirir.
double normalizeDeg(double a) {
  final r = a % 360.0;
  return r < 0 ? r + 360.0 : r;
}

double _clampD(double v, double lo, double hi) => v < lo ? lo : (v > hi ? hi : v);

/// Julian günü (UTC).
double julianDate(DateTime utc) {
  final u = utc.toUtc();
  return u.millisecondsSinceEpoch / 86400000.0 + 2440587.5;
}

double _days(DateTime t) => julianDate(t) - _j2000;

/// Greenwich ortalama yıldız zamanı (derece).
double gmstDeg(DateTime utc) {
  final jd = julianDate(utc);
  final t = (jd - _j2000) / 36525.0;
  final g = 280.46061837 +
      360.98564736629 * (jd - _j2000) +
      0.000387933 * t * t -
      t * t * t / 38710000.0;
  return normalizeDeg(g);
}

/// Yerel ortalama yıldız zamanı (derece). [lonDeg] doğu pozitif.
double lstDeg(double lonDeg, DateTime utc) => normalizeDeg(gmstDeg(utc) + lonDeg);

double _obliquityDeg(double d) {
  final t = d / 36525.0;
  return 23.439291 - 0.0130042 * t;
}

/// Ekliptik (boylam, enlem) -> ekvatoryal (RA, Dec), derece.
({double raDeg, double decDeg}) _eclipticToEquatorial(
    double lonDeg, double latDeg, double epsDeg) {
  final l = _r(lonDeg);
  final b = _r(latDeg);
  final e = _r(epsDeg);
  final ra = math.atan2(
      math.sin(l) * math.cos(e) - math.tan(b) * math.sin(e), math.cos(l));
  final dec = math.asin(
      math.sin(b) * math.cos(e) + math.cos(b) * math.sin(e) * math.sin(l));
  return (raDeg: normalizeDeg(_d(ra)), decDeg: _d(dec));
}

/// Yıldız/gezegen koordinatlarını (RA, Dec) gözlemcinin ufuk sistemine çevirir.
/// [az] kuzeyden doğuya doğru 0-360 derece.
({double alt, double az}) raDecToAltAz(
    double raDeg, double decDeg, double latDeg, double lonDeg, DateTime t) {
  final lst = lstDeg(lonDeg, t);
  final h = _r(normalizeDeg(lst - raDeg));
  final dec = _r(decDeg);
  final lat = _r(latDeg);
  final sinAlt = math.sin(dec) * math.sin(lat) +
      math.cos(dec) * math.cos(lat) * math.cos(h);
  final alt = math.asin(_clampD(sinAlt, -1.0, 1.0));
  final az = math.atan2(-math.sin(h) * math.cos(dec),
      math.sin(dec) * math.cos(lat) - math.cos(h) * math.cos(dec) * math.sin(lat));
  return (alt: _d(alt), az: normalizeDeg(_d(az)));
}

/// Ufuk koordinatlarını (alt, az) ekvatoryal (RA, Dec) koordinatlarına çevirir.
({double raDeg, double decDeg}) altAzToRaDec(
    double altDeg, double azDeg, double latDeg, double lonDeg, DateTime t) {
  final alt = _r(altDeg);
  final az = _r(azDeg);
  final lat = _r(latDeg);
  final sinDec =
      math.sin(alt) * math.sin(lat) + math.cos(alt) * math.cos(lat) * math.cos(az);
  final dec = math.asin(_clampD(sinDec, -1.0, 1.0));
  final cosDec = math.max(math.cos(dec), 1e-12);
  final sinH = -math.sin(az) * math.cos(alt) / cosDec;
  final cosH = (math.sin(alt) - math.sin(lat) * math.sin(dec)) /
      (math.max(math.cos(lat), 1e-12) * cosDec);
  final h = math.atan2(sinH, cosH);
  final ra = normalizeDeg(lstDeg(lonDeg, t) - _d(h));
  return (raDeg: ra, decDeg: _d(dec));
}

double _sunEclipticLonDeg(double d) {
  final l = 280.460 + 0.9856474 * d;
  final g = _r(normalizeDeg(357.528 + 0.9856003 * d));
  return normalizeDeg(l + 1.915 * math.sin(g) + 0.020 * math.sin(2 * g));
}

/// Güneş'in geosantrik RA/Dec (düşük hassasiyet, ~0.01 derece).
({double raDeg, double decDeg}) sunRaDec(DateTime t) {
  final d = _days(t);
  return _eclipticToEquatorial(_sunEclipticLonDeg(d), 0.0, _obliquityDeg(d));
}

/// Ay'ın ekliptik boylam/enlemi (Meeus Bölüm 47, ana terimler).
({double lonDeg, double latDeg}) _moonEcliptic(double d) {
  final lp = normalizeDeg(218.316 + 13.176396 * d); // ortalama boylam
  final mp = _r(normalizeDeg(134.963 + 13.064993 * d)); // Ay ortalama anomali
  final f = _r(normalizeDeg(93.272 + 13.229350 * d)); // enlem argümanı
  final dd = _r(normalizeDeg(297.850 + 12.190749 * d)); // ortalama elongasyon
  final m = _r(normalizeDeg(357.529 + 0.9856003 * d)); // Güneş ortalama anomali

  final lon = lp +
      6.289 * math.sin(mp) +
      1.274 * math.sin(2 * dd - mp) +
      0.658 * math.sin(2 * dd) +
      0.214 * math.sin(2 * mp) -
      0.186 * math.sin(m) -
      0.114 * math.sin(2 * f) +
      0.059 * math.sin(2 * dd - 2 * mp) +
      0.057 * math.sin(2 * dd - m - mp) +
      0.053 * math.sin(2 * dd + mp) +
      0.046 * math.sin(2 * dd - m) -
      0.041 * math.sin(m - mp) -
      0.035 * math.sin(dd);

  final lat = 5.128 * math.sin(f) +
      0.2806 * math.sin(mp + f) +
      0.2777 * math.sin(mp - f) +
      0.1732 * math.sin(2 * dd - f) +
      0.0554 * math.sin(2 * dd + f - mp) +
      0.0326 * math.sin(2 * dd + f);

  return (lonDeg: normalizeDeg(lon), latDeg: lat);
}

/// Ay'ın geosantrik RA/Dec (düşük hassasiyet, ~0.3 derece).
({double raDeg, double decDeg}) moonRaDec(DateTime t) {
  final d = _days(t);
  final m = _moonEcliptic(d);
  return _eclipticToEquatorial(m.lonDeg, m.latDeg, _obliquityDeg(d));
}

const List<String> _moonPhaseNamesTr = [
  'Yeni Ay',
  'Büyüyen hilal',
  'İlk dördün',
  'Büyüyen şişkin Ay',
  'Dolunay',
  'Küçülen şişkin Ay',
  'Son dördün',
  'Küçülen hilal',
];

/// Ay evresi: aydınlanma oranı (0-1), yaşı (gün) ve Türkçe evre adı.
({double illumination, double ageDays, String nameTr}) moonPhaseInfo(DateTime t) {
  final d = _days(t);
  final moon = _moonEcliptic(d);
  final elong = normalizeDeg(moon.lonDeg - _sunEclipticLonDeg(d));
  final illumination = (1.0 - math.cos(_r(elong))) / 2.0;
  final ageDays = elong / 360.0 * _synodicMonthDays;
  final idx = ((elong + 22.5) / 45.0).floor() % 8;
  return (
    illumination: illumination,
    ageDays: ageDays,
    nameTr: _moonPhaseNamesTr[idx],
  );
}

// ---------------------------------------------------------------------------
// Gezegenler: Standish (JPL, J2000 yaklaşık Keplerian elemanlar).
// base: a, e, I, L, varpi, Omega; rate: birim yüzyıl başına değişim.
// ---------------------------------------------------------------------------

class _Orbit {
  const _Orbit(this.base, this.rate);
  final List<double> base;
  final List<double> rate;
}

const _Orbit _earthOrbit = _Orbit(
  [1.00000261, 0.01671123, -0.00001531, 100.46457166, 102.93768193, 0.0],
  [0.00000562, -0.00004392, -0.01294668, 35999.37244981, 0.32327364, 0.0],
);

const Map<String, _Orbit> _planetOrbits = {
  'mercury': _Orbit(
    [0.38709927, 0.20563593, 7.00497902, 252.25032350, 77.45779628, 48.33076593],
    [0.00000037, 0.00001906, -0.00594749, 149472.67411175, 0.16047689, -0.12534081],
  ),
  'venus': _Orbit(
    [0.72333566, 0.00677672, 3.39467605, 181.97909950, 131.60246718, 76.67984255],
    [0.00000390, -0.00004107, -0.00078890, 58517.81538729, 0.00268329, -0.27769418],
  ),
  'mars': _Orbit(
    [1.52371034, 0.09339410, 1.84969142, -4.55343205, -23.94362959, 49.55953891],
    [0.00001847, 0.00007882, -0.00813131, 19140.30268499, 0.44441088, -0.29257343],
  ),
  'jupiter': _Orbit(
    [5.20288700, 0.04838624, 1.30439695, 34.39644051, 14.72847983, 100.47390909],
    [-0.00011607, -0.00013253, -0.00183714, 3034.74612775, 0.21252668, 0.20469106],
  ),
  'saturn': _Orbit(
    [9.53667594, 0.05386179, 2.48599187, 49.95424423, 92.59887831, 113.66242448],
    [-0.00125060, -0.00050991, 0.00193609, 1222.49362201, -0.41897216, -0.28867794],
  ),
};

const Map<String, String> _planetAliases = {
  'mercury': 'mercury',
  'merkur': 'mercury',
  'venus': 'venus',
  'mars': 'mars',
  'jupiter': 'jupiter',
  'saturn': 'saturn',
  'satur': 'saturn',
};

String _planetKey(String s) {
  final k = s
      .trim()
      .toLowerCase()
      .replaceAll('ü', 'u')
      .replaceAll('ö', 'o')
      .replaceAll('ı', 'i')
      .replaceAll('ş', 's')
      .replaceAll('ç', 'c')
      .replaceAll('ğ', 'g');
  return _planetAliases[k] ?? k;
}

/// Heliosantrik ekliptik dik koordinatlar (AU).
List<double> _helioEcliptic(_Orbit o, double d) {
  final t = d / 36525.0;
  final a = o.base[0] + o.rate[0] * t;
  final e = o.base[1] + o.rate[1] * t;
  final inc = _r(o.base[2] + o.rate[2] * t);
  final meanLon = o.base[3] + o.rate[3] * t;
  final lonPeri = o.base[4] + o.rate[4] * t;
  final node = o.base[5] + o.rate[5] * t;
  final argPeri = _r(lonPeri - node);
  final nodeR = _r(node);

  final mDeg = normalizeDeg(meanLon - lonPeri);
  final m = _r(mDeg > 180.0 ? mDeg - 360.0 : mDeg);
  var ecc = m + e * math.sin(m);
  for (var i = 0; i < 50; i++) {
    final delta = (ecc - e * math.sin(ecc) - m) / (1.0 - e * math.cos(ecc));
    ecc -= delta;
    if (delta.abs() < 1e-12) break;
  }

  final xp = a * (math.cos(ecc) - e);
  final yp = a * math.sqrt(1.0 - e * e) * math.sin(ecc);

  final cw = math.cos(argPeri), sw = math.sin(argPeri);
  final cn = math.cos(nodeR), sn = math.sin(nodeR);
  final ci = math.cos(inc), si = math.sin(inc);

  return [
    (cw * cn - sw * sn * ci) * xp + (-sw * cn - cw * sn * ci) * yp,
    (cw * sn + sw * cn * ci) * xp + (-sw * sn + cw * cn * ci) * yp,
    sw * si * xp + cw * si * yp,
  ];
}

/// Gezegenin geosantrik RA/Dec'i (derece). [name]: Merkür/Mercury, Venüs/Venus,
/// Mars, Jüpiter/Jupiter, Satürn/Saturn. Bilinmeyen isimde [ArgumentError] fırlatır.
({double raDeg, double decDeg}) planetRaDec(String name, DateTime t) {
  final orbit = _planetOrbits[_planetKey(name)];
  if (orbit == null) {
    throw ArgumentError.value(name, 'name', 'Bilinmeyen gezegen');
  }
  final d = _days(t);
  final p = _helioEcliptic(orbit, d);
  final e = _helioEcliptic(_earthOrbit, d);
  final x = p[0] - e[0];
  final y = p[1] - e[1];
  final z = p[2] - e[2];
  final eps = _r(_obliquityDeg(d));
  final yEq = y * math.cos(eps) - z * math.sin(eps);
  final zEq = y * math.sin(eps) + z * math.cos(eps);
  return (
    raDeg: normalizeDeg(_d(math.atan2(yEq, x))),
    decDeg: _d(math.atan2(zEq, math.sqrt(x * x + yEq * yEq))),
  );
}

// ---------------------------------------------------------------------------
// Güneş yüksekliği, gece, gölge, dönüş hızı, Polaris
// ---------------------------------------------------------------------------

/// Güneş'in gözlemcideki yüksekliği (derece).
double sunAltitude(double latDeg, double lonDeg, DateTime t) {
  final s = sunRaDec(t);
  return raDecToAltAz(s.raDeg, s.decDeg, latDeg, lonDeg, t).alt;
}

/// Güneş [thresholdDeg] altındaysa gece kabul edilir.
/// Varsayılan -6 (sivil alacakaranlık sonu). Gerçek gece gözlemi için -18 kullanın.
bool isNight(double latDeg, double lonDeg, DateTime t, {double thresholdDeg = -6.0}) =>
    sunAltitude(latDeg, lonDeg, t) < thresholdDeg;

/// Gölge uzunluğu / cisim yüksekliği oranı = 1 / tan(güneş yüksekliği).
/// Güneş ufkun altındaysa [double.infinity] döner.
double shadowLengthRatio(double sunAltDeg) {
  if (sunAltDeg <= 0) return double.infinity;
  return 1.0 / math.tan(_r(sunAltDeg));
}

/// Dünya'nın dönüşünden doğan doğu yönlü yüzey hızı (m/s), yaklaşık.
double earthRotationSpeedMs(double latDeg) => 465.1 * math.cos(_r(latDeg));

/// Polaris'in J2000 konumu (RA, Dec) ve Meeus 21.4 ile tarihe presesyon.
({double raDeg, double decDeg}) _precessFromJ2000(
    double ra0, double dec0, DateTime t) {
  final tc = (julianDate(t) - _j2000) / 36525.0;
  final zeta = (2306.2181 * tc + 0.30188 * tc * tc + 0.017998 * tc * tc * tc) *
      _arcsecToRad;
  final z = (2306.2181 * tc + 1.09468 * tc * tc + 0.018203 * tc * tc * tc) *
      _arcsecToRad;
  final theta = (2004.3109 * tc - 0.42665 * tc * tc - 0.041833 * tc * tc * tc) *
      _arcsecToRad;

  final a0 = _r(ra0);
  final d0 = _r(dec0);
  final cosD0 = math.cos(d0);
  final aa = cosD0 * math.sin(a0 + zeta);
  final bb = math.cos(theta) * cosD0 * math.cos(a0 + zeta) -
      math.sin(theta) * math.sin(d0);
  final cc = math.sin(theta) * cosD0 * math.cos(a0 + zeta) +
      math.cos(theta) * math.sin(d0);
  return (
    raDeg: normalizeDeg(_d(math.atan2(aa, bb) + z)),
    decDeg: _d(math.asin(_clampD(cc, -1.0, 1.0))),
  );
}

/// Polaris'in o anki gök kutbundan açısal uzaklığı (derece), yaklaşık 0.7.
double polarisOffsetDeg(DateTime t) {
  final p = _precessFromJ2000(37.9546, 89.2641, t);
  return 90.0 - p.decDeg;
}

/// Kutup yıldızı yüksekliği notu: Polaris'in ufuk yüksekliği gözlemcinin enlemine eşittir.
String polarisAltitudeNote(double latDeg) {
  final lat = latDeg.toStringAsFixed(1);
  return 'Kutup yıldızı (Polaris) ufuktan yaklaşık $lat° yükseklikte görünür; '
      'bu yükseklik gözlemcinin enlemine eşittir (kutba yakın ~0.7° sapma hariç).';
}
