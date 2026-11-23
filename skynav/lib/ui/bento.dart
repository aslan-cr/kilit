import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/models.dart';
import '../engine/formulas.dart';
import 'hero_scene.dart' show deg, moonLitPath;
import 'sky_bodies.dart';
import 'theme.dart';
import 'wx_glyph.dart';

// Figma "Hava — Ana ekran" bento blokları. Ölçüler Figma'dakiyle aynı (412 genişlik, 18 kenar, 14/12 aralık).

const kBentoBlue = Color(0xFFE8F2FC);
const kBentoMint = Color(0xFFE7F5EF);
const kBentoPeach = Color(0xFFFFF0DF);
const kBentoSand = Color(0xFFF6EEE4);
const kBentoNight = Color(0xFF16224A);

const _trDays = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

/// Opak bento bloğu: renkli zemin, 26 köşe, yumuşak çift gölge.
class Bento extends StatelessWidget {
  final Widget child; final Color color; final EdgeInsets padding; final double? height; final VoidCallback? onTap; final bool clip;
  const Bento({super.key, required this.child, this.color = Colors.white, this.padding = const EdgeInsets.all(16), this.height, this.onTap, this.clip = false});
  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(26);
    Widget body = Padding(padding: padding, child: child);
    if (onTap != null) body = InkWell(borderRadius: r, onTap: onTap, child: body);
    final box = Container(
      height: height,
      decoration: BoxDecoration(color: color, borderRadius: r, boxShadow: const [
        BoxShadow(color: Color(0x0F1B3A5C), blurRadius: 24, spreadRadius: -6, offset: Offset(0, 10)),
        BoxShadow(color: Color(0x0A1B3A5C), blurRadius: 3, offset: Offset(0, 1)),
      ]),
      child: Material(type: MaterialType.transparency, borderRadius: r, clipBehavior: clip || onTap != null ? Clip.antiAlias : Clip.none, child: body),
    );
    return onTap == null ? box : Pressable(child: box);
  }
}

/// Dokununca hafifçe içe çöken sarmalayıcı (yay hissi).
class Pressable extends StatefulWidget {
  final Widget child;
  const Pressable({super.key, required this.child});
  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  @override
  Widget build(BuildContext context) => Listener(
        onPointerDown: (_) => setState(() => _down = true),
        onPointerUp: (_) => setState(() => _down = false),
        onPointerCancel: (_) => setState(() => _down = false),
        child: AnimatedScale(scale: _down ? .975 : 1, duration: Duration(milliseconds: _down ? 90 : 220), curve: _down ? Curves.easeOut : Curves.easeOutBack, child: widget.child),
      );
}

/// Açılışta sırayla, yumuşakça yukarı kayarak beliren blok. Hareket azaltma açıksa anında görünür.
class Reveal extends StatefulWidget {
  final int index; final Widget child;
  const Reveal({super.key, required this.index, required this.child});
  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
  late final Animation<double> _a = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 40 * widget.index.clamp(0, 10)), () { if (mounted) _c.forward(); });
  }
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return widget.child;
    return AnimatedBuilder(animation: _a, child: widget.child, builder: (_, child) => Opacity(
          opacity: _a.value, child: Transform.translate(offset: Offset(0, 18 * (1 - _a.value)), child: child)));
  }
}

/// Blok başlığı: renkli nokta + aralıklı büyük harf etiket (+ sağda ek bilgi).
class BlockHead extends StatelessWidget {
  final String label; final Color dot; final Color? labelColor; final Widget? trailing;
  const BlockHead(this.label, {super.key, this.dot = kAccent, this.labelColor, this.trailing});
  @override
  Widget build(BuildContext context) => Row(children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Expanded(child: Text(trUpper(label), maxLines: 1, overflow: TextOverflow.ellipsis,
            style: T.label.copyWith(fontSize: 11, letterSpacing: 1.0, color: labelColor ?? kInkFaint))),
        if (trailing != null) trailing!,
      ]);
}

class _Trail extends StatelessWidget {
  final String text; final Color color;
  const _Trail(this.text, {super.key, this.color = kInkSoft});
  @override
  Widget build(BuildContext context) => Text(text, style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600, color: color));
}

TextStyle _st(double size, FontWeight w, Color c, {double ls = 0, double? h}) =>
    TextStyle(fontFamily: 'Inter', fontSize: size, fontWeight: w, color: c, letterSpacing: ls, height: h, fontFeatures: const [FontFeature.tabularFigures()]);

/// İki bloklu bento satırı.
class BentoRow extends StatelessWidget {
  final Widget left, right; final double height;
  const BentoRow({super.key, required this.left, required this.right, required this.height});
  @override
  Widget build(BuildContext context) => SizedBox(height: height, child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(child: left), const SizedBox(width: 12), Expanded(child: right),
      ]));
}

// ── Spiker ─────────────────────────────────────────────────────────────────
class SpeakerCard extends StatelessWidget {
  final String text; final VoidCallback onPlay;
  const SpeakerCard({super.key, required this.text, required this.onPlay});
  @override
  Widget build(BuildContext context) => Bento(
        padding: const EdgeInsets.all(14), onTap: onPlay,
        child: Row(children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFFE6F0FD), borderRadius: BorderRadius.circular(15)),
              child: const CustomPaint(painter: _QuotePainter())),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: _st(15, FontWeight.w600, kInk, h: 1.4))),
          const SizedBox(width: 12),
          Semantics(button: true, label: 'Sesli oku', child: Container(width: 40, height: 40, decoration: const BoxDecoration(color: kAccent, shape: BoxShape.circle),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 26))),
        ]),
      );
}

