import 'dart:math';
import 'package:flutter/material.dart';
import '../data/models.dart';
import '../services/climate_service.dart';
import 'bento.dart';
import 'hero_scene.dart' show deg;
import 'theme.dart';

const _dayShort = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

TextStyle _st(double size, FontWeight w, Color c, {double ls = 0, double? h}) =>
    TextStyle(fontFamily: 'Inter', fontSize: size, fontWeight: w, color: c, letterSpacing: ls, height: h, fontFeatures: const [FontFeature.tabularFigures()]);

/// "Normalden 4° soğuk": bugünün en yüksek tahmini, 30 yıllık normal en yüksekle.
String? climateTeaser(WeatherSnapshot s, DateTime now) {
  final n = ClimateService.cached(s.place);
  if (n == null || s.daily.isEmpty) return null;
  final d = s.daily.first.tMax - n.maxOn(now);
  if (d.abs() < 1) return 'Bugün tam mevsim normalinde';
  return 'Bugün normalden ${d.abs().round()}° ${d < 0 ? 'soğuk' : 'sıcak'}';
}

/// İklim: bugün ve önümüzdeki hafta mevsim normaline göre nasıl; bu tarihin rekorları.
class ClimateScreen extends StatefulWidget {
  final WeatherSnapshot s;
  /// Test için hazır normaller; boşsa indirilir/önbellekten.
  final ClimateNormals? normals;
  const ClimateScreen({super.key, required this.s, this.normals});
  @override
  State<ClimateScreen> createState() => _ClimateScreenState();
}

class _ClimateScreenState extends State<ClimateScreen> {
  ClimateNormals? _n;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _n = widget.normals ?? ClimateService.cached(widget.s.place);
    if (_n == null) {
      ClimateService.load(widget.s.place).then((v) { if (mounted) setState(() { _n = v; _failed = v == null; }); })
          .catchError((_) { if (mounted) setState(() => _failed = true); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = _n, s = widget.s, now = DateTime.now();
    final days = s.daily.where((d) => !d.date.isBefore(DateTime(now.year, now.month, now.day))).take(7).toList();
    return Scaffold(
      backgroundColor: kIce,
      appBar: AppBar(title: const Text('İklim')),
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 40), children: [
        if (n == null)
          Bento(padding: const EdgeInsets.all(24), child: Center(child: _failed
              ? Text('İklim verisi indirilemedi. İnternete bağlanınca bir kez indirilir, sonra hep hazır.', textAlign: TextAlign.center, style: T.small)
              : const Column(children: [CircularProgressIndicator(), SizedBox(height: 12), Text('30 yıllık ölçümler indiriliyor…', style: T.small)])))
        else ...[
          if (days.isNotEmpty) _TodayVsNormal(today: days.first, n: n),
          const SizedBox(height: 14),
          if (days.length > 1) _WeekBand(days: days, n: n),
          const SizedBox(height: 14),
          _Records(n: n, now: now),
          const SizedBox(height: 10),
          Text('Normal: ${n.fromYear}–${n.toYear} arası gerçek ölçümlerin (ERA5 yeniden analizi) bu tarih çevresindeki ortalaması.',
              style: T.small.copyWith(fontSize: 11.5)),
        ],
      ]),
    );
  }
}

class _TodayVsNormal extends StatelessWidget {
  final DayPoint today; final ClimateNormals n;
  const _TodayVsNormal({required this.today, required this.n});
  @override
  Widget build(BuildContext context) {
    final nm = n.maxOn(today.date), d = today.tMax - nm;
    final cold = d < 0;
    final col = d.abs() < 1 ? kGood : cold ? kSnow : kHeat;
    return Bento(
      color: d.abs() < 1 ? kBentoMint : cold ? kBentoBlue : kBentoPeach, padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        BlockHead('Bugün ve mevsim normali', dot: col),
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(d.abs() < 1 ? 'Normal' : '${cold ? '−' : '+'}${d.abs().round()}°', style: _st(44, FontWeight.w700, col, ls: -1.2, h: 1)),
          const SizedBox(width: 10),
          Expanded(child: Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(
              d.abs() < 1 ? 'Tam mevsiminde bir gün' : 'Normalden ${d.abs().round()}° ${cold ? 'soğuk' : 'sıcak'}',
              style: _st(16, FontWeight.w700, kInk)))),
        ]),
        const SizedBox(height: 10),
        Text('Bugün en yüksek ${deg(today.tMax)} bekleniyor; bu tarihte normali ${deg(nm)}, gece normali ${deg(n.minOn(today.date))}.',
            style: _st(13, FontWeight.w500, kInkSoft, h: 1.35)),
      ]),
    );
  }
}

