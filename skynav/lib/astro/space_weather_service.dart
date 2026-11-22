import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

/// NOAA SWPC uzay havası verisi (API anahtarı gerekmez).
///
/// [SpaceWeather.auroraProbAtLat] OVATION modelinin yüzde (0-100) cinsinden aurora
/// olasılığıdır; verilen konuma en yakın grid noktasından alınır.
typedef SpaceWeather = ({double kp, String stormLevelTr, double auroraProbAtLat});

const Duration _timeout = Duration(seconds: 12);

final Uri _kpUri = Uri.parse(
  'https://services.swpc.noaa.gov/products/noaa-planetary-k-index.json',
);
final Uri _ovationUri = Uri.parse(
  'https://services.swpc.noaa.gov/json/ovation_aurora_latest.json',
);

/// [lat] (-90..90) ve [lon] (-180..180, doğu pozitif) için güncel Kp, fırtına
/// seviyesi ve aurora olasılığını döndürür. Hata/zaman aşımında exception fırlatır.
Future<SpaceWeather> fetchSpaceWeather(
  double lat,
  double lon, {
  http.Client? client,
}) async {
  if (lat < -90 || lat > 90) {
    throw RangeError.range(lat, -90, 90, 'lat');
  }
  final c = client ?? http.Client();
  try {
    final results = await Future.wait([
      _getJson(c, _kpUri),
      _getJson(c, _ovationUri),
    ]);
    final kp = parseLatestKp(results[0]);
    final aurora = auroraProbabilityAt(results[1], lat, lon);
    return (
      kp: kp,
      stormLevelTr: stormLevelTr(kp),
      auroraProbAtLat: aurora,
    );
  } finally {
    if (client == null) c.close();
  }
}

Future<Object?> _getJson(http.Client c, Uri uri) async {
  final res = await c.get(uri).timeout(_timeout);
  if (res.statusCode != 200) {
    throw Exception('NOAA SWPC HTTP ${res.statusCode}: ${uri.path}');
  }
  return jsonDecode(utf8.decode(res.bodyBytes));
}

/// Kp serisinden en güncel geçerli değeri alır. Hem dizi-of-dizi (başlık satırlı)
/// hem de dizi-of-nesne biçimlerini destekler.
double parseLatestKp(Object? json) {
  if (json is! List || json.isEmpty) {
    throw const FormatException('Kp verisi boş veya geçersiz');
  }
  for (final row in json.reversed) {
    double? kp;
    if (row is Map) {
      kp = _toDouble(row['Kp'] ?? row['kp']);
    } else if (row is List && row.length >= 2) {
      kp = _toDouble(row[1]); // başlık satırındaki "Kp" metni burada elenir
    }
    if (kp != null) return kp;
  }
  throw const FormatException('Kp değeri bulunamadı');
}

/// NOAA jeomanyetik fırtına (G) ölçeği. Kp 4.67 (5-) G0 sayılır, G1 için Kp >= 5.
String stormLevelTr(double kp) {
  if (kp >= 9) return 'G5 - Aşırı jeomanyetik fırtına';
  if (kp >= 8) return 'G4 - Çok şiddetli fırtına';
  if (kp >= 7) return 'G3 - Şiddetli fırtına';
  if (kp >= 6) return 'G2 - Orta fırtına';
  if (kp >= 5) return 'G1 - Hafif fırtına';
  return 'Sakin (G0)';
}

/// OVATION grid'inde [lat]/[lon]'a en yakın noktanın aurora olasılığı (yüzde).
double auroraProbabilityAt(Object? json, double lat, double lon) {
  if (json is! Map || json['coordinates'] is! List) {
    throw const FormatException('OVATION verisi geçersiz');
  }
  final coords = json['coordinates'] as List;
  final lon360 = ((lon % 360) + 360) % 360;
  final cosLat = _cosDeg(lat);

  double bestD = double.infinity;
  double? bestVal;
  for (final p in coords) {
    if (p is! List || p.length < 3) continue;
    final gLon = _toDouble(p[0]);
    final gLat = _toDouble(p[1]);
    final val = _toDouble(p[2]);
    if (gLon == null || gLat == null || val == null) continue;
    var dLon = (gLon - lon360).abs();
    if (dLon > 180) dLon = 360 - dLon;
    final dLat = gLat - lat;
    // Kutuplara yaklaşırken boylam farkı küçülür; kabaca ağırlıklandırma.
    final d = dLat * dLat + (dLon * cosLat) * (dLon * cosLat);
    if (d < bestD) {
      bestD = d;
      bestVal = val;
    }
  }
  if (bestVal == null) {
    throw const FormatException('OVATION grid noktası bulunamadı');
  }
  return bestVal;
}

double _cosDeg(double deg) => math.cos(deg * math.pi / 180.0);

double? _toDouble(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.trim());
  return null;
}
