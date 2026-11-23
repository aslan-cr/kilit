import '../data/models.dart';

/// Şu anki sıcaklığın dün aynı saatteki (gerçek, geçmiş saatlik veri) sıcaklıktan farkı. Veri yoksa null.
double? tempVsYesterday(WeatherSnapshot s, DateTime now) {
  final target = now.subtract(const Duration(hours: 24));
  HourPoint? best;
  var gap = 1 << 30;
  for (final h in s.hourly) {
    final d = h.time.difference(target).inMinutes.abs();
    if (d < gap) { gap = d; best = h; }
  }
  if (best == null || gap > 40 || !best.temp.isFinite) return null;
  return s.temp - best.temp;
}

/// "Dün bu saatten 3° daha soğuk." Fark 2°'den küçükse null.
String? yesterdayLine(WeatherSnapshot s, DateTime now) {
  final d = tempVsYesterday(s, now);
  if (d == null || d.abs() < 2) return null;
  return 'Dün bu saatten ${d.abs().round()}° daha ${d < 0 ? 'soğuk' : 'sıcak'}.';
}
