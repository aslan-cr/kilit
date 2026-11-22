import 'dart:math';
import 'package:flutter/material.dart';
import '../data/models.dart';

/// Gökyüzü durumu: arka planı ve parçacıkları sürer.
class SkyState {
  final PrecipKind kind;
  final double cloud; // 0-100
  final double windMs, windDirDeg;
  final bool isDay;
  final double tempC;
  final double intensity; // 0-1 yağış yoğunluğu
  final double fog; // 0-100
  final int month;
  const SkyState({this.kind = PrecipKind.none, this.cloud = 30, this.windMs = 2,
      this.windDirDeg = 270, this.isDay = true, this.tempC = 15, this.intensity = 0.5,
      this.fog = 0, this.month = 6});
  bool get summer => tempC >= 28 || (month >= 6 && month <= 8 && tempC >= 22);
}

/// Canlı arka plan: gradient + süzülen bulut katmanları + rüzgara eğilen yağış + yıldız parıltısı.
/// Tek bir Ticker, tek CustomPainter (pil dostu); ağır nesne yok.
class SkyBackground extends StatefulWidget {
  final SkyState state;
  const SkyBackground({super.key, required this.state});
  @override
  State<SkyBackground> createState() => _SkyBackgroundState();
}

class _SkyBackgroundState extends State<SkyBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 60))..repeat();
  final _rng = Random(7);
  late final List<_P> _parts = List.generate(140, (_) => _P(_rng));
  late final List<_Cloud> _clouds = List.generate(7, (i) => _Cloud(_rng, i));

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) => CustomPaint(
            painter: _SkyPainter(widget.state, _c.value * 60, _parts, _clouds),
            size: Size.infinite,
          ),
        ),
      );
}

class _P { final double x, y, s, r; _P(Random r0) : x = r0.nextDouble(), y = r0.nextDouble(), s = .5 + r0.nextDouble(), r = r0.nextDouble(); }
class _Cloud { final double y, scale, speed, phase; _Cloud(Random r, int i) : y = .04 + i * .09 + r.nextDouble() * .04, scale = .7 + r.nextDouble() * .8, speed = .004 + r.nextDouble() * .008, phase = r.nextDouble(); }

class _SkyPainter extends CustomPainter {
  final SkyState s; final double t; final List<_P> parts; final List<_Cloud> clouds;
  _SkyPainter(this.s, this.t, this.parts, this.clouds);

