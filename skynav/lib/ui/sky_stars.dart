import 'dart:math';
import 'package:flutter/material.dart';
import '../astro/astro_math.dart';
import '../astro/bsc5.dart';

/// Sahnedeki bir gök noktası: gerçek yıldız ya da gezegen.
@immutable
class SkyDot {
  final String name;
  final double along; // 0 sol kenar … 1 sağ kenar (azimut 90–270, güneye bakış)
  final double alt;   // ufuk yüksekliği (°)
  final double mag;   // atmosfer sönümü eklenmiş görünür parlaklık (kadir)
  final Color color;
  final bool planet;
  final double seed;  // parıldama fazı
  const SkyDot(this.name, this.along, this.alt, this.mag, this.color, this.planet, this.seed);
}

/// Ana sahnenin gece göğü: o an gözlemcinin gördüğü parlak yıldızlar ve gezegenler.
/// Kuzey yarımkürede güneye (doğu solda, batı sağda), güney yarımkürede kuzeye bakar.
/// Yıldızlar Yale Parlak Yıldız Kataloğu'ndan (V ≤ 5, gerçek renk sıcaklığıyla), gezegenler yörünge elemanlarından.
class SceneSky {
  static List<SkyDot>? _cache;
  static String? _key;

  /// Yatay eksende konum (0..1). Kuzey yarımküre: güneye bakış, doğu solda.
  /// Güney yarımküre: kuzeye bakış, batı solda.
  static double along(double azDeg, double lat) =>
      lat < 0 ? normalizeDeg(azDeg + 90) / 180 : (azDeg - 90) / 180;

  /// Ufuk üstündeki parlak yıldız ve gezegenler (dakikada bir yeniden hesaplanır).
  static List<SkyDot> at(double lat, double lon, DateTime t) {
    final u = t.toUtc();
    final key = '${lat.toStringAsFixed(2)},${lon.toStringAsFixed(2)},${u.millisecondsSinceEpoch ~/ 60000}';
    if (key == _key && _cache != null) return _cache!;
    final out = <SkyDot>[];
    void add(String name, double ra, double dec, double mag, Color col, bool planet) {
      final aa = raDecToAltAz(ra, dec, lat, lon, u);
      if (aa.alt <= 0) return;
      final x = along(aa.az, lat);
      if (x < -.02 || x > 1.02) return;
      out.add(SkyDot(name, x, aa.alt, mag + extinction(aa.alt), col, planet, (ra * 7.31 + dec * 3.17) % (2 * pi)));
    }
    for (var i = 0; i + 3 < bsc5.length; i += 4) {
      add('', bsc5[i], bsc5[i + 1], bsc5[i + 2], starColor(bsc5[i + 3] * 100), false);
    }
    for (final (n, col) in _planets) {
      try {
        final rd = planetRaDec(n, u);
        add(n, rd.raDeg, rd.decDeg, planetMagnitude(n, u), col, true);
      } catch (_) {}
    }
    out.sort((a, b) => b.mag.compareTo(a.mag)); // sönükten parlağa: parlaklar üstte çizilir
    _key = key;
    return _cache = out;
  }

  static const _planets = [
    ('mercury', Color(0xFFF1E6D2)),
    ('venus', Color(0xFFFFF8E8)),
    ('mars', Color(0xFFFFB08A)),
    ('jupiter', Color(0xFFFFF0D6)),
    ('saturn', Color(0xFFF6E2B4)),
  ];

  /// Atmosfer sönümü (kadir): ufka yaklaştıkça hava kütlesi artar (k ≈ 0,22 kadir/hava kütlesi).
  static double extinction(double altDeg) {
    final h = max(altDeg, .5) * pi / 180;
    final airmass = 1 / (sin(h) + .025 * exp(-11 * sin(h)));
    return .22 * (airmass - 1);
  }

  /// Konum ve saatten sınır parlaklık (Güneş ve Ay'ın gerçek yüksekliği, Ay'ın evresi).
  static double limitAt(double lat, double lon, DateTime t, {double cloud = 0}) {
    final u = t.toUtc();
    final m = moonRaDec(u);
    final ma = raDecToAltAz(m.raDeg, m.decDeg, lat, lon, u).alt;
    return limitingMag(sunAlt: sunAltitude(lat, lon, u), moonAlt: ma, moonIllum: moonPhaseInfo(u).illumination, cloud: cloud);
  }

