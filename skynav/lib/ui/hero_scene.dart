import 'dart:math';
import 'package:flutter/material.dart';
import '../data/models.dart';
import 'wx_glyph.dart';

/// Ana ekranın üst sahnesi: tamamen kodla çizilmiş manzara.
/// Gök (saat + hava), güneş/ay, yıldızlar, katmanlı dağlar, karlı zirveler, kayan bulutlar ve rüzgârla eğilen yağış.
class HeroScene extends StatefulWidget {
  final WeatherSnapshot s; final Analysis a; final Wx wx;
  final double height;
  final Widget? child;
  const HeroScene({super.key, required this.s, required this.a, required this.wx, this.height = 380, this.child});
  @override
  State<HeroScene> createState() => _HeroSceneState();
}

class _HeroSceneState extends State<HeroScene> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 90))..repeat();
  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(34),
        child: SizedBox(
          height: widget.height,
          child: Stack(fit: StackFit.expand, children: [
            RepaintBoundary(child: AnimatedBuilder(animation: _c, builder: (_, __) => CustomPaint(painter: _ScenePainter(widget.s, widget.a, widget.wx, _c.value * 90)))),
            if (widget.child != null) widget.child!,
          ]),
        ),
      );
}

/// Sahne paleti: gök üst/alt, dağ katmanları, metin rengi.
class ScenePalette {
  final Color skyTop, skyBottom, far, mid, near, text;
  const ScenePalette(this.skyTop, this.skyBottom, this.far, this.mid, this.near, this.text);

  static ScenePalette of(WeatherSnapshot s, Wx wx) {
    final night = !s.isDay;
    final snowy = {Wx.snow, Wx.lentil, Wx.blizzard, Wx.sleet}.contains(wx);
    if (night && s.cloudCover < 60) return const ScenePalette(Color(0xFF0A1238), Color(0xFF2E3F7E), Color(0xFF34447A), Color(0xFF223061), Color(0xFF141D40), Colors.white);
    if (night) return const ScenePalette(Color(0xFF1E2636), Color(0xFF3E4A60), Color(0xFF4A566C), Color(0xFF323C50), Color(0xFF1C2333), Colors.white);
    if (snowy) return const ScenePalette(Color(0xFF9DB5CF), Color(0xFFE6EEF6), Color(0xFFBFCDDB), Color(0xFF8399B0), Color(0xFF41566F), Colors.white);
    if (wx == Wx.rain || wx == Wx.thunder || wx == Wx.drizzle) return const ScenePalette(Color(0xFF7D8FA3), Color(0xFFC9D3DD), Color(0xFFA2B0BF), Color(0xFF6E8195), Color(0xFF34465A), Colors.white);
    if (wx == Wx.overcast || wx == Wx.cloudy || wx == Wx.fog) return const ScenePalette(Color(0xFF9FB2C6), Color(0xFFE3EAF1), Color(0xFFB4C3D2), Color(0xFF7C92A8), Color(0xFF3D5268), Colors.white);
    if (s.temp >= 30) return const ScenePalette(Color(0xFFFF9E5E), Color(0xFFFFE2B8), Color(0xFFE9B48A), Color(0xFFC07F5A), Color(0xFF6B3F2E), Colors.white);
    return const ScenePalette(Color(0xFF4FA5F2), Color(0xFFCDE9FF), Color(0xFF9CC7E8), Color(0xFF5E93BE), Color(0xFF24506F), Colors.white);
  }
}

class _ScenePainter extends CustomPainter {
  final WeatherSnapshot s; final Analysis a; final Wx wx; final double t;
  _ScenePainter(this.s, this.a, this.wx, this.t);

  double _ridge(double x, double w, List<double> k) {
    // Birkaç sinüsün toplamı: doğal görünen sırt çizgisi
    final u = x / w;
    return k[0] * sin(u * k[1] + k[2]) + k[3] * sin(u * k[4] + k[5]) + k[6] * sin(u * k[7] + k[8]);
  }

  Path _mountain(Size sz, double base, double amp, List<double> k) {
    final p = Path()..moveTo(0, sz.height);
    for (var x = 0.0; x <= sz.width + 4; x += 4) {
      p.lineTo(x, base - amp * (0.55 + 0.45 * _ridge(x, sz.width, k).clamp(-1.0, 1.0)));
    }
    p..lineTo(sz.width, sz.height)..close();
    return p;
  }

