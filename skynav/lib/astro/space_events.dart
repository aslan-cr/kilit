// Meteor yağmurları, tutulmalar, periyodik kuyruklu yıldız notları ve geri sayım.
// Tüm tarihler UTC'dir. Tutulma kayıtlarında saat bilgisi yoktur; yalnızca gün
// kullanılır ve her kayıt o günün UTC gününe karşılık gelir.

class MeteorShower {
  const MeteorShower({
    required this.name,
    required this.peakMonth,
    required this.peakDay,
    required this.zhr,
    required this.radiantRaDeg,
    required this.radiantDecDeg,
    required this.parentBody,
  });

  final String name;
  final int peakMonth;
  final int peakDay;

  /// Zenith saatlik yağış oranı (ideal koşullarda ortalama).
  final int zhr;
  final double radiantRaDeg;
  final double radiantDecDeg;
  final String parentBody;
}

const List<MeteorShower> meteorShowers = [
  MeteorShower(
    name: 'Quadrantids',
    peakMonth: 1,
    peakDay: 4,
    zhr: 120,
    radiantRaDeg: 230.0,
    radiantDecDeg: 49.5,
    parentBody: '2003 EH1 (asteroit kökenli)',
  ),
  MeteorShower(
    name: 'Lyrids',
    peakMonth: 4,
    peakDay: 22,
    zhr: 18,
    radiantRaDeg: 271.4,
    radiantDecDeg: 33.6,
    parentBody: 'C/1861 G1 (Thatcher)',
  ),
  MeteorShower(
    name: 'Eta Aquariids',
    peakMonth: 5,
    peakDay: 6,
    zhr: 50,
    radiantRaDeg: 338.5,
    radiantDecDeg: -1.0,
    parentBody: '1P/Halley',
  ),
  MeteorShower(
    name: 'Perseids',
    peakMonth: 8,
    peakDay: 12,
    zhr: 100,
    radiantRaDeg: 48.0,
    radiantDecDeg: 58.0,
    parentBody: '109P/Swift-Tuttle',
  ),
  MeteorShower(
    name: 'Orionids',
    peakMonth: 10,
    peakDay: 21,
    zhr: 20,
    radiantRaDeg: 95.4,
    radiantDecDeg: 15.9,
    parentBody: '1P/Halley',
  ),
  MeteorShower(
    name: 'Leonids',
    peakMonth: 11,
    peakDay: 17,
    zhr: 15,
    radiantRaDeg: 152.0,
    radiantDecDeg: 22.0,
    parentBody: '55P/Tempel-Tuttle',
  ),
  MeteorShower(
    name: 'Geminids',
    peakMonth: 12,
    peakDay: 14,
    zhr: 150,
    radiantRaDeg: 112.0,
    radiantDecDeg: 32.5,
    parentBody: '3200 Phaethon (asteroit kökenli)',
  ),
  MeteorShower(
    name: 'Ursids',
    peakMonth: 12,
    peakDay: 22,
    zhr: 10,
    radiantRaDeg: 217.1,
    radiantDecDeg: 75.8,
    parentBody: '8P/Tuttle',
  ),
];

/// Verilen andan sonraki (ya da o gündeki) en yakın meteor yağmuru tepe günü.
({MeteorShower shower, DateTime peakUtc}) nextMeteorShower(DateTime from) {
  final base = DateTime.utc(from.toUtc().year, from.toUtc().month, from.toUtc().day);
  MeteorShower? bestShower;
  DateTime? bestPeak;
  for (final s in meteorShowers) {
    var peak = DateTime.utc(base.year, s.peakMonth, s.peakDay);
    if (peak.isBefore(base)) {
      peak = DateTime.utc(base.year + 1, s.peakMonth, s.peakDay);
    }
    if (bestPeak == null || peak.isBefore(bestPeak)) {
      bestPeak = peak;
      bestShower = s;
    }
  }
  return (shower: bestShower!, peakUtc: bestPeak!);
}

class Eclipse {
  const Eclipse({
    required this.utcDay,
    required this.kind,
    required this.type,
    required this.visibleIn,
  });

