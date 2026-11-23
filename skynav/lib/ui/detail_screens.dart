import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../astro/sky_times.dart';
import '../astro/tonight.dart';
import '../data/models.dart';
import '../engine/formulas.dart' show moonPhase, windDirName;
import '../services/audio_service.dart';
import 'bento.dart';
import 'hero_scene.dart';
import 'plain.dart';
import 'sky_bodies.dart';
import 'theme.dart';
import 'wx_glyph.dart';

const _dayNames = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];
const _dayShort = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
const _months = ['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];

String _hm(DateTime t) { final l = t.toLocal(); return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}'; }
String _date(DateTime t) { final l = t.toLocal(); return '${l.day} ${_months[l.month - 1]} ${_dayShort[l.weekday - 1]}'; }
String _dateShort(DateTime t) { final l = t.toLocal(); return '${l.day} ${_months[l.month - 1].substring(0, 3)} ${_dayShort[l.weekday - 1]}'; }
String _dur(Duration d) => '${d.inHours} sa ${d.inMinutes % 60} dk';

TextStyle _st(double size, FontWeight w, Color c, {double ls = 0, double? h}) =>
    TextStyle(fontFamily: 'Inter', fontSize: size, fontWeight: w, color: c, letterSpacing: ls, height: h, fontFeatures: const [FontFeature.tabularFigures()]);

const _nightInk = Color(0xFFF4ECCF), _nightSoft = Color(0xFF9DA9CF);

// ═══════════════════════════════════════════════════════════════════════════
// Gün detayı
// ═══════════════════════════════════════════════════════════════════════════

/// 7 günlükte bir güne dokununca: saatlik eğri, yağış, rüzgâr, UV, gün ışığı, fotoğrafçı saatleri, Ay.
class DayDetailScreen extends StatelessWidget {
  final WeatherSnapshot s; final DayPoint day; final int index;
  const DayDetailScreen({super.key, required this.s, required this.day, required this.index});

  static void open(BuildContext context, WeatherSnapshot s, DayPoint day, int index) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => DayDetailScreen(s: s, day: day, index: index)));

  @override
  Widget build(BuildContext context) {
    final d0 = DateTime(day.date.year, day.date.month, day.date.day);
    final hours = s.hourly.where((h) => !h.time.isBefore(d0) && h.time.isBefore(d0.add(const Duration(days: 1)))).toList();
    final title = index == 0 ? 'Bugün' : index == 1 ? 'Yarın' : _dayNames[d0.weekday - 1];
    const gap = SizedBox(height: 14);
    return Scaffold(
      backgroundColor: kIce,
      appBar: AppBar(title: Text(title)),
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 40), children: [
        _DayHeader(day: day, hours: hours),
        if (hours.length > 2) ...[gap, HourlyBlock(hours: hours, fromNow: false, onHour: (h) => showHourSheet(context, h))],
        gap,
        BentoRow(height: 168, left: _PrecipDay(day: day, hours: hours), right: _WindDay(day: day, hours: hours)),
        gap,
        BentoRow(height: 168, left: _UvDay(hours: hours), right: _SunDay(day: day)),
        gap,
        PhotoHoursBlock(lat: s.place.lat, lon: s.place.lon, day: d0),
        gap,
        MoonTimesBlock(lat: s.place.lat, lon: s.place.lon, day: d0),
      ]),
    );
  }
}

class _DayHeader extends StatelessWidget {
  final DayPoint day; final List<HourPoint> hours;
  const _DayHeader({required this.day, required this.hours});
  @override
  Widget build(BuildContext context) {
    final wx = wxFromCode(day.weatherCode);
    final cloud = hours.isEmpty ? null : hours.map((h) => h.cloud).reduce((a, b) => a + b) / hours.length;
    return Bento(
      padding: const EdgeInsets.all(18),
      child: Row(children: [
        WxGlyph(wx, size: 78),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_date(day.date), style: _st(13, FontWeight.w600, kInkSoft)),
          const SizedBox(height: 2),
          Text(wxLabel(wx), maxLines: 1, overflow: TextOverflow.ellipsis, style: _st(20, FontWeight.w800, kInk, ls: -.3)),
          const SizedBox(height: 6),
          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            Text(deg(day.tMax), style: _st(30, FontWeight.w700, kInk, ls: -.8)),
            const SizedBox(width: 8),
            Text(deg(day.tMin), style: _st(20, FontWeight.w600, kInkFaint)),
            const Spacer(),
            if (cloud != null) Text('bulut %${cloud.round()}', style: _st(12, FontWeight.w600, kInkSoft)),
          ]),
        ])),
      ]),
    );
  }
}

class _PrecipDay extends StatelessWidget {
  final DayPoint day; final List<HourPoint> hours;
  const _PrecipDay({required this.day, required this.hours});
  @override
  Widget build(BuildContext context) {
    final snow = day.snowSum >= .5;
    final peak = hours.isEmpty ? null : hours.reduce((a, b) => max(a.precip, a.snowfall * .7) >= max(b.precip, b.snowfall * .7) ? a : b);
    final has = peak != null && max(peak.precip, peak.snowfall * .7) >= .1;
    return Bento(
      color: kBentoBlue,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        BlockHead('Yağış', dot: kSnow),
        const Spacer(),
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Text(snow ? day.snowSum.toStringAsFixed(day.snowSum < 10 ? 1 : 0) : day.precipSum.toStringAsFixed(1), style: _st(28, FontWeight.w700, kInk, ls: -.6)),
          const SizedBox(width: 4),
          Text(snow ? 'cm kar' : 'mm', style: _st(13, FontWeight.w700, kInkSoft)),
        ]),
        const SizedBox(height: 8),
        SizedBox(height: 30, width: double.infinity, child: CustomPaint(painter: _MiniBars([for (final h in hours) max(h.precip, h.snowfall * .7)], kSnow))),
        const SizedBox(height: 6),
        Text(has ? 'En yoğun ${peak.time.hour.toString().padLeft(2, '0')}:00' : 'Yağış beklenmiyor', style: _st(12, FontWeight.w600, kInkSoft)),
      ]),
    );
  }
}

