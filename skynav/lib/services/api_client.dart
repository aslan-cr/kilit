// Servisler arası ortak yardımcılar: HTTP+JSON, zaman aşımı, güvenli parse. Saf Dart.
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Tüm ağ çağrılarında ortak zaman aşımı.
const Duration kNetTimeout = Duration(seconds: 12);

/// GET + JSON. Boş gövde -> null. HTTP != 200 ise Exception fırlatır.
/// Zaman aşımı TimeoutException olarak yukarı taşınır.
Future<dynamic> getJson(http.Client client, Uri uri) async {
  final res = await client
      .get(uri, headers: const {'Accept': 'application/json'})
      .timeout(kNetTimeout);
  if (res.statusCode != 200) {
    final snippet = res.body.length > 200 ? res.body.substring(0, 200) : res.body;
    throw Exception('HTTP ${res.statusCode} (${uri.host}): $snippet');
  }
  final text = utf8.decode(res.bodyBytes).trim();
  return text.isEmpty ? null : jsonDecode(text);
}

double? toD(Object? v) => v is num ? v.toDouble() : null;

Map<String, dynamic> asMap(Object? v) =>
    v is Map<String, dynamic> ? v : const <String, dynamic>{};

List<double?> numList(Object? v) =>
    v is List ? [for (final e in v) toD(e)] : const <double?>[];

List<String> strList(Object? v) =>
    v is List ? [for (final e in v) if (e is String) e] : const <String>[];

String strOf(Object? v) => v is String ? v : '';

/// Koordinat metne çevrilir (üstel gösterim olmadan).
String coord(double v) => v.toStringAsFixed(4);

double? opt(List<double?> l, int i) => (i >= 0 && i < l.length) ? l[i] : null;

double at(List<double?> l, int i) => opt(l, i) ?? 0.0;

/// [from, from+n) aralığındaki boş olmayan değerler.
List<double> window(List<double?> l, int from, int n) {
  final out = <double>[];
  for (var k = from < 0 ? 0 : from; k < from + n && k < l.length; k++) {
    final v = l[k];
    if (v != null) out.add(v);
  }
  return out;
}

double sumOf(List<double> l) => l.fold(0.0, (a, b) => a + b);

double? meanOf(List<double> l) => l.isEmpty ? null : sumOf(l) / l.length;

/// Zaman dizisinde nowIso'dan büyük olmayan son indeks (dizi sıralı varsayılır).
int idxAtOrBefore(List<String> times, String nowIso) {
  var idx = 0;
  for (var i = 0; i < times.length; i++) {
    if (times[i].compareTo(nowIso) <= 0) {
      idx = i;
    } else {
      break;
    }
  }
  return idx;
}

/// Şu anki UTC saat, Open-Meteo "YYYY-MM-DDTHH:00" biçiminde.
String utcHourIso() {
  final n = DateTime.now().toUtc();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${n.year}-${two(n.month)}-${two(n.day)}T${two(n.hour)}:00';
}
