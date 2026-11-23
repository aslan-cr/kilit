import 'dart:math';
import 'astro_math.dart';
import 'sky_times.dart' show nextMoonPhase;
import 'space_events.dart';

/// Gökyüzü takviminde bir olay.
class SkyEvent {
  final DateTime at;       // yerel gösterim için an (meteorlarda tepe gecesi 03:00 yerel)
  final String kind;       // 'meteor' | 'eclipse' | 'full' | 'new'
  final String title, detail;
  final int quality;       // 0..100 gözlem koşulu (meteor: Ay ışığı ve radyant yüksekliği)
  const SkyEvent(this.at, this.kind, this.title, this.detail, {this.quality = -1});
}

const _trShower = {
  'Quadrantids': 'Kuadrantidler', 'Lyrids': 'Liridler', 'Eta Aquariids': 'Eta Akuaridler', 'Perseids': 'Perseidler',
  'Orionids': 'Orionidler', 'Leonids': 'Leonidler', 'Geminids': 'Geminidler', 'Ursids': 'Ursidler',
};

/// Meteor yağmurunun tepe gecesinde (yerel 03:00, en verimli saat) gözlem koşulu.
/// Saatte beklenen ≈ ZHR × sin(radyant yüksekliği) × Ay ışığı çarpanı (kaba, karanlık gök varsayımı).
({int perHour, int quality, double radiantAlt, double moonIllum}) meteorConditions(MeteorShower m, DateTime peakDayLocal, double lat, double lon) {
  final t = DateTime(peakDayLocal.year, peakDayLocal.month, peakDayLocal.day, 3).toUtc();
  final rad = raDecToAltAz(m.radiantRaDeg, m.radiantDecDeg, lat, lon, t).alt;
  final moon = moonRaDec(t);
  final moonUp = raDecToAltAz(moon.raDeg, moon.decDeg, lat, lon, t).alt > 0;
  final illum = moonPhaseInfo(t).illumination;
  final moonFactor = moonUp ? 1 - .75 * illum : 1.0;
  final altFactor = rad <= 0 ? 0.0 : sin(rad * pi / 180);
  final perHour = (m.zhr * altFactor * moonFactor * .6).round(); // .6: şehir dışı ama kusursuz olmayan gök
  final quality = (100 * altFactor * moonFactor).round().clamp(0, 100);
  return (perHour: perHour, quality: quality, radiantAlt: rad, moonIllum: moonUp ? illum : 0);
}

/// [from]'dan itibaren [days] gün içindeki gökyüzü olayları, tarihe göre.
List<SkyEvent> skyCalendar(DateTime from, double lat, double lon, {int days = 120}) {
  final end = from.add(Duration(days: days));
  final out = <SkyEvent>[];
  // Meteor yağmurları (her biri için sıradaki tepe)
  for (final m in meteorShowers) {
    var peak = DateTime(from.year, m.peakMonth, m.peakDay);
    if (peak.isBefore(DateTime(from.year, from.month, from.day))) peak = DateTime(from.year + 1, m.peakMonth, m.peakDay);
    if (peak.isAfter(end)) continue;
    final c = meteorConditions(m, peak, lat, lon);
    final name = _trShower[m.name] ?? m.name;
    final cond = c.radiantAlt <= 0 ? 'buradan radyant ufkun altında kalıyor'
        : c.quality >= 60 ? 'koşullar iyi' : c.quality >= 30 ? 'Ay ışığı biraz engelliyor' : 'Ay parlak, sönük meteorlar kaybolur';
    out.add(SkyEvent(DateTime(peak.year, peak.month, peak.day, 3), 'meteor', '$name meteor yağmuru',
        'Tepe gecesi, şafaktan önce · saatte ~${c.perHour} meteor · $cond', quality: c.quality));
  }
  // Tutulmalar
  for (final e in eclipses) {
    if (e.utcDay.isBefore(from.toUtc().subtract(const Duration(days: 1))) || e.utcDay.isAfter(end.toUtc())) continue;
    out.add(SkyEvent(e.utcDay.toLocal(), 'eclipse', '${e.kind} tutulması (${e.type})', e.visibleIn));
  }
  // Dolunay ve yeni ay
  var t = from;
  while (true) {
    final f = nextMoonPhase(t, 180);
    if (f.isAfter(end)) break;
    out.add(SkyEvent(f.toLocal(), 'full', 'Dolunay', 'Gece boyu gökte; sönük yıldızlar görünmez'));
    t = f.add(const Duration(days: 2));
  }
  t = from;
  while (true) {
    final n = nextMoonPhase(t, 0);
    if (n.isAfter(end)) break;
    out.add(SkyEvent(n.toLocal(), 'new', 'Yeni ay', 'En karanlık geceler: yıldız ve Samanyolu için en iyi zaman'));
    t = n.add(const Duration(days: 2));
  }
  out.sort((a, b) => a.at.compareTo(b.at));
  return out;
}
