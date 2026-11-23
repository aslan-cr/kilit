import '../data/models.dart';

/// Önümüzdeki ~2 saatin yağış özeti (15 dakikalık tahminden).
class Nowcast {
  final bool wetNow, any, snow;
  final int? startsIn, endsIn; // dakika (5'e yuvarlı)
  final String headline;
  const Nowcast({required this.wetNow, required this.any, required this.snow, this.startsIn, this.endsIn, required this.headline});

  /// 15 dakikada ≥ 0,05 mm (≈ 0,2 mm/saat) yağış sayılır.
  static const wet = .05;

  /// Saatlik yoğunluk (mm/sa) → gündelik sözcük.
  static String intensity(double mmPer15) {
    final r = mmPer15 * 4;
    return r < 2.5 ? 'hafif' : r < 7.6 ? 'orta' : 'kuvvetli';
  }

  static int _round5(int m) => ((m + 2) ~/ 5) * 5;

  static Nowcast of(List<NowPoint> pts, DateTime now, {Duration window = const Duration(hours: 2)}) {
    final w = pts.where((p) => p.time.add(const Duration(minutes: 15)).isAfter(now) && p.time.isBefore(now.add(window))).toList();
    if (w.isEmpty) return const Nowcast(wetNow: false, any: false, snow: false, headline: 'Kısa vadeli yağış verisi yok');
    final wetNow = w.first.precip >= wet;
    final any = w.any((p) => p.precip >= wet);
    final snow = w.where((p) => p.precip >= wet).any((p) => p.snowfall > 0);
    final noun = snow ? 'Kar' : 'Yağmur';
    int mins(DateTime t) => _round5(t.difference(now).inMinutes.clamp(0, 600));
    if (!any) return const Nowcast(wetNow: false, any: false, snow: false, headline: 'Önümüzdeki 2 saatte yağış yok');
    if (wetNow) {
      final dry = w.skip(1).where((p) => p.precip < wet);
      if (dry.isEmpty) {
        final peak = w.map((p) => p.precip).reduce((a, b) => a > b ? a : b);
        return Nowcast(wetNow: true, any: true, snow: snow, headline: '$noun 2 saat boyunca sürüyor (${intensity(peak)})');
      }
      final m = mins(dry.first.time);
      return Nowcast(wetNow: true, any: true, snow: snow, endsIn: m, headline: m <= 5 ? '$noun birazdan diniyor' : '$noun ~$m dk sonra diniyor');
    }
    final first = w.firstWhere((p) => p.precip >= wet);
    final m = mins(first.time);
    return Nowcast(wetNow: false, any: true, snow: snow, startsIn: m,
        headline: m <= 5 ? '$noun birazdan başlıyor' : '$noun ~$m dk sonra başlıyor (${intensity(first.precip)})');
  }
}