  List<Color> _grad() {
    if (!s.isDay) return s.cloud > 75 ? [const Color(0xFFDDE5EE), const Color(0xFFF1F5F9)] : [const Color(0xFFCFDCF2), const Color(0xFFF7FAFC)];
    switch (s.kind) {
      case PrecipKind.rain: return [const Color(0xFFCBD9E8), const Color(0xFFF4F7FA)];
      case PrecipKind.snow: case PrecipKind.lentilSnow: case PrecipKind.blizzard: case PrecipKind.sleet:
        return [const Color(0xFFDCEBFA), const Color(0xFFFFFFFF)];
      case PrecipKind.none:
        if (s.summer) return [const Color(0xFFFFE9B8), const Color(0xFFFFFBF2)];
        if (s.cloud > 70) return [const Color(0xFFD5DFEA), const Color(0xFFF7FAFC)];
        return [const Color(0xFFBFE1FF), const Color(0xFFF7FAFC)];
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final g = _grad();
    canvas.drawRect(Offset.zero & size, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: g).createShader(Offset.zero & size));

    // Yaz güneşi
    if (s.isDay && s.summer && s.cloud < 60) {
      final c = Offset(size.width * .82, size.height * .1);
      final col = s.tempC >= 38 ? const Color(0xFFFF5A3C) : s.tempC >= 33 ? const Color(0xFFFF9A2E) : const Color(0xFFFFD23F);
      canvas.drawCircle(c, 90, Paint()..shader = RadialGradient(colors: [col.withValues(alpha: .55), col.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: c, radius: 90)));
    }

    // Yıldızlar (açık gece)
    if (!s.isDay && s.cloud < 60) {
      for (final p in parts.take(70)) {
        final tw = .4 + .6 * (0.5 + 0.5 * sin(t * 1.5 + p.r * 20));
        canvas.drawCircle(Offset(p.x * size.width, p.y * size.height * .6), p.s * 1.1,
            Paint()..color = const Color(0xFF3B5B8C).withValues(alpha: .55 * tw));
      }
    }

    // Rüzgar: yönden gelen rüzgar parçacıkları (yön+180) o tarafa sürükler
    final rad = (s.windDirDeg + 180) * pi / 180;
    final wx = sin(rad);
    final windPx = (s.windMs.clamp(0, 25)) * 9.0;

    // Bulutlar: hacim hissi için 3 katman radyal gradyan blob
    final cloudAlpha = (s.cloud / 100).clamp(.12, 1.0);
    for (final c in clouds) {
      final dir = wx >= 0 ? 1.0 : -1.0;
      final speed = c.speed * (1 + s.windMs / 6);
      final px = ((c.phase + dir * t * speed) % 1.3) - .15;
      final center = Offset(px * size.width, c.y * size.height);
      final w = 170 * c.scale;
      final dark = s.kind == PrecipKind.rain || s.cloud > 85;
      for (int k = 0; k < 4; k++) {
        final o = center + Offset((k - 1.5) * w * .42, (k.isOdd ? -1 : 1) * 8.0 * c.scale);
        final r = w * (.42 + (k % 2) * .12);
        canvas.drawCircle(o, r, Paint()
          ..shader = RadialGradient(colors: [
            (dark ? const Color(0xFFB9C4D0) : Colors.white).withValues(alpha: .75 * cloudAlpha),
            (dark ? const Color(0xFFB9C4D0) : Colors.white).withValues(alpha: 0),
          ]).createShader(Rect.fromCircle(center: o, radius: r)));
      }
    }

    // Sis katmanı
    if (s.fog > 5) {
      canvas.drawRect(Offset.zero & size, Paint()..shader = LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter,
          colors: [Colors.white.withValues(alpha: (s.fog / 100) * .85), Colors.white.withValues(alpha: 0)]).createShader(Offset.zero & size));
    }

    // Yağış parçacıkları
    if (s.kind != PrecipKind.none) {
      final n = (parts.length * (.3 + s.intensity * .7)).round();
      final snowy = s.kind != PrecipKind.rain;
      final fall = snowy ? 40.0 : 520.0;
      for (int i = 0; i < n; i++) {
        final p = parts[i];
        final spd = (snowy ? fall * p.s : fall * (.7 + p.s * .4));
        var y = (p.y * size.height + t * spd) % (size.height + 40);
        var x = p.x * size.width + (y / size.height) * windPx * 3 * wx + (snowy ? sin(t + p.r * 9) * 12 : 0);
        x = x % size.width; if (x < 0) x += size.width;
        if (s.kind == PrecipKind.rain) {
          canvas.drawLine(Offset(x, y), Offset(x + wx * windPx * .15, y + 14),
              Paint()..color = const Color(0xFF4A78B0).withValues(alpha: .5)..strokeWidth = 1.3);
        } else if (s.kind == PrecipKind.lentilSnow) {
          canvas.drawCircle(Offset(x, y), 2.6 * p.s, Paint()..color = Colors.white);
          canvas.drawCircle(Offset(x, y), 2.6 * p.s, Paint()..color = const Color(0xFF9DB6CE)..style = PaintingStyle.stroke..strokeWidth = .7);
        } else {
          final blizz = s.kind == PrecipKind.blizzard;
          canvas.drawCircle(Offset(x, y), (blizz ? 1.6 : 2.4) * p.s + .6,
              Paint()..color = (blizz ? const Color(0xFF8FA9C4) : const Color(0xFFFFFFFF)).withValues(alpha: .95));
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SkyPainter o) => true;
}