class _WindDay extends StatelessWidget {
  final DayPoint day; final List<HourPoint> hours;
  const _WindDay({required this.day, required this.hours});
  @override
  Widget build(BuildContext context) {
    // Baskın yön: hızla ağırlıklı vektör ortalaması
    var vx = 0.0, vy = 0.0;
    for (final h in hours) { vx += h.windSpeed * sin(h.windDir * pi / 180); vy += h.windSpeed * cos(h.windDir * pi / 180); }
    final dir = (atan2(vx, vy) * 180 / pi + 360) % 360;
    final gusts = hours.map((h) => h.gust).where((g) => g.isFinite);
    final gust = gusts.isEmpty ? null : gusts.reduce(max);
    return Bento(
      color: kBentoMint,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        BlockHead('Rüzgâr', dot: kGood, trailing: gust == null ? null : Text(Plain.on ? 'ani esinti ${(gust * 3.6).round()}' : 'hamle ${gust.round()}', style: _st(12, FontWeight.w600, gust > 17 ? kDanger : kInkSoft))),
        const Spacer(),
        Row(children: [
          SizedBox(width: 52, height: 52, child: CustomPaint(painter: WindRosePainter(dir, day.windMax, compact: true))),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
              Text(Plain.on ? '${(day.windMax * 3.6).round()}' : day.windMax.toStringAsFixed(day.windMax < 10 ? 1 : 0), style: _st(28, FontWeight.w700, kInk, ls: -.6)),
              const SizedBox(width: 4),
              Text(Plain.t('m/s', 'km/s'), style: _st(13, FontWeight.w700, kInkSoft)),
            ])),
            Text(Plain.t('${(day.windMax * 3.6).round()} km/s', 'en sert rüzgâr'), style: _st(12, FontWeight.w600, kInkSoft)),
          ])),
        ]),
        const Spacer(),
        Text(hours.isEmpty ? '' : Plain.on ? Plain.windFrom(dir, '') : '${windDirName(dir)} yönünden', style: _st(12, FontWeight.w600, kInkSoft)),
      ]),
    );
  }
}

class _UvDay extends StatelessWidget {
  final List<HourPoint> hours;
  const _UvDay({required this.hours});
  static (String, Color) level(double uv) => uv < 3 ? ('Düşük', kGood) : uv < 6 ? ('Orta', const Color(0xFFE5B814)) : uv < 8 ? ('Yüksek', kWarn) : uv < 11 ? ('Çok yüksek', kHeat) : ('Aşırı', kPro);
  @override
  Widget build(BuildContext context) {
    final withUv = hours.where((h) => h.uv.isFinite).toList();
    final peak = withUv.isEmpty ? null : withUv.reduce((a, b) => a.uv >= b.uv ? a : b);
    final uv = peak?.uv ?? 0;
    final (name, col) = level(uv);
    return Bento(
      color: kBentoPeach,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        BlockHead(Plain.t('UV en yüksek', 'Güneş yakıcılığı'), dot: kSun),
        const Spacer(),
        Text(peak == null ? '–' : uv.toStringAsFixed(1), style: _st(28, FontWeight.w700, kInk, ls: -.6)),
        const SizedBox(height: 6),
        LayoutBuilder(builder: (_, c) => SizedBox(height: 8, child: Stack(children: [
          Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(4),
              gradient: const LinearGradient(colors: [kGood, Color(0xFFE5B814), kWarn, kHeat, kPro]))),
          Positioned(left: (uv / 12).clamp(0.0, 1.0) * (c.maxWidth - 12), top: -2, child: Container(width: 12, height: 12,
              decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: kInk, width: 2.5)))),
        ]))),
        const SizedBox(height: 10),
        Text(peak == null ? 'Veri yok' : uv < 1 ? 'Güneş zayıf' : '$name · ${peak.time.hour.toString().padLeft(2, '0')}:00 civarı',
            style: _st(12, FontWeight.w600, peak == null ? kInkSoft : col)),
      ]),
    );
  }
}

class _SunDay extends StatelessWidget {
  final DayPoint day;
  const _SunDay({required this.day});
  @override
  Widget build(BuildContext context) {
    final r = day.sunrise, st = day.sunset;
    Widget row(IconData ic, String l, String v) => Row(children: [
          Icon(ic, size: 18, color: kSun), const SizedBox(width: 8),
          Expanded(child: Text(l, style: _st(12.5, FontWeight.w600, kInkSoft))),
          Text(v, style: _st(15, FontWeight.w700, kInk)),
        ]);
    return Bento(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        BlockHead('Gün ışığı', dot: kSun),
        const Spacer(),
        row(Icons.wb_twilight_rounded, 'Doğuş', r == null ? '–' : _hm(r)),
        const SizedBox(height: 10),
        row(Icons.nights_stay_outlined, 'Batış', st == null ? '–' : _hm(st)),
        const Spacer(),
        Text(r == null || st == null ? '' : '${_dur(st.difference(r))} gün', style: _st(12, FontWeight.w600, kInkSoft)),
      ]),
    );
  }
}

class _MiniBars extends CustomPainter {
  final List<double> v; final Color col;
  _MiniBars(this.v, this.col);
  @override
  void paint(Canvas c, Size s) {
    if (v.isEmpty) return;
    final mx = max(.8, v.reduce(max));
    final w = s.width / v.length;
    for (var i = 0; i < v.length; i++) {
      final h = v[i] < .05 ? 2.0 : max(3.0, v[i] / mx * s.height);
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(i * w + w * .18, s.height - h, w * .64, h), const Radius.circular(2)),
          Paint()..color = v[i] < .05 ? col.withValues(alpha: .18) : col.withValues(alpha: .85));
    }
  }
  @override
  bool shouldRepaint(covariant _MiniBars o) => o.v != v;
}