class _QuotePainter extends CustomPainter {
  const _QuotePainter();
  @override
  void paint(Canvas c, Size s) {
    // Figma alıntı işareti (24'lük kutuda), 22 px, ortalı
    c.translate((s.width - 22) / 2, (s.height - 22) / 2); c.scale(22 / 24);
    final paint = Paint()..color = kAccent;
    for (final dx in [0.0, 8.0]) {
      final p = Path()
        ..moveTo(5 + dx, 11)
        ..cubicTo(5 + dx, 7.7, 7.2 + dx, 5.4, 10.5 + dx, 5)
        ..lineTo(11 + dx, 6.8)
        ..cubicTo(9 + dx, 7.3, 8 + dx, 8.6, 8 + dx, 10)
        ..lineTo(11 + dx, 10)..lineTo(11 + dx, 17)..lineTo(5 + dx, 17)..close();
      c.drawPath(p, paint);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter o) => false;
}

// ── Saatlik: sıcaklık eğrisi + yağış çubukları ─────────────────────────────
class HourlyBlock extends StatefulWidget {
  final List<HourPoint> hours;
  const HourlyBlock({super.key, required this.hours});
  @override
  State<HourlyBlock> createState() => _HourlyBlockState();
}

class _HourlyBlockState extends State<HourlyBlock> {
  int? _sel;
  void _pick(Offset p, double w) {
    final n = widget.hours.length;
    if (n < 2) return;
    final i = ((p.dx - 6) / (w - 12) * (n - 1)).round().clamp(0, n - 1);
    if (i != _sel) { HapticFeedback.selectionClick(); setState(() => _sel = i); }
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.hours;
    final sel = _sel == null ? null : h[_sel!];
    return Bento(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        BlockHead('Saatlik', trailing: AnimatedSwitcher(duration: const Duration(milliseconds: 160), child: sel == null
            ? _Trail('${h.length} saat · kaydır', key: const ValueKey('n'))
            : _Trail('${sel.time.hour.toString().padLeft(2, '0')}:00 · ${deg(sel.temp)} · ${(max(sel.precip, sel.snowfall * .7)).toStringAsFixed(1)} mm · ${sel.windSpeed.round()} m/s',
                key: ValueKey(_sel), color: kAccent))),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (_, c) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (d) => _pick(d.localPosition, c.maxWidth),
          onHorizontalDragUpdate: (d) => _pick(d.localPosition, c.maxWidth),
          onHorizontalDragEnd: (_) => setState(() => _sel = null),
          onTapDown: (d) => _pick(d.localPosition, c.maxWidth),
          onTapUp: (_) => Future.delayed(const Duration(milliseconds: 1400), () { if (mounted) setState(() => _sel = null); }),
          child: SizedBox(height: 150, width: double.infinity, child: CustomPaint(painter: _HourlyPainter(h, _sel))),
        )),
      ]),
    );
  }
}

class _HourlyPainter extends CustomPainter {
  final List<HourPoint> h; final int? sel;
  _HourlyPainter(this.h, [this.sel]);

  void _text(Canvas c, String s, TextStyle st, Offset at, {double align = .5, double? minX, double? maxX}) {
    final tp = TextPainter(text: TextSpan(text: s, style: st), textDirection: TextDirection.ltr)..layout();
    var x = at.dx - tp.width * align;
    if (minX != null) x = max(minX, x);
    if (maxX != null) x = min(maxX - tp.width, x);
    tp.paint(c, Offset(x, at.dy));
  }

  @override
  void paint(Canvas c, Size sz) {
    if (h.length < 2) return;
    final n = h.length, cw = sz.width, ch = sz.height;
    const top = 30.0, plotH = 70.0;
    final temps = h.map((e) => e.temp).toList();
    final tmin = temps.reduce(min) - 1, tmax = temps.reduce(max) + 1;
    double X(int i) => 6 + i * (cw - 12) / (n - 1);
    double Y(double t) => top + plotH - (t - tmin) / (tmax - tmin) * plotH;

    // 0 °C çizgisi
    if (tmin < 0 && tmax > 0) {
      final zy = Y(0);
      final dash = Paint()..color = kSnow..strokeWidth = 1;
      for (var x = 0.0; x < cw; x += 7) { c.drawLine(Offset(x, zy), Offset(min(cw, x + 3), zy), dash); }
      _text(c, '0°', _st(10, FontWeight.w700, kSnow), Offset(cw - 16, zy - 14), align: 0);
    }

    // Eğri (yumuşak kübik) ve altı dolgu
    final curve = Path()..moveTo(X(0), Y(temps[0]));
    for (var i = 1; i < n; i++) {
      final x0 = X(i - 1), x1 = X(i), y0 = Y(temps[i - 1]), y1 = Y(temps[i]), cx = (x0 + x1) / 2;
      curve.cubicTo(cx, y0, cx, y1, x1, y1);
    }
    final area = Path.from(curve)..lineTo(X(n - 1), top + plotH + 6)..lineTo(X(0), top + plotH + 6)..close();
    c.drawPath(area, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [kAccent.withValues(alpha: .28), kAccent.withValues(alpha: 0)]).createShader(Rect.fromLTRB(0, top, cw, top + plotH + 6)));
    c.drawPath(curve, Paint()..color = kAccent..style = PaintingStyle.stroke..strokeWidth = 3..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);