  @override
  void paint(Canvas c, Size sz) {
    final pal = ScenePalette.of(s, wx);
    final rect = Offset.zero & sz;
    c.drawRect(rect, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [pal.skyTop, pal.skyBottom], stops: const [0, .75]).createShader(rect));

    final rnd = Random(4);
    final night = !s.isDay;
    // Yıldızlar
    if (night && s.cloudCover < 70) {
      for (var i = 0; i < 90; i++) {
        final o = Offset(rnd.nextDouble() * sz.width, rnd.nextDouble() * sz.height * .55);
        final tw = .35 + .65 * (0.5 + 0.5 * sin(t * 2 + i));
        c.drawCircle(o, rnd.nextDouble() * 1.3 + .3, Paint()..color = Colors.white.withValues(alpha: .75 * tw));
      }
    }
    // Güneş / ay
    final disc = Offset(sz.width * .76, sz.height * .2);
    if (!night && s.cloudCover < 80) {
      final col = s.temp >= 30 ? const Color(0xFFFFC46B) : const Color(0xFFFFF4C9);
      c.drawCircle(disc, 120, Paint()..shader = RadialGradient(colors: [col.withValues(alpha: .55), col.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: disc, radius: 120)));
      c.drawCircle(disc, 30, Paint()..color = col);
    } else if (night) {
      c.drawCircle(disc, 70, Paint()..shader = RadialGradient(colors: [const Color(0xFFDDE6FF).withValues(alpha: .28), const Color(0xFFDDE6FF).withValues(alpha: 0)]).createShader(Rect.fromCircle(center: disc, radius: 70)));
      final moon = Path()..addOval(Rect.fromCircle(center: disc, radius: 24));
      final bite = Path()..addOval(Rect.fromCircle(center: disc + const Offset(11, -7), radius: 21));
      c.drawPath(Path.combine(PathOperation.difference, moon, bite), Paint()..color = const Color(0xFFF4ECCF));
    }

