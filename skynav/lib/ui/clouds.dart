import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'gpu.dart';

/// Bulut görünümü: örtü, renkler, güneş konumu, rüzgâr, ölçek.
@immutable
class CloudSpec {
  final double cover; // 0..1
  final Color lit, shade; // aydınlık ve gölge renkleri
  final double opacity; // en yüksek opaklık
  final double weight; // 0 açık pamuk bulut, 1 koyu yağmur bulutu
  final Offset sun; // güneş/ay konumu (alanın kesri, 0..1)
  final Offset wind; // kayma (gürültü birimi/sn)
  final double scale; // 1 gürültü birimi kaç px
  final double horizon; // bulutların söndüğü yükseklik (alanın kesri)
  final double seed;
  final Offset offset; // görünüm kaydırma (px)
  const CloudSpec({this.offset = Offset.zero, required this.cover, this.lit = Colors.white, this.shade = const Color(0xFFA6B4C6), this.opacity = .96, this.weight = 0,
      this.sun = const Offset(.82, .18), this.wind = const Offset(.02, 0), this.scale = 150, this.horizon = .8, this.seed = 3.7});

  @override
  bool operator ==(Object other) => other is CloudSpec && other.cover == cover && other.lit == lit && other.shade == shade && other.opacity == opacity && other.weight == weight
      && other.sun == sun && other.wind == wind && other.scale == scale && other.horizon == horizon && other.seed == seed && other.offset == offset;
  @override
  int get hashCode => Object.hash(cover, lit, shade, opacity, weight, sun, wind, scale, horizon, seed, offset);
}

/// GPU bulut programı. Uygulama açılışında yüklenir ve doğrulanır; yüklenemez ya da bu cihazda
/// yanlış çizerse bulutlar eski kodla çizilir (uygulama etkilenmez).
class CloudShader {
  static ui.FragmentProgram? _p;
  static Future<void>? _loading;
  static bool get ready => _p != null;
  static Future<void> load() => _loading ??= () async {
        try {
          await Gpu.calibrate();
          if (Gpu.broken) return;
          final p = await ui.FragmentProgram.fromAsset('shaders/clouds.frag');
          _p = p;
          if (!await Gpu.verify('bulut', _selfTest)) _p = null;
        } catch (_) { _p = null; }
      }();

  /// Tam kapalı yeşil test bulutu: üst yarıda yeşil ve opak, en alt satır saydam olmalı.
  static Future<bool> _selfTest() async {
    const spec = CloudSpec(cover: 1, lit: Color(0xFF1AE633), shade: Color(0xFF1AB333), opacity: 1, weight: 0, sun: Offset(.5, .1), wind: Offset.zero, scale: 30, horizon: 1);
    final img = image(spec, 0, const Size(48, 48), 1.5);
    if (img == null) return false;
    final px = await Gpu.pixels(img);
    final w = img.width, h = img.height;
    img.dispose();
    if (px == null) return false;
    var green = 0, n = 0;
    for (var y = 0; y < h * .4; y += 3) {
      for (var x = 0; x < w; x += 3) { n++; if (Gpu.greenish(Gpu.at(px, w, x, y))) green++; }
    }
    var bottom = 0;
    for (var x = 0; x < w; x++) { bottom = max(bottom, Gpu.at(px, w, x, h - 1)[3]); }
    return green > n * .2 && bottom < 25;
  }

  /// Bulutları mantıksal [size] alanı için, [px] görüntü pikseli/mantıksal px yoğunlukta üretir.
  static ui.Image? image(CloudSpec s, double t, Size size, double px) {
    final p = _p;
    if (p == null || s.cover <= .02 || size.isEmpty) return null;
    final w = (size.width * px).ceil(), h = (size.height * px).ceil();
    final sh = p.fragmentShader();
    var i = 0;
    void f(double v) => sh.setFloat(i++, v);
    f(size.width); f(size.height); f(t); f(s.cover.clamp(0, 1));
    f(s.sun.dx * size.width); f(s.sun.dy * size.height); f(s.wind.dx); f(s.wind.dy);
    f(s.lit.r); f(s.lit.g); f(s.lit.b); f(s.opacity);
    f(s.shade.r); f(s.shade.g); f(s.shade.b); f(s.weight);
    f(s.scale); f(s.horizon); f(s.seed); f(px);
    f(s.offset.dx); f(s.offset.dy); f(Gpu.flip ? h.toDouble() : 0); f(0);
    final img = Gpu.render(sh, w, h);
    sh.dispose();
    return img;
  }

  /// Bulutları [rect] içine çizer (tek seferlik çizimler için). [t] saniye.
  static bool paint(Canvas c, Rect rect, CloudSpec s, double t, {double px = 1}) {
    final img = image(s, t, rect.size, px);
    if (img == null) return false;
    Gpu.draw(c, img, rect);
    img.dispose();
    return true;
  }
}

/// Canlı bulut katmanı. Bulutlar yumuşak olduğu için düşük çözünürlükte, saniyede ~15 kez üretilip
/// büyütülerek çizilir: eski telefonlarda bile hafif. [animate] kapalıysa tek kare çizer.
class CloudLayer extends StatefulWidget {
  final CloudSpec spec; final bool animate; final double resolution;
  const CloudLayer({super.key, required this.spec, this.animate = true, this.resolution = .45});
  @override
  State<CloudLayer> createState() => _CloudLayerState();
}

class _CloudLayerState extends State<CloudLayer> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  final _repaint = ValueNotifier<int>(0);
  ui.Image? _img;
  Size _size = Size.zero;
  Duration _last = Duration.zero;
  double _t = 0;

  @override
  void initState() {
    super.initState();
    if (!CloudShader.ready) CloudShader.load().then((_) { if (mounted) setState(() {}); });
    if (widget.animate) _ticker.start();
  }

  @override
  void didUpdateWidget(covariant CloudLayer old) {
    super.didUpdateWidget(old);
    if (widget.animate && !_ticker.isActive) _ticker.start();
    if (!widget.animate && _ticker.isActive) _ticker.stop();
    if (old.spec != widget.spec) _render();
  }

  void _tick(Duration e) {
    if (e - _last < const Duration(milliseconds: 66)) return;
    _last = e;
    _t = e.inMicroseconds / 1e6;
    _render();
  }

  void _render() {
    if (!CloudShader.ready || _size.isEmpty) return;
    final img = CloudShader.image(widget.spec, _t, _size, widget.resolution);
    _img?.dispose();
    _img = img;
    _repaint.value++;
  }

  @override
  void dispose() { _ticker.dispose(); _img?.dispose(); _repaint.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => RepaintBoundary(child: LayoutBuilder(builder: (_, c) {
        final size = c.biggest;
        if (size != _size) { _size = size; WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _render(); }); }
        return CustomPaint(size: size, painter: _CloudImagePainter(this, _repaint));
      }));
}

class _CloudImagePainter extends CustomPainter {
  final _CloudLayerState st;
  _CloudImagePainter(this.st, Listenable repaint) : super(repaint: repaint);
  @override
  void paint(Canvas c, Size size) {
    final img = st._img;
    if (img != null) {
      Gpu.draw(c, img, Offset.zero & size);
    } else {
      // İlk kare: önbellek henüz yokken tek seferlik üret.
      CloudShader.paint(c, Offset.zero & size, st.widget.spec, st._t, px: st.widget.resolution);
    }
  }
  @override
  bool shouldRepaint(covariant _CloudImagePainter o) => true;
}