    // Yağış çubukları (mm; kar varsa kar suyu karşılığı da yağışa dahildir)
    final pr = h.map((e) => max(e.precip, e.snowfall * .7)).toList();
    final pMax = max(1.2, pr.reduce(max));
    for (var i = 0; i < n; i++) {
      if (pr[i] < .05) continue;
      final bh = max(3.0, pr[i] / pMax * 26);
      final snowy = h[i].snowfall > .05;
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(X(i) - 3, ch - 22 - bh, 6, bh), const Radius.circular(3)),
          Paint()..color = (snowy ? kSnow : const Color(0xFF3B8EE8)).withValues(alpha: .85));
    }
    c.drawLine(Offset(0, ch - 20), Offset(cw, ch - 20), Paint()..color = kLine..strokeWidth = 1);

    // Her 3 saatte nokta + etiketler
    for (var i = 0; i < n; i += 3) {
      final o = Offset(X(i), Y(temps[i]));
      c.drawCircle(o, 4, Paint()..color = Colors.white);
      c.drawCircle(o, 4, Paint()..color = kAccent..style = PaintingStyle.stroke..strokeWidth = 2.5);
      _text(c, deg(temps[i]), _st(12, FontWeight.w700, kInk), Offset(o.dx, o.dy - 24));
      final first = i == 0;
      _text(c, first ? 'Şimdi' : h[i].time.hour.toString().padLeft(2, '0'), _st(11, first ? FontWeight.w700 : FontWeight.w600, first ? kAccent : kInkSoft),
          Offset(o.dx, ch - 15), minX: 0, maxX: cw);
    }
    // Parmakla seçilen saat: dikey kılavuz ve vurgulu nokta
    final si = sel;
    if (si != null && si >= 0 && si < n) {
      final x = X(si), y = Y(temps[si]);
      c.drawLine(Offset(x, 6), Offset(x, ch - 20), Paint()..color = kAccent.withValues(alpha: .35)..strokeWidth = 1.5);
      c.drawCircle(Offset(x, y), 9, Paint()..color = kAccent.withValues(alpha: .18));
      c.drawCircle(Offset(x, y), 5.5, Paint()..color = Colors.white);
      c.drawCircle(Offset(x, y), 5.5, Paint()..color = kAccent..style = PaintingStyle.stroke..strokeWidth = 3);
    }
  }

  @override
  bool shouldRepaint(covariant _HourlyPainter o) => o.h != h || o.sel != sel;
}

// ── 7 günlük ────────────────────────────────────────────────────────────────
class DailyBlock extends StatelessWidget {
  final List<DayPoint> days;
  const DailyBlock({super.key, required this.days});

  static Color tempColor(double t) => t <= -8 ? const Color(0xFF3B7DDD) : t <= 0 ? kSnow : t <= 4 ? const Color(0xFF52C4B0)
      : t <= 18 ? const Color(0xFFF2C94C) : t <= 27 ? kSun : kHeat;

  @override
  Widget build(BuildContext context) {
    final lo = days.map((d) => d.tMin).reduce(min), hi = days.map((d) => d.tMax).reduce(max);
    return Bento(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        BlockHead('${days.length} günlük'),
        const SizedBox(height: 10),
        for (var i = 0; i < days.length; i++) ...[
          if (i > 0) const Divider(height: 1, thickness: 1, color: kLine),
          Padding(padding: const EdgeInsets.symmetric(vertical: 9), child: Row(children: [
            SizedBox(width: 50, child: Text(i == 0 ? 'Bugün' : i == 1 ? 'Yarın' : _trDays[days[i].date.weekday - 1], maxLines: 1,
                style: _st(15, i == 0 ? FontWeight.w700 : FontWeight.w600, kInk))),
            const SizedBox(width: 10),
            WxGlyph(wxFromCode(days[i].weatherCode), size: 30),
            const SizedBox(width: 10),
            SizedBox(width: 40, child: Text(_amount(days[i]), textAlign: TextAlign.center, maxLines: 1, style: _st(12, FontWeight.w700, kSnow))),
            const SizedBox(width: 10),
            SizedBox(width: 32, child: Text(deg(days[i].tMin), textAlign: TextAlign.right, style: _st(15, FontWeight.w500, kInkSoft))),
            const SizedBox(width: 10),
            Expanded(child: _Range(lo: lo, hi: hi, a: days[i].tMin, b: days[i].tMax)),
            const SizedBox(width: 10),
            SizedBox(width: 30, child: Text(deg(days[i].tMax), style: _st(15, FontWeight.w700, kInk))),
          ])),
        ],
      ]),
    );
  }

  static String _amount(DayPoint d) => d.snowSum >= .5 ? '${d.snowSum.round()} cm' : d.precipSum >= .5 ? '${d.precipSum.round()} mm' : '';
}

class _Range extends StatelessWidget {
  final double lo, hi, a, b;
  const _Range({required this.lo, required this.hi, required this.a, required this.b});
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (_, c) {
        final span = max(1.0, hi - lo);
        final l = (a - lo) / span * c.maxWidth, r = (b - lo) / span * c.maxWidth;
        return SizedBox(height: 6, child: Stack(children: [
          Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(color: kLine, borderRadius: BorderRadius.circular(3)))),
          Positioned(left: l, width: max(8.0, r - l), top: 0, bottom: 0, child: DecoratedBox(decoration: BoxDecoration(
              gradient: LinearGradient(colors: [DailyBlock.tempColor(a), DailyBlock.tempColor(b)]), borderRadius: BorderRadius.circular(3)))),
        ]));
      });
}