/// Saatlik detay: grafikte bir saate dokununca alt sayfada o saatin bütün değerleri.
void showHourSheet(BuildContext context, HourPoint h) {
  HapticFeedback.selectionClick();
  final wx = wxFromCode(h.weatherCode);
  Widget tile(IconData ic, Color c, String label, String value, {String? sub}) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: c.withValues(alpha: .08), borderRadius: BorderRadius.circular(18)),
        child: Row(children: [
          Icon(ic, size: 20, color: c), const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: _st(11.5, FontWeight.w600, kInkSoft)),
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: _st(16, FontWeight.w800, kInk)),
            if (sub != null) Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: _st(11, FontWeight.w600, kInkFaint)),
          ])),
        ]),
      );
  final snow = h.snowfall >= .05;
  showModalBottomSheet(context: context, showDragHandle: true, builder: (_) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        WxGlyph(wx, size: 56),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${_dayNames[h.time.weekday - 1]} ${h.time.hour.toString().padLeft(2, '0')}:00', style: _st(13, FontWeight.w600, kInkSoft)),
          Text(wxLabel(wx), style: _st(19, FontWeight.w800, kInk)),
        ])),
        Text(deg(h.temp), style: _st(38, FontWeight.w700, kInk, ls: -1)),
      ]),
      const SizedBox(height: 16),
      GridView.count(
        crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 2.1,
        children: [
          tile(snow ? Icons.ac_unit_rounded : Icons.water_drop_outlined, kSnow, snow ? 'Kar' : 'Yağış',
              snow ? '${h.snowfall.toStringAsFixed(1)} cm' : '${h.precip.toStringAsFixed(1)} mm'),
          tile(Icons.air_rounded, kGood, 'Rüzgâr', Plain.wind(h.windSpeed),
              sub: '${Plain.windFrom(h.windDir, windDirName(h.windDir), noun: true)}${h.gust.isFinite ? ' · ${Plain.t('hamle', 'ani esinti')} ${Plain.wind(h.gust, digits: 0)}' : ''}'),
          tile(Icons.cloud_outlined, kInkSoft, 'Bulut', '%${h.cloud.round()}'),
          tile(Icons.opacity_rounded, const Color(0xFF3B8EE8), 'Nem', '%${h.humidity.round()}', sub: '${Plain.t('çiy noktası', 'buğu')} ${deg(h.dewPoint)}'),
          if (h.uv.isFinite) tile(Icons.wb_sunny_outlined, kSun, Plain.t('UV indeksi', 'Güneş yakıcılığı'), h.uv.toStringAsFixed(1)),
          if (h.pressure.isFinite) tile(Icons.speed_rounded, kInkSoft, Plain.t('Basınç', 'Hava basıncı'), '${h.pressure.round()}${Plain.on ? '' : ' hPa'}'),
        ],
      ),
    ]),
  ));
}

// ═══════════════════════════════════════════════════════════════════════════
// Fotoğrafçı saatleri
// ═══════════════════════════════════════════════════════════════════════════

/// Altın saat (Güneş −4°…+6°) ve mavi saat (−6°…−4°), sabah ve akşam; gerçek Güneş yüksekliğinden.
class PhotoHoursBlock extends StatelessWidget {
  final double lat, lon; final DateTime day;
  const PhotoHoursBlock({super.key, required this.lat, required this.lon, required this.day});

  @override
  Widget build(BuildContext context) {
    final p = PhotoHours.of(lat, lon, day);
    final now = DateTime.now();
    Widget chip(String label, Span? sp, List<Color> g, IconData ic) {
      final active = sp != null && now.isAfter(sp.start) && now.isBefore(sp.end);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), gradient: LinearGradient(colors: g),
            boxShadow: [if (active) BoxShadow(color: g.last.withValues(alpha: .45), blurRadius: 14, offset: const Offset(0, 4))]),
        child: Row(children: [
          Icon(ic, size: 18, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(child: Text(active ? '$label · şimdi' : label, maxLines: 1, overflow: TextOverflow.ellipsis, style: _st(12.5, FontWeight.w700, Colors.white))),
          Text(sp == null ? '–' : '${_hm(sp.start)}–${_hm(sp.end)}', style: _st(13, FontWeight.w700, Colors.white)),
        ]),
      );
    }
    const blue = [Color(0xFF2F4C8F), Color(0xFF5D7FCB)], gold = [Color(0xFFF0954F), Color(0xFFF7BD5C)];
    return Bento(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const BlockHead('Fotoğrafçı saatleri', dot: kSun),
        const SizedBox(height: 4),
        Text('Yumuşak, sıcak ışık altın saatte; derin mavi gök mavi saatte.', style: _st(12, FontWeight.w500, kInkSoft)),
        const SizedBox(height: 12),
        Text('SABAH', style: T.label.copyWith(fontSize: 10.5)),
        const SizedBox(height: 6),
        chip('Mavi saat', p.morningBlue, blue, Icons.dark_mode_outlined),
        const SizedBox(height: 6),
        chip('Altın saat', p.morningGolden, gold, Icons.wb_sunny_outlined),
        const SizedBox(height: 12),
        Text('AKŞAM', style: T.label.copyWith(fontSize: 10.5)),
        const SizedBox(height: 6),
        chip('Altın saat', p.eveningGolden, gold, Icons.wb_sunny_outlined),
        const SizedBox(height: 6),
        chip('Mavi saat', p.eveningBlue, blue, Icons.dark_mode_outlined),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Ay: doğuş/batış ve evreler
// ═══════════════════════════════════════════════════════════════════════════

class MoonTimesBlock extends StatelessWidget {
  final double lat, lon; final DateTime day;
  const MoonTimesBlock({super.key, required this.lat, required this.lon, required this.day});
  @override
  Widget build(BuildContext context) {
    final rs = moonRiseSet(lat, lon, day);
    final noon = day.add(const Duration(hours: 12));
    final m = moonPhase(noon);
    final full = nextMoonPhase(day, 180), fresh = nextMoonPhase(day, 0);
    Widget row(IconData ic, String l, String v) => Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(children: [
          Icon(ic, size: 18, color: _nightSoft), const SizedBox(width: 10),
          Expanded(child: Text(l, style: _st(13, FontWeight.w600, _nightSoft))),
          Text(v, style: _st(14, FontWeight.w700, _nightInk)),
        ]));
    return Bento(
      color: kBentoNight, padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const BlockHead('Ay', dot: _nightInk, labelColor: _nightSoft),
        const SizedBox(height: 10),
        Row(children: [
          SizedBox(width: 72, height: 72, child: CustomPaint(painter: _MoonDisc(MoonView.at(lat, lon, noon), m.fraction, lat < 0))),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(m.name, style: _st(17, FontWeight.w800, _nightInk)),
            const SizedBox(height: 3),
            Text('%${(m.illumination * 100).round()} aydınlık', style: _st(13, FontWeight.w600, _nightSoft)),
          ])),
        ]),
        const SizedBox(height: 10),
        row(Icons.north_east_rounded, 'Doğuş', rs.rise == null ? 'bugün doğmuyor' : _hm(rs.rise!)),
        row(Icons.south_east_rounded, 'Batış', rs.set == null ? 'bugün batmıyor' : _hm(rs.set!)),
        const Divider(color: Color(0x33FFFFFF), height: 18),
        row(Icons.brightness_1_rounded, 'Dolunay', '${_date(full)} ${_hm(full)}'),
        row(Icons.brightness_1_outlined, 'Yeni ay', '${_date(fresh)} ${_hm(fresh)}'),
      ]),
    );
  }
}

