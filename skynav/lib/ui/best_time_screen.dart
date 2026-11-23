import 'package:flutter/material.dart';
import '../data/models.dart';
import '../engine/best_time.dart';
import 'bento.dart';
import 'theme.dart';

const _dayShort = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

String _when(DateTime t, DateTime now) {
  final d = DateTime(t.year, t.month, t.day), today = DateTime(now.year, now.month, now.day);
  final diff = d.difference(today).inDays;
  return diff == 0 ? 'Bugün' : diff == 1 ? 'Yarın' : _dayShort[t.weekday - 1];
}

String _hh(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:00';

/// Kısa özet (Keşfet kutusu için): "Yürüyüş: bugün 14:00".
String bestTimeTeaser(WeatherSnapshot s, DateTime now) {
  final b = bestTimes(s, now).where((e) => e.found).toList();
  if (b.isEmpty) return '2 gün boyunca hava uygun değil';
  final w = b.first;
  return '${w.name}: ${_when(w.start!, now).toLowerCase()} ${_hh(w.start!)}';
}

/// En iyi zaman: yürüyüş, koşu, bisiklet, çamaşır, araba yıkama, yıldız gözlemi için 48 saatin en uygun aralığı.
class BestTimeScreen extends StatelessWidget {
  final WeatherSnapshot s;
  const BestTimeScreen({super.key, required this.s});

  static const _look = {
    'walk': (Icons.directions_walk_rounded, kGood, kBentoMint),
    'run': (Icons.directions_run_rounded, kHeat, kBentoPeach),
    'bike': (Icons.directions_bike_rounded, kAccent, kBentoBlue),
    'laundry': (Icons.local_laundry_service_outlined, Color(0xFF8D6E63), kBentoSand),
    'car': (Icons.local_car_wash_rounded, Color(0xFF4F6BED), Color(0xFFE6EEFF)),
    'stars': (Icons.auto_awesome, Color(0xFFF4ECCF), kBentoNight),
  };

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final slots = bestTimes(s, now);
    return Scaffold(
      backgroundColor: kIce,
      appBar: AppBar(title: const Text('En iyi zaman')),
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 40), children: [
        Text('Önümüzdeki 48 saatin saatlik tahmininden, her iş için en uygun aralık.', style: T.small),
        const SizedBox(height: 12),
        for (final b in slots) ...[
          _SlotCard(b: b, now: now, look: _look[b.key]!),
          const SizedBox(height: 12),
        ],
      ]),
    );
  }
}

class _SlotCard extends StatelessWidget {
  final BestSlot b; final DateTime now; final (IconData, Color, Color) look;
  const _SlotCard({required this.b, required this.now, required this.look});
  @override
  Widget build(BuildContext context) {
    final (icon, fg, bg) = look;
    final night = bg == kBentoNight;
    final ink = night ? const Color(0xFFF4ECCF) : kInk, soft = night ? const Color(0xFF9DA9CF) : kInkSoft;
    return Bento(
      color: bg, padding: const EdgeInsets.all(16),
      child: Row(children: [
        Container(width: 46, height: 46, decoration: BoxDecoration(color: night ? const Color(0x22FFFFFF) : Colors.white.withValues(alpha: .85), shape: BoxShape.circle),
            child: Icon(icon, color: fg, size: 24)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(b.name, style: T.body.copyWith(fontWeight: FontWeight.w800, color: ink)),
          const SizedBox(height: 2),
          Text(b.found ? '${_when(b.start!, now)} ${_hh(b.start!)}–${_hh(b.end!)}' : 'Uygun zaman yok',
              style: T.h2.copyWith(fontSize: 17, color: b.found ? ink : soft)),
          const SizedBox(height: 2),
          Text(b.why, style: T.small.copyWith(fontSize: 12.5, color: soft)),
        ])),
        if (b.found) SizedBox(width: 52, height: 52, child: Stack(alignment: Alignment.center, children: [
          SizedBox.expand(child: CircularProgressIndicator(value: b.score / 100, strokeWidth: 5, strokeCap: StrokeCap.round,
              backgroundColor: night ? const Color(0x22FFFFFF) : Colors.white, color: fg)),
          Text('%${b.score}', style: T.small.copyWith(fontSize: 12, fontWeight: FontWeight.w800, color: ink)),
        ])),
      ]),
    );
  }
}