// ── Ne yağıyor: iç içe halkalar ───────────────────────────────────────────
class PrecipRingsBlock extends StatelessWidget {
  final Analysis a; final VoidCallback? onTap;
  const PrecipRingsBlock({super.key, required this.a, this.onTap});
  @override
  Widget build(BuildContext context) {
    final data = [('Kar', a.snowProb, kSnow), ('Karla k.', a.sleetProb, kSleet), ('Mercimek', a.lentilProb, kLentil), ('Tipi', a.blizzardProb, kBlizzard)];
    return Bento(
      color: kBentoBlue, onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const BlockHead('Ne yağıyor', dot: kSnow),
        const Spacer(),
        Row(children: [
          SizedBox(width: 92, height: 92, child: CustomPaint(painter: _RingsPainter([for (final d in data) (d.$2, d.$3)]))),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            for (final (n, v, col) in data) Padding(padding: const EdgeInsets.only(bottom: 4), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('%${v.round()}', style: _st(13, FontWeight.w700, col, h: 1.15)),
              Text(n, maxLines: 1, softWrap: false, overflow: TextOverflow.visible, style: _st(10, FontWeight.w600, kInkSoft, h: 1.2)),
            ])),
          ])),
        ]),
        const Spacer(),
      ]),
    );
  }
}

class _RingsPainter extends CustomPainter {
  final List<(double, Color)> d;
  _RingsPainter(this.d);
  @override
  void paint(Canvas c, Size s) {
    final k = s.width / 100, ctr = s.center(Offset.zero);
    for (var i = 0; i < d.length; i++) {
      final r = (44 - i * 11) * k;
      final (v, col) = d[i];
      final rect = Rect.fromCircle(center: ctr, radius: r);
      c.drawCircle(ctr, r, Paint()..color = col.withValues(alpha: .16)..style = PaintingStyle.stroke..strokeWidth = 8 * k);
      if (v <= .5) continue;
      c.drawArc(rect, -pi / 2, 2 * pi * (v / 100).clamp(0.0, 1.0), false,
          Paint()..color = col..style = PaintingStyle.stroke..strokeWidth = 8 * k..strokeCap = v >= 99.5 ? StrokeCap.butt : StrokeCap.round);
    }
  }
  @override
  bool shouldRepaint(covariant _RingsPainter o) => true;
}

// ── Rüzgâr pusulası ────────────────────────────────────────────────────────
class WindBlock extends StatelessWidget {
  final WeatherSnapshot s; final VoidCallback? onTap;
  const WindBlock({super.key, required this.s, this.onTap});
  @override
  Widget build(BuildContext context) => Bento(
        color: kBentoMint, onTap: onTap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          BlockHead('Rüzgâr', dot: kGood, trailing: _Trail('hamle ${s.windGust.round()}', color: s.windGust > 17 ? kDanger : kInkSoft)),
          const Spacer(),
          SizedBox(width: 100, height: 100, child: CustomPaint(painter: _CompassPainter(s.windDir))),
          const Spacer(),
          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            Text(s.windSpeed.toStringAsFixed(1), style: _st(24, FontWeight.w700, kInk, ls: -.48)),
            const SizedBox(width: 4),
            Flexible(child: Text('m/s · ${windDirName(s.windDir)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: _st(12, FontWeight.w600, kInkSoft))),
          ]),
        ]),
      );
}

class _CompassPainter extends CustomPainter {
  final double dir;
  _CompassPainter(this.dir);
  @override
  void paint(Canvas c, Size s) {
    final k = s.width / 100; c.scale(k);
    const ctr = Offset(50, 50);
    c.drawCircle(ctr, 46, Paint()..color = Colors.white.withValues(alpha: .7));
    for (var i = 0; i < 36; i++) {
      final a = i * pi / 18, major = i % 9 == 0, len = major ? 7.0 : 3.5;
      c.drawLine(ctr + Offset(sin(a), -cos(a)) * 46, ctr + Offset(sin(a), -cos(a)) * (46 - len),
          Paint()..color = major ? kGood : const Color(0xFF9BC8B4)..strokeWidth = major ? 2 : 1..strokeCap = StrokeCap.round);
    }
    final tp = TextPainter(text: const TextSpan(text: 'K', style: TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.w800, color: kDanger)), textDirection: TextDirection.ltr)..layout();
    tp.paint(c, Offset(50 - tp.width / 2, 10));
    final to = (dir + 180) * pi / 180; // rüzgârın gittiği yön
    final tip = ctr + Offset(sin(to), -cos(to)) * 40, tail = ctr - Offset(sin(to), -cos(to)) * 22;
    c.drawLine(tail, tip, Paint()..color = kInk..strokeWidth = 3.5..strokeCap = StrokeCap.round);
    c.drawCircle(tip, 5, Paint()..color = kGood);
    c.drawCircle(ctr, 4, Paint()..color = Colors.white);
    c.drawCircle(ctr, 4, Paint()..color = kInk..style = PaintingStyle.stroke..strokeWidth = 2);
  }
  @override
  bool shouldRepaint(covariant _CompassPainter o) => o.dir != dir;
}