  /// Tutulmanın UTC günü (saat bilgisi içermez).
  final DateTime utcDay;

  /// 'Güneş' veya 'Ay'.
  final String kind;

  /// Örn. 'tam', 'halka', 'kısmi'.
  final String type;

  /// Görüldüğü yerler (kısa, bölgesel; kesin değil).
  final String visibleIn;
}

/// 2026-2029 arası tutulmalar. Yalnızca güvenilir bilinen kayıtlar eklenmiştir;
/// 2030-2032 ve belirsiz tarihler bilinçli olarak dahil edilmemiştir.
final List<Eclipse> eclipses = [
  // Tarihler ve türler PyEphem ile Güneş/Ay konumlarından hesaplanarak doğrulandı (2026–2030).
  Eclipse(utcDay: DateTime.utc(2026,2,17), kind: 'Güneş', type: 'halka', visibleIn: 'Antarktika (kısmi: Güney Afrika ve Güney Amerika ucu)'),
  Eclipse(utcDay: DateTime.utc(2026,3,3), kind: 'Ay', type: 'tam', visibleIn: 'Doğu Asya, Avustralya, Pasifik ve Kuzey Amerika'),
  Eclipse(utcDay: DateTime.utc(2026,8,12), kind: 'Güneş', type: 'tam', visibleIn: 'Grönland, İzlanda ve İspanya (kısmi: Avrupa, Kuzey Afrika)'),
  Eclipse(utcDay: DateTime.utc(2026,8,28), kind: 'Ay', type: 'kısmi', visibleIn: 'Amerika, Avrupa ve Afrika'),
  Eclipse(utcDay: DateTime.utc(2027,2,6), kind: 'Güneş', type: 'halka', visibleIn: 'Şili, Arjantin, Güney Atlantik ve Batı Afrika'),
  Eclipse(utcDay: DateTime.utc(2027,2,20), kind: 'Ay', type: 'yarı gölge', visibleIn: 'Amerika, Avrupa, Afrika ve Asya (Türkiye\'den görünür, çok sönük)'),
  Eclipse(utcDay: DateTime.utc(2027,7,18), kind: 'Ay', type: 'yarı gölge', visibleIn: 'Asya, Avustralya ve Pasifik (çok zayıf)'),
  Eclipse(utcDay: DateTime.utc(2027,8,2), kind: 'Güneş', type: 'tam', visibleIn: 'Fas, İspanya, Cezayir, Libya, Mısır, Suudi Arabistan, Yemen (Türkiye\'den kısmi)'),
  Eclipse(utcDay: DateTime.utc(2027,8,17), kind: 'Ay', type: 'yarı gölge', visibleIn: 'Pasifik ve Amerika'),
  Eclipse(utcDay: DateTime.utc(2028,1,12), kind: 'Ay', type: 'kısmi', visibleIn: 'Amerika, Avrupa ve Afrika (çok küçük)'),
  Eclipse(utcDay: DateTime.utc(2028,1,26), kind: 'Güneş', type: 'halka', visibleIn: 'Ekvador, Peru, Brezilya, Portekiz ve İspanya'),
  Eclipse(utcDay: DateTime.utc(2028,7,6), kind: 'Ay', type: 'kısmi', visibleIn: 'Avrupa, Afrika, Asya ve Avustralya'),
  Eclipse(utcDay: DateTime.utc(2028,7,22), kind: 'Güneş', type: 'tam', visibleIn: 'Avustralya ve Yeni Zelanda'),
  Eclipse(utcDay: DateTime.utc(2028,12,31), kind: 'Ay', type: 'tam', visibleIn: 'Avrupa, Afrika, Asya ve Avustralya (Türkiye\'den görünür, yılbaşı akşamı)'),
  Eclipse(utcDay: DateTime.utc(2029,1,14), kind: 'Güneş', type: 'kısmi', visibleIn: 'Kuzey Amerika'),
  Eclipse(utcDay: DateTime.utc(2029,6,12), kind: 'Güneş', type: 'kısmi', visibleIn: 'Kuzey Kutbu çevresi, kuzey Avrupa ve Asya'),
  Eclipse(utcDay: DateTime.utc(2029,6,26), kind: 'Ay', type: 'tam', visibleIn: 'Amerika, Avrupa ve Afrika'),
  Eclipse(utcDay: DateTime.utc(2029,7,11), kind: 'Güneş', type: 'kısmi', visibleIn: 'Şili ve Arjantin\'in güneyi'),
  Eclipse(utcDay: DateTime.utc(2029,12,5), kind: 'Güneş', type: 'kısmi', visibleIn: 'Güney Amerika\'nın güneyi ve Antarktika'),
  Eclipse(utcDay: DateTime.utc(2029,12,20), kind: 'Ay', type: 'tam', visibleIn: 'Amerika, Avrupa, Afrika ve Asya (Türkiye\'den görünür)'),
  Eclipse(utcDay: DateTime.utc(2030,6,1), kind: 'Güneş', type: 'halka', visibleIn: 'Cezayir, Tunus, Yunanistan, Türkiye, Rusya, Çin ve Japonya'),
  Eclipse(utcDay: DateTime.utc(2030,6,15), kind: 'Ay', type: 'kısmi', visibleIn: 'Avrupa, Afrika ve Asya'),
  Eclipse(utcDay: DateTime.utc(2030,11,25), kind: 'Güneş', type: 'tam', visibleIn: 'Namibya, Güney Afrika ve Avustralya'),
  Eclipse(utcDay: DateTime.utc(2030,12,9), kind: 'Ay', type: 'yarı gölge', visibleIn: 'Amerika, Avrupa, Afrika ve Asya'),
];