class _MoonDisc extends CustomPainter {
  final MoonView mv; final double f; final bool south;
  _MoonDisc(this.mv, this.f, this.south);
  @override
  void paint(Canvas c, Size s) {
    final ctr = s.center(Offset.zero), r = s.width * .42;
    if (MoonRenderer.paint(c, ctr, r, mv.withAlt(45), halo: false)) return;
    c.drawCircle(ctr, r, Paint()..color = const Color(0xFF2B3866));
    c.drawPath(moonLitPath(ctr, r, f, south: south), Paint()..color = _nightInk);
  }
  @override
  bool shouldRepaint(covariant _MoonDisc o) => o.f != f;
}

/// Bu gece çıplak gözle görülecek gezegenler: ne zaman, nerede, ne kadar parlak (gerçek konumlardan).
class TonightSkyBlock extends StatelessWidget {
  final double lat, lon, cloud; final DateTime now;
  const TonightSkyBlock({super.key, required this.lat, required this.lon, required this.now, this.cloud = 0});

  static const _colors = {'mercury': Color(0xFFD9CBB4), 'venus': Color(0xFFFFF3D6), 'mars': Color(0xFFFF9C74), 'jupiter': Color(0xFFF3D9AE), 'saturn': Color(0xFFE9CF8C)};

  @override
  Widget build(BuildContext context) {
    final ps = planetsTonight(lat, lon, now);
    return Bento(
      color: kBentoNight, padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        BlockHead('Bu gece gökte', dot: _nightInk, labelColor: _nightSoft,
            trailing: Text(cloud > 75 ? 'bulutlar örtüyor' : cloud > 40 ? 'bulut aralarından' : 'açık gök', style: _st(12, FontWeight.w600, _nightSoft))),
        const SizedBox(height: 10),
        if (ps.isEmpty)
          Text('Bu gece çıplak gözle görülen gezegen yok kanki; yıldızlara bak.', style: _st(13.5, FontWeight.w600, _nightSoft))
        else
          for (final p in ps) Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: Row(children: [
            Container(width: 14, height: 14, decoration: BoxDecoration(shape: BoxShape.circle, color: _colors[p.key],
                boxShadow: [BoxShadow(color: (_colors[p.key] ?? _nightInk).withValues(alpha: .6), blurRadius: p.mag < -1 ? 10 : 5)])),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${p.name} · ${p.brightness}', style: _st(15, FontWeight.w800, _nightInk)),
              const SizedBox(height: 2),
              Text('En iyi ${_hm(p.best)} · ${TonightPlanet.where(p.bestAz)} · ${p.bestAlt.round()}° yukarıda',
                  style: _st(12.5, FontWeight.w600, _nightSoft)),
            ])),
            Text('${_hm(p.start)}–${_hm(p.end)}', style: _st(13, FontWeight.w700, _nightInk)),
          ])),
        const SizedBox(height: 6),
        Text('Saatler: gök kararıp gezegen ufkun 10° üstüne çıktığı aralık.', style: _st(11.5, FontWeight.w500, _nightSoft.withValues(alpha: .8))),
      ]),
    );
  }
}