// ── Gün ışığı yayı ─────────────────────────────────────────────────────────
class DaylightBlock extends StatelessWidget {
  final DateTime sunrise, sunset; final DateTime now;
  const DaylightBlock({super.key, required this.sunrise, required this.sunset, required this.now});

  static String _hm(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  static String _dur(Duration d) => '${d.inHours} sa ${d.inMinutes % 60} dk';

  @override
  Widget build(BuildContext context) {
    final len = sunset.difference(sunrise);
    final frac = len.inSeconds <= 0 ? -1.0 : now.difference(sunrise).inSeconds / len.inSeconds;
    final day = frac >= 0 && frac <= 1;
    final note = day ? 'Batışa ${_dur(sunset.difference(now))}'
        : now.isBefore(sunrise) ? 'Doğuşa ${_dur(sunrise.difference(now))}' : 'Güneş battı · iyi geceler kanki';
    return Bento(
      color: kBentoPeach, padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        BlockHead('Gün ışığı', dot: kSun, trailing: _Trail('${_dur(len)} gün')),
        const SizedBox(height: 10),
        SizedBox(height: 110, width: double.infinity, child: CustomPaint(painter: _ArcPainter(day ? frac : null, _hm(sunrise), _hm(sunset), note))),
      ]),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final double? frac; final String rise, set, note;
  _ArcPainter(this.frac, this.rise, this.set, this.note);
  @override
  void paint(Canvas c, Size s) {
    final aw = s.width, ah = s.height, base = ah - 18;
    final rx = (aw - 40) / 2, ry = ah - 30, cx = aw / 2;
    c.drawLine(Offset(8, base), Offset(aw - 8, base), Paint()..color = const Color(0xFFE8D3B8)..strokeWidth = 1.5);
    final arc = Path()..moveTo(20, base)..arcToPoint(Offset(aw - 20, base), radius: Radius.elliptical(rx, ry));
    // Kesikli tam yay
    for (final m in arc.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 10) {
        c.drawPath(m.extractPath(d, min(m.length, d + 4)), Paint()..color = const Color(0xFFE8C99A)..style = PaintingStyle.stroke..strokeWidth = 2);
      }
    }
    final tp = TextPainter(textDirection: TextDirection.ltr);
    void label(String t, double x, double y, {bool right = false, Color col = kInkSoft}) {
      tp.text = TextSpan(text: t, style: _st(12, FontWeight.w600, col)); tp.layout();
      tp.paint(c, Offset(right ? x - tp.width : x, y));
    }
    final f = frac;
    if (f != null) {
      final ang = pi * (1 - f);
      final sp = Offset(cx + rx * cos(ang), base - ry * sin(ang));
      c.save(); c.clipRect(Rect.fromLTWH(0, 0, sp.dx, ah));
      c.drawPath(Path.from(arc)..close(), Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [kSun.withValues(alpha: .35), kSun.withValues(alpha: 0)]).createShader(Rect.fromLTRB(0, base - ry, aw, base)));
      c.drawPath(arc, Paint()..color = kSun..style = PaintingStyle.stroke..strokeWidth = 3);
      c.restore();
      c.drawCircle(sp, 16, Paint()..color = kSun.withValues(alpha: .22));
      c.drawCircle(sp, 9, Paint()..color = kSun);
    }
    tp.text = TextSpan(text: note, style: _st(12, FontWeight.w600, f == null ? kInkSoft : const Color(0xFFB9852F))); tp.layout();
    tp.paint(c, Offset(cx - tp.width / 2, base - (f == null ? ry * .45 : 24)));
    label('$rise doğuş', 6, base + 4);
    label('$set batış', aw - 4, base + 4, right: true);
  }
  @override
  bool shouldRepaint(covariant _ArcPainter o) => o.frac != frac || o.note != note;
}

// ── Nem dalgası ────────────────────────────────────────────────────────────
class HumidityBlock extends StatelessWidget {
  final WeatherSnapshot s;
  const HumidityBlock({super.key, required this.s});
  @override
  Widget build(BuildContext context) => Bento(
        color: kBentoBlue, clip: true, padding: EdgeInsets.zero,
        child: Stack(children: [
          Positioned.fill(child: CustomPaint(painter: _WavePainter(s.humidity / 100))),
          Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const BlockHead('Nem', dot: Color(0xFF3B8EE8)),
            const SizedBox(height: 10),
            Text('%${s.humidity.round()}', style: _st(30, FontWeight.w700, kInk, ls: -.6)),
            const SizedBox(height: 10),
            Text('Çiy noktası ${deg(s.dewPoint)}', style: _st(12, FontWeight.w600, kInkSoft)),
          ])),
        ]),
      );
}

class _WavePainter extends CustomPainter {
  final double level; // 0-1
  _WavePainter(this.level);
  @override
  void paint(Canvas c, Size s) {
    // Figma: 200×70'lik iki dalga, nem %88 iken üst kenar ~104/170. Seviye neme göre yükselir.
    final w = s.width, top = s.height - 62 * level.clamp(.15, 1.0);
    final k = w / 200;
    Path wave(double y0, double amp, double phase) {
      final p = Path()..moveTo(0, top + y0);
      p.cubicTo(25 * k, top + y0 - amp + phase, 50 * k, top + y0 + amp - phase, 75 * k, top + y0);
      p.cubicTo(100 * k, top + y0 - amp, 125 * k, top + y0 - amp + phase, 150 * k, top + y0);
      p.cubicTo(175 * k, top + y0 + amp, 200 * k, top + y0 + amp, w, top + y0);
      return p..lineTo(w, s.height)..lineTo(0, s.height)..close();
    }
    c.drawPath(wave(0, 12, 0), Paint()..color = kSnow.withValues(alpha: .22));
    c.drawPath(wave(10, 12, 2), Paint()..color = kSnow.withValues(alpha: .35));
  }
  @override
  bool shouldRepaint(covariant _WavePainter o) => o.level != level;
}

