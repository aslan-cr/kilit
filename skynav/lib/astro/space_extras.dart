// Ek yardımcılar: Starlink sinyal kalitesi tahmini, Ay/Mars karşılaştırması,
// pusula kalibrasyon notu. Tüm sayısal değerler ortalama/tahmini değerlerdir.
import 'dart:math' as math;

double _clampD(double v, double lo, double hi) => v < lo ? lo : (v > hi ? hi : v);

/// Starlink sinyal kalitesini kaba bir sezgisel modelle (0-100) tahmin eder.
///
/// - [cloudCover]: bulutluluk yüzdesi (0-100)
/// - [precipMm]: yağış miktarı (mm/saat)
/// - [windMs]: rüzgâr hızı (m/s)
/// - [horizonObstructionPct]: ufuk engeli yüzdesi (0-100; bina, ağaç, dağ)
///
/// Bu bir ölçüm değil, tahmindir; gerçek sinyal kalitesi uydu konumuna ve
/// alıcı donanımına da bağlıdır.
({int score0to100, String noteTr}) starlinkSignalQuality({
  required double cloudCover,
  required double precipMm,
  required double windMs,
  required double horizonObstructionPct,
}) {
  final cloud = _clampD(cloudCover, 0.0, 100.0);
  final precip = math.max(0.0, precipMm);
  final wind = math.max(0.0, windMs);
  final obstruction = _clampD(horizonObstructionPct, 0.0, 100.0);

  var score = 100.0;
  score -= cloud * 0.5;
  if (precip > 0) {
    score -= math.min(25.0, 10.0 + precip * 5.0);
  }
  if (wind > 8.0) {
    score -= math.min(10.0, (wind - 8.0) * 1.0);
  }
  score -= obstruction * 0.8;

  final s = _clampD(score.roundToDouble(), 0.0, 100.0).round();

  final String note;
  if (s >= 80) {
    note = 'Sinyal kalitesi iyi (tahmini). Açık gökyüzü ve düşük engel bekleniyor.';
  } else if (s >= 50) {
    note = 'Sinyal kalitesi orta (tahmini). Bulut veya ufuk engeli kesintilere yol açabilir.';
  } else if (s >= 25) {
    note = 'Sinyal kalitesi zayıf (tahmini). Yağış, yoğun bulut veya engeller belirgin etkili.';
  } else {
    note = 'Sinyal kalitesi çok zayıf (tahmini). Bağlantı kesintileri beklenebilir.';
  }
  return (score0to100: s, noteTr: note);
}

/// Ay ile Mars'ın yüzey ortamını karşılaştıran Türkçe metinler.
/// Tüm değerler ortalama/tahmini olup konum, mevsim ve saate göre değişir.
List<String> moonVsMars() => const [
      'Ay (ortalama, tahmini): gündüz yüzey sıcaklığı yaklaşık +120 °C, gece yaklaşık -130 °C.',
      'Ay\'da atmosfer neredeyse yoktur; sıcaklık farkı ve doğrudan güneş radyasyonu çok serttir.',
      'Mars (ortalama, tahmini): yüzey sıcaklığı ortalama yaklaşık -63 °C; gündüz ve gece arasındaki fark Ay\'a göre daha küçüktür.',
      'Mars yüzey basıncı yaklaşık 6 mbar (Dünya\'nın yaklaşık %0,6\'sı) ve atmosfer ağırlıklı olarak karbondioksittir.',
      'Mars\'ta ince atmosfer, toz fırtınaları ve güneş kaynaklı radyasyon yüzey koşullarını etkiler.',
      'Not: Bu değerler genel ortalama tahminlerdir; kesin değerler konum, mevsim ve saate göre değişir.',
    ];

/// Pusula kalibrasyonu ve manyetik sapma hakkında kısa not.
const String compassCalibrationNote =
    'Pusula kalibrasyonu: Telefonu havada 8 şeklinde birkaç kez çevirin. '
    'Metal yüzeylerden, mıknatıslardan ve elektronik cihazlardan uzak durun. '
    'Manyetik sapma (deklinasyon) bölgeye göre değişir; yönü haritadaki gerçek kuzeyle karşılaştırın.';
