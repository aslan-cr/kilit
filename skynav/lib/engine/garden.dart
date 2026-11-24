import 'dart:math';
import '../astro/astro_math.dart' show sunAltitude;
import '../data/models.dart';

/// Bir gecenin don durumu (akşam 18:00 → sabah 09:00).
/// [level]: 0 don yok, 1 yer donu (yalnızca toprak yüzeyi), 2 hafif (0…−2 °C), 3 orta (−2…−4), 4 kuvvetli (< −4).
class FrostNight {
  final DateTime date; // gecenin başladığı gün
  final double air, ground; // en düşük hava ve toprak yüzeyi sıcaklığı
  final int level;
  const FrostNight(this.date, this.air, this.ground, this.level);
}

String frostName(int level) => const ['Don yok', 'Yer donu', 'Hafif don', 'Orta don', 'Kuvvetli don'][level.clamp(0, 4)];

/// Bir ürünün çimlenmesi için gereken en düşük toprak sıcaklığı (6 cm).
class Crop {
  final String name;
  final double minSoil;
  /// Sıcak sever: ekimden sonra don olmamalı.
  final bool tender;
  const Crop(this.name, this.minSoil, {this.tender = false});
}

/// Genel kabul gören en düşük çimlenme sıcaklıkları (yaklaşık).
const crops = <Crop>[
  Crop('Buğday, arpa', 4),
  Crop('Ispanak, marul', 5),
  Crop('Patates', 8),
  Crop('Mısır', 10, tender: true),
  Crop('Fasulye', 12, tender: true),
  Crop('Domates, biber fidesi', 15, tender: true),
  Crop('Karpuz, kavun', 18, tender: true),
];

class CropState {
  final Crop crop;
  final bool ok;
  final String why;
  const CropState(this.crop, this.ok, this.why);
}

/// İlaçlama için uygun aralık.
class SprayWindow {
  final DateTime from, to;
  final double wind, temp;
  const SprayWindow(this.from, this.to, this.wind, this.temp);
}

/// Günlük su dengesi: yağış ve bitkinin buharlaştırdığı su (ET₀, mm = litre/m²).
class WaterDay {
  final DateTime date;
  final double rain, et0;
  const WaterDay(this.date, this.rain, this.et0);
}

class GardenReport {
  final List<FrostNight> nights;
  /// 6 cm toprak sıcaklığı: şu an ve önümüzdeki 3 günün ortalaması (yoksa NaN).
  final double soilNow, soil3d;
  final bool soilFrozen, snowCover;
  final List<CropState> crops;
  final List<SprayWindow> spray;
  final String? sprayBlock;
  final List<WaterDay> water;
  final String waterVerdict;
  final List<String> tips;
  const GardenReport({required this.nights, required this.soilNow, required this.soil3d, required this.soilFrozen, required this.snowCover,
      required this.crops, required this.spray, required this.sprayBlock, required this.water, required this.waterVerdict, required this.tips});
  FrostNight? get nextFrost => nights.where((n) => n.level >= 2).firstOrNull;
}

/// FAO-56 Hargreaves: günlük referans buharlaşma (mm/gün). [doy]: yılın günü.
double et0Hargreaves(double tMax, double tMin, double latDeg, int doy) {
  if (tMax.isNaN || tMin.isNaN) return double.nan;
  final phi = latDeg * pi / 180;
  final dr = 1 + .033 * cos(2 * pi * doy / 365);
  final dec = .409 * sin(2 * pi * doy / 365 - 1.39);
  final ws = acos((-tan(phi) * tan(dec)).clamp(-1.0, 1.0));
  final ra = 24 * 60 / pi * .082 * dr * (ws * sin(phi) * sin(dec) + cos(phi) * cos(dec) * sin(ws));
  final tm = (tMax + tMin) / 2;
  return max(0.0, .0023 * (tm + 17.8) * sqrt(max(0.0, tMax - tMin)) * .408 * ra);
}

int _doy(DateTime d) => d.difference(DateTime(d.year)).inDays + 1;

