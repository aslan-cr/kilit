// Yaşam laboratuvarı hesaplayıcıları. Saf Dart. Eksik veride makul varsayılan kullanır, exception atmaz.
import 'dart:math' as math;

import '../data/models.dart';
import 'formulas.dart';

/// Tüm hesaplayıcıların çıktı listesi.
List<LabResult> computeLab(WeatherSnapshot s, Analysis a, {DateTime? now}) {
  final t = now ?? s.fetchedAt;
  final hasDaily = s.daily.isNotEmpty;
  final tMinToday = hasDaily ? s.daily.first.tMin : s.temp;
  final sunset = hasDaily ? s.daily.first.sunset : null;
  final snowCm = (s.snowDepthM ?? 0) * 100;
  final wbv = s.wetBulb ?? wetBulbC(s.temp, s.humidity);
  final wind = s.windSpeed;
  final rainSoon = s.hourly.take(6).any((h) => h.precip > 0.2);

  final out = <LabResult>[];

  // 1. Kardan Adam Kalitesi
  {
    final depthScore = _c(snowCm / 30 * 100);
    final tempScore = s.temp <= -1 ? 100 : (s.temp <= 1 ? 70 : 10);
    final score = _c(0.7 * depthScore + 0.3 * tempScore);
    out.add(_mk(
      'kardan_adam', '⛄', 'Kardan Adam Kalitesi', '${pct(snowCm)} cm kar', score,
      score >= 70
          ? "Kardan adam için tam kıvamında kanki, malzemeyi kap!"
          : score >= 35
              ? "Kar var ama kardan adam için biraz az kanki, mini bir tane yapabilirsin."
              : "Kardan adam için yeterli kar yok kanki, bu sefer kar topu bile zor.",
      "Kardan adamın kalitesi yerdeki karın derinliğine ve kıvamına bağlı. Derinlik 30 cm civarına yaklaştıkça puan artar; 0 °C civarı ıslak kar daha iyi yapışır, -5 °C altında ise kar toz gibi kalır.",
    ));
  }

  // 2. Kartopu Savaş Skoru
  {
    final packScore = _c(100 - (s.temp + 1).abs() * 25);
    final depthScore = _c(snowCm / 10 * 100);
    final score = _c(0.45 * packScore + 0.35 * depthScore + 0.2 * (wind < 6 ? 100 : 40));
    out.add(_mk(
      'kartopu_savas', '❄️', 'Kartopu Savaş Skoru', 'Skor ${pct(score)}/100', score,
      score >= 65
          ? "Kartopu savaşı için her şey hazır kanki, siperleri kur!"
          : "Kar biraz kuru ya da az kanki, top yapmak zor olabilir.",
      "Kartopu kıvamı -1 °C civarında en iyi olur, çok soğukta kar dağılır. Yerdeki kar derinliği ve rüzgarın sakinliği de skoru etkiler.",
    ));
  }

  // 3. Okul Tatili Kahini (eğlence)
  {
    final score = _c(0.55 * a.snowProb + 0.35 * a.blizzardProb + 0.1 * a.confidence);
    out.add(_mk(
      'okul_tatili', '🏫', 'Okul Tatili Kahini', '%${pct(score)}', score,
      score >= 60
          ? "Kulağına kar fısıldıyor kanki, yine de resmi duyuruyu bekle!"
          : "Bu sefer tatil kahini zayıf kanki, sınav programına bak.",
      "Eğlence amaçlı bir tahmindir. Kar ve tipi ihtimali ile tahmin güvenine dayanır; okul kararları resmi duyurulara göre verilir.",
      entertainment: true,
    ));
  }

  // 4. Kar Erime & Çamur İndeksi
  {
    final meltPart = s.temp > 0 ? s.temp * 8 : 0;
    final score = _c(meltPart + s.precip * 6 + (snowCm > 2 ? 10 : 0));
    out.add(_mk(
      'kar_erime_camur', '💧', 'Kar Erime & Çamur İndeksi', '${pct(score)}/100', score,
      score >= 50
          ? "Kar eriyor, yollar çamura dönebilir kanki; botunu giy."
          : "Erime ve çamur şu an ciddi değil kanki, rahat ol.",
      "Pozitif sıcaklıklar karı eritir, yağış da eriyen karı ve toprağı ıslatarak çamuru artırır. Yerde kar varsa ek puan verilir.",
    ));
  }

  // 5. Kıyafet Katman Hesabı
  {
    final f = s.feelsLike;
    final layers = f >= 25 ? 1 : (f >= 18 ? 2 : (f >= 10 ? 3 : (f >= 0 ? 4 : (f >= -10 ? 5 : 6))));
    final extras = <String>[
      if (s.precip > 0.1) 'yağmurluk',
      if (wind >= 8) 'rüzgarlık',
    ];
    final value = extras.isEmpty ? '$layers katman' : '$layers katman + ${extras.join(' + ')}';
    out.add(_mk(
      'kiyafet_katman', '🧥', 'Kıyafet Katman Hesabı', value, null,
      layers >= 4
          ? "Soğuk kanki, bot ve mont ayarı şart, kat kat giyin!"
          : "Hava ılık kanki, katmanı abartma, hafif giyin yeter.",
      "Hissedilen sıcaklığa göre kaç katman giyileceği hesaplanır. Yağış varsa yağmurluk, rüzgar güçlüyse rüzgarlık eklenir.",
    ));
  }

  // 6. Kombi Tasarruf Koçu
  {
    final need = _c((20 - s.feelsLike) * 4);
    out.add(_mk(
      'kombi_tasarruf', '🔥', 'Kombi Tasarruf Koçu', 'Isıtma ihtiyacı %${pct(need)}', need,
      need > 60
          ? "Kombiyi tamamen kapatma kanki, 20 derece civarında tutmak yeter."
          : (need < 20
              ? "Dışarısı ılık kanki, kombiyi kapat, cüzdanın sevinsin."
              : "Ayarı 1-2 derece kısarsan fark eder kanki."),
      "Dış hissedilen sıcaklık 20 °C'nin altına düştükçe ısıtma ihtiyacı artar. Genelde ayarı birkaç derece düşürmek, fazla ısıtmaya göre belirgin tasarruf sağlar.",
    ));
  }

  // 7. Pencere Buğulanma Uyarısı
  {
    final score = _c((12 - s.temp) * 6);
    out.add(_mk(
      'pencere_bugulanma', '🪟', 'Pencere Buğulanma Uyarısı', '%${pct(score)}', score,
      score >= 60
          ? "Camlar terleyebilir kanki, havalandırmayı ihmal etme."
          : "Pencerelerde buğu riski düşük kanki.",
      "Buğu, içerideki sıcak nemli havanın soğuk cama değmesiyle oluşur. Dış sıcaklık düştükçe cam soğur; hesap iç mekanın yaklaşık 22 °C ve %50 nem olduğunu varsayar.",
    ));
  }

  // 8. Sokak Hayvanı Su Donma Alarmı
  {
    final score = _c((4 - s.temp) * 20);
    out.add(_mk(
      'sokak_hayvani_su', '🐾', 'Sokak Hayvanı Su Donma Alarmı', '%${pct(score)} donma riski', score,
      score >= 60
          ? "Sokaktaki dostlara sıcak su bırak kanki, içmekte zorlanabilirler."
          : "Su donma riski düşük kanki, yine de bir kap bırakmak iyi olur.",
      "Su, sıcaklık sıfıra yaklaşınca ve özellikle gece donabilir. Hesap 4 °C'nin altındaki sıcaklıkları riskli kabul eder.",
    ));
  }

  // 9. Gökkuşağı Dedektörü
  {
    final sunPart = (s.isDay && s.cloudCover >= 20 && s.cloudCover <= 80) ? 40 : 0;
    final wetPart = (s.precip > 0.05 || s.humidity > 85) ? 35 : 0;
    final h = t.hour;
    final angleOk = (h >= 7 && h <= 10) || (h >= 15 && h <= 18);
    final anglePart = angleOk ? 25 : 5;
    final score = _c(sunPart + wetPart + anglePart);
    out.add(_mk(
      'gokkusagi', '🌈', 'Gökkuşağı Dedektörü', 'Olasılık %${pct(score)}', score,
      score >= 60
          ? "Güneş ve yağmur aynı anda, gökyüzüne bak kanki!"
          : "Gökkuşağı için şartlar tam oturmamış kanki.",
      "Gökkuşağı, güneşin arkandayken yağmur damlalarına vurmasıyla oluşur. Güneşin alçak olduğu sabah ve akşam saatleri ile yağış ve açık gökyüzü birlikte aranır.",
    ));
  }

  // 10. Gün Batımı Kızıllık Puanı
  {
    final cloudHighPart = _c(100 - (s.cloudHigh - 40).abs() * 2);
    final dustPart = _c(s.aqDust / 60 * 100);
    final visPart = _c(s.visibilityM / 200);
    var score = 0.45 * cloudHighPart + 0.2 * (100 - s.humidity) + 0.2 * dustPart + 0.15 * visPart;
    if (s.cloudCover > 85) score *= 0.4;
    final sc = _c(score);
    final timeText = sunset == null ? '' : ' - ${_hm(sunset)}';
    out.add(_mk(
      'gun_batimi', '🌇', 'Gün Batımı Kızıllık Puanı', '%${pct(sc)}$timeText', sc,
      sc >= 60
          ? "Akşam gökyüzü yanabilir kanki, batımı izlemeye çık!"
          : "Bu akşam batımı sade olabilir kanki.",
      "Kızıllık, yüksek ince bulutların ve atmosferdeki parçacıkların güneş ışığını renklendirmesiyle oluşur. Yüksek bulutun yaklaşık %40 olması ve kuru hava idealdir; kalın bulut manzarayı kapatır.",
    ));
  }

  // 11. Çamaşır Kurutma Süresi
  {
    var mins = 180.0 *
        (1 + (s.humidity - 40) / 100) *
        (1 - clampD((s.temp - 15) / 40, 0, 1) * 0.5) *
        (1 - clampD(wind / 16, 0, 0.5)) *
        (1 + s.cloudCover / 200);
    if (s.precip > 0.1) mins *= 3;
    if (s.uv >= 3) mins *= 0.9;
    mins = clampD(mins, 45, 900);
    final String kanki;
    if (mins < 120) {
      kanki = "Çamaşır hızlı kuruyacak kanki, ipi hemen ger!";
    } else if (mins < 300) {
      kanki = "Biraz sabır lazım kanki, öğleden sonra bakarsın.";
    } else {
      kanki = "Bu hava çamaşır için ağır kanki, kurutmalık ya da içeri çözüm.";
    }
    out.add(_mk(
      'camasir_kurutma', '👕', 'Çamaşır Kurutma Süresi', '${pct(mins)} dk',
      _c(100 - (mins - 60) / 8), kanki,
      "Süre; nem, sıcaklık, rüzgar, bulutluluk ve yağış ile kabaca tahmin edilir. Nem yüksekse ve rüzgar zayıfsa süre uzar, yağmurda çamaşır dışarıda kurumaz.",
    ));
  }

  // 12. Çay/Kahve Soğuma Dakikası
  {
    const startC = 85.0, drinkC = 60.0;
    final ta = s.temp;
    final k = 0.035 + 0.006 * wind; // dakika başına soğuma katsayısı
    if (ta >= drinkC) {
      out.add(_mk(
        'cay_sogutma', '☕', 'Çay/Kahve Soğuma Dakikası', 'Soğumuyor', null,
        "Dışarısı zaten sıcak kanki, çayın kendi kendine soğumaz.",
        "Dış hava içilebilir sıcaklığın üstünde olduğunda içecek kendi başına soğumaz.",
      ));
    } else {
      final mins = -math.log((drinkC - ta) / (startC - ta)) / k;
      out.add(_mk(
        'cay_sogutma', '☕', 'Çay/Kahve Soğuma Dakikası', '${pct(mins)} dk', null,
        mins < 10
            ? "Çay hemen içilebilir hale gelir kanki, acele et!"
            : "Çayın içilebilir sıcaklığa inmesi için biraz beklemen gerek kanki.",
        "Newton soğuma yasasına göre içecek 85 °C'den başlayıp 60 °C'ye (içilebilir sıcaklık) iner. Rüzgar soğumayı hızlandırır, bu yüzden süre kısalır.",
      ));
    }
  }

  // 13. Saç Kabarma & Statik Elektrik
  {
    final score = _c((40 - s.humidity) * 2.5 + wind * 4 + (s.temp < 5 ? 15 : 0));
    out.add(_mk(
      'sac_statik', '💇', 'Saç Kabarma & Statik Elektrik', '%${pct(score)}', score,
      score >= 60
          ? "Saçın dik dik kalkabilir kanki, nemlendirici sprey yanına al."
          : "Saçın büyük ihtimalle sakin kalır kanki.",
      "Hava kuru ve rüzgarlıysa sürtünme elektriği birikir ve saç kabarır. Kış aylarında ve düşük nemde bu etki artar.",
    ));
  }

  // 14. Araba Yıkama Kahini
  {
    final score = _c((s.precip < 0.1 ? 40 : 0) +
        (rainSoon ? -40 : 20) +
        (s.temp > 3 ? 20 : 0) +
        (wind < 8 ? 15 : 0) +
        (s.aqDust > 30 ? 10 : 0) +
        (a.snowProb < 20 ? 5 : 0));
    out.add(_mk(
      'araba_yikama', '🚗', 'Araba Yıkama Kahini', score >= 60 ? 'Yıkat' : 'Ertele', score,
      score >= 60
          ? "Arabayı yıkatmanın tam zamanı kanki, parlasın!"
          : "Yağmur ya da soğuk var kanki, yıkamayı ertele.",
      "Yıkamanın anlamı, yakın saatlerde yağış olmamasına bağlıdır. Sıcaklık sıfırın üstünde, rüzgar sakin ve yağış yoksa puan artar.",
    ));
  }

  // 15. Mangal Rüzgar Testi
  {
    final kmh = wind * 3.6;
    final score = _c(100 - (wind - 2) * 12);
    out.add(_mk(
      'mangal_ruzgar', '🍖', 'Mangal Rüzgar Testi', '${pct(kmh)} km/sa', score,
      score >= 70
          ? "Mangal yakmak için rüzgar tam uygun kanki, dumanı kimse yüzüne vurmaz."
          : (score >= 40
              ? "Biraz esiyor kanki, mangalı rüzgara ters koy."
              : "Rüzgar çok sert kanki, mangalı bu gün unut."),
      "Sakin havada mangal rahat yanar ve duman dağılır. Rüzgar 8 m/s ve üzerine çıktığında mangal yanmaz hale gelir.",
    ));
  }

  // 16. Balık Tutma Basınç Radarı
  {
    final score = _c(50 + (1013 - s.pressure) * 5 - (wind > 8 ? 15 : 0));
    out.add(_mk(
      'balik_basinc', '🎣', 'Balık Tutma Basınç Radarı', '${pct(s.pressure)} hPa', score,
      score >= 60
          ? "Balıklar bu havada daha hareketli olabilir kanki, olta hazır!"
          : "Basınç ve rüzgar balığa pek uygun değil kanki, sabırlı ol.",
      "Basınç düştükçe balıkların beslenme eğilimi arttığı söylenir. Bu hesap yalnızca mutlak basıncı kullanır; basınç trendi verisi eklenirse doğruluk artar.",
    ));
  }

  // 17. Kamp Uyku Tulumu Derecesi
  {
    final rating = tMinToday - 5;
    final score = _c(60 + tMinToday * 2.5);
    out.add(_mk(
      'kamp_tulum', '⛺', 'Kamp Uyku Tulumu Derecesi', '${pct(rating)} °C tulum', score,
      tMinToday < 0
          ? "Gece donacak kanki, kalın tulum şart!"
          : "Gece serin ama idare eder kanki, ince tulum yeter.",
      "Gecenin en düşük sıcaklığına göre önerilen tulum konfor derecesi hesaplanır. Güvenlik payı olarak yaklaşık 5 °C düşülür.",
    ));
  }

  // 18. Deprem Bulutu / Basınç Anomali Günlüğü (eğlence)
  {
    final dev = s.pressure - 1013;
    final sign = dev >= 0 ? '+' : '';
    final score = _c(dev.abs() * 5);
    out.add(_mk(
      'deprem_bulut', '🌩️', 'Deprem Bulutu / Basınç Anomali Günlüğü',
      '$sign${dev.toStringAsFixed(1)} hPa sapma', score,
      "Bu sadece eğlence kanki, deprem bulutu gerçek bir tahmin değil; basınç sapmasına bakıp gülelim.",
      "Bu hesaplayıcı yalnızca eğlence amaçlıdır ve bilimsel bir deprem tahmini değildir; depremler bugünkü bilimle önceden kestirilemez. Ölçülen basıncın 1013 hPa'dan sapmasını gösterir.",
      entertainment: true,
    ));
  }

  // 19. Migren/Eklem Basınç Uyarısı
  {
    final temps = s.hourly.take(12).map((h) => h.temp).toList();
    final range = temps.isEmpty
        ? 0.0
        : temps.reduce((x, y) => x > y ? x : y) - temps.reduce((x, y) => x < y ? x : y);
    final score = _c((s.pressure - 1013).abs() * 4 + (s.humidity > 80 ? 15 : 0) + (range > 8 ? 20 : 0));
    out.add(_mk(
      'migren_eklem', '🦴', 'Migren/Eklem Basınç Uyarısı', '%${pct(score)}', score,
      score >= 50
          ? "Hava oynak kanki, bol su iç ve kendine iyi bak."
          : "Basınç ve sıcaklık sakin kanki, eklemler rahat olabilir.",
      "Basınç ve sıcaklık değişimleri bazı kişilerde migren ve eklem ağrısını tetikleyebilir. Bu bir genel bilgi aracıdır; tıbbi tavsiye değildir, şikayetin varsa doktoruna danış.",
    ));
  }

  // 20. Polen Riski (vekil göstergelerle)
  {
    final score = _c((s.temp > 12 ? 25 : 0) +
        (wind > 3 ? 25 : 0) +
        (s.humidity < 60 ? 20 : 0) +
        (s.precip < 0.1 ? 15 : 0) +
        (s.uv > 3 ? 15 : 0));
    out.add(_mk(
      'polen_riski', '🌼', 'Polen Riski', '%${pct(score)} (tahmini)', score,
      score >= 60
          ? "Alerjin varsa bu gün burnun isyan edebilir kanki, pencereyi kapat."
          : "Polen riski orta ya da düşük kanki, rahat nefes al.",
      "Gerçek polen sayımı kullanılmaz; rüzgar, sıcaklık, kuraklık ve UV gibi polen dağılımını etkileyen faktörlerden kabaca bir risk üretilir. Alerjin varsa resmi polen takip servislerine de bak.",
    ));
  }

  // 21. Uyku Konforu
  {
    final score = _c(100 - (s.temp - 19).abs() * 8 - math.max(0.0, (s.humidity - 50).abs() - 10) * 1.5);
    out.add(_mk(
      'uyku_konforu', '😴', 'Uyku Konforu', '%${pct(score)}', score,
      score >= 70
          ? "Uyku için ideal bir gece gibi duruyor kanki, yorganı hazırla."
          : "Oda ortamı uykuya tam uygun değil kanki, sıcaklığı biraz ayarla.",
      "Uyku için ideal oda sıcaklığı yaklaşık 18-20 °C ve nem %40-60 arasıdır. Bu hesap dış havayı temel alır, odanın gerçek koşulları farklı olabilir.",
    ));
  }

  // 22. Koşu Nefes/Terleme İndeksi
  {
    final score = _c((s.feelsLike - 5) * 4 + (s.humidity - 40) * 0.8);
    out.add(_mk(
      'kosu_nefes', '🏃', 'Koşu Nefes/Terleme İndeksi', 'Zorluk %${pct(score)}', score,
      score >= 60
          ? "Bu havada koşu zor olacak kanki, su yanında olsun."
          : "Koşu için hava uygun kanki, nefes nefese kalmazsın.",
      "Hissedilen sıcaklık ve nem arttıkça terleme ve nefes zorluğu artar. Yüksek nemde ter buharlaşmadığı için vücut daha zor serinler.",
    ));
  }

  // 23. Güneş Yanığı Sayacı
  {
    final uv = s.uv;
    final minutes = (s.isDay && uv > 0.5) ? 180 / uv : null;
    final String kanki;
    if (uv >= 8) {
      kanki = "UV çok yüksek kanki, şapka ve krem şart!";
    } else if (uv >= 3) {
      kanki = "Güneş var kanki, kremi unutma.";
    } else {
      kanki = "UV düşük kanki, rahat takılabilirsin.";
    }
    out.add(_mk(
      'gunes_yanigi', '☀️', 'Güneş Yanığı Sayacı',
      minutes == null ? 'Güneş yok' : '${pct(minutes)} dk', _c(uv * 10), kanki,
      "Yaklaşık hesap: açık tenli biri için 180 / UV indeksi dakika. Gerçek süre cilt tipine, bulutlara ve yansımaya göre çok değişir.",
    ));
  }

  // Ek: Buzlanma & Yol Kayganlığı
  {
    final score = _c((s.temp >= -6 && s.temp <= 1 ? 40 : 0) +
        (s.humidity > 85 ? 20 : 0) +
        (s.precip > 0.05 ? 25 : 0) +
        (wbv <= 0 ? 15 : 0));
    out.add(_mk(
      'yol_kayganlik', '🧊', 'Buzlanma & Yol Kayganlığı', '%${pct(score)}', score,
      score >= 60
          ? "Yollar kayabilir kanki, frende ve hızına dikkat!"
          : "Yollarda buzlanma riski düşük kanki.",
      "Sıcaklık sıfır civarındayken ve yağış ya da yüksek nem varsa yol yüzeyinde ince buz oluşabilir. Köprü ve gölgeli yerlerde risk daha da artar.",
    ));
  }

  // Ek: Uçurtma Keyfi
  {
    var score = _c(100 - (wind - 7).abs() * 12);
    if (s.precip > 0.1) score *= 0.3;
    out.add(_mk(
      'ucurtma', '🪁', 'Uçurtma Keyfi', '${pct(wind * 3.6)} km/sa', score,
      score >= 60
          ? "Uçurtma uçurmak için rüzgar tam kanki, ipi bırak!"
          : "Rüzgar ya da yağış uçurtma için uygun değil kanki.",
      "Uçurtma için rüzgarın orta şiddette (yaklaşık 4-12 m/s) olması idealdir. Yağış varsa uçurtma keyfi ciddi biçimde düşer.",
    ));
  }

  // Ek: Bahçe Don Koruma
  {
    final score = _c((3 - tMinToday) * 20);
    out.add(_mk(
      'bahce_don', '🌱', 'Bahçe Don Koruma', 'Gece en düşük ${pct(tMinToday)} °C', score,
      score >= 60
          ? "Gece bitkilerin donabilir kanki, örtüyü hazırla."
          : "Bahçe için don riski düşük kanki.",
      "Gecenin en düşük sıcaklığı sıfırın altına yaklaşırsa hassas bitkiler zarar görebilir. Hesap 3 °C'nin altındaki gece minimumlarını riskli kabul eder.",
    ));
  }

  // Ek: Bisiklet Rüzgar Cezası
  {
    final gustExtra = math.max(0.0, s.windGust - wind);
    final score = _c(100 - wind * 8 - gustExtra * 3);
    out.add(_mk(
      'bisiklet_ruzgar', '🚲', 'Bisiklet Rüzgar Cezası', '${pct(wind * 3.6)} km/sa rüzgar', score,
      score >= 65
          ? "Pedal çevirmek keyifli olacak kanki, rüzgar seni itiyor olabilir!"
          : "Rüzgar pedalı ağırlaştırır kanki, rota seç.",
      "Rüzgar hızı ve hamleler bisiklet sürüşünde ek direnç yaratır. Yön bilgisi olmadığı için bu puan yalnızca şiddete dayanır.",
    ));
  }

  return out;
}

double _c(num v) => clampD(v, 0, 100);

String pct(num v) => v.round().toString();

String _hm(DateTime d) =>
    "${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}";

LabResult _mk(
  String id,
  String emoji,
  String title,
  String valueText,
  double? score,
  String kanki,
  String explain, {
  bool entertainment = false,
}) =>
    LabResult(
      id: id,
      emoji: emoji,
      title: title,
      valueText: valueText,
      score: score,
      kanki: kanki,
      explain: explain,
      entertainment: entertainment,
    );
