import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../data/models.dart';
import 'clouds.dart';
import 'hero_scene.dart' show ScenePalette;
import 'sky_bodies.dart';
import 'wx_glyph.dart';

/// Dağ sahnesinin ayarları (havaya göre): palet, ışık, kar, güneş konumu.
@immutable
class MountainSpec {
  final ScenePalette pal; final double light, snow, ground; final Offset sun; final double seed; final Color snowLit;
  const MountainSpec({required this.pal, required this.light, required this.snow, required this.ground, required this.sun, this.seed = 1.3, this.snowLit = const Color(0xFFFCFDFF)});
  @override
  bool operator ==(Object o) => o is MountainSpec && o.pal == pal && o.light == light && o.snow == snow && o.ground == ground && o.sun == sun && o.seed == seed && o.snowLit == snowLit;
  @override
  int get hashCode => Object.hash(pal, light, snow, ground, sun, seed, snowLit);
}

/// GPU dağ programı (ışıklı yamaçlar, erozyon, gerçekçi kar, pus).
class MountainShader {
  static ui.FragmentProgram? _p;
  static Future<void>? _loading;
  static bool get ready => _p != null;
  static Future<void> load() => _loading ??= () async {
        try { _p = await ui.FragmentProgram.fromAsset('shaders/mountains.frag'); } catch (_) { _p = null; }
      }();

  static bool paint(Canvas c, Rect rect, MountainSpec m) {
    final p = _p;
    if (p == null) return false;
    final sh = p.fragmentShader();
    final w = rect.width, h = rect.height;
    var i = 0;
    void f(double v) => sh.setFloat(i++, v);
    void col(Color x) { f(x.r); f(x.g); f(x.b); }
    f(w); f(h); f(m.sun.dx * w); f(m.sun.dy * h); f(m.light);
    final pal = m.pal;
    col(pal.far1); col(pal.far2); col(pal.mid1); col(pal.mid2); col(pal.near1); col(pal.near2); col(pal.haze);
    col(m.snowLit);
    f(m.snow); f(m.ground); f(m.seed);
    c.save(); c.translate(rect.left, rect.top);
    c.drawRect(Offset.zero & rect.size, Paint()..shader = sh);
    c.restore();
    sh.dispose();
    return true;
  }
}

/// Dağlar hareket etmez: ayar ya da boyut değişince bir kez tam çözünürlükte çizilip saklanır.
class MountainLayer extends StatefulWidget {
  final MountainSpec spec;
  const MountainLayer({super.key, required this.spec});
  @override
  State<MountainLayer> createState() => _MountainLayerState();
}

class _MountainLayerState extends State<MountainLayer> {
  ui.Image? _img; Size _size = Size.zero; double _dpr = 1; MountainSpec? _for;

  @override
  void initState() {
    super.initState();
    if (!MountainShader.ready) MountainShader.load().then((_) { if (mounted) setState(() {}); });
  }

  void _render() {
    if (!MountainShader.ready || _size.isEmpty) return;
    if (_img != null && _for == widget.spec) return;
    final w = (_size.width * _dpr).ceil(), h = (_size.height * _dpr).ceil();
    final rec = ui.PictureRecorder();
    final c = Canvas(rec)..scale(_dpr);
    MountainShader.paint(c, Offset.zero & _size, widget.spec);
    final pic = rec.endRecording();
    final img = pic.toImageSync(w, h);
    pic.dispose();
    _img?.dispose();
    _img = img; _for = widget.spec;
  }

  @override
  void dispose() { _img?.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    _dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 2;
    return LayoutBuilder(builder: (_, c) {
      final size = c.biggest;
      if (size != _size) { _size = size; _img?.dispose(); _img = null; }
      _render();
      return CustomPaint(size: size, painter: _ImgPainter(_img));
    });
  }
}

class _ImgPainter extends CustomPainter {
  final ui.Image? img;
  _ImgPainter(this.img);
  @override
  void paint(Canvas c, Size s) {
    final i = img;
    if (i == null) return;
    c.drawImageRect(i, Rect.fromLTWH(0, 0, i.width.toDouble(), i.height.toDouble()), Offset.zero & s, Paint()..filterQuality = FilterQuality.medium);
  }
  @override
  bool shouldRepaint(covariant _ImgPainter o) => o.img != img;
}

/// Havadan sahne görünümü: bulut ve dağ ayarları.
class SceneLook {
  final CloudSpec clouds; final MountainSpec mountains;
  const SceneLook(this.clouds, this.mountains);

