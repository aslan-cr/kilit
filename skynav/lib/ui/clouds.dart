import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

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
  bool operator ==(Object o) => o is CloudSpec && o.cover == cover && o.lit == lit && o.shade == shade && o.opacity == opacity && o.weight == weight
      && o.sun == sun && o.wind == wind && o.scale == scale && o.horizon == horizon && o.seed == seed && o.offset == offset;
  @override
  int get hashCode => Object.hash(cover, lit, shade, opacity, weight, sun, wind, scale, horizon, seed, offset);
}

/// GPU bulut programı. Uygulama açılışında yüklenir; yüklenemezse bulutlar çizilmez (uygulama etkilenmez).
class CloudShader {
  static ui.FragmentProgram? _p;
  static Future<void>? _loading;
  static bool get ready => _p != null;
  static Future<void> load() => _loading ??= () async {
        try { _p = await ui.FragmentProgram.fromAsset('shaders/clouds.frag'); } catch (_) { _p = null; }
      }();

  /// Bulutları [rect] içine çizer. [t] saniye.
  static bool paint(Canvas c, Rect rect, CloudSpec s, double t) {
    final p = _p;
    if (p == null || s.cover <= .02) return false;
    final sh = p.fragmentShader();
    final w = rect.width, h = rect.height;
    var i = 0;
    void f(double v) => sh.setFloat(i++, v);
    f(w); f(h); f(t); f(s.cover.clamp(0, 1));
    f(s.sun.dx * w); f(s.sun.dy * h);
    f(s.lit.r); f(s.lit.g); f(s.lit.b); f(s.opacity);
    f(s.shade.r); f(s.shade.g); f(s.shade.b); f(s.weight);
    f(s.wind.dx); f(s.wind.dy); f(s.scale); f(s.horizon); f(s.seed); f(s.offset.dx); f(s.offset.dy);
    c.save();
    c.translate(rect.left, rect.top);
    c.drawRect(Offset.zero & rect.size, Paint()..shader = sh);
    c.restore();
    sh.dispose();
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
    final r = widget.resolution;
    final w = (_size.width * r).ceilToDouble(), h = (_size.height * r).ceilToDouble();
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final s = widget.spec;
    CloudShader.paint(c, Rect.fromLTWH(0, 0, w, h), CloudSpec(cover: s.cover, lit: s.lit, shade: s.shade, opacity: s.opacity, weight: s.weight,
        sun: s.sun, wind: s.wind, scale: s.scale * r, horizon: s.horizon, seed: s.seed, offset: s.offset * r), _t);
    final pic = rec.endRecording();
    final img = pic.toImageSync(w.toInt(), h.toInt());
    pic.dispose();
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
      c.drawImageRect(img, Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()), Offset.zero & size, Paint()..filterQuality = FilterQuality.medium);
    } else {
      // İlk kare: önbellek henüz yokken doğrudan çiz (widget görüntüsü gibi tek seferlik çizimler de bu yolu kullanır).
      CloudShader.paint(c, Offset.zero & size, st.widget.spec, st._t);
    }
  }
  @override
  bool shouldRepaint(covariant _CloudImagePainter o) => true;
}