  /// Gökyüzünde görülebilen en sönük parlaklık: alacakaranlık, Ay ışığı ve ince bulut.
  static double limitingMag({required double sunAlt, double moonAlt = -90, double moonIllum = 0, double cloud = 0}) {
    double lim;
    if (sunAlt >= -1) {
      lim = -4.5;
    } else if (sunAlt >= -6) {
      lim = -4.5 + (-1 - sunAlt) / 5 * 5.5; // yalnızca Venüs → en parlak yıldızlar
    } else if (sunAlt >= -12) {
      lim = 1 + (-6 - sunAlt) / 6 * 2.5;
    } else if (sunAlt >= -18) {
      lim = 3.5 + (-12 - sunAlt) / 6 * 1.5;
    } else {
      lim = 5.0;
    }
    if (moonAlt > 0) lim -= 1.6 * moonIllum * min(1.0, moonAlt / 20);
    lim -= 1.5 * (cloud / 100).clamp(0.0, 1.0);
    return lim;
  }

  /// Yıldızın renk sıcaklığından (K) gerçek rengi. Göz yıldız renklerini soluk algılar: yarı yarıya beyaza karıştırılır.
  static Color starColor(double kelvin) {
    final key = (kelvin / 250).round();
    return _colors[key] ??= () {
      final t = (kelvin / 100).clamp(10.0, 400.0);
      final r = t <= 66 ? 255.0 : 329.698727446 * pow(t - 60, -0.1332047592);
      final g = t <= 66 ? 99.4708025861 * log(t) - 161.1195681661 : 288.1221695283 * pow(t - 60, -0.0755148492);
      final b = t >= 66 ? 255.0 : t <= 19 ? 0.0 : 138.5177312231 * log(t - 10) - 305.0447927307;
      final m = max(r, max(g, b));
      int ch(double v) => (255 * (.5 + .5 * (v.clamp(0.0, 255.0) / m))).round().clamp(0, 255);
      return Color.fromARGB(255, ch(r), ch(g), ch(b));
    }();
  }

  static final _colors = <int, Color>{};

  /// [c]'ye çizer. [horizonY]: ufkun ekrandaki yüksekliği; başucu üst kenarda.
  /// [t] saniye (parıldama), [lim] sınır parlaklık, [fade] genel saydamlık (bulut perdesi).
  static void paint(Canvas c, Size sz, List<SkyDot> dots, {required double horizonY, required double t, required double lim, double fade = 1, double scale = 1}) {
    if (fade <= .01) return;
    final W = sz.width;
    final glow = Paint();
    final core = Paint();
    for (final d in dots) {
      final m = d.mag;
      if (m > lim) continue;
      final edge = ((lim - m) / 1.2).clamp(0.0, 1.0); // sınıra yaklaşan yıldız yavaşça kaybolur
      final x = d.along * W, y = horizonY * (1 - d.alt / 90);
      // Parıldama: ufka yakın yıldızda daha güçlü; gezegenler neredeyse hiç parıldamaz.
      final low = pow(1 - d.alt / 90, 2).toDouble();
      final amp = d.planet ? .05 : .18 + .42 * low;
      final tw = 1 - amp * (.5 + .5 * sin(t * (2.1 + d.seed * .7) + d.seed)) * (.6 + .4 * sin(t * 5.3 + d.seed * 3));
      final b = ((3.4 - m) / 4.4).clamp(0.0, 1.0); // 0 sönük … 1 parlak
      final r = (d.planet ? .9 : .6) + 1.35 * b + (m < -1.5 ? .5 : 0);
      final a = (.45 + .55 * b) * edge * fade * tw;
      if (a <= .01) continue;
      final p = Offset(x, y);
      if (m < 1.6) {
        final gr = r * (d.planet ? 5.0 : 4.2) * scale;
        glow.shader = RadialGradient(colors: [d.color.withValues(alpha: .34 * a), d.color.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: p, radius: gr));
        c.drawCircle(p, gr, glow);
      }
      c.drawCircle(p, r * scale, core..color = d.color.withValues(alpha: a.clamp(0.0, 1.0)));
    }
  }
}