/// Bahçe & tarla raporu: don takvimi, ekim için toprak, ilaçlama saatleri, sulama.
/// Saf hesaptır; tüm değerler tahminden çıkarılır.
GardenReport gardenReport(WeatherSnapshot s, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final hs = s.hourly;

  // 1) Don takvimi: bu geceden başlayarak (sabah 06'dan önce: süren gece dahil), saatlik veri izin verdikçe.
  final nights = <FrostNight>[];
  for (var d = now.hour < 6 ? -1 : 0; d < 7; d++) {
    final a = today.add(Duration(days: d, hours: 18)), b = today.add(Duration(days: d + 1, hours: 9));
    final n = hs.where((h) => !h.time.isBefore(a) && h.time.isBefore(b) && !h.time.isBefore(now.subtract(const Duration(hours: 1)))).toList();
    if (n.length < (d < 0 ? 2 : 6)) continue;
    final air = n.map((h) => h.temp).reduce(min);
    final gs = n.map((h) => h.surface).where((v) => !v.isNaN);
    final ground = gs.isEmpty ? air : gs.reduce(min);
    final lv = air < -4 ? 4 : air < -2 ? 3 : air <= 0 ? 2 : ground <= 0 ? 1 : 0;
    nights.add(FrostNight(today.add(Duration(days: d)), air, ground, lv));
  }

  // 2) Ekim: 6 cm toprak sıcaklığı (şimdi ve önümüzdeki 72 saat ortalaması).
  final next72 = hs.where((h) => !h.time.isBefore(now.subtract(const Duration(hours: 1))) && h.time.isBefore(now.add(const Duration(hours: 72)))).toList();
  final s6 = next72.map((h) => h.soil6).where((v) => !v.isNaN).toList();
  final soilNow = s.soil6 ?? (s6.isEmpty ? double.nan : s6.first);
  final soil3d = s6.isEmpty ? soilNow : s6.reduce((a, b) => a + b) / s6.length;
  final surf = next72.map((h) => h.surface).where((v) => !v.isNaN).toList();
  final soilFrozen = (surf.isNotEmpty && surf.reduce((a, b) => a + b) / surf.length <= 0) || (!soil3d.isNaN && soil3d <= 0);
  final snowCover = (s.snowDepthM ?? 0) >= .02;
  final frostAhead = nights.any((n) => n.level >= 2);
  final cropStates = <CropState>[
    for (final c in crops)
      if (soil3d.isNaN)
        CropState(c, false, 'Toprak verisi yok')
      else if (soilFrozen || snowCover)
        CropState(c, false, snowCover ? 'Toprak karla örtülü' : 'Toprak donuk')
      else if (soil3d < c.minSoil)
        CropState(c, false, 'Toprak en az ${c.minSoil.round()}° olmalı')
      else if (c.tender && frostAhead)
        CropState(c, false, 'Toprak uygun ama önümüzde don var')
      else
        CropState(c, true, 'Toprak uygun'),
  ];

  // 3) İlaçlama: önümüzdeki 72 saatte en az 2 saatlik uygun aralıklar.
  // Rüzgâr ≤ 4 m/s (hamle ≤ 7), sıcaklık 5–25 °C, nem ≥ %40, o saat ve sonraki 4 saat kuru, alacakaranlık dahil gündüz.
  final from = DateTime(now.year, now.month, now.day, now.hour);
  final idx = hs.indexWhere((h) => !h.time.isBefore(from));
  final spray = <SprayWindow>[];
  final blocks = <String, int>{};
  if (idx >= 0) {
    final end = min(hs.length - 4, idx + 72);
    int? a;
    for (var i = idx; i <= end; i++) {
      String? why;
      if (i < end) {
        final h = hs[i];
        final gust = h.gust.isNaN ? h.windSpeed * 1.6 : h.gust;
        final dryAhead = hs.sublist(i, min(hs.length, i + 5)).every((x) => x.precip < .1);
        if (sunAltitude(s.place.lat, s.place.lon, h.time.add(const Duration(minutes: 30)).toUtc()) < -6) {
          why = 'dark';
        } else if (!dryAhead) {
          why = 'Yağış: ilaç yıkanır';
        } else if (h.windSpeed > 4 || gust > 7) {
          why = 'Rüzgâr: ilaç savrulur';
        } else if (h.temp < 5) {
          why = 'Hava çok soğuk';
        } else if (h.temp > 25) {
          why = 'Hava çok sıcak: ilaç buharlaşır';
        } else if (h.humidity < 40) {
          why = 'Hava çok kuru';
        }
      } else {
        why = 'end';
      }
      if (why == null) {
        a ??= i;
      } else {
        if (why != 'dark' && why != 'end') blocks[why] = (blocks[why] ?? 0) + 1;
        if (a != null && i - a >= 2) {
          final w = hs.sublist(a, i);
          spray.add(SprayWindow(w.first.time, w.last.time.add(const Duration(hours: 1)), w.map((h) => h.windSpeed).reduce(max),
              w.map((h) => h.temp).reduce((x, y) => x + y) / w.length));
        }
        a = null;
      }
    }
  }
  final String? sprayBlock = spray.isNotEmpty
      ? null
      : blocks.isEmpty ? 'Önümüzdeki 3 günde uygun saat yok' : blocks.entries.reduce((x, y) => y.value > x.value ? y : x).key;

  // 4) Sulama: 7 günlük yağış − buharlaşma.
  final water = <WaterDay>[
    for (final d in s.daily.where((d) => !d.date.isBefore(today)).take(7))
      WaterDay(d.date, d.precipSum.isNaN ? 0 : d.precipSum, et0Hargreaves(d.tMax, d.tMin, s.place.lat, _doy(d.date))),
  ];
  final rain = water.fold<double>(0, (t, w) => t + w.rain);
  final et = water.fold<double>(0, (t, w) => t + (w.et0.isNaN ? 0 : w.et0));
  final bal = rain - et;
  final String waterVerdict;
  if (soilFrozen || snowCover) {
    waterVerdict = snowCover ? 'Toprak karla örtülü: sulama gerekmez.' : 'Toprak donuk: sulama gerekmez, su donup köklere zarar verebilir.';
  } else if (water.isEmpty) {
    waterVerdict = 'Günlük veri yok.';
  } else if (bal >= -5) {
    waterVerdict = 'Yağış yetiyor: bu hafta sulamaya pek gerek yok.';
  } else {
    final need = (-bal).round();
    waterVerdict = 'Bu hafta yağış az: metrekareye yaklaşık $need litre su ver (2–3 seferde, sabah ya da akşam).';
  }

  // İpuçları
  final tips = <String>[];
  final nf = nights.where((n) => n.level >= 2).firstOrNull;
  if (nf != null && !snowCover) {
    tips.add('Don gecesinden önce fidanları ve çiçekleri örtüyle (tülbent, naylon değil) koru; saksıları içeri al.');
    if (!soilFrozen) tips.add('Don beklenen akşam toprağı hafifçe sula: nemli toprak ısıyı daha uzun tutar.');
  }
  if (nights.any((n) => n.level == 1)) tips.add('Yer donu: hava 0°\'ın üstünde olsa da toprak yüzeyi donuyor. Yeni çıkan filizler zarar görebilir.');
  if (snowCover) tips.add('Kar örtüsü bitkileri soğuktan korur; dalları kırmasın diye ağaçlardaki ağır karı silkele.');
  if (spray.isNotEmpty) tips.add('İlaçlamayı arıları korumak için sabah erken ya da akşamüstü yap; çiçekli bitkiye öğlen ilaç atma.');
  return GardenReport(nights: nights, soilNow: soilNow, soil3d: soil3d, soilFrozen: soilFrozen, snowCover: snowCover, crops: cropStates,
      spray: spray.take(4).toList(), sprayBlock: sprayBlock, water: water, waterVerdict: waterVerdict, tips: tips);
}