/// 7 gün: normal bandı (normal en düşük–en yüksek) üstünde tahmin edilen en yüksek/en düşük.
class _WeekBand extends StatelessWidget {
  final List<DayPoint> days; final ClimateNormals n;
  const _WeekBand({required this.days, required this.n});
  @override
  Widget build(BuildContext context) => Bento(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          BlockHead('Önümüzdeki hafta', trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 14, height: 8, decoration: BoxDecoration(color: kGood.withValues(alpha: .18), borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 4), Text('normal', style: _st(11, FontWeight.w600, kInkSoft)),
          ])),
          const SizedBox(height: 12),
          SizedBox(height: 180, width: double.infinity, child: CustomPaint(painter: _BandPainter(days, n))),
        ]),
      );
}

class _BandPainter extends CustomPainter {
  final List<DayPoint> d; final ClimateNormals n;
  _BandPainter(this.d, this.n);
  @override
  void paint(Canvas c, Size s) {
    const top = 18.0, bottom = 22.0;
    final ch = s.height - top - bottom, cw = s.width;
    final vals = [for (final x in d) ...[x.tMax, x.tMin, n.maxOn(x.date), n.minOn(x.date)]];
    final lo = vals.reduce(min) - 2, hi = vals.reduce(max) + 2;
    double X(int i) => cw * (i + .5) / d.length;
    double Y(double v) => top + ch - (v - lo) / (hi - lo) * ch;
    // Normal bandı
    final band = Path()..moveTo(X(0), Y(n.maxOn(d.first.date)));
    for (var i = 1; i < d.length; i++) { band.lineTo(X(i), Y(n.maxOn(d[i].date))); }
    for (var i = d.length - 1; i >= 0; i--) { band.lineTo(X(i), Y(n.minOn(d[i].date))); }
    c.drawPath(band..close(), Paint()..color = kGood.withValues(alpha: .16));
    // Gün çubukları: tahmin en düşük–en yüksek, normale göre renk
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (var i = 0; i < d.length; i++) {
      final x = X(i), dev = d[i].tMax - n.maxOn(d[i].date);
      final col = dev.abs() < 1.5 ? kGood : dev < 0 ? kSnow : kHeat;
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(x - 5, Y(d[i].tMax), x + 5, Y(d[i].tMin)), const Radius.circular(5)), Paint()..color = col);
      tp.text = TextSpan(text: deg(d[i].tMax), style: _st(11, FontWeight.w700, kInk)); tp.layout();
      tp.paint(c, Offset(x - tp.width / 2, Y(d[i].tMax) - 16));
      tp.text = TextSpan(text: i == 0 ? 'Bugün' : _dayShort[d[i].date.weekday - 1], style: _st(10.5, i == 0 ? FontWeight.w800 : FontWeight.w600, i == 0 ? kAccent : kInkSoft));
      tp.layout();
      tp.paint(c, Offset(x - tp.width / 2, s.height - 15));
    }
  }
  @override
  bool shouldRepaint(covariant _BandPainter o) => o.d != d || o.n != n;
}

class _Records extends StatelessWidget {
  final ClimateNormals n; final DateTime now;
  const _Records({required this.n, required this.now});
  @override
  Widget build(BuildContext context) {
    final k = ClimateNormals.doy(now);
    Widget box(String label, double v, int year, Color col, IconData ic) => Expanded(child: Bento(
          color: col == kHeat ? kBentoPeach : kBentoBlue, padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Icon(ic, size: 18, color: col), const SizedBox(width: 6), Text(label, style: _st(12, FontWeight.w700, kInkSoft))]),
            const SizedBox(height: 8),
            Text(year > 0 ? deg(v) : '–', style: _st(26, FontWeight.w700, kInk, ls: -.5)),
            Text(year > 0 ? '$year yılında' : '', style: _st(12, FontWeight.w600, kInkSoft)),
          ]),
        ));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('BU TARİHİN REKORLARI (${n.fromYear}–${n.toYear})', style: T.label.copyWith(fontSize: 11)),
      const SizedBox(height: 8),
      Row(children: [
        box('En sıcak', n.recMax[k], n.recMaxYear[k], kHeat, Icons.wb_sunny_outlined),
        const SizedBox(width: 12),
        box('En soğuk', n.recMin[k], n.recMinYear[k], kSnow, Icons.ac_unit_rounded),
      ]),
    ]);
  }
}
