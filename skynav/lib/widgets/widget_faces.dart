import 'dart:math';
import 'package:flutter/material.dart';
import '../data/models.dart';

/// Ana ekran widget görüntüleri (Flutter ile çizilip PNG olarak yerel widget'a verilir).
class WeatherWidgetFace extends StatelessWidget {
  final PrecipKind kind; final double temp; final bool isDay; final double cloud; final String line1, line2;
  const WeatherWidgetFace({super.key, required this.kind, required this.temp, required this.isDay, required this.cloud, required this.line1, required this.line2});

  @override
  Widget build(BuildContext context) {
    final summer = temp >= 28;
    final grad = !isDay && cloud < 60 ? const [Color(0xFFCFDCF2), Color(0xFFF7FAFC)]
        : kind == PrecipKind.rain ? const [Color(0xFFCBD9E8), Color(0xFFF4F7FA)]
        : (kind == PrecipKind.snow || kind == PrecipKind.lentilSnow || kind == PrecipKind.blizzard || kind == PrecipKind.sleet) ? const [Color(0xFFDCEBFA), Colors.white]
        : summer ? [temp >= 38 ? const Color(0xFFFFC9B8) : temp >= 33 ? const Color(0xFFFFDDB0) : const Color(0xFFFFEFB8), const Color(0xFFFFFBF2)]
        : const [Color(0xFFBFE1FF), Color(0xFFF7FAFC)];
    return Container(
      width: 320, height: 160,
      decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: grad), borderRadius: BorderRadius.circular(28)),
      child: Stack(children: [
        Positioned.fill(child: CustomPaint(painter: _FacePainter(kind, temp, isDay, cloud))),
        Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${temp.round()}°', style: const TextStyle(fontSize: 46, fontWeight: FontWeight.w900, color: Color(0xFF1A2B3C), height: 1)),
          const SizedBox(height: 4),
          Text(line1, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1A2B3C))),
          Text(line2, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Color(0xFF50657A))),
        ])),
      ]),
    );
  }
}

class _FacePainter extends CustomPainter {
  final PrecipKind kind; final double temp, cloud; final bool isDay;
  _FacePainter(this.kind, this.temp, this.isDay, this.cloud);
  @override
  void paint(Canvas c, Size s) {
    final r = Random(3);
    if (kind == PrecipKind.snow || kind == PrecipKind.blizzard || kind == PrecipKind.sleet) {
      for (var i = 0; i < 28; i++) { c.drawCircle(Offset(r.nextDouble() * s.width, r.nextDouble() * s.height), 1.5 + r.nextDouble() * 2.5, Paint()..color = Colors.white.withValues(alpha: .95)); }
    } else if (kind == PrecipKind.lentilSnow) {
      for (var i = 0; i < 20; i++) { final o = Offset(r.nextDouble() * s.width, r.nextDouble() * s.height); c.drawCircle(o, 4, Paint()..color = Colors.white); c.drawCircle(o, 4, Paint()..color = const Color(0xFF9DB6CE)..style = PaintingStyle.stroke); }
    } else if (kind == PrecipKind.rain) {
      for (var i = 0; i < 22; i++) { final x = r.nextDouble() * s.width, y = r.nextDouble() * s.height; c.drawLine(Offset(x, y), Offset(x - 3, y + 12), Paint()..color = const Color(0xFF4A78B0).withValues(alpha: .6)..strokeWidth = 1.5); }
    } else if (!isDay && cloud < 60) {
      for (var i = 0; i < 26; i++) { c.drawCircle(Offset(r.nextDouble() * s.width, r.nextDouble() * s.height * .8), .8 + r.nextDouble() * 1.4, Paint()..color = const Color(0xFF3B5B8C).withValues(alpha: .6)); }
      c.drawCircle(Offset(s.width - 44, 38), 20, Paint()..color = const Color(0xFFF6E7B0));
      c.drawCircle(Offset(s.width - 36, 34), 18, Paint()..color = const Color(0xFFDDE7F5));
    } else if (temp >= 28) {
      final col = temp >= 38 ? const Color(0xFFE53935) : temp >= 33 ? const Color(0xFFFF9800) : const Color(0xFFFFD23F);
      c.drawCircle(Offset(s.width - 48, 46), 52, Paint()..shader = RadialGradient(colors: [col.withValues(alpha: .5), col.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: Offset(s.width - 48, 46), radius: 52)));
      c.drawCircle(Offset(s.width - 48, 46), 22, Paint()..color = col);
    }
  }
  @override
  bool shouldRepaint(covariant _FacePainter o) => true;
}

class SpeedWidgetFace extends StatelessWidget {
  final double speedKmh; final String road, gText, warn; final int level; // 0 iyi, 1 dikkat, 2 tehlike
  const SpeedWidgetFace({super.key, required this.speedKmh, required this.road, required this.gText, required this.warn, required this.level});
  @override
  Widget build(BuildContext context) {
    final col = [const Color(0xFF2E9E5B), const Color(0xFFF59E0B), const Color(0xFFE53935)][level.clamp(0, 2)];
    return Container(
      width: 240, height: 160,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), border: Border.all(color: col, width: 4)),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(speedKmh.round().toString(), style: const TextStyle(fontSize: 50, fontWeight: FontWeight.w900, color: Color(0xFF1A2B3C), height: 1)),
          const SizedBox(width: 6),
          const Padding(padding: EdgeInsets.only(bottom: 6), child: Text('km/s', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF50657A)))),
        ]),
        Text('🛣️ $road   $gText', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1A2B3C))),
        const SizedBox(height: 4),
        Expanded(child: Container(
          width: double.infinity, padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: col.withValues(alpha: .15), borderRadius: BorderRadius.circular(12)),
          child: Text(warn, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: col)),
        )),
      ]),
    );
  }
}
