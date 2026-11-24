import 'dart:math';
import 'package:flutter/material.dart';
import '../data/models.dart';
import '../engine/garden.dart';
import 'bento.dart';
import 'hero_scene.dart' show deg;
import 'plain.dart';
import 'theme.dart';

const _dayShort = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
String _hh(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:00';

String _night(DateTime d, DateTime now) {
  final diff = d.difference(DateTime(now.year, now.month, now.day)).inDays;
  return diff < 0 ? 'Şimdi' : diff == 0 ? 'Bu gece' : diff == 1 ? 'Yarın' : _dayShort[d.weekday - 1];
}

String _day(DateTime d, DateTime now) {
  final diff = DateTime(d.year, d.month, d.day).difference(DateTime(now.year, now.month, now.day)).inDays;
  return diff == 0 ? 'Bugün' : diff == 1 ? 'Yarın' : _dayShort[d.weekday - 1];
}

const _frostColors = [kGood, Color(0xFF4BA3E3), kWarn, Color(0xFFE0702A), kDanger];

/// Bahçe & tarla: don takvimi, ekim için toprak sıcaklığı, ilaçlama saatleri ve haftalık sulama.
class GardenScreen extends StatelessWidget {
  final WeatherSnapshot s;
  /// Test için sabit "şimdi".
  final DateTime? now;
  const GardenScreen({super.key, required this.s, this.now});

  @override
  Widget build(BuildContext context) {
    final now = this.now ?? DateTime.now();
    final r = gardenReport(s, now);
    return Scaffold(
      backgroundColor: kIce,
      appBar: AppBar(title: const Text('Bahçe & tarla')),
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 40), children: [
        Text('Saatlik tahminden; tarlanın kendi ölçümü değil. Ekim zamanı yöreye göre değişir, son don tarihini de gözet.', style: T.small.copyWith(fontSize: 12.5)),
        const SizedBox(height: 4),
        const SectionLabel('Don takvimi'),
        _FrostCard(r: r, now: now),
        const SectionLabel('Ekim için toprak'),
        _SoilCard(r: r),
        const SectionLabel('İlaçlama saatleri'),
        _SprayCard(r: r, now: now),
        const SectionLabel('Sulama · 7 gün'),
        _WaterCard(r: r, now: now),
        if (r.tips.isNotEmpty) ...[
          const SectionLabel('Öneriler'),
          Bento(color: kBentoMint, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final (i, t) in r.tips.indexed) Padding(padding: EdgeInsets.only(top: i == 0 ? 0 : 10), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Padding(padding: EdgeInsets.only(top: 1), child: Icon(Icons.eco_rounded, size: 16, color: kGood)),
              const SizedBox(width: 10),
              Expanded(child: Text(t, style: T.small.copyWith(color: kInk, fontSize: 13.5, height: 1.4))),
            ])),
          ])),
        ],
      ]),
    );
  }
}