// ── UV kadranı ─────────────────────────────────────────────────────────────
class UvBlock extends StatelessWidget {
  final double uv;
  const UvBlock({super.key, required this.uv});
  static String advice(double v) => v < 3 ? 'Düşük · krem gerekmez' : v < 6 ? 'Orta · krem sür, şapka tak'
      : v < 8 ? 'Yüksek · öğlen gölgede kal' : v < 11 ? 'Çok yüksek · dışarıyı kısa tut' : 'Aşırı · güneşe çıkma kanki';
  @override
  Widget build(BuildContext context) => Bento(
        color: const Color(0xFFFFF1E2),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const BlockHead('UV indeksi', dot: kHeat),
          const Spacer(),
          SizedBox(width: 140, height: 70, child: CustomPaint(painter: _UvPainter(uv), child: Align(alignment: const Alignment(0, .55),
              child: Text(uv.toStringAsFixed(1), style: _st(22, FontWeight.w700, kInk, ls: -.44))))),
          const Spacer(),
          Text(advice(uv), maxLines: 2, overflow: TextOverflow.ellipsis, style: _st(12, FontWeight.w600, kInkSoft, h: 1.3)),
        ]),
      );
}

class _UvPainter extends CustomPainter {
  final double v;
  _UvPainter(this.v);
  @override
  void paint(Canvas c, Size s) {
    const cx = 70.0, cy = 62.0, r = 52.0;
    Offset pt(double val) { final a = pi * (1 - val.clamp(0, 12) / 12); return Offset(cx + r * cos(a), cy - r * sin(a)); }
    for (final (col, a, b) in const [(Color(0xFF2E9E6A), 0.0, 3.0), (Color(0xFFF2C94C), 3.0, 6.0), (kSun, 6.0, 8.0), (kHeat, 8.0, 11.0), (Color(0xFFB04BD6), 11.0, 12.0)]) {
      final p = Path()..moveTo(pt(a + .15).dx, pt(a + .15).dy)..arcToPoint(pt(b - .15), radius: const Radius.circular(r));
      c.drawPath(p, Paint()..color = col..style = PaintingStyle.stroke..strokeWidth = 10..strokeCap = StrokeCap.round);
    }
    final o = pt(v);
    c.drawCircle(o, 8, Paint()..color = Colors.white);
    c.drawCircle(o, 8, Paint()..color = kInk..style = PaintingStyle.stroke..strokeWidth = 3);
  }
  @override
  bool shouldRepaint(covariant _UvPainter o) => o.v != v;
}

// ── Basınç barometresi ─────────────────────────────────────────────────────
class PressureBlock extends StatelessWidget {
  final double hpa; final String? trend;
  const PressureBlock({super.key, required this.hpa, this.trend});

  /// Son 3 saatteki gerçek basınç değişimi (saatlik geçmiş veriden). Veri yoksa null.
  static String? trendOf(List<HourPoint> hourly, DateTime now) {
    final past = hourly.where((h) => !h.time.isAfter(now) && h.pressure.isFinite).toList();
    if (past.length < 4) return null;
    final d = past.last.pressure - past[past.length - 4].pressure;
    return d >= 1 ? 'yükseliyor' : d <= -1 ? 'düşüyor' : 'sabit';
  }

  @override
  Widget build(BuildContext context) => Bento(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const BlockHead('Basınç', dot: kInkSoft),
          const Spacer(),
          SizedBox(width: 140, height: 118, child: CustomPaint(painter: _BaroPainter(hpa), child: Column(children: [
            const SizedBox(height: 80),
            Text('${hpa.round()}', style: _st(20, FontWeight.w700, kInk, ls: -.4, h: 1.2)),
            Text(trend == null ? 'hPa' : 'hPa · $trend', style: _st(11, FontWeight.w600, trend == 'düşüyor' ? kWarn : kInkSoft, h: 1.2)),
          ]))),
          const Spacer(),
        ]),
      );
}

