// Hava koşullarına göre ETA düzeltmesi ve geçit kapanma uyarıları.
// Saf Dart. Girdi: WeatherSnapshot (birimler: sıcaklık °C, rüzgâr m/s,
// yağış mm/sa, kar cm/sa, görüş m) ve Analysis.
import 'dart:math' as math;

import '../data/models.dart';

/// Düzeltilmiş süre, uygulanan hız çarpanı ve Türkçe açıklama.
/// [factor] 0.3-1.0 arası; süre = base / factor.
typedef EtaResult = ({Duration eta, double factor, String reasonTr});

/// Hava koşullarına göre ETA. Her koşul bir hız çarpanı verir; en kısıtlayıcı
/// olan temel alınır, her ek koşul için ×0.95 uygulanır. Alt sınır 0.3.
///
/// Sabit eşikler:
/// - Tipi: a.kind == blizzard, blizzardProb >= 60, ya da görüş < 300 m ve rüzgâr >= 10 m/s -> ×0.55
/// - Kar: kind == snow, snowProb >= 60 ya da kar >= 0.5 cm/sa -> ×0.75 (mercimek kar ×0.80)
/// - Buzlanma: sleetProb >= 50, ya da sıcaklık <= 0.5 °C ve yağış > 0.1 mm -> ×0.60
/// - Karla karışık yağmur (kind == sleet) -> ×0.80
/// - Yağmur: kind == rain veya (yağış >= 1 mm ve sıcaklık > 2 °C) -> ×0.90
/// - Yoğun sis: fogDensity >= 50 ya da görüş < 500 m (tipi değilse) -> ×0.70
/// - Orta sis: fogDensity >= 30 -> ×0.85
/// - Şiddetli rüzgâr: hamle >= 20 m/s -> ×0.80
EtaResult adjustedEta({
  required double baseSeconds,
  required WeatherSnapshot s,
  required Analysis a,
}) {
  if (baseSeconds < 0) {
    throw ArgumentError.value(baseSeconds, 'baseSeconds', 'Negatif olamaz');
  }

  final tipi = a.kind == PrecipKind.blizzard ||
      a.blizzardProb >= 60 ||
      (s.visibilityM < 300 && s.windSpeed >= 10);
  final kar = a.kind == PrecipKind.snow || a.snowProb >= 60 || s.snowfall >= 0.5;
  final buz = a.sleetProb >= 50 ||
      (s.temp <= 0.5 && s.precip > 0.1);

  final f = <(double factor, String label)>[];
  if (tipi) {
    f.add((0.55, 'tipi'));
  } else {
    if (a.kind == PrecipKind.lentilSnow) {
      f.add((0.80, 'mercimek kar'));
    } else if (kar) {
      f.add((0.75, 'kar'));
    }
  }
  if (buz) f.add((0.60, 'buzlanma riski'));
  if (a.kind == PrecipKind.sleet) f.add((0.80, 'karla karışık yağış'));
  if (a.kind == PrecipKind.rain || (s.precip >= 1.0 && s.temp > 2)) {
    f.add((0.90, 'yağmur'));
  }
  if (a.fogDensity >= 50 || (s.visibilityM < 500 && !tipi)) {
    f.add((0.70, 'yoğun sis / düşük görüş'));
  } else if (a.fogDensity >= 30) {
    f.add((0.85, 'orta sis'));
  }
  if (s.windGust >= 20) f.add((0.80, 'şiddetli rüzgâr'));

  if (f.isEmpty) {
    return (
      eta: Duration(milliseconds: (baseSeconds * 1000).round()),
      factor: 1.0,
      reasonTr: 'Yol ve hava koşulları normal; süre değişmedi.',
    );
  }

  f.sort((x, y) => x.$1.compareTo(y.$1));
  var factor = f.first.$1;
  for (var i = 1; i < f.length; i++) {
    factor *= 0.95;
  }
  factor = math.max(0.3, math.min(1.0, factor));

  final parts = f.map((e) => '${e.$2} (×${e.$1.toStringAsFixed(2)})').join(', ');
  final extraPct = ((1 / factor - 1) * 100).round();
  return (
    eta: Duration(milliseconds: (baseSeconds / factor * 1000).round()),
    factor: factor,
    reasonTr: 'Koşullar: $parts. Tahmini süre yaklaşık %$extraPct uzadı.',
  );
}

/// Dağ geçidi kapanma riski metinleri. [passElevationM] verilmezse konumun
/// rakımı kullanılır. 1200 m altında boş liste döner.
///
/// Risk puanı (0-100) bileşenleri: rakım (1200 m üstü), kar/tipi olasılığı,
/// kar yağış hızı, rüzgâr hamlesi ve görüş. Puan >= 70 yüksek, >= 45 orta,
/// >= 25 dikkat olarak yazılır; ardından ayrıntı satırları eklenir.
List<String> closureWarnings({
  required WeatherSnapshot s,
  required Analysis a,
  double? passElevationM,
}) {
  final elev = passElevationM ?? s.place.elevation ?? 0;
  if (elev <= 1200) return const [];

  var score = 10.0 + math.min(20.0, (elev - 1200) / 100);
  score += 15 * a.snowProb / 100 + 10 * a.blizzardProb / 100;
  if (s.snowfall >= 2) score += 10;
  if (s.windGust >= 18) {
    score += 20;
  } else if (s.windGust >= 12) {
    score += 10;
  }
  if (s.visibilityM < 1000) score += 10;
  score = math.min(100.0, score);

  final String head;
  if (score >= 70) {
    head = 'Geçit kapanma riski YÜKSEK (~${elev.round()} m). Yola çıkmadan önce yol durumunu kontrol et kanki.';
  } else if (score >= 45) {
    head = 'Geçit kapanma riski ORTA (~${elev.round()} m). Ara ara yol durumunu takip et.';
  } else if (score >= 25) {
    head = 'Geçitte dikkatli ol kanki (~${elev.round()} m), hava hızlı değişebilir.';
  } else {
    return const [];
  }

  final out = <String>[head];
  if (s.windGust >= 12) {
    out.add('Rüzgâr hamlesi ${s.windGust.toStringAsFixed(0)} m/sn: savrulan kar yolu kapatabilir.');
  }
  if (s.snowfall >= 2) {
    out.add('Kar yağışı ${s.snowfall.toStringAsFixed(1)} cm/sa: yamaçlarda birikme hızlı olabilir.');
  }
  if (s.visibilityM < 1000) {
    out.add('Görüş ${s.visibilityM.round()} m: geçitte görüş birden kapanabilir.');
  }
  if (a.blizzardProb >= 40) {
    out.add('Tipi olasılığı %${a.blizzardProb.round()}: geçit bir anda kapanabilir.');
  }
  return out;
}
