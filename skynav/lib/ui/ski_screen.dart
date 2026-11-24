import 'package:flutter/material.dart';
import '../data/models.dart';
import '../services/ski_service.dart';
import 'bento.dart';
import 'hero_scene.dart' show deg;
import 'plain.dart';
import 'theme.dart';
import 'wx_glyph.dart';

TextStyle _st(double size, FontWeight w, Color c, {double h = 1.2, double ls = 0}) =>
    TextStyle(fontFamily: 'Inter', fontSize: size, fontWeight: w, color: c, height: h, letterSpacing: ls, fontFeatures: const [FontFeature.tabularFigures()]);

/// Kayak merkezleri: kar kalınlığı, son 24 saatte ve önümüzdeki 3 günde yağacak kar, orta yükseklikte sıcaklık ve rüzgâr.
/// En yakın merkez üstte. Değerler model tahminidir (merkezlerin kendi kar raporu değil).
class SkiScreen extends StatefulWidget {
  final GeoPoint2 here;
  /// Test için hazır veri; boşsa indirilir.
  final List<SkiNow>? data;
  const SkiScreen({super.key, required this.here, this.data});
  @override
  State<SkiScreen> createState() => _SkiScreenState();
}

class _SkiScreenState extends State<SkiScreen> {
  List<SkiNow>? _d;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _d = widget.data;
    if (_d == null) {
      SkiService.load().then((v) { if (mounted) setState(() => _d = v); }).catchError((_) { if (mounted) setState(() => _failed = true); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _d == null ? null : ([..._d!]..sort((a, b) => SkiService.km(widget.here, a.r).compareTo(SkiService.km(widget.here, b.r))));
    return Scaffold(
      backgroundColor: kIce,
      appBar: AppBar(title: const Text('Kayak merkezleri')),
      body: RefreshIndicator(
        onRefresh: () async { final v = await SkiService.load(); if (mounted) setState(() => _d = v); },
        child: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 40), children: [
          Text('En yakın merkez üstte. Kar ve hava, pistlerin orta yüksekliği için model tahminidir; merkezin kendi kar raporu değildir.',
              style: T.small.copyWith(fontSize: 12.5)),
          const SizedBox(height: 12),
          if (d == null)
            Bento(padding: const EdgeInsets.all(24), child: Center(child: _failed
                ? Text('Kayak verisi alınamadı. İnternete bağlanınca tekrar dene.', textAlign: TextAlign.center, style: T.small)
                : const CircularProgressIndicator()))
          else
            for (final s in d) ...[_ResortCard(s: s, km: SkiService.km(widget.here, s.r)), const SizedBox(height: 12)],
        ]),
      ),
    );
  }
}

class _ResortCard extends StatelessWidget {
  final SkiNow s; final double km;
  const _ResortCard({required this.s, required this.km});
  @override
  Widget build(BuildContext context) {
    Widget chip(IconData ic, String t, Color c) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(color: c.withValues(alpha: .1), borderRadius: BorderRadius.circular(12)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(ic, size: 14, color: c), const SizedBox(width: 4), Text(t, style: _st(12, FontWeight.w700, c))]),
        );
    final depth = s.snowCm.round();
    return Bento(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.r.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: _st(16.5, FontWeight.w800, kInk)),
            Text('${s.r.city} · ${km.round()} km · ${s.r.base.round()}–${s.r.top.round()} m', maxLines: 1, overflow: TextOverflow.ellipsis,
                style: _st(12, FontWeight.w600, kInkSoft)),
          ])),
          WxGlyph(wxFromCode(s.code), size: 34),
        ]),
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('KAR KALINLIĞI', style: T.label.copyWith(fontSize: 10)),
            Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
              Text('$depth', style: _st(34, FontWeight.w700, depth > 0 ? kSnow : kInkFaint, ls: -1, h: 1.1)),
              const SizedBox(width: 3),
              Text('cm', style: _st(13, FontWeight.w700, kInkSoft)),
            ]),
          ]),
          const Spacer(),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(s.temp.isFinite ? deg(s.temp) : '–', style: _st(22, FontWeight.w700, kInk)),
            Text('${Plain.wind(s.wind, digits: 0)} · ${Plain.t('hamle', 'ani esinti')} ${Plain.wind(s.gust, digits: 0)}', style: _st(11.5, FontWeight.w600, kInkSoft)),
          ]),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 6, children: [
          chip(Icons.ac_unit_rounded, '24 sa: +${s.new24.round()} cm', s.new24 >= 1 ? kSnow : kInkSoft),
          chip(Icons.trending_up_rounded, '3 gün: +${s.next72.round()} cm', s.next72 >= 5 ? kGood : kInkSoft),
          if (s.windy) chip(Icons.air_rounded, 'Sert rüzgâr: teleferikler durabilir', kWarn),
        ]),
      ]),
    );
  }
}