/// [from] gününden itibaren (aynı UTC günü dahil) bir sonraki tutulma; yoksa null.
Eclipse? nextEclipse(DateTime from) {
  final base = DateTime.utc(from.toUtc().year, from.toUtc().month, from.toUtc().day);
  for (final e in eclipses) {
    if (!e.utcDay.isBefore(base)) return e;
  }
  return null;
}

class Comet {
  const Comet(this.name, this.periodYears, this.nextPerihelionYear, this.noteTr);

  final String name;

  /// Yaklaşık periyot (yıl).
  final double periodYears;

  /// Bilinen bir sonraki günberi yılı (yaklaşık); bilinmiyorsa null.
  final int? nextPerihelionYear;
  final String noteTr;
}

const List<Comet> comets = [
  Comet('1P/Halley', 76.0, 2061,
      'En ünlü periyodik kuyruklu yıldız; bir sonraki günberi geçişi 2061 yılında beklenir.'),
  Comet('2P/Encke', 3.3, null,
      'Bilinen en kısa periyotlu kuyruklu yıldızlardan biri; yaklaşık 3,3 yılda bir döner.'),
  Comet('55P/Tempel-Tuttle', 33.2, 2031,
      'Leonid meteor yağmurunun kaynağıdır; 2031 civarında günberi geçişi beklenir.'),
  Comet('109P/Swift-Tuttle', 133.0, 2126,
      'Perseid meteor yağmurunun kaynağıdır; bir sonraki günberi geçişi yaklaşık 2126.'),
  Comet('67P/Churyumov-Gerasimenko', 6.45, null,
      'Rosetta uzay aracının incelediği kuyruklu yıldız; yaklaşık 6,45 yıllık periyoda sahiptir.'),
];

/// Geri sayım metni (Türkçe). Süre geçmişse 'Şimdi / geçti' döner.
String countdownText(Duration d) {
  if (d.inSeconds <= 0) return 'Şimdi / geçti';
  if (d.inMinutes == 0) return '${d.inSeconds} sn';
  final days = d.inDays;
  final hours = d.inHours % 24;
  final minutes = d.inMinutes % 60;
  if (days > 0) return '$days gün $hours sa $minutes dk';
  if (hours > 0) return '$hours sa $minutes dk';
  return '$minutes dk';
}
