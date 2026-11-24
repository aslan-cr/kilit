import 'dart:math';
import 'package:flutter/material.dart';
import '../astro/sky_times.dart';
import '../data/models.dart';
import '../engine/formulas.dart' show moonPhase;
import '../engine/nowcast.dart';
import '../services/ski_service.dart';
import '../ui/hero_scene.dart' show SceneStill, deg, moonLitPath;
import '../ui/sky_bodies.dart';
import '../ui/theme.dart';
import '../ui/wx_glyph.dart';

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

TextStyle _t(double size, FontWeight w, Color c, {double h = 1.2, double ls = 0}) =>
    TextStyle(fontFamily: 'Inter', fontSize: size, fontWeight: w, color: c, height: h, letterSpacing: ls, fontFeatures: const [FontFeature.tabularFigures()]);

String _hh(DateTime t) => t.hour.toString().padLeft(2, '0');
String _hm(DateTime t) { final l = t.toLocal(); return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}'; }

/// Saatlik widget (4×2): yer, şimdiki sıcaklık, önümüzdeki 8 saat (simge, sıcaklık, yağış çubuğu).
class HourlyWidgetFace extends StatelessWidget {
  final WeatherSnapshot s; final String place; final DateTime now;
  const HourlyWidgetFace({super.key, required this.s, required this.place, required this.now});
  @override
  Widget build(BuildContext context) {
    final hs = s.hourly.where((h) => h.time.isAfter(now.subtract(const Duration(minutes: 59)))).take(8).toList();
    final pMax = hs.isEmpty ? 1.0 : max(1.0, hs.map((h) => max(h.precip, h.snowfall * .7)).reduce(max));
    final n = Nowcast.of(s.nowcast, now);
    final today = s.daily.where((d) => d.date.year == now.year && d.date.month == now.month && d.date.day == now.day);
    final line = n.any ? n.headline : today.isEmpty ? '' : 'Bugün ↑ ${deg(today.first.tMax)}  ↓ ${deg(today.first.tMin)}';
    return Container(
      width: 320, height: 160, padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.location_on_rounded, size: 13, color: kAccent),
          const SizedBox(width: 3),
          Expanded(child: Text(place, maxLines: 1, overflow: TextOverflow.ellipsis, style: _t(12.5, FontWeight.w700, kInk))),
          Text(deg(s.temp), style: _t(18, FontWeight.w800, kInk)),
          const SizedBox(width: 4),
          WxGlyph(wxFromCode(s.weatherCode), day: s.isDay, size: 22),
        ]),
        if (line.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(line, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: _t(11.5, FontWeight.w600, n.any ? kSnow : kInkSoft))),
        const Spacer(),
        Row(children: [
          for (var i = 0; i < hs.length; i++) Expanded(child: Column(children: [
            Text(i == 0 ? 'Şimdi' : _hh(hs[i].time), style: _t(10, i == 0 ? FontWeight.w800 : FontWeight.w600, i == 0 ? kAccent : kInkSoft)),
            const SizedBox(height: 4),
            WxGlyph(wxFromCode(hs[i].weatherCode), size: 24),
            const SizedBox(height: 3),
            Text(deg(hs[i].temp), style: _t(13, FontWeight.w800, kInk)),
            const SizedBox(height: 5),
            Container(height: 14, alignment: Alignment.bottomCenter, child: Container(
              width: 10, height: max(2.0, max(hs[i].precip, hs[i].snowfall * .7) / pMax * 14),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(3),
                  color: max(hs[i].precip, hs[i].snowfall) < .05 ? kLine : hs[i].snowfall > .05 ? kSnow : const Color(0xFF3B8EE8)),
            )),
          ])),
        ]),
      ]),
    );
  }
}

