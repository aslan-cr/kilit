import 'package:http/http.dart' as http;
import '../data/models.dart';
import 'api_client.dart';

/// Bir saatin hava kalitesi (CAMS, Open-Meteo Air Quality API).
class AirPoint {
  final DateTime time;
  final double aqi, pm25, pm10, ozone, no2; // Avrupa HKİ; µg/m³
  const AirPoint(this.time, this.aqi, this.pm25, this.pm10, this.ozone, this.no2);
}

/// Avrupa Hava Kalitesi İndeksi kademeleri (EEA): 0–20 iyi … 100+ aşırı kötü.
class Aqi {
  static String label(double v) => v < 20 ? 'İyi' : v < 40 ? 'Makul' : v < 60 ? 'Orta' : v < 80 ? 'Kötü' : v < 100 ? 'Çok kötü' : 'Aşırı kötü';

  static String advice(double v) => v < 20
      ? 'Hava tertemiz kanki, dışarıda spor için ideal.'
      : v < 40
          ? 'Hava temiz sayılır; herkes için uygun.'
          : v < 60
              ? 'Astım ya da kalp rahatsızlığı olanlar dışarıda yorucu sporu azaltsın.'
              : v < 80
                  ? 'Dışarıda uzun süre ağır efordan kaçın; hassas olanlar içeride kalsın.'
                  : 'Hava kirli: dışarıda spor yapma, pencereleri kapalı tut.';

  /// EEA ölçeğine yakın renkler.
  static int color(double v) => v < 20 ? 0xFF50C8A8 : v < 40 ? 0xFF50AF5A : v < 60 ? 0xFFE5B814 : v < 80 ? 0xFFF2643D : v < 100 ? 0xFFC0344B : 0xFF7D2181;
}

class AirService {
  /// Şimdiden itibaren ~3 günlük saatlik hava kalitesi tahmini.
  static Future<List<AirPoint>> forecast(GeoPoint2 p, {http.Client? client}) async {
    final j = asMap(await getJson(client ?? http.Client(), Uri.https('air-quality-api.open-meteo.com', '/v1/air-quality', {
      'latitude': coord(p.lat),
      'longitude': coord(p.lon),
      'hourly': 'european_aqi,pm2_5,pm10,ozone,nitrogen_dioxide',
      'past_days': '1',
      'forecast_days': '3',
      'timezone': 'auto',
    })));
    return parse(asMap(j['hourly']));
  }

  /// Saf ayrıştırma (test edilebilir).
  static List<AirPoint> parse(Map<String, dynamic> h) {
    final t = strList(h['time']);
    final a = numList(h['european_aqi']), p25 = numList(h['pm2_5']), p10 = numList(h['pm10']), o3 = numList(h['ozone']), no2 = numList(h['nitrogen_dioxide']);
    return [
      for (var i = 0; i < t.length; i++)
        if (opt(a, i) != null) AirPoint(DateTime.parse(t[i]), opt(a, i)!, opt(p25, i) ?? 0, opt(p10, i) ?? 0, opt(o3, i) ?? 0, opt(no2, i) ?? 0),
    ];
  }
}