class _BaroPainter extends CustomPainter {
  final double v;
  _BaroPainter(this.v);
  @override
  void paint(Canvas c, Size s) {
    const cx = 70.0, cy = 66.0, r0 = 54.0;
    Offset P(double val, double r) { final a = pi * (1.25 - 1.5 * (val.clamp(960, 1060) - 960) / 100); return Offset(cx + r * cos(a), cy - r * sin(a)); }
    final track = Path()..moveTo(P(960, r0).dx, P(960, r0).dy)..arcToPoint(P(1060, r0), radius: const Radius.circular(r0), largeArc: true);
    c.drawPath(track, Paint()..color = kLine..style = PaintingStyle.stroke..strokeWidth = 6..strokeCap = StrokeCap.round);
    for (var x = 960; x <= 1060; x += 5) {
      final major = x % 25 == 0;
      c.drawLine(P(x.toDouble(), r0 - 10), P(x.toDouble(), r0 - (major ? 18 : 14)),
          Paint()..color = major ? kInkSoft : const Color(0xFFB5C3D1)..strokeWidth = major ? 2 : 1..strokeCap = StrokeCap.round);
    }
    final sweep = 1.5 * pi * (v.clamp(960, 1060) - 960) / 100;
    final val = Path()..moveTo(P(960, r0).dx, P(960, r0).dy)..arcToPoint(P(v, r0), radius: const Radius.circular(r0), largeArc: sweep > pi);
    c.drawPath(val, Paint()..color = kAccent..style = PaintingStyle.stroke..strokeWidth = 6..strokeCap = StrokeCap.round);
    c.drawLine(const Offset(cx, cy), P(v, r0 - 8), Paint()..color = kInk..strokeWidth = 3..strokeCap = StrokeCap.round);
    c.drawCircle(const Offset(cx, cy), 5, Paint()..color = kInk);
  }
  @override
  bool shouldRepaint(covariant _BaroPainter o) => o.v != v;
}

// ── Ay evresi ──────────────────────────────────────────────────────────────
class MoonBlock extends StatelessWidget {
  final DateTime now; final bool south; final double lat, lon;
  const MoonBlock({super.key, required this.now, this.south = false, this.lat = 39, this.lon = 35});
  @override
  Widget build(BuildContext context) {
    final m = moonPhase(now);
    return Bento(
      color: kBentoNight,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const BlockHead('Ay', dot: Color(0xFFF4ECCF), labelColor: Color(0xFF9DA9CF)),
        const Spacer(),
        SizedBox(width: 92, height: 92, child: CustomPaint(painter: _MoonPainter(m.fraction, south, MoonView.at(lat, lon, now)))),
        const Spacer(),
        Text(m.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: _st(13, FontWeight.w700, const Color(0xFFF4ECCF))),
        const SizedBox(height: 4),
        Text('%${(m.illumination * 100).round()} aydınlık', style: _st(12, FontWeight.w600, const Color(0xFF9DA9CF))),
      ]),
    );
  }
}

class _MoonPainter extends CustomPainter {
  final double f; final bool south; final MoonView mv;
  _MoonPainter(this.f, this.south, this.mv);
  @override
  void paint(Canvas c, Size s) {
    // Gerçek Ay (NASA LRO haritası); bloktaki görünüm ufuk renginden bağımsız (yüksek Ay gibi)
    final flat = MoonView(illum: mv.illum, phaseAngle: mv.phaseAngle, bright: mv.bright, rot: mv.rot, alt: 45);
    if (MoonRenderer.paint(c, s.center(Offset.zero), s.width * .41, flat)) return;
    final k = s.width / 92; c.scale(k);
    const ctr = Offset(46, 46), r = 38.0;
    c.drawCircle(ctr, 46, Paint()..shader = RadialGradient(colors: [const Color(0xFFF4ECCF).withValues(alpha: .25), const Color(0x00F4ECCF)], stops: const [.6, 1])
        .createShader(Rect.fromCircle(center: ctr, radius: 46)));
    c.drawCircle(ctr, r, Paint()..color = const Color(0xFF2B3866));
    final lit = moonLitPath(ctr, r, f, south: south);
    c.drawPath(lit, Paint()..color = const Color(0xFFF4ECCF));
    c.save(); c.clipPath(lit);
    for (final (x, y, cr) in const [(58.0, 34.0, 6.0), (40.0, 56.0, 8.0), (62.0, 60.0, 4.5), (50.0, 24.0, 3.5), (30.0, 40.0, 4.0)]) {
      c.drawCircle(Offset(x, y), cr, Paint()..color = const Color(0xFFD8CDA8).withValues(alpha: .55));
    }
    c.restore();
  }
  @override
  bool shouldRepaint(covariant _MoonPainter o) => o.f != f;
}

// ── Toprak kesiti ──────────────────────────────────────────────────────────
class SoilBlock extends StatelessWidget {
  final WeatherSnapshot s;
  const SoilBlock({super.key, required this.s});
  static String _sg(double? v) => v == null ? '–' : '${v > 0.05 ? '+' : v < -0.05 ? '−' : ''}${v.abs().toStringAsFixed(1)}°';
  @override
  Widget build(BuildContext context) {
    final layers = [('0 cm', s.soil0, const Color(0xFF8A6A54)), ('6 cm', s.soil6, const Color(0xFF7A5C47)), ('18 cm', s.soil18, const Color(0xFF6A4E3B)), ('54 cm', s.soil54, const Color(0xFF583F30))];
    final s0 = s.soil0;
    final state = s0 == null ? 'Toprak verisi yok' : s0 <= 0 ? 'Zemin donuk' : s0 < 4 ? 'Zemin soğuk' : 'Zemin ılık';
    final avg = s.soil0Past3dAvg;
    final snowCover = (s.snowDepthM ?? 0) > .02;
    return Bento(
      color: kBentoSand,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const BlockHead('Toprak', dot: Color(0xFF8D6E63)),
        const SizedBox(height: 10),
        ClipRRect(borderRadius: BorderRadius.circular(14), child: Column(children: [
          if (snowCover) Container(height: 10, color: Colors.white),
          for (final (d, v, col) in layers) Container(
            color: col, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Row(children: [
              Text(d, style: _st(11, FontWeight.w600, const Color(0xFFF1E6DC).withValues(alpha: .85))),
              const Spacer(),
              Text(_sg(v), style: _st(13, FontWeight.w700, Colors.white)),
            ]),
          ),
        ])),
        const Spacer(),
        Text(avg == null ? state : '$state · 3 gün ort. ${_sg(avg)}', maxLines: 2, style: _st(11, FontWeight.w600, kInkSoft, h: 1.35)),
      ]),
    );
  }
}