/// Ay widget'ı (2×2): gerçek Ay görüntüsü, evre, doğuş/batış, sıradaki dolunay.
class MoonWidgetFace extends StatelessWidget {
  final double lat, lon; final DateTime now;
  const MoonWidgetFace({super.key, required this.lat, required this.lon, required this.now});
  @override
  Widget build(BuildContext context) {
    final m = moonPhase(now);
    final rs = moonRiseSet(lat, lon, DateTime(now.year, now.month, now.day));
    final full = nextMoonPhase(now, 180);
    const ink = Color(0xFFF4ECCF), soft = Color(0xFF9DA9CF);
    return Container(
      width: 160, height: 160, padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(color: const Color(0xFF16224A), borderRadius: BorderRadius.circular(28)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          SizedBox(width: 52, height: 52, child: CustomPaint(painter: _MoonDiscPainter(MoonView.at(lat, lon, now).withAlt(45), m.fraction, lat < 0))),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(m.name, maxLines: 2, style: _t(13, FontWeight.w800, ink, h: 1.15)),
            Text('%${(m.illumination * 100).round()}', style: _t(11.5, FontWeight.w600, soft)),
          ])),
        ]),
        const Spacer(),
        Row(children: [const Icon(Icons.north_east_rounded, size: 13, color: soft), const SizedBox(width: 4),
          Text('Doğuş', style: _t(11, FontWeight.w600, soft)), const Spacer(), Text(rs.rise == null ? '–' : _hm(rs.rise!), style: _t(12.5, FontWeight.w800, ink))]),
        const SizedBox(height: 3),
        Row(children: [const Icon(Icons.south_east_rounded, size: 13, color: soft), const SizedBox(width: 4),
          Text('Batış', style: _t(11, FontWeight.w600, soft)), const Spacer(), Text(rs.set == null ? '–' : _hm(rs.set!), style: _t(12.5, FontWeight.w800, ink))]),
        const SizedBox(height: 6),
        Text('Dolunay ${full.toLocal().day}.${full.toLocal().month.toString().padLeft(2, '0')}', style: _t(11, FontWeight.w700, soft)),
      ]),
    );
  }
}

class _MoonDiscPainter extends CustomPainter {
  final MoonView mv; final double f; final bool south;
  _MoonDiscPainter(this.mv, this.f, this.south);
  @override
  void paint(Canvas c, Size s) {
    final ctr = s.center(Offset.zero), r = s.width * .44;
    if (MoonRenderer.paint(c, ctr, r, mv, halo: false)) return;
    c.drawCircle(ctr, r, Paint()..color = const Color(0xFF2B3866));
    c.drawPath(moonLitPath(ctr, r, f, south: south), Paint()..color = const Color(0xFFF4ECCF));
  }
  @override
  bool shouldRepaint(covariant _MoonDiscPainter o) => o.f != f;
}

/// Mini widget (2×2): küçük sahne, sıcaklık, en yüksek/düşük ve kısa yağış notu.
class MiniWidgetFace extends StatelessWidget {
  final WeatherSnapshot s; final Analysis a; final String place; final DayPoint? today; final DateTime now;
  const MiniWidgetFace({super.key, required this.s, required this.a, required this.place, this.today, required this.now});
  @override
  Widget build(BuildContext context) {
    final n = Nowcast.of(s.nowcast, now);
    final note = n.any ? _short(n) : (today == null ? '' : '↑ ${deg(today!.tMax)}  ↓ ${deg(today!.tMin)}');
    TextStyle w(double size, FontWeight fw, {double al = 1}) => TextStyle(fontFamily: 'Inter', fontSize: size, fontWeight: fw, color: Colors.white.withValues(alpha: al), height: 1.15,
        shadows: const [Shadow(color: Color(0x330D1F38), blurRadius: 8)]);
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: SizedBox(width: 160, height: 160, child: Stack(children: [
        Positioned.fill(child: SceneStill(s: s, a: a)),
        Positioned(left: 12, top: 10, right: 12, child: Text(place, maxLines: 1, overflow: TextOverflow.ellipsis, style: w(12, FontWeight.w700))),
        Positioned(left: 10, top: 26, child: Text(deg(s.temp), style: const TextStyle(fontFamily: 'InterDisplay', fontSize: 48, fontWeight: FontWeight.w300, height: 1, letterSpacing: -2, color: Colors.white,
            shadows: [Shadow(color: Color(0x330D1F38), offset: Offset(0, 3), blurRadius: 12)]))),
        Positioned(left: 12, right: 12, bottom: 10, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(wxLabel(wxFromCode(s.weatherCode), day: s.isDay), maxLines: 1, overflow: TextOverflow.ellipsis, style: w(12.5, FontWeight.w800)),
          if (note.isNotEmpty) Text(note, maxLines: 1, overflow: TextOverflow.ellipsis, style: w(11, FontWeight.w600, al: .9)),
        ])),
      ])),
    );
  }

  static String _short(Nowcast n) {
    final noun = n.snow ? 'Kar' : 'Yağmur';
    if (n.startsIn != null) return n.startsIn! <= 5 ? '$noun başlıyor' : '$noun ${n.startsIn} dk sonra';
    if (n.endsIn != null) return '$noun ${n.endsIn} dk sonra diner';
    return '$noun sürüyor';
  }
}

