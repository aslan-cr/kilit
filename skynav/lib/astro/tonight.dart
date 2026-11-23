import 'astro_math.dart';

/// Bu gece çıplak gözle görülebilecek bir gezegen.
class TonightPlanet {
  final String key, name;
  final double mag;               // en iyi andaki parlaklık (kadir)
  final DateTime start, end;      // karanlıkta ve ufkun ≥ 10° üstünde olduğu aralık
  final DateTime best;            // en yüksek olduğu an
  final double bestAlt, bestAz;   // o andaki yükseklik ve yön
  const TonightPlanet(this.key, this.name, this.mag, this.start, this.end, this.best, this.bestAlt, this.bestAz);

  /// Parlaklık, gündelik sözcükle.
  String get brightness => mag < -3 ? 'göz kamaştırıcı' : mag < -1 ? 'çok parlak' : mag < 1 ? 'parlak' : 'sönükçe';

  /// Yön, bulunma halinde: "güneydoğuda".
  static String where(double az) {
    const n = ['kuzeyde', 'kuzeydoğuda', 'doğuda', 'güneydoğuda', 'güneyde', 'güneybatıda', 'batıda', 'kuzeybatıda'];
    return n[(((az % 360) + 360) % 360 + 22.5) ~/ 45 % 8];
  }
}

const _planets = [('mercury', 'Merkür'), ('venus', 'Venüs'), ('mars', 'Mars'), ('jupiter', 'Jüpiter'), ('saturn', 'Satürn')];

/// [now]'dan sonraki gece (Güneş −8°'nin altındayken) görülebilecek gezegenler, en parlaktan sönüğe.
/// Gece sürüyorsa şu andan sabaha kadar. 10 dakikalık adımlarla taranır.
List<TonightPlanet> planetsTonight(double lat, double lon, DateTime now) {
  final t0 = now.toUtc();
  // Gecenin başı: şimdi karanlıksa şimdi, değilse sıradaki Güneş −8° geçişi
  bool dark(DateTime t) => sunAltitude(lat, lon, t) < -8;
  var start = t0;
  if (!dark(start)) {
    var t = t0;
    for (var i = 0; i < 24 * 6 && !dark(t); i++) { t = t.add(const Duration(minutes: 10)); }
    if (!dark(t)) return const []; // kutup yazı: karanlık yok
    start = t;
  }
  var end = start;
  for (var i = 0; i < 24 * 6 && dark(end); i++) { end = end.add(const Duration(minutes: 10)); }

  final out = <TonightPlanet>[];
  for (final (key, name) in _planets) {
    DateTime? a, b, best;
    var bestAlt = -90.0, bestAz = 0.0;
    for (var t = start; !t.isAfter(end); t = t.add(const Duration(minutes: 10))) {
      final rd = planetRaDec(key, t);
      final aa = raDecToAltAz(rd.raDeg, rd.decDeg, lat, lon, t);
      if (aa.alt >= 10) {
        a ??= t;
        b = t;
        if (aa.alt > bestAlt) { bestAlt = aa.alt; bestAz = aa.az; best = t; }
      }
    }
    if (a == null || best == null) continue;
    if (b!.difference(a).inMinutes < 20) continue; // şafakta bir anlık görünüş sayılmaz
    final mag = planetMagnitude(key, best);
    if (mag > 2.5) continue; // şehir ışığında görülmesi zor
    out.add(TonightPlanet(key, name, mag, a, b, best, bestAlt, bestAz));
  }
  out.sort((x, y) => x.mag.compareTo(y.mag));
  return out;
}