/// Ana ekrandaki Ay bloğuna dokununca: bugünün doğuş/batışı, önümüzdeki ana evreler ve 7 günlük Ay saatleri.
class MoonDetailScreen extends StatelessWidget {
  final double lat, lon;
  const MoonDetailScreen({super.key, required this.lat, required this.lon});
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final d0 = DateTime(now.year, now.month, now.day);
    final phases = [
      ('Yeni ay', nextMoonPhase(now, 0), Icons.brightness_1_outlined),
      ('İlk dördün', nextMoonPhase(now, 90), Icons.brightness_2_outlined),
      ('Dolunay', nextMoonPhase(now, 180), Icons.brightness_1_rounded),
      ('Son dördün', nextMoonPhase(now, 270), Icons.brightness_3_outlined),
    ]..sort((a, b) => a.$2.compareTo(b.$2));
    return Scaffold(
      backgroundColor: kIce,
      appBar: AppBar(title: const Text('Ay')),
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 40), children: [
        MoonTimesBlock(lat: lat, lon: lon, day: d0),
        const SizedBox(height: 14),
        Bento(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const BlockHead('Sıradaki evreler', dot: Color(0xFFB7C2F2)),
          const SizedBox(height: 8),
          for (final (n, t, ic) in phases) Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: Row(children: [
            Icon(ic, size: 20, color: kBlizzard), const SizedBox(width: 12),
            Expanded(child: Text(n, style: _st(14.5, FontWeight.w700, kInk))),
            Text('${_date(t)} · ${_hm(t)}', style: _st(13.5, FontWeight.w600, kInkSoft)),
          ])),
        ])),
        const SizedBox(height: 14),
        Bento(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const BlockHead('7 gün Ay saatleri', dot: Color(0xFFB7C2F2)),
          const SizedBox(height: 8),
          for (var i = 0; i < 7; i++) Builder(builder: (_) {
            final d = d0.add(Duration(days: i));
            final rs = moonRiseSet(lat, lon, d);
            return Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [
              SizedBox(width: 104, child: Text(i == 0 ? 'Bugün' : _dateShort(d), maxLines: 1, style: _st(13.5, i == 0 ? FontWeight.w800 : FontWeight.w600, kInk))),
              const Icon(Icons.north_east_rounded, size: 15, color: kInkFaint), const SizedBox(width: 4),
              Expanded(child: Text(rs.rise == null ? '–' : _hm(rs.rise!), style: _st(13.5, FontWeight.w700, kInk))),
              const Icon(Icons.south_east_rounded, size: 15, color: kInkFaint), const SizedBox(width: 4),
              Text(rs.set == null ? '–' : _hm(rs.set!), style: _st(13.5, FontWeight.w700, kInk)),
            ]));
          }),
        ])),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Basınç ve rüzgâr: 72 saatlik grafikler
// ═══════════════════════════════════════════════════════════════════════════

/// Basınç ya da rüzgâr bloğuna dokununca: son 48 saat (gerçek geçmiş veri) + önümüzdeki 24 saat.
class TrendScreen extends StatelessWidget {
  final WeatherSnapshot s; final bool windFirst;
  const TrendScreen({super.key, required this.s, this.windFirst = false});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final t0 = now.subtract(const Duration(hours: 48)), t1 = now.add(const Duration(hours: 24));
    final hs = s.hourly.where((h) => !h.time.isBefore(t0) && !h.time.isAfter(t1)).toList();
    final pr = [for (final h in hs) if (h.pressure.isFinite) (h.time, h.pressure)];
    final ws = [for (final h in hs) (h.time, h.windSpeed)];
    final gs = [for (final h in hs) if (h.gust.isFinite) (h.time, h.gust)];
    final past = s.hourly.where((h) => !h.time.isAfter(now) && h.pressure.isFinite).toList();
    final d3 = past.length >= 4 ? past.last.pressure - past[past.length - 4].pressure : null;
    final pressure = Bento(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      BlockHead(Plain.t('Basınç · hPa', 'Hava basıncı'), dot: kInkSoft, trailing: Text(d3 == null ? '' : '3 sa ${d3 >= 0 ? '+' : '−'}${d3.abs().toStringAsFixed(1)}',
          style: _st(12, FontWeight.w700, (d3 ?? 0) <= -3 ? kWarn : kInkSoft))),
      const SizedBox(height: 4),
      Text('${s.pressure.round()} hPa', style: _st(26, FontWeight.w700, kInk, ls: -.5)),
      const SizedBox(height: 10),
      SeriesChart(series: pr, color: kAccent, t0: t0, t1: t1, now: now, unit: Plain.t('hPa', 'basınç'), decimals: 0),
      const SizedBox(height: 10),
      Text(d3 != null && d3 <= -3 ? 'Basınç hızla düşüyor: rüzgâr ve yağış artabilir kanki.'
          : d3 != null && d3 >= 3 ? 'Basınç hızla yükseliyor: hava açmaya dönüyor.'
          : Plain.t('Basınç dengeli. 3 saatte 3 hPa\'dan fazla düşüş bozulma habercisidir.', 'Hava basıncı dengeli. Çizgi hızla aşağı inerse hava bozuyor demektir.'),
          style: _st(12.5, FontWeight.w500, kInkSoft)),
    ]));
    final wind = Bento(color: kBentoMint, padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      BlockHead(Plain.t('Rüzgâr · m/s', 'Rüzgâr · km/s'), dot: kGood, trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 14, height: 3, color: kGood), const SizedBox(width: 4), Text('hız', style: _st(11, FontWeight.w600, kInkSoft)),
        const SizedBox(width: 10),
        Container(width: 14, height: 3, color: kGood.withValues(alpha: .35)), const SizedBox(width: 4), Text(Plain.t('hamle', 'ani esinti'), style: _st(11, FontWeight.w600, kInkSoft)),
      ])),
      const SizedBox(height: 8),
      Row(children: [
        SizedBox(width: 96, height: 96, child: CustomPaint(painter: WindRosePainter(s.windDir, s.windSpeed))),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(Plain.wind(s.windSpeed), style: _st(26, FontWeight.w700, kInk, ls: -.5)),
          Text(Plain.on ? Plain.windFrom(s.windDir, '') : '${windDirName(s.windDir)} yönünden · ${(s.windSpeed * 3.6).round()} km/s', style: _st(12.5, FontWeight.w600, kInkSoft)),
          const SizedBox(height: 8),
          Pill(Plain.on ? 'Ani esinti ${(s.windGust * 3.6).round()} km/s' : 'Hamle ${s.windGust.round()} m/s · ${(s.windGust * 3.6).round()} km/s', color: s.windGust > 17 ? kDanger : kAccent, icon: Icons.air),
        ])),
      ]),
      const SizedBox(height: 12),
      SeriesChart(series: Plain.on ? [for (final e in ws) (e.$1, e.$2 * 3.6)] : ws, second: Plain.on ? [for (final e in gs) (e.$1, e.$2 * 3.6)] : gs,
          color: kGood, t0: t0, t1: t1, now: now, unit: Plain.t('m/s', 'km/s'), decimals: Plain.on ? 0 : 1, zeroBase: true),
    ]));
    return Scaffold(
      backgroundColor: kIce,
      appBar: AppBar(title: const Text('Basınç ve rüzgâr')),
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 40), children: [
        Text('Son 48 saat gerçek ölçüm, sonrası 24 saat tahmin. Grafikte parmağını gezdir.', style: _st(12.5, FontWeight.w500, kInkSoft)),
        const SizedBox(height: 12),
        if (windFirst) ...[wind, const SizedBox(height: 14), pressure] else ...[pressure, const SizedBox(height: 14), wind],
      ]),
    );
  }
}

