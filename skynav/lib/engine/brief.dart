import 'dart:math';
import '../data/models.dart';

String _deg(double v) { final r = v.round(); return '${r < 0 ? '−' : ''}${r.abs()}°'; }

/// Bir zaman diliminin baskın havası (gündelik sözcük).
String _period(List<HourPoint> hs) {
  if (hs.isEmpty) return '';
  final snow = hs.fold<double>(0, (a, h) => a + h.snowfall);
  final rain = hs.fold<double>(0, (a, h) => a + max(0, h.precip - h.snowfall * .7));
  if (hs.any((h) => h.weatherCode >= 95)) return 'gök gürültülü sağanaklı';
  if (snow >= .3) return snow >= 4 ? 'yoğun karlı' : 'karlı';
  if (rain >= .3) return rain >= 6 ? 'sağanak yağışlı' : 'yağmurlu';
  final cloud = hs.map((h) => h.cloud).reduce((a, b) => a + b) / hs.length;
  return cloud < 25 ? 'açık' : cloud < 65 ? 'parçalı bulutlu' : 'kapalı';
}

/// Sabah özeti: bugünün en yüksek/en düşüğü, sabah–öğleden sonra–akşam gidişatı ve kısa bir öneri.
String morningBrief(WeatherSnapshot s, DateTime now) {
  final d0 = DateTime(now.year, now.month, now.day);
  final today = s.daily.where((d) => d.date.year == d0.year && d.date.month == d0.month && d.date.day == d0.day);
  List<HourPoint> range(int a, int b) => s.hourly.where((h) => !h.time.isBefore(d0.add(Duration(hours: a))) && h.time.isBefore(d0.add(Duration(hours: b)))).toList();
  final m = _period(range(6, 12)), a = _period(range(12, 18)), e = _period(range(18, 24));
  final parts = <String>[];
  if (today.isNotEmpty) parts.add('Bugün ${_deg(today.first.tMin)} / ${_deg(today.first.tMax)}');
  if (m.isNotEmpty && m == a && a == e) {
    parts.add('gün boyu $m');
  } else {
    final seq = [if (m.isNotEmpty) 'sabah $m', if (a.isNotEmpty && a != m) 'öğleden sonra $a', if (e.isNotEmpty && e != a) 'akşam $e'];
    if (seq.isNotEmpty) parts.add(seq.join(', '));
  }
  final day = range(6, 22);
  final tips = <String>[];
  if (day.any((h) => h.weatherCode >= 95)) tips.add('Açıkta kalma, şimşek çakabilir.');
  if (day.fold<double>(0, (t, h) => t + h.snowfall) >= .3) {
    tips.add('Kalın giyin, yollar kaygan olabilir.');
  } else if (day.fold<double>(0, (t, h) => t + h.precip) >= .5) {
    tips.add('Şemsiyeni al.');
  }
  if (today.isNotEmpty && today.first.tMax <= 3 && tips.isEmpty) tips.add('Sıkı giyin, hava soğuk.');
  final uv = day.map((h) => h.uv).where((u) => u.isFinite).fold<double>(0, max);
  if (uv >= 6) tips.add('Öğlen güneşi yakıyor, krem sür.');
  final gust = day.map((h) => h.gust).where((g) => g.isFinite).fold<double>(0, max);
  if (gust >= 17) tips.add('Rüzgâr sert esecek.');
  final head = parts.join(', ');
  return [if (head.isNotEmpty) '$head.', ...tips.take(2)].join(' ');
}
