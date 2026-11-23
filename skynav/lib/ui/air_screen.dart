import 'package:flutter/material.dart';
import '../data/models.dart';
import '../services/air_service.dart';
import 'bento.dart';
import 'detail_screens.dart' show SeriesChart;
import 'theme.dart';

const _dayShort = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

TextStyle _st(double size, FontWeight w, Color c, {double ls = 0, double? h}) =>
    TextStyle(fontFamily: 'Inter', fontSize: size, fontWeight: w, color: c, letterSpacing: ls, height: h, fontFeatures: const [FontFeature.tabularFigures()]);

/// Hava kalitesi: Avrupa endeksi, kirleticiler gündelik adlarıyla, 72 saatlik tahmin ve en temiz saat.
class AirScreen extends StatefulWidget {
  final WeatherSnapshot s;
  /// Test için hazır veri; boşsa indirilir.
  final List<AirPoint>? data;
  const AirScreen({super.key, required this.s, this.data});
  @override
  State<AirScreen> createState() => _AirScreenState();
}

class _AirScreenState extends State<AirScreen> {
  List<AirPoint>? _d;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _d = widget.data;
    if (_d == null) {
      AirService.forecast(widget.s.place).then((v) { if (mounted) setState(() => _d = v); })
          .catchError((_) { if (mounted) setState(() => _failed = true); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _d, now = DateTime.now();
    return Scaffold(
      backgroundColor: kIce,
      appBar: AppBar(title: const Text('Hava kalitesi')),
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 40), children: [
        if (d == null || d.isEmpty)
          Bento(padding: const EdgeInsets.all(24), child: Center(child: _failed || (d != null && d.isEmpty)
              ? Text('Hava kalitesi verisi alınamadı. İnternete bağlanınca tekrar dene.', textAlign: TextAlign.center, style: T.small)
              : const Column(children: [CircularProgressIndicator(), SizedBox(height: 12), Text('Hava kalitesi alınıyor…', style: T.small)])))
        else ..._body(d, now),
      ]),
    );
  }

  List<Widget> _body(List<AirPoint> d, DateTime now) {
    final cur = d.reduce((a, b) => (a.time.difference(now).inMinutes).abs() <= (b.time.difference(now).inMinutes).abs() ? a : b);
    final future = d.where((p) => p.time.isAfter(now)).toList();
    final cleanest = future.isEmpty ? null : future.take(48).reduce((a, b) => a.aqi <= b.aqi ? a : b);
    final col = Color(Aqi.color(cur.aqi));
    String when(DateTime t) {
      final diff = DateTime(t.year, t.month, t.day).difference(DateTime(now.year, now.month, now.day)).inDays;
      return '${diff == 0 ? 'bugün' : diff == 1 ? 'yarın' : _dayShort[t.weekday - 1]} ${t.hour.toString().padLeft(2, '0')}:00';
    }
    Widget pol(String name, String plain, double v, double limit) => Expanded(child: Bento(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(plain, maxLines: 1, overflow: TextOverflow.ellipsis, style: _st(12.5, FontWeight.w700, kInkSoft)),
            const SizedBox(height: 6),
            Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
              Text(v.round().toString(), style: _st(24, FontWeight.w700, kInk, ls: -.4)),
              const SizedBox(width: 4),
              Text('µg/m³', style: _st(11, FontWeight.w600, kInkFaint)),
            ]),
            const SizedBox(height: 8),
            ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: (v / limit).clamp(0.0, 1.0), minHeight: 6,
                backgroundColor: kLine, color: v > limit ? kDanger : v > limit * .6 ? kWarn : kGood)),
            const SizedBox(height: 6),
            Text('$name · sınır $limit'.replaceAll('.0', ''), style: _st(11, FontWeight.w600, kInkFaint)),
          ]),
        ));
    return [
      Bento(
        padding: const EdgeInsets.all(18),
        child: Row(children: [
          SizedBox(width: 92, height: 92, child: Stack(alignment: Alignment.center, children: [
            SizedBox.expand(child: CircularProgressIndicator(value: (cur.aqi / 100).clamp(0.0, 1.0), strokeWidth: 9, strokeCap: StrokeCap.round, backgroundColor: kLine, color: col)),
            Column(mainAxisSize: MainAxisSize.min, children: [
              Text(cur.aqi.round().toString(), style: _st(26, FontWeight.w800, kInk, h: 1)),
              Text('endeks', style: _st(10.5, FontWeight.w600, kInkFaint)),
            ]),
          ])),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            BlockHead('Şu an', dot: col),
            const SizedBox(height: 4),
            Text(Aqi.label(cur.aqi), style: _st(24, FontWeight.w800, col, ls: -.4)),
            const SizedBox(height: 4),
            Text(Aqi.advice(cur.aqi), style: _st(13, FontWeight.w500, kInkSoft, h: 1.35)),
          ])),
        ]),
      ),
      const SizedBox(height: 14),
      // DSÖ 2021 24 saatlik kılavuz değerleri (O₃ ve NO₂ için 8 sa/24 sa üst sınırlar yakınsaması)
      Row(children: [pol('PM2.5', 'İnce toz', cur.pm25, 15), const SizedBox(width: 12), pol('PM10', 'Kaba toz', cur.pm10, 45)]),
      const SizedBox(height: 12),
      Row(children: [pol('O₃', 'Ozon', cur.ozone, 100), const SizedBox(width: 12), pol('NO₂', 'Egzoz gazı', cur.no2, 25)]),
      const SizedBox(height: 14),
      Bento(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          BlockHead('Önümüzdeki 3 gün', dot: col, trailing: cleanest == null ? null : Text('en temiz ${when(cleanest.time)}', style: _st(12, FontWeight.w700, kGood))),
          const SizedBox(height: 10),
          SeriesChart(series: [for (final p in d) (p.time, p.aqi)], color: col, t0: d.first.time, t1: d.last.time, now: now, unit: 'endeks', decimals: 0, zeroBase: true),
        ]),
      ),
      const SizedBox(height: 10),
      Text('Endeks: Avrupa Hava Kalitesi İndeksi (0–20 iyi, 20–40 makul, 40–60 orta, 60–80 kötü, 80+ çok kötü). '
          'Sınırlar: DSÖ 2021 günlük kılavuz değerleri. Veri: CAMS (Copernicus) tahmini.', style: T.small.copyWith(fontSize: 11.5)),
    ];
  }
}