/// Kayak widget'ı (2×2): en yakın merkez, kar kalınlığı, son 24 saat ve 3 günlük kar.
class SkiWidgetFace extends StatelessWidget {
  final SkiNow s; final double km;
  const SkiWidgetFace({super.key, required this.s, required this.km});
  @override
  Widget build(BuildContext context) => Container(
        width: 160, height: 160, padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFE4EEFB), Colors.white])),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.downhill_skiing_rounded, size: 15, color: kSnow),
            const SizedBox(width: 4),
            Expanded(child: Text(s.r.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: _t(12.5, FontWeight.w800, kInk))),
          ]),
          Text('${km.round()} km · ${s.temp.isFinite ? deg(s.temp) : '–'}', style: _t(10.5, FontWeight.w600, kInkSoft)),
          const Spacer(),
          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            Text('${s.snowCm.round()}', style: _t(40, FontWeight.w700, kSnow, h: 1, ls: -1.5)),
            const SizedBox(width: 3),
            Text('cm kar', style: _t(11.5, FontWeight.w700, kInkSoft)),
          ]),
          const SizedBox(height: 6),
          Text('24 sa +${s.new24.round()} · 3 gün +${s.next72.round()} cm', maxLines: 1, overflow: TextOverflow.ellipsis,
              style: _t(10.5, FontWeight.w700, s.next72 >= 5 ? kGood : kInkSoft)),
          if (s.windy) Text('Sert rüzgâr', style: _t(10.5, FontWeight.w700, kWarn)),
        ]),
      );
}

/// Hava kalitesi widget'ı (2×2): toz-duman durumu (PM10 ve PM2.5, DSÖ 2021 günlük sınırlarına göre).
class AirWidgetFace extends StatelessWidget {
  final WeatherSnapshot s; final String place;
  const AirWidgetFace({super.key, required this.s, required this.place});
  static (String, Color) level(double pm10, double pm25) {
    final r = max(pm10 / 45, pm25 / 15); // sınıra oran
    return r < .5 ? ('Temiz', kGood) : r < 1 ? ('Makul', const Color(0xFF50AF5A)) : r < 2 ? ('Kirli', kWarn) : ('Çok kirli', kDanger);
  }
  @override
  Widget build(BuildContext context) {
    final (label, col) = level(s.aqPm10, s.aqPm25);
    return Container(
      width: 160, height: 160, padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: col, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Expanded(child: Text('HAVA KALİTESİ', maxLines: 1, style: _t(9.5, FontWeight.w800, kInkFaint, ls: .8))),
        ]),
        Text(place, maxLines: 1, overflow: TextOverflow.ellipsis, style: _t(11, FontWeight.w600, kInkSoft)),
        const Spacer(),
        Text(label, style: _t(26, FontWeight.w800, col, h: 1.05, ls: -.5)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('İnce toz', style: _t(9.5, FontWeight.w600, kInkFaint)),
            Text('${s.aqPm25.round()}', style: _t(15, FontWeight.w800, kInk)),
          ])),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Kaba toz', style: _t(9.5, FontWeight.w600, kInkFaint)),
            Text('${s.aqPm10.round()}', style: _t(15, FontWeight.w800, kInk)),
          ])),
        ]),
      ]),
    );
  }
}