/// Zaman serisi grafiği: geçmiş düz, tahmin kesikli çizgi; "şimdi" çizgisi, gün ayraçları, parmakla okuma.
class SeriesChart extends StatefulWidget {
  final List<(DateTime, double)> series; final List<(DateTime, double)> second;
  final Color color; final DateTime t0, t1, now; final String unit; final int decimals; final bool zeroBase;
  const SeriesChart({super.key, required this.series, this.second = const [], required this.color, required this.t0, required this.t1,
      required this.now, required this.unit, this.decimals = 0, this.zeroBase = false});
  @override
  State<SeriesChart> createState() => _SeriesChartState();
}

class _SeriesChartState extends State<SeriesChart> {
  double? _x;
  @override
  Widget build(BuildContext context) {
    if (widget.series.length < 2) return SizedBox(height: 60, child: Center(child: Text('Veri yok', style: _st(13, FontWeight.w600, kInkSoft))));
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (d) => setState(() => _x = d.localPosition.dx),
      onHorizontalDragUpdate: (d) { HapticFeedback.selectionClick(); setState(() => _x = d.localPosition.dx); },
      onHorizontalDragEnd: (_) => setState(() => _x = null),
      onTapDown: (d) => setState(() => _x = d.localPosition.dx),
      onTapUp: (_) => Future.delayed(const Duration(milliseconds: 1400), () { if (mounted) setState(() => _x = null); }),
      child: SizedBox(height: 190, width: double.infinity, child: CustomPaint(painter: _SeriesPainter(widget, _x))),
    );
  }
}

class _SeriesPainter extends CustomPainter {
  final SeriesChart w; final double? sel;
  _SeriesPainter(this.w, this.sel);

  void _text(Canvas c, String s, TextStyle st, Offset at, {double align = .5, double? minX, double? maxX}) {
    final tp = TextPainter(text: TextSpan(text: s, style: st), textDirection: TextDirection.ltr)..layout();
    var x = at.dx - tp.width * align;
    if (minX != null) x = max(minX, x);
    if (maxX != null) x = min(maxX - tp.width, x);
    tp.paint(c, Offset(x, at.dy));
  }

  @override
  void paint(Canvas c, Size sz) {
    const top = 22.0, bottom = 22.0, right = 34.0;
    final cw = sz.width - right, ch = sz.height - top - bottom;
    final span = w.t1.difference(w.t0).inMinutes.toDouble();
    double X(DateTime t) => t.difference(w.t0).inMinutes / span * cw;
    final all = [...w.series.map((e) => e.$2), ...w.second.map((e) => e.$2)];
    var lo = all.reduce(min), hi = all.reduce(max);
    if (w.zeroBase) lo = 0;
    final pad = max(.5, (hi - lo) * .12);
    lo -= w.zeroBase ? 0 : pad; hi += pad;
    double Y(double v) => top + ch - (v - lo) / (hi - lo) * ch;

    // Yatay kılavuzlar ve değer etiketleri
    final grid = Paint()..color = kLine..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final v = lo + (hi - lo) * i / 3, y = Y(v);
      c.drawLine(Offset(0, y), Offset(cw, y), grid);
      _text(c, v.toStringAsFixed(w.decimals == 0 ? 0 : (hi - lo) < 6 ? 1 : 0), _st(10, FontWeight.w600, kInkFaint), Offset(cw + 4, y - 6), align: 0);
    }
    // Gün ayraçları
    var d = DateTime(w.t0.year, w.t0.month, w.t0.day).add(const Duration(days: 1));
    while (d.isBefore(w.t1)) {
      final x = X(d);
      c.drawLine(Offset(x, top - 4), Offset(x, top + ch), Paint()..color = kLine..strokeWidth = 1);
      _text(c, _dayShort[d.weekday - 1], _st(10.5, FontWeight.w700, kInkSoft), Offset(x + 4, sz.height - 16), align: 0);
      d = d.add(const Duration(days: 1));
    }
    // İkinci seri (hamle): soluk alan
    if (w.second.length > 1) {
      final p = Path()..moveTo(X(w.second.first.$1), Y(w.second.first.$2));
      for (final e in w.second.skip(1)) { p.lineTo(X(e.$1), Y(e.$2)); }
      c.drawPath(p, Paint()..color = w.color.withValues(alpha: .35)..style = PaintingStyle.stroke..strokeWidth = 2..strokeJoin = StrokeJoin.round);
    }
    // Ana seri: alan + çizgi (geçmiş düz, gelecek kesikli)
    final pts = [for (final e in w.series) Offset(X(e.$1), Y(e.$2))];
    // Catmull-Rom: sık saatlik veride basamaksız, yumuşak eğri
    final curve = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      final p0 = pts[max(0, i - 2)], p1 = pts[i - 1], p2 = pts[i], p3 = pts[min(pts.length - 1, i + 1)];
      final c1 = p1 + (p2 - p0) / 6, c2 = p2 - (p3 - p1) / 6;
      curve.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }
    final area = Path.from(curve)..lineTo(pts.last.dx, top + ch)..lineTo(pts.first.dx, top + ch)..close();
    c.drawPath(area, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [w.color.withValues(alpha: .22), w.color.withValues(alpha: 0)]).createShader(Rect.fromLTRB(0, top, cw, top + ch)));
    final nx = X(w.now);
    final line = Paint()..color = w.color..style = PaintingStyle.stroke..strokeWidth = 2.6..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    c.save(); c.clipRect(Rect.fromLTRB(-4, 0, nx, sz.height)); c.drawPath(curve, line); c.restore();
    c.save(); c.clipRect(Rect.fromLTRB(nx, 0, cw + 4, sz.height));
    for (final m in curve.computeMetrics()) {
      for (var t = 0.0; t < m.length; t += 9) { c.drawPath(m.extractPath(t, min(m.length, t + 5)), line); }
    }
    c.restore();
    // Şimdi
    c.drawLine(Offset(nx, top - 6), Offset(nx, top + ch), Paint()..color = kInk.withValues(alpha: .25)..strokeWidth = 1.5);
    _text(c, 'Şimdi', _st(10.5, FontWeight.w800, kAccent), Offset(nx, 2), minX: 0, maxX: cw);
    // Parmakla seçilen an
    final sx = sel;
    if (sx != null) {
      final t = w.t0.add(Duration(minutes: (sx.clamp(0, cw) / cw * span).round()));
      final e = w.series.reduce((a, b) => (a.$1.difference(t).inMinutes).abs() <= (b.$1.difference(t).inMinutes).abs() ? a : b);
      final x = X(e.$1), y = Y(e.$2);
      c.drawLine(Offset(x, top - 4), Offset(x, top + ch), Paint()..color = w.color.withValues(alpha: .4)..strokeWidth = 1.5);
      c.drawCircle(Offset(x, y), 6, Paint()..color = Colors.white);
      c.drawCircle(Offset(x, y), 6, Paint()..color = w.color..style = PaintingStyle.stroke..strokeWidth = 3);
      final label = '${_dayShort[e.$1.weekday - 1]} ${e.$1.hour.toString().padLeft(2, '0')}:00 · ${e.$2.toStringAsFixed(w.decimals)} ${w.unit}';
      final tp = TextPainter(text: TextSpan(text: label, style: _st(11.5, FontWeight.w700, Colors.white)), textDirection: TextDirection.ltr)..layout();
      final bx = (x - tp.width / 2 - 8).clamp(0.0, cw - tp.width - 16);
      final by = y - 38 < 0 ? y + 12 : y - 38;
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(bx, by, tp.width + 16, 24), const Radius.circular(12)), Paint()..color = kInk);
      tp.paint(c, Offset(bx + 8, by + 5));
    }
  }

  @override
  bool shouldRepaint(covariant _SeriesPainter o) => o.sel != sel || o.w != w;
}