class _FrostCard extends StatelessWidget {
  final GardenReport r; final DateTime now;
  const _FrostCard({required this.r, required this.now});
  @override
  Widget build(BuildContext context) {
    final ns = r.nights.take(7).toList();
    if (ns.isEmpty) return Bento(child: Text('Gece tahmini yok.', style: T.small));
    final f = r.nextFrost;
    final head = f == null
        ? (ns.any((n) => n.level == 1) ? 'Hava donmuyor ama toprak yüzeyi donabilir' : 'Önümüzdeki gecelerde don yok')
        : '${_night(f.date, now)} ${frostName(f.level).toLowerCase()}: ${deg(f.air)}';
    return Bento(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 42, height: 42, decoration: BoxDecoration(color: (f == null ? kGood : _frostColors[f.level]).withValues(alpha: .12), shape: BoxShape.circle),
            child: Icon(f == null ? Icons.local_florist_rounded : Icons.ac_unit_rounded, color: f == null ? kGood : _frostColors[f.level], size: 22)),
        const SizedBox(width: 12),
        Expanded(child: Text(head, style: T.body.copyWith(fontWeight: FontWeight.w800, fontSize: 16))),
      ]),
      const SizedBox(height: 14),
      Row(children: [
        for (final n in ns)
          Expanded(child: Semantics(
            label: '${_night(n.date, now)}: ${frostName(n.level)}, hava en düşük ${deg(n.air)}, toprak ${deg(n.ground)}',
            child: ExcludeSemantics(child: Column(children: [
              FittedBox(child: Text(_night(n.date, now),
                  style: T.small.copyWith(fontSize: 11, fontWeight: FontWeight.w700, color: kInkSoft))),
              const SizedBox(height: 6),
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(color: _frostColors[n.level].withValues(alpha: n.level == 0 ? .14 : .2), shape: BoxShape.circle),
                child: Icon(n.level == 0 ? Icons.check_rounded : n.level == 1 ? Icons.grass_rounded : Icons.ac_unit_rounded, size: 17, color: _frostColors[n.level]),
              ),
              const SizedBox(height: 6),
              FittedBox(child: Text(deg(n.air), style: T.body.copyWith(fontWeight: FontWeight.w800, fontSize: 14))),
              FittedBox(child: Text(deg(n.ground), style: T.small.copyWith(fontSize: 11, color: const Color(0xFF8D6E63)))),
            ])),
          )),
      ]),
      const SizedBox(height: 10),
      Wrap(spacing: 12, runSpacing: 4, children: [
        Text('Üstte: en düşük hava', style: T.small.copyWith(fontSize: 11)),
        Text(Plain.t('Altta: toprak yüzeyi', 'Altta: toprağın üstü'), style: T.small.copyWith(fontSize: 11, color: const Color(0xFF8D6E63))),
      ]),
    ]));
  }
}

class _SoilCard extends StatelessWidget {
  final GardenReport r;
  const _SoilCard({required this.r});
  @override
  Widget build(BuildContext context) {
    final t = r.soil3d;
    return Bento(color: kBentoSand, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('6 CM DERİNLİK', style: T.label.copyWith(fontSize: 10)),
          Text(t.isNaN ? '–' : deg(t), style: T.h1.copyWith(fontSize: 38, color: const Color(0xFF6D4C41))),
        ]),
        const SizedBox(width: 12),
        Expanded(child: Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(
          '3 günlük ortalama${r.soilNow.isNaN ? '' : ' · şu an ${deg(r.soilNow)}'}',
          style: T.small.copyWith(fontWeight: FontWeight.w600)))),
      ]),
      const SizedBox(height: 10),
      if (r.crops.every((c) => !c.ok && c.why == r.crops.first.why)) ...[
        // Hepsi aynı nedenle bekliyorsa (kar, don): nedeni bir kez yaz, ürünleri sade etiketlerle göster.
        Text('${r.crops.first.why}: şimdilik ekim zamanı değil.', style: T.body.copyWith(fontSize: 14.5, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final c in r.crops)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: .7), borderRadius: BorderRadius.circular(12)),
              child: Text('${c.crop.name} ${c.crop.minSoil.round()}°+', style: T.small.copyWith(fontSize: 12, fontWeight: FontWeight.w600)),
            ),
        ]),
      ] else
        for (final c in r.crops)
          Padding(padding: const EdgeInsets.only(top: 6), child: Row(children: [
            Icon(c.ok ? Icons.check_circle_rounded : Icons.remove_circle_outline_rounded, size: 19, color: c.ok ? kGood : kInkFaint),
            const SizedBox(width: 10),
            Expanded(child: Text(c.crop.name, style: T.body.copyWith(fontSize: 14.5, fontWeight: FontWeight.w700, color: c.ok ? kInk : kInkSoft))),
            const SizedBox(width: 10),
            Flexible(child: Text(c.ok ? 'Ekilebilir' : c.why, textAlign: TextAlign.end, maxLines: 2,
                style: T.small.copyWith(fontSize: 12, color: c.ok ? kGood : kInkSoft, fontWeight: c.ok ? FontWeight.w700 : FontWeight.w500))),
          ])),
    ]));
  }
}

