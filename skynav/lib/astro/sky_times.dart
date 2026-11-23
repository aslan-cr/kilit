import 'dart:math' as math;
import 'astro_math.dart';

/// Gün içi gök zamanları: fotoğrafçı saatleri, Ay doğuş/batış, ana evreler.
/// Hepsi astro_math'teki Güneş/Ay konumlarından sayısal olarak bulunur (PyEphem ile karşılaştırıldı).

/// Bir aralık (başlangıç–bitiş). Kutup bölgelerinde olmayabilir.
typedef Span = ({DateTime start, DateTime end});

/// [f] fonksiyonunun [target] değerini kestiği anlar ([from]–[to] arası). rising: yukarı doğru geçiş.
List<({DateTime t, bool rising})> crossings(double Function(DateTime) f, DateTime from, DateTime to, double target,
    {Duration step = const Duration(minutes: 10)}) {
  final out = <({DateTime t, bool rising})>[];
  var a = from.toUtc();
  var fa = f(a) - target;
  final end = to.toUtc();
  while (a.isBefore(end)) {
    var b = a.add(step);
    if (b.isAfter(end)) b = end;
    final fb = f(b) - target;
    if ((fa <= 0 && fb > 0) || (fa > 0 && fb <= 0)) {
      // İkiye bölerek ~10 sn hassasiyete in
      var lo = a, hi = b, flo = fa;
      while (hi.difference(lo).inSeconds > 10) {
        final mid = lo.add(Duration(milliseconds: hi.difference(lo).inMilliseconds ~/ 2));
        final fm = f(mid) - target;
        if ((flo <= 0) == (fm <= 0)) { lo = mid; flo = fm; } else { hi = mid; }
      }
      out.add((t: lo.add(Duration(milliseconds: hi.difference(lo).inMilliseconds ~/ 2)), rising: fb > fa));
    }
    a = b; fa = fb;
  }
  return out;
}

/// Fotoğrafçı saatleri: mavi saat (Güneş −6°…−4°) ve altın saat (−4°…+6°), sabah ve akşam.
class PhotoHours {
  final Span? morningBlue, morningGolden, eveningGolden, eveningBlue;
  const PhotoHours({this.morningBlue, this.morningGolden, this.eveningGolden, this.eveningBlue});

  /// [dayStart]: yerel gece yarısı (UTC anı olarak), 24 saat taranır.
  static PhotoHours of(double lat, double lon, DateTime dayStart) {
    final from = dayStart.toUtc(), to = from.add(const Duration(hours: 24));
    double alt(DateTime t) => sunAltitude(lat, lon, t);
    DateTime? cross(double target, bool rising) {
      for (final c in crossings(alt, from, to, target)) { if (c.rising == rising) return c.t; }
      return null;
    }
    Span? span(DateTime? a, DateTime? b) => a != null && b != null && b.isAfter(a) ? (start: a, end: b) : null;
    final m6 = cross(-6, true), m4 = cross(-4, true), p6 = cross(6, true);
    final e6 = cross(6, false), e4 = cross(-4, false), em6 = cross(-6, false);
    return PhotoHours(
      morningBlue: span(m6, m4), morningGolden: span(m4, p6),
      eveningGolden: span(e6, e4), eveningBlue: span(e4, em6),
    );
  }
}

/// Ay'ın ufuk yüksekliği (°, yer merkezli).
double moonAltitude(double lat, double lon, DateTime t) {
  final m = moonRaDec(t.toUtc());
  return raDecToAltAz(m.raDeg, m.decDeg, lat, lon, t.toUtc()).alt;
}

/// Ay doğuş ve batışı ([dayStart]'tan itibaren 24 saat). Ufuk: +0,125° (paralaks − kırılma − yarıçap).
({DateTime? rise, DateTime? set}) moonRiseSet(double lat, double lon, DateTime dayStart) {
  final from = dayStart.toUtc();
  DateTime? rise, set;
  for (final c in crossings((t) => moonAltitude(lat, lon, t), from, from.add(const Duration(hours: 24)), .125)) {
    if (c.rising) { rise ??= c.t; } else { set ??= c.t; }
  }
  return (rise: rise, set: set);
}

double _eclipticLon(({double raDeg, double decDeg}) e, DateTime t) {
  final d = julianDate(t) - 2451545.0;
  final eps = (23.439291 - 0.0130042 * d / 36525.0) * math.pi / 180;
  final ra = e.raDeg * math.pi / 180, dec = e.decDeg * math.pi / 180;
  return normalizeDeg(math.atan2(math.sin(ra) * math.cos(eps) + math.tan(dec) * math.sin(eps), math.cos(ra)) * 180 / math.pi);
}

/// Ay ile Güneş arasındaki ekliptik boylam farkı (0 yeni ay, 90 ilk dördün, 180 dolunay).
double moonElongation(DateTime t) {
  final u = t.toUtc();
  return normalizeDeg(_eclipticLon(moonRaDec(u), u) - _eclipticLon(sunRaDec(u), u));
}

/// [from]'dan sonraki ilk ana evre anı. [target]: 0 yeni ay, 90 ilk dördün, 180 dolunay, 270 son dördün.
DateTime nextMoonPhase(DateTime from, double target) {
  // Farkı hedefe göre −180…180 aralığına taşı; yükselen sıfır geçişi aranır.
  double f(DateTime t) { var d = moonElongation(t) - target; d = (d + 540) % 360 - 180; return d; }
  final start = from.toUtc();
  final hits = crossings(f, start, start.add(const Duration(days: 31)), 0, step: const Duration(hours: 6));
  for (final h in hits) { if (h.rising) return h.t; }
  return start.add(const Duration(days: 30));
}
