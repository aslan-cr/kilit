import 'dart:math';
import 'package:flutter/material.dart';
import '../data/models.dart';

/// Uygulamanın kendi hava ikonları (emoji yerine). Tek tip, net, her boyutta keskin.
enum Wx { clear, partly, cloudy, overcast, fog, drizzle, rain, sleet, snow, lentil, blizzard, thunder }

/// WMO hava kodu → ikon.
Wx wxFromCode(int code) {
  if (code == 0) return Wx.clear;
  if (code <= 2) return Wx.partly;
  if (code == 3) return Wx.overcast;
  if (code == 45 || code == 48) return Wx.fog;
  if (code >= 51 && code <= 55) return Wx.drizzle;
  if (code == 56 || code == 57 || code == 66 || code == 67) return Wx.sleet;
  if ((code >= 61 && code <= 65) || (code >= 80 && code <= 82)) return Wx.rain;
  if (code == 77) return Wx.lentil;
  if ((code >= 71 && code <= 75) || code == 85 || code == 86) return Wx.snow;
  if (code >= 95) return Wx.thunder;
  return Wx.cloudy;
}

/// Motorun anlık kararı → ikon (şu anki durum için kod yerine bunu kullan).
Wx wxFromNow(WeatherSnapshot s, Analysis a) {
  switch (a.kind) {
    case PrecipKind.snow: return Wx.snow;
    case PrecipKind.lentilSnow: return Wx.lentil;
    case PrecipKind.blizzard: return Wx.blizzard;
    case PrecipKind.sleet: return Wx.sleet;
    case PrecipKind.rain: return s.cape > 800 ? Wx.thunder : Wx.rain;
    case PrecipKind.none:
      if (a.fogProb > 60 && a.fogDensity > 50) return Wx.fog;
      if (s.cloudCover > 85) return Wx.overcast;
      if (s.cloudCover > 55) return Wx.cloudy;
      if (s.cloudCover > 20) return Wx.partly;
      return Wx.clear;
  }
}

String wxLabel(Wx w, {bool day = true}) => switch (w) {
      Wx.clear => day ? 'Güneşli' : 'Açık',
      Wx.partly => 'Parçalı bulutlu',
      Wx.cloudy => 'Bulutlu',
      Wx.overcast => 'Kapalı',
      Wx.fog => 'Sisli',
      Wx.drizzle => 'Çisenti',
      Wx.rain => 'Yağmurlu',
      Wx.sleet => 'Karla karışık',
      Wx.snow => 'Karlı',
      Wx.lentil => 'Mercimek karı',
      Wx.blizzard => 'Tipi',
      Wx.thunder => 'Gök gürültülü',
    };

class WxGlyph extends StatelessWidget {
  final Wx wx; final bool day; final double size;
  const WxGlyph(this.wx, {super.key, this.day = true, this.size = 48});
  @override
  Widget build(BuildContext context) => SizedBox(width: size, height: size, child: CustomPaint(painter: _GlyphPainter(wx, day)));
}

class _GlyphPainter extends CustomPainter {
  final Wx wx; final bool day;
  _GlyphPainter(this.wx, this.day);

  @override
  void paint(Canvas c, Size sz) {
    final s = sz.width / 100; // 100 birimlik tuval
    c.save(); c.scale(s);
    final hasPrecip = {Wx.drizzle, Wx.rain, Wx.sleet, Wx.snow, Wx.lentil, Wx.blizzard, Wx.thunder}.contains(wx);
    switch (wx) {
      case Wx.clear:
        day ? _sun(c, const Offset(50, 50), 22) : _moon(c, const Offset(52, 50), 26);
        break;
      case Wx.partly:
        day ? _sun(c, const Offset(36, 36), 17) : _moon(c, const Offset(38, 36), 19);
        _cloud(c, const Offset(56, 62), 1.0, dark: false);
        break;
      case Wx.cloudy:
        _cloud(c, const Offset(40, 44), .72, dark: false, faint: true);
        _cloud(c, const Offset(54, 60), 1.0, dark: false);
        break;
      case Wx.overcast:
        _cloud(c, const Offset(38, 44), .8, dark: true, faint: true);
        _cloud(c, const Offset(54, 58), 1.05, dark: true);
        break;
      case Wx.fog:
        _cloud(c, const Offset(50, 42), .95, dark: false);
        final p = Paint()..color = const Color(0xFF9FB1C4)..strokeWidth = 5..strokeCap = StrokeCap.round;
        c.drawLine(const Offset(22, 72), const Offset(78, 72), p);
        c.drawLine(const Offset(30, 84), const Offset(70, 84), p);
        break;
      default:
        _cloud(c, const Offset(50, 42), 1.0, dark: wx == Wx.thunder || wx == Wx.blizzard || wx == Wx.rain);
    }
    if (hasPrecip) _precip(c);
    c.restore();
  }

