import 'dart:math';
import '../data/models.dart';

/// Bir hava uyarısı. [key] aynı uyarının sık tekrarlanmaması için kullanılır.
class WxAlert {
  final String key, title, body;
  const WxAlert(this.key, this.title, this.body);
  @override
  String toString() => '$key: $body';
}

String _hh(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:00';

/// Anlık veri + saatlik tahminden uyarılar, önem sırasıyla. Arka plan görevi de kullanır:
/// saf hesaptır, depolamaya (Hive) dokunmaz.
List<WxAlert> weatherAlerts(WeatherSnapshot s, Analysis a, DateTime now) {
  final out = <WxAlert>[];
  final next6 = s.hourly.where((h) => !h.time.isBefore(now.subtract(const Duration(minutes: 59))) && h.time.isBefore(now.add(const Duration(hours: 6)))).toList();
  final next12 = s.hourly.where((h) => !h.time.isBefore(now.subtract(const Duration(minutes: 59))) && h.time.isBefore(now.add(const Duration(hours: 12)))).toList();
  final past6 = s.hourly.where((h) => h.time.isBefore(now) && h.time.isAfter(now.subtract(const Duration(hours: 6)))).toList();

  // 1) Gök gürültülü fırtına: önümüzdeki 6 saatte WMO 95–99 ya da şu an yüksek CAPE ile yağış.
  final thunder = next6.where((h) => h.weatherCode >= 95).toList();
  if (thunder.isNotEmpty || (s.cape >= 1500 && s.precip > .2)) {
    final at = thunder.isNotEmpty ? thunder.first.time : now;
    out.add(WxAlert('storm', 'Gök gürültülü fırtına',
        '${at.isAfter(now.add(const Duration(minutes: 30))) ? '${_hh(at)} civarı ' : 'Şu an '}gök gürültülü sağanak bekleniyor. Açık alanda ve ağaç altında kalma kanki.'));
  }

  // 2) Tipi
  if (a.blizzardProb >= 50) out.add(WxAlert('blizzard', 'Tipi', 'Tipi ihtimali %${a.blizzardProb.round()} kanki, görüş düşebilir. Yola çıkacaksan dikkat!'));

  // 3) Buzlanma: donan çisenti/yağmur; ya da ıslak zemin donmaya geçiyor; ya da donma altında doymuş hava (kırağı/gizli buz).
  final freezingRain = next6.where((h) => const {56, 57, 66, 67}.contains(h.weatherCode)).toList();
  DateTime? iceAt;
  if (freezingRain.isNotEmpty) {
    iceAt = freezingRain.first.time;
  } else {
    final wet = [...past6, ...next12].any((h) => h.precip - h.snowfall * .7 >= .2 && h.temp > 0);
    final freeze = next12.where((h) => h.temp <= -.5).toList();
    if (wet && freeze.isNotEmpty) iceAt = freeze.first.time;
    if (iceAt == null && s.temp <= 0 && s.humidity >= 92 && (s.temp - s.dewPoint) <= 1.2 && !s.isDay) iceAt = now;
  }
  if (iceAt != null) {
    out.add(WxAlert('ice', 'Buzlanma',
        'Buzlanma riski${iceAt.isAfter(now.add(const Duration(minutes: 30))) ? ' (${_hh(iceAt)} sonrası)' : ''}: yollar ve kaldırımlar gizli buz tutabilir. Yavaş sür, dikkatli yürü kanki.'));
  }

  // 4) Yoğun kar: 6 saatte ≥ 6 cm ya da tek saatte ≥ 2 cm.
  final snow6 = next6.fold<double>(0, (t, h) => t + h.snowfall);
  final peak = next6.isEmpty ? 0.0 : next6.map((h) => h.snowfall).reduce(max);
  if (snow6 >= 6 || peak >= 2) {
    out.add(WxAlert('heavySnow', 'Yoğun kar', 'Önümüzdeki 6 saatte yaklaşık ${snow6.round()} cm kar bekleniyor. Zincir/kar lastiği yanında olsun kanki.'));
  }

  // 5) Rüzgâr fırtınası
  final gustNext = next6.map((h) => h.gust).where((g) => !g.isNaN).fold<double>(0, max);
  final gust = max(s.windGust, gustNext);
  if (gust >= 24) out.add(WxAlert('gale', 'Fırtına', 'Fırtına hamlesi ${gust.round()} m/s (${(gust * 3.6).round()} km/s). Savrulacak şeyleri topla kanki.'));

  // 6) Diğerleri (eski uyarılar)
  if (a.lentilProb >= 50) out.add(WxAlert('lentil', 'Mercimek karı', 'Mercimek karı ihtimali %${a.lentilProb.round()}!'));
  if (a.snowProb >= 50 && !out.any((e) => e.key == 'heavySnow')) out.add(WxAlert('snow', 'Kar', 'Kar ihtimali %${a.snowProb.round()}, yağıyor olabilir kanki.'));
  if (s.temp >= 38) out.add(WxAlert('heat', 'Aşırı sıcak', 'Aşırı sıcak: ${s.temp.round()}°. Gölgede kal, su iç kanki.'));
  return out;
}
