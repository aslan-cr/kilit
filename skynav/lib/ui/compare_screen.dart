import 'package:flutter/material.dart';
import '../data/models.dart';
import 'bento.dart';
import 'hero_scene.dart' show deg;
import 'theme.dart';
import 'wx_glyph.dart';

const _dayShort = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

TextStyle _st(double size, FontWeight w, Color c, {double h = 1.2}) =>
    TextStyle(fontFamily: 'Inter', fontSize: size, fontWeight: w, color: c, height: h, fontFeatures: const [FontFeature.tabularFigures()]);

String _short(String name) => name.split(',').first.trim();

/// Türkçe ayrılma eki: ünlü uyumu ve sert ünsüz benzeşmesiyle ("Evim'den", "Erzurum'dan", "Kars'tan").
String ablative(String name) {
  final low = name.toLowerCase();
  String? v;
  for (var i = low.length - 1; i >= 0; i--) {
    final c = low[i];
    if ('aıou'.contains(c)) { v = 'a'; break; }
    if ('eiöü'.contains(c)) { v = 'e'; break; }
  }
  final last = low.isEmpty ? '' : low[low.length - 1];
  final cons = 'fstkçşhp'.contains(last) ? 't' : 'd';
  return "$name'$cons${v ?? 'a'}n";
}

/// İki yerin havası yan yana: şu an ve 7 gün (sıcaklık, durum, yağış/kar), kısa özet.
class CompareScreen extends StatelessWidget {
  final PlaceNow a, b;
  const CompareScreen({super.key, required this.a, required this.b});

  /// "Anneannem, Evim'den 3° daha soğuk." gibi özet.
  static String summary(PlaceNow a, PlaceNow b) {
    final d = b.temp - a.temp;
    final na = _short(a.place.name), nb = _short(b.place.name);
    final now = d.abs() < 1 ? 'Şu an $na ile $nb aynı sıcaklıkta.' : 'Şu an $nb, ${ablative(na)} ${d.abs().round()}° daha ${d < 0 ? 'soğuk' : 'sıcak'}.';
    double snow(PlaceNow p) => p.days.fold<double>(0, (t, x) => t + x.snowSum);
    final sa = snow(a), sb = snow(b);
    final s = sa < .5 && sb < .5 ? '' : ' 7 günde kar: $na ${sa.round()} cm, $nb ${sb.round()} cm.';
    return '$now$s';
  }

  @override
  Widget build(BuildContext context) {
    final n = a.days.length < b.days.length ? a.days.length : b.days.length;
    final today = DateTime.now();
    return Scaffold(
      backgroundColor: kIce,
      appBar: AppBar(title: const Text('Karşılaştır')),
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 40), children: [
        Row(children: [Expanded(child: _NowCard(p: a)), const SizedBox(width: 12), Expanded(child: _NowCard(p: b))]),
        const SizedBox(height: 14),
        Bento(color: kBentoBlue, padding: const EdgeInsets.all(14), child: Row(children: [
          const Icon(Icons.compare_arrows_rounded, color: kAccent), const SizedBox(width: 10),
          Expanded(child: Text(summary(a, b), style: _st(14, FontWeight.w700, kInk, h: 1.35))),
        ])),
        const SizedBox(height: 14),
        if (n > 0) Bento(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
          child: Column(children: [
            Row(children: [
              const SizedBox(width: 44),
              Expanded(child: Text(_short(a.place.name), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: _st(12.5, FontWeight.w800, kInkSoft))),
              Expanded(child: Text(_short(b.place.name), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: _st(12.5, FontWeight.w800, kInkSoft))),
            ]),
            const SizedBox(height: 6),
            for (var i = 0; i < n; i++) ...[
              if (i > 0) const Divider(height: 1, color: kLine),
              Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(children: [
                SizedBox(width: 44, child: Text(_sameDay(a.days[i].date, today) ? 'Bugün' : _dayShort[a.days[i].date.weekday - 1],
                    style: _st(13, _sameDay(a.days[i].date, today) ? FontWeight.w800 : FontWeight.w600, kInk))),
                Expanded(child: _DayCell(d: a.days[i], other: b.days[i])),
                Expanded(child: _DayCell(d: b.days[i], other: a.days[i])),
              ])),
            ],
          ]),
        ),
      ]),
    );
  }

  static bool _sameDay(DateTime x, DateTime y) => x.year == y.year && x.month == y.month && x.day == y.day;
}

class _NowCard extends StatelessWidget {
  final PlaceNow p;
  const _NowCard({required this.p});
  @override
  Widget build(BuildContext context) {
    final wx = wxFromCode(p.code);
    return Bento(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_short(p.place.name), maxLines: 1, overflow: TextOverflow.ellipsis, style: _st(14, FontWeight.w800, kInk)),
        const SizedBox(height: 8),
        Row(children: [
          WxGlyph(wx, day: p.isDay, size: 40),
          const SizedBox(width: 6),
          Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
              child: Text(deg(p.temp), style: const TextStyle(fontFamily: 'InterDisplay', fontSize: 40, fontWeight: FontWeight.w300, color: kInk, height: 1)))),
        ]),
        const SizedBox(height: 6),
        Text(wxLabel(wx, day: p.isDay), maxLines: 1, overflow: TextOverflow.ellipsis, style: _st(12.5, FontWeight.w700, kInkSoft)),
        Text('↑ ${deg(p.tMax)}  ↓ ${deg(p.tMin)}', style: _st(12, FontWeight.w600, kInkFaint)),
      ]),
    );
  }
}

/// Bir yerin bir günü; diğer yere göre daha soğuksa en yüksek sıcaklık mavi, daha sıcaksa turuncu.
class _DayCell extends StatelessWidget {
  final DayPoint d, other;
  const _DayCell({required this.d, required this.other});
  @override
  Widget build(BuildContext context) {
    final diff = d.tMax - other.tMax;
    final col = diff <= -1.5 ? kSnow : diff >= 1.5 ? kHeat : kInk;
    final amt = d.snowSum >= .5 ? '${d.snowSum.round()} cm' : d.precipSum >= .5 ? '${d.precipSum.round()} mm' : '';
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      WxGlyph(wxFromCode(d.weatherCode), size: 24),
      const SizedBox(width: 6),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${deg(d.tMax)} / ${deg(d.tMin)}', style: _st(13, FontWeight.w800, col)),
        if (amt.isNotEmpty) Text(amt, style: _st(10.5, FontWeight.w700, kSnow)),
      ]),
    ]);
  }
}
