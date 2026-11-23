import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../astro/astro_math.dart';
import 'gpu.dart';

/// Gökteki Ay'ın gözlemciye göre gerçek görünümü.
@immutable
class MoonView {
  final double illum;      // aydınlık oran 0..1
  final double phaseAngle; // Güneş-Ay-Dünya açısı (radyan): 0 dolunay, π yeni ay
  final Offset bright;     // ekranda aydınlık kenar yönü (x sağ, y yukarı)
  final double rot;        // ekranda Ay kuzeyinin dönüşü (radyan)
  final double alt;        // ufuk yüksekliği (°)
  const MoonView({required this.illum, required this.phaseAngle, required this.bright, required this.rot, required this.alt});

  /// Aynı evre, farklı yükseklik (ör. süs sahnesi ya da blokta ufuk renginden bağımsız görünüm).
  MoonView withAlt(double a) => MoonView(illum: illum, phaseAngle: phaseAngle, bright: bright, rot: rot, alt: a);

  /// Konum ve saatten: evre, aydınlık kenarın açısı (Meeus 48.5) ve paralaktik açı.
  static MoonView at(double lat, double lon, DateTime t) {
    final u = t.toUtc();
    final m = moonRaDec(u), s = sunRaDec(u);
    final info = moonPhaseInfo(u);
    final r = pi / 180;
    final a = m.raDeg * r, d = m.decDeg * r, as = s.raDeg * r, ds = s.decDeg * r;
    // Aydınlık kenarın konum açısı (kuzeyden doğuya)
    final chi = atan2(cos(ds) * sin(as - a), sin(ds) * cos(d) - cos(ds) * sin(d) * cos(as - a));
    // Paralaktik açı: gökte kuzeyin başucuna göre eğikliği
    final h = (lstDeg(lon, u) - m.raDeg) * r, phi = lat * r;
    final q = atan2(sin(h), tan(phi) * cos(d) - sin(d) * cos(h));
    final ang = chi - q; // başucundan, doğu (sol) yönüne
    final aa = raDecToAltAz(m.raDeg, m.decDeg, lat, lon, u);
    final k = info.illumination.clamp(0.0, 1.0);
    return MoonView(illum: k, phaseAngle: acos((2 * k - 1).clamp(-1.0, 1.0)), bright: Offset(-sin(ang), cos(ang)), rot: q, alt: aa.alt);
  }
}

/// Gerçek Ay çizicisi: NASA LRO tabanlı Ay haritası + GPU aydınlatma. Yüklenemezse false döner (yedek çizim).
class MoonRenderer {
  static ui.FragmentProgram? _p;
  static ui.Image? _big, _small;
  static Future<void>? _loading;
  static bool get ready => _p != null && _big != null && _small != null;

  static Future<void> load() => _loading ??= () async {
        try {
          await Gpu.calibrate();
          if (Gpu.broken) return;
          _p = await ui.FragmentProgram.fromAsset('shaders/moon.frag');
          _big = await _img('assets/moon/moon_1k.jpg');
          _small = await _img('assets/moon/moon_256.jpg');
          if (!await Gpu.verify('ay', _selfTest)) _p = null;
        } catch (_) { _p = null; }
      }();

  /// Dolunay testi: merkez opak ve gri (mor/eflatun değil), köşe saydam olmalı.
  static Future<bool> _selfTest() async {
    final img = _render(16, 0, 0, 1, 0, const [1, 1, 1], 0, 1, 1.5, _small!);
    final px = await Gpu.pixels(img);
    final w = img.width;
    img.dispose();
    if (px == null) return false;
    final c = Gpu.at(px, w, w ~/ 2, w ~/ 2), corner = Gpu.at(px, w, 1, 1);
    final hi = max(c[0], max(c[1], c[2])), lo = min(c[0], min(c[1], c[2]));
    return c[3] > 220 && hi > 30 && hi - lo < hi * .3 + 10 && corner[3] < 12;
  }

  /// Ay diskini (yarıçap [r] mantıksal px) kendi küçük görüntüsüne çizer; disk görüntünün ortasında.
  static ui.Image _render(double r, double sx, double sy, double sz, double rot, List<double> tint, double earth, double alpha, double px, ui.Image tex) {
    final side = 2 * (r + 2);
    final n = (side * px).ceil();
    final sh = _p!.fragmentShader();
    var i = 0;
    void f(double x) => sh.setFloat(i++, x);
    f(r + 2); f(r + 2); f(r); f(rot);
    f(sx); f(sy); f(sz); f(earth);
    f(tint[0]); f(tint[1]); f(tint[2]); f(alpha);
    f(px); f(Gpu.flip ? n.toDouble() : 0); f(0); f(0);
    sh.setImageSampler(0, tex);
    final img = Gpu.render(sh, n, n);
    sh.dispose();
    return img;
  }

  // Ay çok yavaş değişir: aynı görünüm tekrar tekrar üretilmesin (her karede çizilen sahneler için).
  static final Map<String, ui.Image> _cache = {};

  static Future<ui.Image> _img(String path) async {
    final data = await rootBundle.load(path);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    return (await codec.getNextFrame()).image;
  }