// ── Donma seviyesi cetveli ────────────────────────────────────────────────
class FreezeBlock extends StatelessWidget {
  final double? freezeM, elevation;
  const FreezeBlock({super.key, required this.freezeM, required this.elevation});

  static String note(double? fl, double? el) {
    if (fl == null) return 'Donma seviyesi verisi yok.';
    if (el == null) return 'Rakımın bilinmiyor; konumu elle seçebilirsin.';
    final d = fl - el;
    if (d <= 0) return 'Donma çizgisinin üstündesin: yağış kar olur.';
    if (d < 300) return 'Donma çizgisi ${d.round()} m yukarıda: karla karışık olabilir.';
    return 'Donma çizgisi ${d.round()} m yukarıda: yağış yağmur olur.';
  }

  @override
  Widget build(BuildContext context) => Bento(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const BlockHead('Donma seviyesi', dot: kSnow),
          const SizedBox(height: 10),
          Expanded(child: CustomPaint(size: Size.infinite, painter: _FreezePainter(freezeM, elevation))),
          const SizedBox(height: 10),
          Text(note(freezeM, elevation), maxLines: 3, overflow: TextOverflow.ellipsis, style: _st(11, FontWeight.w600, kInkSoft, h: 1.35)),
        ]),
      );
}

class _FreezePainter extends CustomPainter {
  final double? fl, el;
  _FreezePainter(this.fl, this.el);
  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height;
    // Ölçek: 0 → en az 2400 m, rakım ve donma seviyesini kapsayacak şekilde 600'ün katı
    final need = max(2400.0, max(el ?? 0, fl ?? 0) * 1.2);
    final top = (need / 600).ceil() * 600.0;
    double Y(double m) => h - 6 - m.clamp(0, top) / top * (h - 14);
    double X(double fx) => fx / 150 * w;
    // Dağ silüeti (Figma kesiti), ölçeğe göre
    double pk(double m) => Y(m * top / 2400);
    final mt = Path()..moveTo(X(10), h - 6)..lineTo(X(40), pk(1500))..lineTo(X(58), pk(1100))..lineTo(X(86), pk(2250))..lineTo(X(112), pk(1400))..lineTo(X(132), pk(1800))..lineTo(X(150), h - 6)..close();
    c.drawPath(mt, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFCFDDEA), Color(0xFF8FA5BC)])
        .createShader(Rect.fromLTRB(0, pk(2250), w, h)));
    final cap = Path()..moveTo(X(76), pk(1900))..lineTo(X(86), pk(2250))..lineTo(X(96), pk(1880))..lineTo(X(91), pk(1950))..lineTo(X(86), pk(1870))..lineTo(X(81), pk(1960))..close();
    c.drawPath(cap, Paint()..color = Colors.white);
    for (var m = 0.0; m <= top; m += 600) {
      c.drawLine(Offset(0, Y(m)), Offset(6, Y(m)), Paint()..color = const Color(0xFFB5C3D1)..strokeWidth = 1.5);
    }
    final tp = TextPainter(textDirection: TextDirection.ltr);
    if (fl != null) {
      final fy = Y(fl!);
      final dash = Paint()..color = kSnow..strokeWidth = 2;
      for (var x = 0.0; x < w; x += 9) { c.drawLine(Offset(x, fy), Offset(min(w, x + 5), fy), dash); }
      tp.text = TextSpan(text: '0°C · ${fl!.round()} m', style: _st(11, FontWeight.w700, kSnow)); tp.layout();
      tp.paint(c, Offset(X(10), fy - 16 < 0 ? fy + 4 : fy - 16));
    }
    if (el != null) {
      final o = Offset(X(62), Y(el!));
      c.drawCircle(o, 6, Paint()..color = kAccent);
      c.drawCircle(o, 6, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2.5);
      tp.text = TextSpan(text: 'Sen · ${el!.round()} m', style: _st(11, FontWeight.w700, kInk)); tp.layout();
      var ly = o.dy - 7;
      if (fl != null && (ly - (Y(fl!) - 16)).abs() < 14) ly = Y(fl!) > o.dy ? ly - 10 : ly + 10;
      tp.paint(c, Offset(min(w - tp.width, X(72)), ly));
    }
  }
  @override
  bool shouldRepaint(covariant _FreezePainter o) => o.fl != fl || o.el != el;
}

// ── Küçük ölçüm kutusu (Figma'da olmayan ek ölçümler aynı dilde) ──────────
class MiniBento extends StatelessWidget {
  final String label, value, sub; final Color dot; final Color color;
  const MiniBento(this.label, this.value, this.sub, {super.key, this.dot = kAccent, this.color = Colors.white});
  @override
  Widget build(BuildContext context) => Bento(
        color: color,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          BlockHead(label, dot: dot),
          const Spacer(),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, maxLines: 1, style: _st(24, FontWeight.w700, kInk, ls: -.48))),
          const SizedBox(height: 4),
          Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: _st(12, FontWeight.w600, kInkSoft, h: 1.3)),
        ]),
      );
}
