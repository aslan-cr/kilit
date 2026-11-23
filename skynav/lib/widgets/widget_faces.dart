import 'package:flutter/material.dart';
import '../data/models.dart';
import '../ui/hero_scene.dart' show SceneStill, deg;
import '../ui/theme.dart';

/// Ana ekran widget görüntüleri (Flutter ile çizilip PNG olarak yerel widget'a verilir).
/// Hava widget'ı uygulamadaki üst sahnenin küçük, hareketsiz hâli: aynı dağlar, aynı gök, aynı yazı dili.
class WeatherWidgetFace extends StatelessWidget {
  final WeatherSnapshot s; final Analysis a; final String place, condition, line2;
  final DayPoint? today;
  const WeatherWidgetFace({super.key, required this.s, required this.a, required this.place, required this.condition, required this.line2, this.today});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: SizedBox(width: 320, height: 160, child: Stack(children: [
          Positioned.fill(child: SceneStill(s: s, a: a)),
          Positioned(left: 16, top: 12, right: 120, child: Row(children: [
            const Icon(Icons.location_on_rounded, size: 13, color: Colors.white),
            const SizedBox(width: 3),
            Flexible(child: Text(place, maxLines: 1, overflow: TextOverflow.ellipsis, style: _w(13, FontWeight.w600))),
          ])),
          Positioned(left: 12, top: 30, child: Text(deg(s.temp), style: const TextStyle(fontFamily: 'InterDisplay', fontSize: 58, fontWeight: FontWeight.w300, height: 1, letterSpacing: -2.9, color: Colors.white,
              shadows: [Shadow(color: Color(0x330D1F38), offset: Offset(0, 3), blurRadius: 14)]))),
          Positioned(left: 16, right: 16, bottom: 30, child: Text(condition, maxLines: 1, overflow: TextOverflow.ellipsis, style: _w(16, FontWeight.w700))),
          Positioned(left: 16, right: 16, bottom: 12, child: Text(
            [if (today != null) '↑ ${deg(today!.tMax)}  ↓ ${deg(today!.tMin)}', line2].join('  ·  '),
            maxLines: 1, overflow: TextOverflow.ellipsis, style: _w(11.5, FontWeight.w500, a: .88))),
        ])),
      );

  static TextStyle _w(double size, FontWeight w, {double a = 1}) => TextStyle(fontFamily: 'Inter', fontSize: size, fontWeight: w, color: Colors.white.withValues(alpha: a), height: 1.2);
}

/// Araç hızı & yol koşulu widget'ı: beyaz bento, durum rengi noktası, büyük hız, yol çipi, uyarı kutusu.
class SpeedWidgetFace extends StatelessWidget {
  final double speedKmh; final String road, gText, warn; final int level; // 0 iyi, 1 dikkat, 2 tehlike
  const SpeedWidgetFace({super.key, required this.speedKmh, required this.road, required this.gText, required this.warn, required this.level});
  @override
  Widget build(BuildContext context) {
    final col = [kGood, kWarn, kDanger][level.clamp(0, 2)];
    final label = ['YOL İYİ', 'DİKKAT', 'TEHLİKE'][level.clamp(0, 2)];
    return Container(
      width: 240, height: 160,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: col, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontFamily: 'Inter', fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 1, color: col)),
          const Spacer(),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: kIce, borderRadius: BorderRadius.circular(10)),
              child: Text('$road · $gText', style: const TextStyle(fontFamily: 'Inter', fontSize: 10.5, fontWeight: FontWeight.w700, color: kInkSoft))),
        ]),
        const SizedBox(height: 4),
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Text(speedKmh.round().toString(), style: const TextStyle(fontFamily: 'InterDisplay', fontSize: 52, fontWeight: FontWeight.w500, letterSpacing: -2, color: kInk, height: 1.05)),
          const SizedBox(width: 6),
          const Text('km/s', style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w600, color: kInkSoft)),
        ]),
        const Spacer(),
        Container(
          width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(color: col.withValues(alpha: .12), borderRadius: BorderRadius.circular(12)),
          child: Text(warn, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: 'Inter', fontSize: 11.5, fontWeight: FontWeight.w700, color: col, height: 1.25)),
        ),
      ]),
    );
  }
}