    // Bulutlar (yavaşça rüzgâr yönünde süzülür)
    final cover = (s.cloudCover / 100).clamp(0.0, 1.0);
    final dir = sin((s.windDir + 180) * pi / 180) >= 0 ? 1.0 : -1.0;
    if (cover > .1) {
      for (var i = 0; i < (3 + cover * 6).round(); i++) {
        final r2 = Random(i * 13 + 1);
        final base = r2.nextDouble();
        final x = (((base + dir * t * (.004 + s.windSpeed * .0012) * (1 + i % 3)) % 1.4) - .2) * sz.width;
        final y = sz.height * (.08 + r2.nextDouble() * .32);
        final w = 70 + r2.nextDouble() * 110;
        final cloudCol = (night ? const Color(0xFF8C98B4) : Colors.white).withValues(alpha: (.35 + .45 * cover) * (night ? .5 : 1));
        final cp = Paint()..color = cloudCol..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x, y + 10), width: w, height: 26), const Radius.circular(13)), cp);
        c.drawCircle(Offset(x - w * .18, y + 2), w * .18, cp);
        c.drawCircle(Offset(x + w * .1, y - 4), w * .24, cp);
      }
    }

    // Dağ katmanları (uzak → yakın); karlıysa zirvelerde kar örtüsü
    final snowCap = (s.snowDepthM ?? 0) > .02 || {Wx.snow, Wx.lentil, Wx.blizzard}.contains(wx) || s.temp < 0;
    final layers = [
      (pal.far, sz.height * .62, 70.0, [0.7, 9.0, 1.2, 0.3, 23.0, 0.4, 0.15, 51.0, 2.0]),
      (pal.mid, sz.height * .74, 62.0, [0.8, 6.5, 2.6, 0.25, 17.0, 1.1, 0.12, 41.0, 0.3]),
      (pal.near, sz.height * .90, 58.0, [0.6, 4.2, 0.4, 0.3, 13.0, 2.2, 0.1, 33.0, 1.7]),
    ];
    for (var i = 0; i < layers.length; i++) {
      final (col, base, amp, k) = layers[i];
      final m = _mountain(sz, base, amp, k);
      c.drawPath(m, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [col, Color.lerp(col, Colors.black, .12)!]).createShader(Rect.fromLTWH(0, base - amp, sz.width, sz.height - base + amp)));
      if (snowCap && i < 2) {
        // Zirve karı: sırtın üst bandını beyazla, alt kenarı tırtıklı
        c.save(); c.clipPath(m);
        final line = Path()..moveTo(0, 0);
        for (var x = 0.0; x <= sz.width + 4; x += 4) {
          line.lineTo(x, base - amp * .35 + 6 * sin(x / 9 + i));
        }
        line..lineTo(sz.width, 0)..close();
        c.drawPath(line, Paint()..color = Colors.white.withValues(alpha: i == 0 ? .85 : .7));
        c.restore();
      }
      // Katman arası atmosfer pusu
      if (i < 2) c.drawRect(Rect.fromLTWH(0, base - amp * .2, sz.width, sz.height), Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [pal.skyBottom.withValues(alpha: 0), pal.skyBottom.withValues(alpha: .25)]).createShader(Rect.fromLTWH(0, base - amp * .2, sz.width, sz.height)));
    }
    // Yakın plan zemin karı
    if (snowCap) {
      final g = Path()..moveTo(0, sz.height);
      for (var x = 0.0; x <= sz.width + 4; x += 4) { g.lineTo(x, sz.height - 18 - 6 * sin(x / 37) - 4 * sin(x / 11)); }
      g..lineTo(sz.width, sz.height)..close();
      c.drawPath(g, Paint()..color = Colors.white.withValues(alpha: .92));
    }

    // Sis bandı
    final fog = (a.fogProb * a.fogDensity / 10000).clamp(0.0, 1.0);
    if (fog > .05) {
      c.drawRect(Rect.fromLTWH(0, sz.height * .5, sz.width, sz.height * .5), Paint()..shader = LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.white.withValues(alpha: .8 * fog), Colors.white.withValues(alpha: 0)]).createShader(Rect.fromLTWH(0, sz.height * .5, sz.width, sz.height * .5)));
    }

    // Yağış: rüzgârla eğilir, yakın taneler büyük ve hızlı
    final precip = {Wx.rain, Wx.drizzle, Wx.thunder, Wx.sleet, Wx.snow, Wx.lentil, Wx.blizzard}.contains(wx);
    if (precip) {
      final snowish = wx != Wx.rain && wx != Wx.drizzle && wx != Wx.thunder;
      final wind = sin((s.windDir + 180) * pi / 180) * s.windSpeed.clamp(0, 25);
      final n = wx == Wx.blizzard ? 170 : 110;
      for (var i = 0; i < n; i++) {
        final r2 = Random(i * 7 + 3);
        final depth = r2.nextDouble();
        final speed = (snowish ? 26.0 : 380.0) * (.5 + depth);
        final y = (r2.nextDouble() * sz.height + t * speed) % (sz.height + 20) - 10;
        var x = r2.nextDouble() * sz.width + (y / sz.height) * wind * 9 + t * wind * (snowish ? 3 : 1) + (snowish ? sin(t * 1.3 + i) * 6 : 0);
        x %= sz.width; if (x < 0) x += sz.width;
        if (snowish) {
          if (wx == Wx.lentil) {
            c.drawCircle(Offset(x, y), 1.6 + depth * 2.4, Paint()..color = Colors.white);
          } else {
            c.drawCircle(Offset(x, y), .8 + depth * 2.2, Paint()..color = Colors.white.withValues(alpha: .55 + .4 * depth));
          }
        } else {
          c.drawLine(Offset(x, y), Offset(x + wind * .5, y + 9 + 9 * depth), Paint()..color = Colors.white.withValues(alpha: .35 + .3 * depth)..strokeWidth = .9 + depth);
        }
      }
    }

    // Metin okunurluğu için alt koyulaştırma
    c.drawRect(Rect.fromLTWH(0, sz.height * .45, sz.width, sz.height * .55), Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withValues(alpha: 0), Colors.black.withValues(alpha: .28)]).createShader(Rect.fromLTWH(0, sz.height * .45, sz.width, sz.height * .55)));
  }

  @override
  bool shouldRepaint(covariant _ScenePainter o) => true;
}
