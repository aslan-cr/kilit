import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../data/models.dart';
import 'clouds.dart';
import 'hero_scene.dart' show ScenePalette;
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