  /// [c]'ye merkez [o], yarıçap [r] (mantıksal px) ile çizer. [dpr] doku seçimi için.
  static bool paint(Canvas c, Offset o, double r, MoonView v, {double alpha = 1, double dpr = 3, bool halo = true, double exposure = 1.45}) {
    final p = _p;
    if (p == null || !ready || r <= 0) return false;
    // Atmosfer: ufka yakınken sarı-turuncu, yüksekte nötr
    final low = (1 - (v.alt / 22).clamp(0.0, 1.0));
    // Pozlama: gece karanlığında Ay göze parlak beyaz görünür
    final tint = [exposure, exposure * (1 - .20 * low), exposure * (1 - .42 * low)];
    if (halo) {
      final hr = r * 4.2;
      c.drawCircle(o, hr, Paint()..shader = RadialGradient(colors: [
        Color.fromRGBO(255, (236 - 30 * low).round(), (205 - 60 * low).round(), .20 * v.illum * alpha),
        Color.fromRGBO(255, 236, 205, .06 * v.illum * alpha), const Color(0x00FFECCD)], stops: const [0, .35, 1]).createShader(Rect.fromCircle(center: o, radius: hr)));
    }
    final sx = v.bright.dx * sin(v.phaseAngle), sy = v.bright.dy * sin(v.phaseAngle), sz = cos(v.phaseAngle);
    final px = Gpu.dpr.clamp(1.0, 4.0);
    final earth = pow(1 - v.illum, 2).toDouble();
    String q(double x) => x.toStringAsFixed(3);
    final key = [r.toStringAsFixed(1), q(sx), q(sy), q(sz), q(v.rot), tint.map((e) => e.toStringAsFixed(2)).join(','), q(earth), alpha.toStringAsFixed(2), px].join('|');
    var img = _cache.remove(key);
    if (img == null) {
      img = _render(r, sx, sy, sz, v.rot, tint, earth, alpha, px, r * px > 70 ? _big! : _small!);
      if (_cache.length >= 8) _cache.remove(_cache.keys.first)?.dispose();
    }
    _cache[key] = img; // en son kullanılan sona
    final side = img.width / px;
    Gpu.draw(c, img, Rect.fromCenter(center: o, width: side, height: side));
    return true;
  }
}

/// Gerçekçi güneş: kenarı kararan disk, çok katmanlı parlama; yüksekliğe göre renk ve ufukta basıklık.
void paintSun(Canvas c, Offset o, double r, {required double alt, required double cover, double alpha = 1}) {
  final a = alt.clamp(-2.0, 60.0);
  // Renk sıcaklığı: tepede beyaz, alçakta sarı, ufukta turuncu-kızıl
  Color lerp3(List<Color> cs) {
    final t = (a / 30).clamp(0.0, 1.0);
    return t < .2 ? Color.lerp(cs[0], cs[1], t / .2)! : Color.lerp(cs[1], cs[2], ((t - .2) / .8).clamp(0.0, 1.0))!;
  }
  final core = lerp3(const [Color(0xFFFFC86E), Color(0xFFFFEBBE), Color(0xFFFFFDF6)]);
  final edge = lerp3(const [Color(0xFFFF6326), Color(0xFFFFB45E), Color(0xFFFFF1CE)]);
  final glow = lerp3(const [Color(0xFFFF9150), Color(0xFFFFD28A), Color(0xFFFFF3D2)]);
  final see = (1 - cover * .85).clamp(0.05, 1.0) * alpha; // bulut diski örter, parıltı sızar
  final haze = (1 - cover * .55).clamp(.25, 1.0) * alpha;
  // Geniş saçılma (gökyüzünde güneş çevresi aydınlığı)
  for (final (k, op) in [(9.0, .16), (4.5, .24), (2.2, .38)]) {
    final rr = r * k;
    c.drawCircle(o, rr, Paint()..shader = RadialGradient(colors: [glow.withValues(alpha: op * haze), glow.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: o, radius: rr)));
  }
  if (cover >= .93) return;
  // Disk: ufukta kırılmadan dolayı basık; kenar kararması
  final squash = 1 - .14 * (1 - (a / 2).clamp(0.0, 1.0));
  c.save();
  c.translate(o.dx, o.dy); c.scale(1, squash);
  // Kenar kararması hafif; kenarda koyu halka olmasın
  final limb = Color.lerp(core, edge, .45)!;
  c.drawCircle(Offset.zero, r * 1.04, Paint()..shader = RadialGradient(colors: [core.withValues(alpha: see), core.withValues(alpha: see), limb.withValues(alpha: see), limb.withValues(alpha: 0)], stops: const [0, .55, .93, 1])
      .createShader(Rect.fromCircle(center: Offset.zero, radius: r * 1.04)));
  // Göz kamaşması: diskin üstünde parlak çekirdek
  c.drawCircle(Offset.zero, r * .8, Paint()..shader = RadialGradient(colors: [Colors.white.withValues(alpha: .55 * see * (a / 20).clamp(.2, 1.0)), Colors.white.withValues(alpha: 0)])
      .createShader(Rect.fromCircle(center: Offset.zero, radius: r * .8)));
  c.restore();
}

/// Bulutların üstüne binen hafif parlama: ince bulut arkasındaki güneş ışığı sızar.
void paintSunBloom(Canvas c, Offset o, double r, {required double alt, required double cover}) {
  if (alt < -1) return;
  final rr = r * 3.2;
  final op = (.30 * (1 - cover * .6)).clamp(.0, .3);
  c.drawCircle(o, rr, Paint()..blendMode = BlendMode.screen..shader = RadialGradient(colors: [const Color(0xFFFFF6E0).withValues(alpha: op), const Color(0x00FFF6E0)])
      .createShader(Rect.fromCircle(center: o, radius: rr)));
}