  void _sun(Canvas c, Offset o, double r) {
    c.drawCircle(o, r * 1.9, Paint()..shader = RadialGradient(colors: [const Color(0xFFFFC93C).withValues(alpha: .35), const Color(0xFFFFC93C).withValues(alpha: 0)]).createShader(Rect.fromCircle(center: o, radius: r * 1.9)));
    final ray = Paint()..color = const Color(0xFFFFB020)..strokeWidth = r * .2..strokeCap = StrokeCap.round;
    for (var i = 0; i < 8; i++) {
      final a = i * pi / 4;
      c.drawLine(o + Offset(cos(a), sin(a)) * r * 1.35, o + Offset(cos(a), sin(a)) * r * 1.7, ray);
    }
    c.drawCircle(o, r, Paint()..shader = const RadialGradient(center: Alignment(-.3, -.3), colors: [Color(0xFFFFE27A), Color(0xFFFFB020)]).createShader(Rect.fromCircle(center: o, radius: r)));
  }

  void _moon(Canvas c, Offset o, double r) {
    c.drawCircle(o, r * 1.6, Paint()..shader = RadialGradient(colors: [const Color(0xFFB9C8F0).withValues(alpha: .35), const Color(0xFFB9C8F0).withValues(alpha: 0)]).createShader(Rect.fromCircle(center: o, radius: r * 1.6)));
    final moon = Path()..addOval(Rect.fromCircle(center: o, radius: r));
    final bite = Path()..addOval(Rect.fromCircle(center: o + Offset(r * .55, -r * .35), radius: r * .85));
    c.drawPath(Path.combine(PathOperation.difference, moon, bite),
        Paint()..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFFF1C2), Color(0xFFE9C96B)]).createShader(Rect.fromCircle(center: o, radius: r)));
  }

  void _cloud(Canvas c, Offset o, double k, {required bool dark, bool faint = false}) {
    // Tek parça bulut: kabarıklar arasında çentik yok; teğetleri sürekli tek bir eğri.
    Offset P(double x, double y) => o + Offset(x * k, y * k);
    final path = Path()
      ..moveTo(P(-24, 17).dx, P(-24, 17).dy)
      ..lineTo(P(24, 17).dx, P(24, 17).dy)
      ..cubicTo(P(31, 17).dx, P(31, 17).dy, P(35, 11).dx, P(35, 11).dy, P(34, 4).dx, P(34, 4).dy)
      ..cubicTo(P(33, -5).dx, P(33, -5).dy, P(27, -14).dx, P(27, -14).dy, P(19, -14).dx, P(19, -14).dy)
      ..cubicTo(P(15, -14).dx, P(15, -14).dy, P(12, -14.5).dx, P(12, -14.5).dy, P(11, -17).dx, P(11, -17).dy)
      ..cubicTo(P(8, -25).dx, P(8, -25).dy, P(3, -28).dx, P(3, -28).dy, P(-3, -28).dx, P(-3, -28).dy)
      ..cubicTo(P(-9, -28).dx, P(-9, -28).dy, P(-14, -23).dx, P(-14, -23).dy, P(-15, -17).dx, P(-15, -17).dy)
      ..cubicTo(P(-15.5, -14).dx, P(-15.5, -14).dy, P(-19, -11.5).dx, P(-19, -11.5).dy, P(-24, -11.5).dx, P(-24, -11.5).dy)
      ..cubicTo(P(-29, -11.5).dx, P(-29, -11.5).dy, P(-33, -6).dx, P(-33, -6).dy, P(-33, 1).dx, P(-33, 1).dy)
      ..cubicTo(P(-33, 10).dx, P(-33, 10).dy, P(-30, 17).dx, P(-30, 17).dy, P(-24, 17).dx, P(-24, 17).dy)
      ..close();
    c.drawPath(path.shift(const Offset(0, 3)), Paint()..color = const Color(0xFF2B4A6B).withValues(alpha: faint ? .04 : .10)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    final colors = dark ? [const Color(0xFFC9D3DE), const Color(0xFF93A4B8)] : [Colors.white, const Color(0xFFDCE7F2)];
    final b = path.getBounds();
    c.drawPath(path, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: faint ? colors.map((e) => e.withValues(alpha: .75)).toList() : colors).createShader(b));
    c.drawPath(path, Paint()..color = (dark ? const Color(0xFF7F92A8) : const Color(0xFFB8C9DA)).withValues(alpha: faint ? .4 : .7)..style = PaintingStyle.stroke..strokeWidth = 1.2);
  }

  void _drop(Canvas c, Offset o) {
    c.drawLine(o, o + const Offset(-4, 10), Paint()..color = const Color(0xFF3B8EE8)..strokeWidth = 4.5..strokeCap = StrokeCap.round);
  }

  void _flake(Canvas c, Offset o, {double r = 5.5, Color col = const Color(0xFF4BA3E3)}) {
    final p = Paint()..color = col..strokeWidth = 2.4..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      final a = i * pi / 3 + pi / 2;
      c.drawLine(o + Offset(cos(a), sin(a)) * r, o - Offset(cos(a), sin(a)) * r, p);
    }
  }

  void _bead(Canvas c, Offset o) {
    c.drawCircle(o, 4.6, Paint()..color = Colors.white);
    c.drawCircle(o, 4.6, Paint()..color = const Color(0xFF7C8DA6)..style = PaintingStyle.stroke..strokeWidth = 1.8);
  }

  void _precip(Canvas c) {
    switch (wx) {
      case Wx.drizzle:
        for (final x in [38.0, 54.0, 70.0]) { c.drawCircle(Offset(x, 74), 2.8, Paint()..color = const Color(0xFF3B8EE8)); }
        break;
      case Wx.rain:
        for (final x in [36.0, 52.0, 68.0]) { _drop(c, Offset(x, 70)); }
        break;
      case Wx.sleet:
        _drop(c, const Offset(38, 70)); _flake(c, const Offset(56, 76)); _drop(c, const Offset(72, 70));
        break;
      case Wx.snow:
        _flake(c, const Offset(34, 74)); _flake(c, const Offset(52, 82)); _flake(c, const Offset(70, 74));
        break;
      case Wx.lentil:
        for (final o in const [Offset(34, 72), Offset(48, 80), Offset(62, 72), Offset(74, 82), Offset(42, 89)]) { _bead(c, o); }
        break;
      case Wx.blizzard:
        _flake(c, const Offset(30, 76), r: 4.5); _flake(c, const Offset(46, 86), r: 4.5); _flake(c, const Offset(62, 76), r: 4.5);
        final w = Paint()..color = const Color(0xFF3D5A80)..strokeWidth = 3.2..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
        c.drawPath(Path()..moveTo(56, 88)..quadraticBezierTo(76, 84, 86, 90)..quadraticBezierTo(92, 94, 86, 98), w);
        c.drawPath(Path()..moveTo(66, 70)..quadraticBezierTo(82, 66, 90, 72), w);
        break;
      case Wx.thunder:
        c.drawPath(Path()..moveTo(56, 58)..lineTo(42, 80)..lineTo(52, 80)..lineTo(46, 96)..lineTo(66, 72)..lineTo(55, 72)..lineTo(62, 58)..close(),
            Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFFD84D), Color(0xFFFFA726)]).createShader(const Rect.fromLTWH(40, 58, 28, 40)));
        break;
      default:
    }
  }

  @override
  bool shouldRepaint(covariant _GlyphPainter o) => o.wx != wx || o.day != day;
}
