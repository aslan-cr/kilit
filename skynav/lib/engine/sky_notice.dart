import '../astro/sky_calendar.dart';

/// Akşam bildirimi için bu gecenin gökyüzü olayı (meteor tepe gecesi ya da Türkiye'den görülen tutulma).
/// [now] akşam saati; olay önümüzdeki 14 saat içinde olmalı. Yoksa null.
({String title, String body, String key})? skyNotice(DateTime now, double lat, double lon) {
  for (final e in skyCalendar(now.subtract(const Duration(hours: 24)), lat, lon, days: 3)) {
    // Tutulma kayıtlarında saat yok: o günün akşamı bildirilir
    if (e.kind == 'eclipse') {
      if (e.at.year == now.year && e.at.month == now.month && e.at.day == now.day && e.detail.contains('Türkiye')) {
        return (title: e.title, body: e.detail, key: 'e${e.at.year}${e.at.month}${e.at.day}');
      }
      continue;
    }
    final dt = e.at.difference(now);
    if (dt.isNegative || dt > const Duration(hours: 14)) continue;
    if (e.kind == 'meteor' && e.quality >= 30) {
      return (title: 'Bu gece ${e.title}', body: '${e.detail}. Şehir ışıklarından uzaklaş, gözlerin 20 dakikada karanlığa alışır kanki.', key: 'm${e.at.year}${e.at.month}${e.at.day}');
    }
  }
  return null;
}