/// Rüzgâr gülü: rüzgârın gittiği yönü gösteren ok.
class WindRosePainter extends CustomPainter {
  final double dir, speed; final bool compact;
  WindRosePainter(this.dir, this.speed, {this.compact = false});
  @override
  void paint(Canvas c, Size s) {
    final ctr = s.center(Offset.zero); final r = min(s.width, s.height) / 2 - 4;
    c.drawCircle(ctr, r, Paint()..color = Colors.white.withValues(alpha: .75));
    c.drawCircle(ctr, r, Paint()..color = kLine..style = PaintingStyle.stroke..strokeWidth = 1.5);
    for (var i = 0; i < 36; i++) {
      final a = i * pi / 18; final len = i % 9 == 0 ? 7.0 : 3.5;
      c.drawLine(ctr + Offset(sin(a), -cos(a)) * r, ctr + Offset(sin(a), -cos(a)) * (r - len), Paint()..color = kInkFaint..strokeWidth = i % 9 == 0 ? 2 : 1);
    }
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (final e in [('K', 0.0), ('D', 90.0), ('G', 180.0), ('B', 270.0)]) {
      if (compact && e.$1 != 'K') continue;
      tp.text = TextSpan(text: e.$1, style: TextStyle(fontFamily: 'Inter', fontSize: compact ? 8 : 10, color: e.$1 == 'K' ? kDanger : kInkSoft, fontWeight: FontWeight.w800)); tp.layout();
      final a = e.$2 * pi / 180; tp.paint(c, ctr + Offset(sin(a), -cos(a)) * (r - (compact ? 11 : 15)) - Offset(tp.width / 2, tp.height / 2));
    }
    final to = (dir + 180) * pi / 180;
    final tip = ctr + Offset(sin(to), -cos(to)) * (r - 6), tail = ctr - Offset(sin(to), -cos(to)) * (r - (compact ? 14 : 22));
    c.drawLine(tail, tip, Paint()..color = kGood..strokeWidth = 3.5..strokeCap = StrokeCap.round);
    final head = Path()..moveTo(tip.dx, tip.dy)
      ..lineTo(tip.dx - 8 * sin(to) + 5 * cos(to), tip.dy + 8 * cos(to) + 5 * sin(to))
      ..lineTo(tip.dx - 8 * sin(to) - 5 * cos(to), tip.dy + 8 * cos(to) - 5 * sin(to))..close();
    c.drawPath(head, Paint()..color = kGood);
    c.drawCircle(ctr, 4.5, Paint()..color = Colors.white);
    c.drawCircle(ctr, 4.5, Paint()..color = kInk..style = PaintingStyle.stroke..strokeWidth = 2);
  }
  @override
  bool shouldRepaint(covariant WindRosePainter o) => o.dir != dir || o.speed != speed;
}

// ═══════════════════════════════════════════════════════════════════════════
// Canlı pencere
// ═══════════════════════════════════════════════════════════════════════════

/// Sahneye dokununca: tam ekran canlı sahne + havaya uygun gerçek doğa kaydı (CC0).
/// Çıkınca uyku mikserinin önceki karışımı geri yüklenir.
class LiveWindow extends StatefulWidget {
  final WeatherSnapshot s; final Analysis a; final Wx wx; final DayPoint? today;
  const LiveWindow({super.key, required this.s, required this.a, required this.wx, this.today});