class _SprayCard extends StatelessWidget {
  final GardenReport r; final DateTime now;
  const _SprayCard({required this.r, required this.now});
  @override
  Widget build(BuildContext context) {
    if (r.spray.isEmpty) {
      return Bento(child: Row(children: [
        Container(width: 42, height: 42, decoration: BoxDecoration(color: kWarn.withValues(alpha: .12), shape: BoxShape.circle),
            child: const Icon(Icons.block_rounded, color: kWarn, size: 21)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('3 gün içinde uygun saat yok', style: T.body.copyWith(fontWeight: FontWeight.w800)),
          Text(r.sprayBlock ?? '', style: T.small.copyWith(fontSize: 12.5)),
        ])),
      ]));
    }
    return Bento(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Rüzgâr hafif, yağış yok, sıcaklık uygun:', style: T.small.copyWith(fontSize: 12.5)),
      for (final w in r.spray)
        Padding(padding: const EdgeInsets.only(top: 10), child: Row(children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(color: kGood.withValues(alpha: .12), shape: BoxShape.circle),
              child: const Icon(Icons.water_drop_outlined, color: kGood, size: 21)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${_day(w.from, now)} ${_hh(w.from)}–${_hh(w.to)}', style: T.body.copyWith(fontWeight: FontWeight.w800)),
            Text('${deg(w.temp)} · rüzgâr en çok ${Plain.wind(w.wind, digits: 0)}', style: T.small.copyWith(fontSize: 12.5)),
          ])),
        ])),
    ]));
  }
}

class _WaterCard extends StatelessWidget {
  final GardenReport r; final DateTime now;
  const _WaterCard({required this.r, required this.now});
  @override
  Widget build(BuildContext context) {
    final ws = r.water;
    final top = ws.isEmpty ? 1.0 : max(4.0, ws.map((w) => max(w.rain, w.et0.isNaN ? 0.0 : w.et0)).reduce(max));
    const rainC = Color(0xFF3B7DDD), etC = Color(0xFFE59A14);
    return Bento(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(r.waterVerdict, style: T.body.copyWith(fontWeight: FontWeight.w700, fontSize: 14.5)),
      if (ws.isNotEmpty) ...[
        const SizedBox(height: 14),
        Semantics(
          label: 'Günlük yağış ve buharlaşma: ${ws.map((w) => '${_day(w.date, now)} yağış ${w.rain.toStringAsFixed(1)}, buharlaşma ${w.et0.isNaN ? '–' : w.et0.toStringAsFixed(1)} milimetre').join('; ')}',
          child: ExcludeSemantics(child: SizedBox(height: 96, child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (final w in ws)
              Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Container(width: 9, height: max(2.0, 64 * w.rain / top), decoration: BoxDecoration(color: rainC, borderRadius: BorderRadius.circular(3))),
                  const SizedBox(width: 3),
                  Container(width: 9, height: max(2.0, 64 * (w.et0.isNaN ? 0 : w.et0) / top), decoration: BoxDecoration(color: etC, borderRadius: BorderRadius.circular(3))),
                ]),
                const SizedBox(height: 6),
                Text(_day(w.date, now), maxLines: 1, overflow: TextOverflow.clip, style: T.small.copyWith(fontSize: 10.5, fontWeight: FontWeight.w700)),
              ])),
          ]))),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 14, runSpacing: 4, children: [
          for (final (c, t) in [(rainC, 'Yağış'), (etC, Plain.t('Buharlaşma (ET₀)', 'Bitkinin harcadığı su'))])
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 9, height: 9, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
              const SizedBox(width: 5),
              Text(t, style: T.small.copyWith(fontSize: 11.5)),
            ]),
          Text('1 mm = metrekareye 1 litre', style: T.small.copyWith(fontSize: 11.5, color: kInkFaint)),
        ]),
      ],
    ]));
  }
}