/// Keşfet kutusu için kısa özet.
String gardenTeaser(WeatherSnapshot s, DateTime now) {
  final r = gardenReport(s, now);
  final f = r.nextFrost;
  if (f != null) {
    final d = f.date.difference(DateTime(now.year, now.month, now.day)).inDays;
    final when = d < 0 ? 'şu an' : d == 0 ? 'bu gece' : d == 1 ? 'yarın gece' : '$d gün sonra';
    final t = f.air.round();
    return 'Don: $when ${t < 0 ? '−' : ''}${t.abs()}°';
  }
  if (r.spray.isNotEmpty) return 'İlaçlama: ${r.spray.first.from.hour.toString().padLeft(2, '0')}:00';
  final g = r.soil3d.isNaN ? null : r.soil3d.round();
  return 'Don yok · toprak ${g == null ? '–' : '${g < 0 ? '−' : ''}${g.abs()}°'}';
}

/// Akşam don bildirimi: yalnızca ılık günlerden sonra gelen "sürpriz" don gecesi (bahçe ve fidanlar için).
/// Kışın her gece don olan yerlerde rahatsız etmez. Saf hesap; arka plan görevi kullanır (Hive yok).
class FrostNotice {
  final String key, title, body;
  const FrostNotice(this.key, this.title, this.body);
}

FrostNotice? frostNotice(WeatherSnapshot s, DateTime now) {
  if (now.hour < 16 || now.hour >= 21) return null;
  if ((s.snowDepthM ?? 0) >= .02) return null;
  final today = DateTime(now.year, now.month, now.day);
  final a = today.add(const Duration(hours: 18)), b = today.add(const Duration(days: 1, hours: 9));
  final night = s.hourly.where((h) => !h.time.isBefore(a) && h.time.isBefore(b)).toList();
  if (night.length < 10) return null;
  final low = night.map((h) => h.temp).reduce(min);
  if (low > 0) return null;
  // Son 48 saatte gündüz en az 8 °C olmalı (büyüme mevsimi; bitkiler dona hazırlıksız)
  final past = s.hourly.where((h) => h.time.isBefore(now) && h.time.isAfter(now.subtract(const Duration(hours: 48)))).toList();
  if (past.isEmpty || past.map((h) => h.temp).reduce(max) < 8) return null;
  final lv = low < -4 ? 4 : low < -2 ? 3 : 2;
  final at = night.firstWhere((h) => h.temp <= 0).time;
  final t = low.round();
  return FrostNotice('frost-${today.year}-${today.month}-${today.day}', 'Bu gece ${frostName(lv).toLowerCase()}',
      '${at.hour.toString().padLeft(2, '0')}:00 sonrası hava donuyor, en düşük ${t < 0 ? '−' : ''}${t.abs()}°. Fidanları ört, saksıları içeri al kanki.');
}