  static SceneLook of(WeatherSnapshot s, Wx wx, {required Offset sun, double cloudScale = 150, double horizon = .78}) {
    final pal = ScenePalette.of(s, wx);
    final night = !s.isDay;
    final golden = identical(pal, ScenePalette.goldenHour) || identical(pal, ScenePalette.blueHour);
    final wet = {Wx.rain, Wx.drizzle, Wx.thunder}.contains(wx);
    final snowy = {Wx.snow, Wx.lentil, Wx.blizzard, Wx.sleet}.contains(wx);
    final grey = {Wx.overcast, Wx.cloudy, Wx.fog}.contains(wx);
    // Bulut renkleri: açık havada pamuk beyazı, yağışta kurşuni, gecede ay ışığı mavisi.
    final (Color lit, Color shade, double weight, double op) = golden
        ? (night ? (const Color(0xFFE7A9A0), const Color(0xFF4A3F63), .35, .9) : (const Color(0xFFFFDCC0), const Color(0xFF8E6F88), .2, .95))
        : night
        ? (s.cloudCover < 60 && !wet && !snowy ? (const Color(0xFF9EA8C6), const Color(0xFF2E3754), .4, .85) : (const Color(0xFF6F7A92), const Color(0xFF262D3D), .6, .92))
        : wx == Wx.thunder ? (const Color(0xFFC9D0DA), const Color(0xFF3E4652), 1.0, .98)
        : wet ? (const Color(0xFFD5DCE5), const Color(0xFF56616F), .9, .97)
        : snowy ? (const Color(0xFFFAFCFF), const Color(0xFF9EADC0), .25, .96)
        : grey ? (const Color(0xFFEEF2F6), const Color(0xFF8F9CAD), .45, .96)
        : s.temp >= 30 ? (const Color(0xFFFFF8EE), const Color(0xFFD9BCA2), 0.0, .95)
        : (Colors.white, const Color(0xFFB4C4D6), 0.0, .97);
    // Bulutlar rüzgârın gittiği yöne süzülür (gürültü örneklemesi ters yönde kayar).
    final to = (s.windDir + 180) * pi / 180;
    final spd = .006 + s.windSpeed.clamp(0, 25) * .0016;
    final wind = Offset(-sin(to) * spd, 0);
    final seed = ((s.place.lat * 13 + s.place.lon * 7) % 10).abs();
    final cover = wx == Wx.fog ? .55 : (s.cloudCover / 100).clamp(0.0, 1.0);
    final snowCap = (s.snowDepthM ?? 0) > .02 || snowy || s.temp <= 1;
    final ground = (s.snowDepthM ?? 0) > .02 || {Wx.snow, Wx.blizzard, Wx.lentil}.contains(wx);
    return SceneLook(
      CloudSpec(cover: cover, lit: lit, shade: shade, weight: weight, opacity: op, sun: sun, wind: wind, scale: cloudScale, horizon: horizon, seed: seed),
      MountainSpec(pal: pal, light: golden ? (night ? .55 : .9) : night ? .35 : (wet || grey ? .8 : 1), snow: snowCap ? 1 : 0, ground: ground ? 1 : 0, sun: sun, seed: 1.3,
          snowLit: golden ? const Color(0xFFFFC9B5) : const Color(0xFFFCFDFF)),
    );
  }
}

/// Süs sahnesi (veri göstermez): tanıtım ve Pro ekranlarının başlığı. Aynı gök, bulut ve dağ çizicileri.
class DecorScene extends StatelessWidget {
  final ScenePalette pal; final double cover; final bool night; final double light; final double height; final Widget? child;
  final Color cloudLit, cloudShade; final double cloudWeight; final Offset sun; final Color snowLit;
  const DecorScene({super.key, required this.pal, this.cover = .35, this.night = false, this.light = 1, this.height = 180, this.child,
      this.cloudLit = Colors.white, this.cloudShade = const Color(0xFFB4C4D6), this.cloudWeight = 0, this.sun = const Offset(.8, .3), this.snowLit = const Color(0xFFFCFDFF)});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: SizedBox(height: height, child: Stack(fit: StackFit.expand, children: [
          CustomPaint(painter: _DecorSky(pal, sun, night, cover)),
          CloudLayer(spec: CloudSpec(cover: cover, lit: cloudLit, shade: cloudShade, weight: cloudWeight, sun: sun, scale: 140 * height / 380 + 40, horizon: .8, seed: 6.4, wind: const Offset(-.012, 0))),
          MountainLayer(spec: MountainSpec(pal: pal, light: light, snow: 1, ground: 0, sun: sun, seed: 2.1, snowLit: snowLit)),
          const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x00000000), Color(0x55050F1F)], stops: [.45, 1]))),
          if (child != null) child!,
        ])),
      );
}

class _DecorSky extends CustomPainter {
  final ScenePalette pal; final Offset sun; final bool night; final double cover;
  _DecorSky(this.pal, this.sun, this.night, this.cover);
  @override
  void paint(Canvas c, Size s) {
    final r = Offset.zero & s;
    c.drawRect(r, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [pal.skyTop, pal.skyBottom], stops: [0, pal.skyStop]).createShader(r));
    final o = Offset(sun.dx * s.width, sun.dy * s.height), k = s.height / 380;
    if (night) {
      if (!MoonRenderer.paint(c, o, 24 * k + 6, MoonView.at(39, 35, DateTime.now()).withAlt(40))) {
        c.drawCircle(o, 24 * k + 6, Paint()..color = const Color(0xFFF4ECCF));
      }
      final rnd = Random(3);
      for (var i = 0; i < 60; i++) {
        c.drawCircle(Offset(rnd.nextDouble() * s.width, rnd.nextDouble() * s.height * .5), .4 + rnd.nextDouble(), Paint()..color = Colors.white.withValues(alpha: .4 + rnd.nextDouble() * .5));
      }
    } else {
      paintSun(c, o, 22 * k + 4, alt: 4, cover: cover);
    }
  }
  @override
  bool shouldRepaint(covariant _DecorSky o) => false;
}