  static void open(BuildContext context, WeatherSnapshot s, Analysis a, Wx wx, DayPoint? today) {
    HapticFeedback.lightImpact();
    Navigator.push(context, PageRouteBuilder(
      opaque: true, transitionDuration: const Duration(milliseconds: 420), reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => LiveWindow(s: s, a: a, wx: wx, today: today),
      transitionsBuilder: (_, an, __, child) => FadeTransition(opacity: CurvedAnimation(parent: an, curve: Curves.easeOut), child: child),
    ));
  }

  /// Havaya uygun kayıt: yağmurda yağmur, karda kamp ateşi (sıcak bir köşe), gece orman, gündüz şelale.
  static ({String key, String label}) ambience(Wx wx, WeatherSnapshot s) {
    if ({Wx.rain, Wx.drizzle, Wx.thunder, Wx.sleet}.contains(wx)) return (key: 'rain', label: 'Yağmur');
    if ({Wx.snow, Wx.blizzard, Wx.lentil}.contains(wx)) return (key: 'campfire', label: 'Kamp ateşi');
    if (!s.isDay) return (key: 'forest', label: 'Gece ormanı');
    return (key: 'waterfall', label: 'Şelale');
  }

  @override
  State<LiveWindow> createState() => _LiveWindowState();
}

class _LiveWindowState extends State<LiveWindow> {
  late final Map<String, double> _before = Map.of(SleepMixer.I.level);
  late final _amb = LiveWindow.ambience(widget.wx, widget.s);
  final _tilt = ValueNotifier(Offset.zero);
  final _shot = GlobalKey();
  bool _sharing = false;
  StreamSubscription<AccelerometerEvent>? _acc;
  double? _bx, _bz;
  bool _sound = true;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _play();
    // Telefon eğimi: ilk duruş referans; yumuşatılmış, −1…1 aralığında
    try {
      _acc = accelerometerEventStream(samplingPeriod: SensorInterval.uiInterval).listen((e) {
        _bx ??= e.x; _bz ??= e.z;
        final t = Offset(((e.x - _bx!) / 4).clamp(-1.0, 1.0), ((e.z - _bz!) / 4).clamp(-1.0, 1.0));
        _tilt.value = Offset.lerp(_tilt.value, t, .12)!;
      }, onError: (_) {});
    } catch (_) {}
  }

  void _play() => SleepMixer.I.preset({_amb.key: .7}, remember: false);

  @override
  void dispose() {
    _acc?.cancel();
    _tilt.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SleepMixer.I.preset(_before, remember: false);
    super.dispose();
  }

  /// Manzarayı resim olarak paylaş: sahne + köşede küçük "SkyNav · yer" imzası.
  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final b = _shot.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (b == null) return;
      final dpr = min(MediaQuery.devicePixelRatioOf(context), 2.5);
      final padTop = MediaQuery.paddingOf(context).top;
      final img = await b.toImage(pixelRatio: dpr);
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      c.drawImage(img, Offset.zero, Paint());
      final s = widget.s;
      final name = s.place.name.isEmpty ? 'Konumum' : s.place.name;
      final tp = TextPainter(textDirection: TextDirection.ltr, text: TextSpan(text: 'SkyNav · $name',
          style: TextStyle(fontFamily: 'Inter', fontSize: 13 * dpr, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: .85),
              shadows: const [Shadow(color: Color(0x66000000), blurRadius: 6)])))..layout();
      tp.paint(c, Offset(img.width - tp.width - 18 * dpr, 18 * dpr + padTop * dpr));
      final out = await rec.endRecording().toImage(img.width, img.height);
      final png = await out.toByteData(format: ui.ImageByteFormat.png);
      img.dispose(); out.dispose();
      if (png == null) return;
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/skynav_manzara.png');
      await f.writeAsBytes(png.buffer.asUint8List());
      await SharePlus.instance.share(ShareParams(files: [XFile(f.path, mimeType: 'image/png')],
          text: '$name: ${deg(s.temp)}, ${wxLabel(widget.wx, day: s.isDay).toLowerCase()} · SkyNav'));
    } catch (_) {
      // paylaşım iptal ya da desteklenmiyor
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(fit: StackFit.expand, children: [
        RepaintBoundary(key: _shot, child: HeroScene(s: widget.s, a: widget.a, wx: widget.wx, today: widget.today, height: mq.size.height, radius: 0, live: true, tilt: _tilt)),
        Positioned(top: mq.padding.top + 12, right: 16, child: Row(children: [
          _GlassButton(icon: _sharing ? Icons.hourglass_top_rounded : Icons.ios_share_rounded, onTap: _share),
          const SizedBox(width: 10),
          _GlassButton(icon: Icons.close_rounded, onTap: () => Navigator.pop(context)),
        ])),
        Positioned(bottom: mq.padding.bottom + 24, right: 16, child: _GlassButton(
          icon: _sound ? Icons.volume_up_rounded : Icons.volume_off_rounded,
          label: _sound ? _amb.label : 'Sessiz',
          onTap: () {
            setState(() => _sound = !_sound);
            if (_sound) { _play(); } else { SleepMixer.I.stopAll(); }
          },
        )),
      ]),
    );
  }
}

class _GlassButton extends StatelessWidget {
  final IconData icon; final String? label; final VoidCallback onTap;
  const _GlassButton({required this.icon, this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white.withValues(alpha: .22), shape: const StadiumBorder(side: BorderSide(color: Color(0x40FFFFFF))),
        child: InkWell(customBorder: const StadiumBorder(), onTap: () { HapticFeedback.selectionClick(); onTap(); },
            child: Padding(padding: EdgeInsets.symmetric(horizontal: label == null ? 10 : 14, vertical: 10), child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, color: Colors.white, size: 22),
              if (label != null) ...[const SizedBox(width: 8), Text(label!, style: _st(14, FontWeight.w700, Colors.white))],
            ]))),
      );
}
